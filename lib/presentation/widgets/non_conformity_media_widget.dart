// lib/presentation/widgets/non_conformity_media_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final int nonConformityId;
  final int inspectionId;
  final bool isReadOnly;
  final Function(String) onMediaAdded;

  const NonConformityMediaWidget({
    Key? key,
    required this.nonConformityId,
    required this.inspectionId,
    this.isReadOnly = false,
    required this.onMediaAdded,
  }) : super(key: key);

  @override
  State<NonConformityMediaWidget> createState() => _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadMedia();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);

    try {
      if (_isOffline) {
        // Carregar mídia do banco local
        final mediaList = await LocalDatabaseService.getNonConformityMedia(widget.nonConformityId);
        setState(() {
          _mediaItems = mediaList;
          _isLoading = false;
        });
      } else {
        // Carregar do Supabase
        try {
          final mediaList = await _supabase
              .from('non_conformity_media')
              .select('id, url, type, created_at')
              .eq('non_conformity_id', widget.nonConformityId)
              .order('created_at', ascending: false);

          setState(() {
            _mediaItems = List<Map<String, dynamic>>.from(mediaList);
            _isLoading = false;
          });
        } catch (e) {
          print('Erro ao carregar mídia do Supabase: $e');
          // Se falhar online, tenta carregar do local também
          final mediaList = await LocalDatabaseService.getNonConformityMedia(widget.nonConformityId);
          setState(() {
            _mediaItems = mediaList;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar mídia: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Forçar modo paisagem para captura
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );

      // Restaurar orientações
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Criar diretório para mídias
      final mediaDir = await _getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'nc_${widget.nonConformityId}_img_$timestamp${path.extension(pickedFile.path)}';
      final localPath = '${mediaDir.path}/$filename';

      // Copiar arquivo para diretório de mídia
      final file = File(pickedFile.path);
      await file.copy(localPath);

      print('Arquivo salvo localmente em: $localPath');

      if (!_isOffline) {
        // Se estiver online, tenta enviar ao Supabase
        try {
          print('Tentando fazer upload para Supabase...');
          
          // Primeiro verificar tamanho do arquivo
          final fileSize = await file.length();
          print('Tamanho do arquivo: ${fileSize / 1024} KB');
          
          // Verificar se o bucket existe
          try {
            final buckets = await _supabase.storage.listBuckets();
            print('Buckets disponíveis: ${buckets.map((b) => b.name).join(", ")}');
            
            // Se não encontrar o bucket, tente criar
            if (!buckets.any((b) => b.name == 'non_conformity_media')) {
              print('Bucket não encontrado, tentando criar...');
              try {
                await _supabase.storage.createBucket('non_conformity_media');
                print('Bucket criado com sucesso');
              } catch (e) {
                print('Erro ao criar bucket: $e');
              }
            }
          } catch (e) {
            print('Erro ao listar buckets: $e');
          }
          
          // Criar caminho para o arquivo
          final storagePath = 'inspections/${widget.inspectionId}/non_conformities/${widget.nonConformityId}/$filename';
          print('Caminho no storage: $storagePath');
          
          try {
            // Tentar fazer upload diretamente
            final storageResponse = await _supabase.storage
                .from('non_conformity_media')
                .upload(storagePath, file);
                
            print('Upload bem-sucedido: $storageResponse');

            final publicUrl = _supabase.storage
                .from('non_conformity_media')
                .getPublicUrl(storageResponse);
                
            print('URL pública: $publicUrl');

            // Inserir referência no banco
            try {
              await _supabase.from('non_conformity_media').insert({
                'non_conformity_id': widget.nonConformityId,
                'type': 'image',
                'url': publicUrl,
                'created_at': DateTime.now().toIso8601String(),
              });
              
              print('Referência inserida no banco');
            } catch (e) {
              print('Erro ao inserir referência no banco: $e');
            }
          } catch (e) {
            print('Erro no upload: $e');
          }
        } catch (e) {
          print('Erro geral ao enviar imagem para o Supabase: $e');
        }
      }

      // Sempre salvar localmente, independente do upload
      await LocalDatabaseService.saveNonConformityMedia(
        widget.nonConformityId,
        localPath,
        'image',
      );

      // Adicionar à lista local
      setState(() {
        _mediaItems.add({
          'path': localPath,
          'type': 'image',
          'timestamp': DateTime.now().toIso8601String(),
          'isLocal': true,
        });
      });

      // Notificar adição
      widget.onMediaAdded(localPath);
      
      // Mostrar mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem salva com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erro ao capturar imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      // Forçar modo paisagem para captura
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 1),
      );

      // Restaurar orientações
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Criar diretório para mídias
      final mediaDir = await _getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'nc_${widget.nonConformityId}_vid_$timestamp${path.extension(pickedFile.path)}';
      final localPath = '${mediaDir.path}/$filename';

      // Copiar arquivo para diretório de mídia
      final file = File(pickedFile.path);
      await file.copy(localPath);
      
      print('Vídeo salvo localmente em: $localPath');

      // Sempre salvar localmente, independente do upload
      await LocalDatabaseService.saveNonConformityMedia(
        widget.nonConformityId,
        localPath,
        'video',
      );

      // Adicionar à lista local
      setState(() {
        _mediaItems.add({
          'path': localPath,
          'type': 'video',
          'timestamp': DateTime.now().toIso8601String(),
          'isLocal': true,
        });
      });

      // Notificar adição
      widget.onMediaAdded(localPath);
      
      // Mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vídeo salvo com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erro ao capturar vídeo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar vídeo: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMedia(Map<String, dynamic> media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover mídia'),
        content: const Text('Tem certeza que deseja remover esta mídia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      if (media.containsKey('isLocal') && media['isLocal'] == true) {
        // Remover mídia local
        await LocalDatabaseService.deleteNonConformityMedia(
          widget.nonConformityId,
          media['path'],
        );
      } else if (!_isOffline && media.containsKey('id')) {
        // Remover do Supabase
        try {
          await _supabase
              .from('non_conformity_media')
              .delete()
              .eq('id', media['id']);

          // Se tiver URL, tenta deletar do storage
          if (media.containsKey('url')) {
            final uri = Uri.parse(media['url']);
            final storageFilePath = uri.pathSegments.join('/');
            await _supabase.storage.from('non_conformity_media').remove([storageFilePath]);
          }
        } catch (e) {
          print('Erro ao remover mídia do Supabase: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao remover mídia: $e')),
          );
        }
      }

      // Remover da lista local
      setState(() {
        if (media.containsKey('id')) {
          _mediaItems.removeWhere((item) => item['id'] == media['id']);
        } else if (media.containsKey('path')) {
          _mediaItems.removeWhere((item) => item['path'] == media['path']);
        }
      });
    } catch (e) {
      print('Erro ao remover mídia: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover mídia: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/nc_media');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título e botões de mídia
        Row(
          children: [
            const Expanded(
              child: Text(
                'Arquivos de Mídia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Adicione explicitamente os botões de mídia, mesmo que não esteja em modo somente leitura
        if (!widget.isReadOnly) 
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Foto'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Vídeo'),
                  onPressed: () => _pickVideo(ImageSource.camera),
                ),
              ),
            ],
          ),
                
        const SizedBox(height: 8),
        
        if (!widget.isReadOnly)
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeria'),
            onPressed: () => _pickImage(ImageSource.gallery),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          
        // Separador
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        
        // Indicador de carregamento
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_mediaItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nenhum arquivo de mídia adicionado'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mídia Salva:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final media = _mediaItems[index];
                    final bool isImage = media['type'] == 'image';
                    final bool isLocal = media.containsKey('isLocal') && media['isLocal'] == true;
                    
                    // Determinar o widget a mostrar (imagem local, imagem remota, vídeo, etc.)
                    Widget mediaWidget;
                    
                    if (isImage) {
                      if (isLocal && media.containsKey('path')) {
                        // Imagem salva localmente
                        mediaWidget = Image.file(
                          File(media['path']),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        );
                      } else if (media.containsKey('url')) {
                        // Imagem do Supabase
                        mediaWidget = Image.network(
                          media['url'],
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        );
                      } else {
                        // Fallback
                        mediaWidget = Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        );
                      }
                    } else {
                      // Vídeo (ícone de vídeo com fundo)
                      mediaWidget = Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          // Conteúdo da mídia
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: mediaWidget,
                          ),
                          
                          // Botão para remover mídia
                          if (!widget.isReadOnly)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeMedia(media),
                                ),
                              ),
                            ),
                          
                          // Indicador de tipo de mídia
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isImage ? 'Foto' : 'Vídeo',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }
  }
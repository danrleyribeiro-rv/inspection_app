// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/hierarchical_inspection_view.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/loading_state.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/sync/sync_progress_overlay.dart';
import 'package:lince_inspecoes/services/navigation_state_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> with WidgetsBindingObserver {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  bool _isLoading = true;
  final bool _isSyncing = false;
  bool _isApplyingTemplate = false;
  bool _isAvailableOffline =
      false; // Track if inspection is fully available offline
  bool _canEdit =
      false; // Track if user can edit (based on offline availability)
  Inspection? _inspection;
  List<Topic> _topics = [];
  final Map<String, List<Item>> _itemsCache = {};
  final Map<String, List<Detail>> _detailsCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToConnectivity();
    _loadInspection();
    // Limpa estados de navegação antigos em background
    NavigationStateService.cleanupOldStates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Reload data when app resumes to ensure consistency
      _loadInspection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Limpar overlay ao sair da tela
    SyncProgressOverlay.hide();
    // Sincronizar ao sair da tela
    _syncOnExit();
    super.dispose();
  }

  Future<void> _syncOnExit() async {
    // OFFLINE-FIRST: Never auto-sync on exit
    // Users must manually sync when they want to upload changes
    debugPrint(
        'InspectionDetailScreen: Exiting without auto-sync (offline-first mode)');
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        // Network status updated (removed _isOnline field)

        // OFFLINE-FIRST: Don't automatically apply templates when coming online
        // Templates should be applied only through manual user action
      }
    });

    Connectivity().checkConnectivity().then((connectivityResult) {
      if (mounted) {
        // Initial connectivity check (removed _isOnline field)
      }
    });
  }

  Future<void> _loadInspection() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Check if inspection is fully downloaded
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      _isAvailableOffline = inspection != null;
      _canEdit = _isAvailableOffline;

      if (_isAvailableOffline) {
        // Load from offline storage (OFFLINE-FIRST)
        final offlineInspection = await _serviceFactory.dataService
            .getInspection(widget.inspectionId);
        if (offlineInspection != null) {
          setState(() {
            _inspection = offlineInspection;
          });

          // Marcar como "em progresso" apenas se estiver pending
          if (offlineInspection.status == 'pending') {
            await _markAsInProgress();
          }

          await _loadAllData();
        } else {
          _showErrorSnackBar('Erro ao carregar inspeção offline.');
        }
      } else {
        // Inspection not downloaded - show download dialog
        _showOfflineRequiredDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAllData() async {
    debugPrint('InspectionDetailScreen: _loadAllData() called - Stack trace:');
    debugPrint(StackTrace.current.toString().split('\n').take(8).join('\n'));
    
    if (_inspection?.id == null) return;

    try {
      // Clear cache before reloading to ensure consistency
      _itemsCache.clear();
      _detailsCache.clear();

      // Carregar todos os tópicos
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);

      // Carregar todos os itens e detalhes em paralelo
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = topics[topicIndex];

        // Carregar itens do tópico - use fallback if ID is null
        final topicId = topic.id ?? 'topic_$topicIndex';
        
        // Verificar se o tópico tem detalhes diretos
        if (topic.directDetails == true) {
          // Para tópicos com detalhes diretos, carregar detalhes diretamente
          final directDetails = await _serviceFactory.dataService.getDirectDetails(topicId);
          _detailsCache['${topicId}_direct'] = directDetails;
          debugPrint('InspectionDetailScreen: Loaded ${directDetails.length} direct details for topic $topicId');
          // Não carregar itens para tópicos com detalhes diretos
          _itemsCache[topicId] = [];
        } else {
          // Para tópicos normais, carregar itens e seus detalhes
          final items = await _serviceFactory.dataService.getItems(topicId);
          _itemsCache[topicId] = items;

          // Carregar detalhes de cada item
          for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
            final item = items[itemIndex];
            final itemId = item.id ?? 'item_$itemIndex';
            final details = await _serviceFactory.dataService.getDetails(itemId);
            _detailsCache['${topicId}_$itemId'] = details;
            debugPrint('InspectionDetailScreen: Loaded ${details.length} details for item $itemId');
          }
        }
      }

      if (mounted) {
        setState(() {
          _topics = topics;
        });
        debugPrint('InspectionDetailScreen: Successfully loaded ${topics.length} topics with cache refreshed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar dados: $e');
      }
    }
  }



  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showOfflineRequiredDialog() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Necessário'),
            content: const Text(
                'Esta inspeção está apenas parcialmente disponível. Para editar, '
                'você precisa baixar todos os dados e mídias. Deseja baixar agora?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Also close inspection screen
                },
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _downloadInspectionForOffline();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F4B99),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Baixar'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _downloadInspectionForOffline() async {
    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _OfflineDownloadDialog(inspectionId: widget.inspectionId),
    );

    try {
      await _serviceFactory.syncService.syncInspection(widget.inspectionId);

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      setState(() {
        _isAvailableOffline = true;
        _canEdit = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Inspeção baixada com sucesso! Agora você pode editá-la offline.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload inspection from offline storage
      await _loadInspection();
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar inspeção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Removed _convertDateTimesToTimestamps - handled by cache service now

  Future<void> _addTopic() async {
    // Check if user can edit
    if (!_canEdit) {
      _showOfflineRequiredDialog();
      return;
    }

    // Use offline-capable dialog that works with cached templates
    final result = await showDialog<Topic>(
      context: context,
      builder: (context) => OfflineTemplateTopicSelectorDialog(
        inspectionId: widget.inspectionId,
        templateId: _inspection?.templateId,
      ),
    );

    if (result == null || !mounted) return;

    try {
      // Adicionar o tópico à estrutura aninhada da inspeção
      await _addTopicToNestedStructure(result);

      await _markAsModified();

      // Reload data to ensure consistency
      await _loadAllData();

      if (mounted) {
        setState(() {}); // Trigger UI update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico adicionado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar interface: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTopicToNestedStructure(Topic topic) async {
    if (_inspection == null) return;

    try {
      // Verificar se o tópico tem ID válido
      if (topic.id == null) {
        debugPrint('InspectionDetailScreen: Topic ID is null, cannot add to nested structure');
        return;
      }
      
      // Buscar itens criados para este tópico
      final items = await _serviceFactory.dataService.getItems(topic.id!);
      debugPrint('InspectionDetailScreen: Found ${items.length} items for topic ${topic.id}');
      
      // Criar estrutura dos itens com seus detalhes
      final List<Map<String, dynamic>> itemsData = [];
      for (final item in items) {
        if (item.id == null) {
          debugPrint('InspectionDetailScreen: Item ID is null, skipping item');
          continue;
        }
        
        final details = await _serviceFactory.dataService.getDetails(item.id!);
        debugPrint('InspectionDetailScreen: Found ${details.length} details for item ${item.id}');
        
        final List<Map<String, dynamic>> detailsData = [];
        for (final detail in details) {
          try {
            detailsData.add({
              'name': detail.detailName,
              'value': detail.detailValue ?? '',
              'type': detail.type ?? 'text',
              'options': detail.options ?? [],
              'required': detail.isRequired ?? false,
              'observation': detail.observation ?? '',
              'media': [],
              'non_conformities': [],
            });
          } catch (e) {
            debugPrint('InspectionDetailScreen: Error processing detail ${detail.id}: $e');
            // Continue com outros detalhes se um falhar
          }
        }
        
        itemsData.add({
          'name': item.itemName,
          'description': item.itemLabel ?? '',
          'observation': item.observation ?? '',
          'details': detailsData,
          'media': [],
          'non_conformities': [],
        });
      }
      
      // Criar estrutura do tópico como seria no Firestore
      final topicData = {
        'name': topic.topicName,
        'description': topic.topicLabel ?? '',
        'observation': topic.observation ?? '',
        'items': itemsData,
        'media': [],
        'non_conformities': [],
      };
      
      debugPrint('InspectionDetailScreen: Created topic data with ${itemsData.length} items');

      // Obter os topics atuais da inspeção
      final currentTopics =
          List<Map<String, dynamic>>.from(_inspection!.topics ?? []);

      // Adicionar o novo tópico
      currentTopics.add(topicData);

      // Atualizar a inspeção com a nova estrutura
      final updatedInspection = _inspection!.copyWith(topics: currentTopics);

      try {
        // Atualizar no banco local (não inserir novamente)
        await _serviceFactory.dataService.updateInspection(updatedInspection);
        debugPrint('InspectionDetailScreen: Updated inspection in database');
      } catch (e) {
        debugPrint('InspectionDetailScreen: Error updating inspection: $e');
        rethrow;
      }

      try {
        // Processar a estrutura aninhada atualizada
        await _serviceFactory.syncService.syncInspection(widget.inspectionId);
        debugPrint('InspectionDetailScreen: Synced inspection');
      } catch (e) {
        debugPrint('InspectionDetailScreen: Error syncing inspection: $e');
        // Não deve impedir a atualização da interface
      }

      // Atualizar o estado local
      _inspection = updatedInspection;

      debugPrint(
          'InspectionDetailScreen: Added topic to nested structure successfully');
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error adding topic to nested structure: $e');
      rethrow;
    }
  }

  Future<void> _markAsInProgress() async {
    try {
      // Verificar se ainda está pending antes de atualizar
      final currentInspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (currentInspection?.status == 'pending') {
        await _serviceFactory.dataService
            .updateInspectionStatus(widget.inspectionId, 'in_progress');
        debugPrint(
            'InspectionDetailScreen: Marked inspection ${widget.inspectionId} as in progress');
      } else {
        debugPrint(
            'InspectionDetailScreen: Inspection ${widget.inspectionId} is already ${currentInspection?.status}, not changing to in_progress');
      }
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error marking inspection as in progress: $e');
    }
  }

  Future<void> _markAsModified() async {
    try {
      await _serviceFactory.dataService
          .updateInspectionStatus(widget.inspectionId, 'modified');
      debugPrint(
          'InspectionDetailScreen: Marked inspection ${widget.inspectionId} as modified');
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error marking inspection as modified: $e');
    }
  }

  Future<void> _updateCache() async {
    debugPrint('InspectionDetailScreen: _updateCache() called - Stack trace:');
    debugPrint(StackTrace.current.toString().split('\n').take(5).join('\n'));
    
    await _markAsModified();
    
    // Atualização completa - recarregar todos os dados após operações como duplicação
    await _loadAllData();
  }

  double _calculateInspectionProgress() {
    if (_topics.isEmpty) return 0.0;
    
    int totalUnits = 0;  // Total de unidades avaliáveis (detalhes + itens avaliáveis)
    int completedUnits = 0;  // Unidades completadas
    
    for (final topic in _topics) {
      final topicId = topic.id ?? 'topic_${_topics.indexOf(topic)}';
      
      // Hierarquia flexível: Verificar se tem detalhes diretos
      if (topic.directDetails == true) {
        // Para tópicos com detalhes diretos
        final directDetailsKey = '${topicId}_direct';
        final details = _detailsCache[directDetailsKey] ?? [];
        
        for (final detail in details) {
          totalUnits++;
          if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
            completedUnits++;
          }
        }
      } else {
        // Para tópicos normais com itens
        final items = _itemsCache[topicId] ?? [];
        
        for (final item in items) {
          final itemId = item.id ?? 'item_${items.indexOf(item)}';
          
          // Contar item avaliável como unidade se for avaliável
          if (item.evaluable == true) {
            totalUnits++;
            if (item.evaluationValue != null && item.evaluationValue!.isNotEmpty) {
              completedUnits++;
            }
          }
          
          // Contar detalhes do item
          final details = _detailsCache['${topicId}_$itemId'] ?? [];
          for (final detail in details) {
            totalUnits++;
            if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
              completedUnits++;
            }
          }
        }
      }
    }
    
    return totalUnits > 0 ? completedUnits / totalUnits : 0.0;
  }


  Future<void> _exportInspection() async {
    if (!mounted) return;

    try {
      // Criar um backup completo da inspeção
      final Map<String, dynamic> exportData = {
        'inspection': _inspection?.toMap(),
        'topics': _topics.map((topic) => topic.toMap()).toList(),
        'items': <String, dynamic>{},
        'details': <String, dynamic>{},
        'media': <String, dynamic>{},
        'non_conformities': <String, dynamic>{},
      };

      // Coletar todos os itens
      final itemsMap = exportData['items'] as Map<String, dynamic>;
      final detailsMap = exportData['details'] as Map<String, dynamic>;
      
      for (final topic in _topics) {
        final topicId = topic.id ?? 'topic_${_topics.indexOf(topic)}';
        final items = _itemsCache[topicId] ?? [];
        itemsMap[topicId] = items.map((item) => item.toMap()).toList();

        // Coletar detalhes para cada item
        for (final item in items) {
          final itemId = item.id ?? 'item_${items.indexOf(item)}';
          final details = _detailsCache['${topicId}_$itemId'] ?? [];
          detailsMap['${topicId}_$itemId'] = details.map((detail) => detail.toMap()).toList();
        }
      }

      // Coletar mídias
      final allMedia = await _serviceFactory.mediaService.getMediaByInspection(widget.inspectionId);
      exportData['media'] = allMedia.map((media) => media.toMap()).toList();

      // Coletar não conformidades
      final allNCs = await _serviceFactory.dataService.getNonConformities(widget.inspectionId);
      exportData['non_conformities'] = allNCs.map((nc) => nc.toMap()).toList();

      // Criar arquivo ZIP
      final archive = Archive();
      
      // Adicionar arquivo JSON ao ZIP
      final jsonString = jsonEncode(exportData);
      final jsonBytes = utf8.encode(jsonString);
      final jsonFile = ArchiveFile('inspection_data.json', jsonBytes.length, jsonBytes);
      archive.addFile(jsonFile);

      // Adicionar imagens ao ZIP
      for (final media in allMedia) {
        try {
          if (media.localPath.isNotEmpty) {
            final imageFile = File(media.localPath);
            if (await imageFile.exists()) {
              final imageBytes = await imageFile.readAsBytes();
              final fileName = media.filename;
              final archiveImageFile = ArchiveFile('images/$fileName', imageBytes.length, imageBytes);
              archive.addFile(archiveImageFile);
            }
          }
        } catch (e) {
          debugPrint('Erro ao adicionar imagem ${media.filename}: $e');
        }
      }

      // Gerar o arquivo ZIP
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Erro ao criar arquivo ZIP');
      }

      // Obter diretório para salvar o arquivo
      Directory? directory;
      
      try {
        if (Platform.isAndroid) {
          // Tentar usar Downloads primeiro
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            // Fallback para diretório externo da aplicação
            directory = await getExternalStorageDirectory();
          }
          // Se ainda não conseguir, usar diretório interno da aplicação
          if (directory == null || !await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
          }
        } else {
          // Para iOS e outras plataformas
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        debugPrint('Erro ao acessar diretório: $e');
        // Fallback final para diretório interno
        directory = await getApplicationDocumentsDirectory();
      }


      // Criar pasta "Lince Inspeções" se não existir
      final linceDirectory = Directory('${directory.path}/Lince Inspeções');
      if (!await linceDirectory.exists()) {
        await linceDirectory.create(recursive: true);
      }

      // Salvar o arquivo ZIP
      final fileName = 'inspecao_${_inspection?.cod ?? 'export'}_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File('${linceDirectory.path}/$fileName');
      await zipFile.writeAsBytes(zipBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inspeção exportada como ZIP!'),
                const SizedBox(height: 4),
                Text(
                  'Local: ${zipFile.path}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ABRIR',
              textColor: Colors.white,
              onPressed: () => _openExportedFile(zipFile.path),
            ),
          ),
        );
      }

      debugPrint('Inspection exported successfully as ZIP: ${zipFile.path}');
      debugPrint('ZIP contains JSON data and ${allMedia.length} images');

    } catch (e) {
      debugPrint('Error exporting inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openExportedFile(String filePath) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivo Exportado com Sucesso!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text('O arquivo ZIP foi salvo em:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Você pode compartilhar o arquivo ou encontrá-lo no gerenciador de arquivos.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: 'Inspeção exportada - ${_inspection?.cod ?? 'Lince Inspeções'}',
                );
              } catch (e) {
                debugPrint('Erro ao compartilhar arquivo: $e');
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Erro ao compartilhar: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6F4B99),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importInspection() async {
    if (!mounted) return;

    try {
      // Criar um diálogo de seleção de arquivo
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importar Inspeção'),
          content: const Text(
              'Esta funcionalidade permite importar uma inspeção exportada anteriormente.\n\nDeseja continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Implementar importação usando createInspectionFromJson
      await _importFromVistoriaFlexivel();

    } catch (e) {
      debugPrint('Error importing inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importFromVistoriaFlexivel() async {
    if (!mounted) return;

    try {
      // Dados do Vistoria_Flexivel.json
      const vistoriaFlexivelData = {
        "title": "Flexível",
        "observation": null,
        "project_id": "DQOFavelUHcuwdEuPE4I",
        "template_id": "KrzoTXUdv1yRcYDWBND2",
        "inspector_id": "bSTmE0Ix6WbBMueqvZWfpKc3Ngy2",
        "status": "pending",
        "address": {
          "cep": "88062110",
          "street": "Rua Crisógono Vieira da Cruz",
          "number": "233",
          "complement": "",
          "neighborhood": "Lagoa da Conceição",
          "city": "Florianópolis",
          "state": "SC"
        },
        "address_string": "Rua Crisógono Vieira da Cruz, 233, Lagoa da Conceição, Florianópolis - SC",
        "is_templated": true,
        "area": "0",
        "topics": [
          {
            "name": "Novo Tópico 1",
            "description": null,
            "observation": null,
            "direct_details": false,
            "items": [
              {
                "name": "Novo Item 1",
                "description": null,
                "observation": null,
                "evaluable": true,
                "evaluation_options": ["a", "b", "c"],
                "evaluation_value": null,
                "details": [
                  {
                    "name": "Novo Detalhe 1",
                    "type": "text",
                    "required": false,
                    "options": [],
                    "value": null,
                    "observation": null,
                    "is_damaged": false,
                    "media": [],
                    "non_conformities": []
                  }
                ]
              }
            ]
          },
          {
            "name": "Novo Tópico 2",
            "description": null,
            "observation": null,
            "direct_details": true,
            "details": [
              {
                "name": "Novo Detalhe 1",
                "type": "select",
                "required": false,
                "options": ["a", "b", "c"],
                "value": null,
                "observation": null,
                "is_damaged": false,
                "media": [],
                "non_conformities": []
              }
            ]
          },
          {
            "name": "Novo Tópico 3",
            "description": null,
            "observation": null,
            "direct_details": true,
            "details": [
              {
                "name": "Novo Detalhe 1",
                "type": "boolean",
                "required": false,
                "options": [],
                "value": null,
                "observation": null,
                "is_damaged": false,
                "media": [],
                "non_conformities": []
              }
            ]
          }
        ],
        "cod": "INSP250715-001.TP0004",
        "deleted_at": null,
        "updated_at": {
          "_seconds": 1752625367,
          "_nanoseconds": 469000000
        },
        "created_at": {
          "_seconds": 1752625367,
          "_nanoseconds": 469000000
        }
      };

      // Usar o serviço de dados para processar a estrutura aninhada
      await _serviceFactory.dataService.createInspectionFromJson(vistoriaFlexivelData);

      // Recarregar a inspeção após importação
      await _loadInspection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vistoria_Flexivel.json importado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      debugPrint('Error importing Vistoria_Flexivel.json: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
        ),
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    if (!mounted) return;

    switch (value) {
      case 'import':
        await _importInspection();
        break;
      case 'export':
        await _exportInspection();
        break;
      case 'nonConformities':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NonConformityScreen(
              inspectionId: widget.inspectionId,
              initialTabIndex: 1, // Ir direto para a aba de listagem
            ),
          ),
        );
        break;
      case 'media':
        _navigateToMediaGallery();
        break;
      case 'refresh':
        await _loadInspection();
        break;
      case 'info':
        if (_inspection != null) {
          final inspectionId = _inspection!.id;
          int totalTopics = _topics.length;
          int totalItems = 0;
          int totalDetails = 0;
          int totalMedia = 0;

          for (final topic in _topics) {
            if (!mounted) return;
            final topicId = topic.id ?? 'topic_${_topics.indexOf(topic)}';
            final items = _itemsCache[topicId] ?? [];
            totalItems += items.length;
            for (final item in items) {
              if (!mounted) return;
              final itemId = item.id ?? 'item_${items.indexOf(item)}';
              final details = _detailsCache['${topicId}_$itemId'] ?? [];
              totalDetails += details.length;
            }
          }

          if (!mounted) return;
          final allMedia = await _serviceFactory.mediaService
              .getMediaByInspection(inspectionId);
          totalMedia = allMedia.length;

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => InspectionInfoDialog(
                inspection: _inspection!,
                totalTopics: totalTopics,
                totalItems: totalItems,
                totalDetails: totalDetails,
                totalMedia: totalMedia,
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _inspection?.cod ?? 'Inspeção',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isLoading && _topics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: LinearProgressIndicator(
                        value: _calculateInspectionProgress(),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _calculateInspectionProgress() >= 1.0 
                            ? Colors.green 
                            : Colors.white,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSyncing || _isApplyingTemplate)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          if (!(_isSyncing || _isApplyingTemplate))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(5),
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload),
                      SizedBox(width: 8),
                      Text('Importar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Exportar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Informações'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Conteúdo principal
          Expanded(
            child: _isLoading
                ? LoadingState(
                    isDownloading: false,
                    isApplyingTemplate: _isApplyingTemplate)
                : _topics.isEmpty
                    ? EmptyTopicState(onAddTopic: _addTopic)
                    : HierarchicalInspectionView(
                        inspectionId: widget.inspectionId,
                        topics: _topics,
                        itemsCache: _itemsCache,
                        detailsCache: _detailsCache,
                        onUpdateCache: _updateCache,
                      ),
          ),

          // Barra inferior
          if (keyboardHeight == 0 && !_isLoading && _topics.isNotEmpty)
            Container(
              padding: EdgeInsets.only(
                top: 4,
                bottom: bottomPadding + 4,
                left: 8,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF312456),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShortcutButton(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    onTap: _navigateToMediaGallery,
                    color: Colors.purple,
                  ),
                  _buildShortcutButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'NCs',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NonConformityScreen(
                            inspectionId: widget.inspectionId,
                            initialTabIndex: 1, // Ir direto para a aba de listagem
                          ),
                        ),
                      );
                    },
                    color: Colors.red,
                  ),
                  _buildShortcutButton(
                    icon: Icons.add_circle_outline,
                    label: '+ Tópico',
                    onTap: _canEdit
                        ? _addTopic
                        : () => _showOfflineRequiredDialog(),
                    color: _canEdit ? Color(0xFF6F4B99) : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.08).round()),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineDownloadDialog extends StatefulWidget {
  final String inspectionId;

  const _OfflineDownloadDialog({required this.inspectionId});

  @override
  State<_OfflineDownloadDialog> createState() => _OfflineDownloadDialogState();
}

class _OfflineDownloadDialogState extends State<_OfflineDownloadDialog> {
  final double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // No download progress listener needed for offline-first architecture
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Baixando Inspeção'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Baixando todos os dados e mídias...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%'),
          if (_progress > 0.2 && _progress < 1.0) ...[
            const SizedBox(height: 8),
            const Text(
              'Baixando mídias...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

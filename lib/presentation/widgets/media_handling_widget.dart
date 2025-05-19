import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:inspection_app/services/image_watermark_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MediaHandlingWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;

  const MediaHandlingWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.onMediaAdded,
    required this.onMediaDeleted,
  });

  @override
  State<MediaHandlingWidget> createState() => _MediaHandlingWidgetState();
}

class _MediaHandlingWidgetState extends State<MediaHandlingWidget> {
  final InspectionDataService _inspectionService = InspectionDataService();
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid();
  final _watermarkService = ImageWatermarkService();
  final _connectivity = Connectivity();

  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;
  bool _isProcessingVideo = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final inspection = await _inspectionService.getInspection(widget.inspectionId);
      if (inspection?.topics != null && 
          widget.topicIndex < inspection!.topics!.length) {
        
        final topic = inspection.topics![widget.topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        
        if (widget.itemIndex < items.length) {
          final item = items[widget.itemIndex];
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          
          if (widget.detailIndex < details.length) {
            final detail = details[widget.detailIndex];
            final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
            
            setState(() {
              _mediaItems = media.asMap().entries.map((entry) => {
                ...entry.value,
                'media_index': entry.key,
              }).toList();
              _isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        _mediaItems = [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading media: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final position = await _watermarkService.getCurrentLocation();
      String? address;

      if (position != null) {
        address = await _watermarkService.getAddressFromPosition(position);
      }

      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now();
      final filename = p.basename(pickedFile.path);
      final newFilename = 'img_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      final file = File(pickedFile.path);
      final watermarkedFile = await _watermarkService.addWatermarkToImage(
        file,
        isFromGallery: source == ImageSource.gallery,
        timestamp: timestamp,
        location: position,
        locationAddress: address,
      );

      final finalFile = await _watermarkService.addMetadataToImage(
        watermarkedFile,
        source == ImageSource.gallery,
        timestamp,
        location: position,
        locationAddress: address,
      );

      await finalFile.copy(localPath);

      final mediaData = <String, dynamic>{
        'id': _uuid.v4(),
        'type': 'image',
        'localPath': localPath,
        'created_at': timestamp.toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
      };

      // Try to upload to Firebase Storage
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
                      connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        try {
          final storagePath = 'inspections/${widget.inspectionId}/topic_${widget.topicIndex}/item_${widget.itemIndex}/detail_${widget.detailIndex}/$newFilename';
          final uploadTask = await _storage.ref(storagePath).putFile(
                File(localPath),
                SettableMetadata(contentType: 'image/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
              );

          final downloadUrl = await uploadTask.ref.getDownloadURL();
          mediaData['url'] = downloadUrl;
        } catch (e) {
          debugPrint('Error uploading to Firebase Storage: $e');
        }
      }

      await _inspectionService.addMedia(
        widget.inspectionId,
        widget.topicIndex,
        widget.itemIndex,
        widget.detailIndex,
        mediaData,
      );

      widget.onMediaAdded(localPath);
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem salva com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar imagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 1),
    );

    if (pickedFile == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processando vídeo com marca d\'água...'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    setState(() {
      _isLoading = true;
      _isProcessingVideo = true;
    });

    try {
      final position = await _watermarkService.getCurrentLocation();
      String? address;

      if (position != null) {
        address = await _watermarkService.getAddressFromPosition(position);
      }

      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now();
      final filename = p.basename(pickedFile.path);
      final newFilename = 'vid_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      final file = File(pickedFile.path);
      final watermarkedFile = await _watermarkService.addWatermarkToVideo(
        file,
        isFromGallery: source == ImageSource.gallery,
        timestamp: timestamp,
        location: position,
        locationAddress: address,
      );

      if (watermarkedFile.path != localPath) {
        await watermarkedFile.copy(localPath);
      }

      final mediaData = <String, dynamic>{
        'id': _uuid.v4(),
        'type': 'video',
        'localPath': localPath,
        'created_at': timestamp.toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
      };

      // Try to upload to Firebase Storage
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
                      connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        try {
          final storagePath = 'inspections/${widget.inspectionId}/topic_${widget.topicIndex}/item_${widget.itemIndex}/detail_${widget.detailIndex}/$newFilename';
          final uploadTask = await _storage.ref(storagePath).putFile(
                File(localPath),
                SettableMetadata(contentType: 'video/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
              );

          final downloadUrl = await uploadTask.ref.getDownloadURL();
          mediaData['url'] = downloadUrl;
        } catch (e) {
          debugPrint('Error uploading to Firebase Storage: $e');
        }
      }

      await _inspectionService.addMedia(
        widget.inspectionId,
        widget.topicIndex,
        widget.itemIndex,
        widget.detailIndex,
        mediaData,
      );

      widget.onMediaAdded(localPath);
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vídeo salvo com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar vídeo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessingVideo = false;
        });
      }
    }
  }

  Future<void> _deleteMedia(int mediaIndex, Map<String, dynamic> media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Mídia'),
        content: const Text('Tem certeza que deseja excluir este arquivo de mídia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete from storage if URL exists
      if (media['url'] != null) {
        try {
          final storageRef = _storage.refFromURL(media['url']);
          await storageRef.delete();
        } catch (e) {
          debugPrint('Error deleting from storage: $e');
        }
      }

      // Delete local file
      if (media['localPath'] != null) {
        try {
          final file = File(media['localPath']);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting local file: $e');
        }
      }

      // Remove from inspection document
      final inspection = await _inspectionService.getInspection(widget.inspectionId);
      if (inspection?.topics != null && 
          widget.topicIndex < inspection!.topics!.length) {
        
        final topics = List<Map<String, dynamic>>.from(inspection.topics!);
        final topic = topics[widget.topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        
        if (widget.itemIndex < items.length) {
          final item = items[widget.itemIndex];
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          
          if (widget.detailIndex < details.length) {
            final detail = Map<String, dynamic>.from(details[widget.detailIndex]);
            final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
            
            if (mediaIndex < mediaList.length) {
              mediaList.removeAt(mediaIndex);
              detail['media'] = mediaList;
              details[widget.detailIndex] = detail;
              item['details'] = details;
              items[widget.itemIndex] = item;
              topic['items'] = items;
              topics[widget.topicIndex] = topic;
              
              await _inspectionService._firestore.collection('inspections')
                  .doc(widget.inspectionId).update({
                'topics': topics,
                'updated_at': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      if (media['localPath'] != null) {
        widget.onMediaDeleted(media['localPath']);
      }

      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mídia excluída com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir mídia: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Directory> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');

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
        // Media capture buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar Foto'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _pickVideo(ImageSource.camera),
                icon: const Icon(Icons.videocam),
                label: const Text('Gravar Vídeo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Da Galeria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _pickVideo(ImageSource.gallery),
                icon: const Icon(Icons.video_library),
                label: const Text('Vídeo Galeria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Media display
        if (_isLoading)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                if (_isProcessingVideo)
                  const Text(
                    'Processando vídeo com marca d\'água...\nIsso pode levar alguns instantes.',
                    textAlign: TextAlign.center,
                  )
                else
                  const Text('Carregando...'),
              ],
            ),
          )
        else if (_mediaItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nenhuma mídia anexada'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mídias Anexadas:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final media = _mediaItems[index];
                    final isImage = media['type'] == 'image';
                    final hasUrl = media['url'] != null && (media['url'] as String).isNotEmpty;
                    final hasLocalPath = media['localPath'] != null && (media['localPath'] as String).isNotEmpty;

                    Widget displayWidget;
                    if (isImage) {
                      if (hasLocalPath) {
                        final file = File(media['localPath']);
                        if (file.existsSync()) {
                          displayWidget = Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, error, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, color: Colors.red),
                            ),
                          );
                        } else if (hasUrl) {
                          displayWidget = Image.network(
                            media['url'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (ctx, error, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error_outline, color: Colors.red),
                            ),
                          );
                        } else {
                          displayWidget = Container(
                            color: Colors.grey[300],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported),
                                SizedBox(height: 4),
                                Text('Sem Imagem', style: TextStyle(fontSize: 10))
                              ]
                            ),
                          );
                        }
                      } else if (hasUrl) {
                        displayWidget = Image.network(
                          media['url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (ctx, error, _) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.cloud_off, color: Colors.orange),
                          ),
                        );
                      } else {
                        displayWidget = Container(
                          color: Colors.grey[300],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image),
                              SizedBox(height: 4),
                              Text('Sem Fonte', style: TextStyle(fontSize: 10))
                            ]
                          ),
                        );
                      }
                    } else {
                      displayWidget = Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.video_file, size: 50, color: Colors.grey),
                        ),
                      );
                      
                      if (!hasLocalPath && !hasUrl) {
                        displayWidget = Container(
                          color: Colors.grey[300],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off),
                              SizedBox(height: 4),
                              Text('Sem Fonte', style: TextStyle(fontSize: 10))
                            ]
                          ),
                        );
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: displayWidget,
                            ),
                          ),

                          // Action buttons
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                onPressed: () => _deleteMedia(index, media),
                                tooltip: 'Excluir Mídia',
                                constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),

                          // Media type indicator
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isImage ? 'Foto' : 'Vídeo',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
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
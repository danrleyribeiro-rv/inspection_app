import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import FieldValue
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final int ncIndex;
  final bool isReadOnly;
  final Function(String) onMediaAdded;

  const NonConformityMediaWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.ncIndex,
    this.isReadOnly = false,
    required this.onMediaAdded,
  });

  @override
  State<NonConformityMediaWidget> createState() => _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;
  bool _isOnline = false;
  final _storage = FirebaseStorage.instance;
  final InspectionDataService _inspectionService = InspectionDataService();
  final _connectivityService = Connectivity();
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadMedia();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = connectivityResult.contains(ConnectivityResult.wifi) || 
                    connectivityResult.contains(ConnectivityResult.mobile);
      });
    }
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
            final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
            
            if (widget.ncIndex < nonConformities.length) {
              final nc = nonConformities[widget.ncIndex];
              final media = List<Map<String, dynamic>>.from(nc['media'] ?? []);
              
              setState(() {
                _mediaItems = media.asMap().entries.map((entry) => {
                  ...entry.value,
                  'nc_media_index': entry.key,
                }).toList();
                _isLoading = false;
              });
              return;
            }
          }
        }
      }

      setState(() {
        _mediaItems = [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading non-conformity media: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    if (!mounted) return;

    try {
      // Force landscape mode for capture
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final picker = ImagePicker();
      final XFile? pickedFile = type == 'image'
          ? await picker.pickImage(
              source: source,
              maxWidth: 1200,
              maxHeight: 800,
              imageQuality: 80,
            )
          : await picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 1),
            );

      // Restore orientations
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      if (pickedFile == null) return;
      if (!mounted) return;

      setState(() => _isLoading = true);

      try {
        // Create media directory
        final mediaDir = await _getMediaDirectory();
        final fileExt = path.extension(pickedFile.path);
        final filename = 'nc_${widget.inspectionId}_${type}_${_uuid.v4()}$fileExt';
        final localPath = '${mediaDir.path}/$filename';

        // Copy file to media directory for local access
        final file = File(pickedFile.path);
        await file.copy(localPath);

        // For media tracking
        final mediaData = {
          'id': _uuid.v4(),
          'type': type,
          'localPath': localPath,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // If online, upload to Firebase Storage
        if (_isOnline) {
          final storagePath = 
            'inspections/${widget.inspectionId}/topic_${widget.topicIndex}/item_${widget.itemIndex}/detail_${widget.detailIndex}/non_conformities/nc_${widget.ncIndex}/$filename';
          
          final contentType = type == 'image'
              ? 'image/${fileExt.toLowerCase().replaceAll(".", "")}'
              : 'video/${fileExt.toLowerCase().replaceAll(".", "")}';

          final uploadTask = await _storage.ref(storagePath).putFile(
                File(localPath),
                SettableMetadata(contentType: contentType),
              );

          final downloadUrl = await uploadTask.ref.getDownloadURL();
          mediaData['url'] = downloadUrl;
        }

        // Save to inspection document
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
              final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
              
              if (widget.ncIndex < nonConformities.length) {
                final nc = Map<String, dynamic>.from(nonConformities[widget.ncIndex]);
                final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
                
                ncMedia.add(mediaData);
                nc['media'] = ncMedia;
                nonConformities[widget.ncIndex] = nc;
                detail['non_conformities'] = nonConformities;
                details[widget.detailIndex] = detail;
                item['details'] = details;
                items[widget.itemIndex] = item;
                topic['items'] = items;
                topics[widget.topicIndex] = topic;
                
await _inspectionService.firestore.collection('inspections')
                    .doc(widget.inspectionId).update({
                  'topics': topics,
                  'updated_at': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }

        // Notify of addition
        widget.onMediaAdded(localPath);

        // Reload media
        await _loadMedia();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} salvo com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error processing media: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao processar ${type == 'image' ? 'foto' : 'vídeo'}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error capturing media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar ${type == 'image' ? 'foto' : 'vídeo'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMedia(int mediaIndex, Map<String, dynamic> media) async {
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

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Try to delete from storage if URL exists
      if (_isOnline && media['url'] != null) {
        try {
          final storageRef = _storage.refFromURL(media['url']);
          await storageRef.delete();
        } catch (e) {
          print('Error deleting from storage: $e');
        }
      }

      // Try to delete local file
      if (media['localPath'] != null) {
        try {
          final file = File(media['localPath']);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting local file: $e');
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
            final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
            
            if (widget.ncIndex < nonConformities.length) {
              final nc = Map<String, dynamic>.from(nonConformities[widget.ncIndex]);
              final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
              
              if (mediaIndex < ncMedia.length) {
                ncMedia.removeAt(mediaIndex);
                nc['media'] = ncMedia;
                nonConformities[widget.ncIndex] = nc;
                detail['non_conformities'] = nonConformities;
                details[widget.detailIndex] = detail;
                item['details'] = details;
                items[widget.itemIndex] = item;
                topic['items'] = items;
                topics[widget.topicIndex] = topic;
                
                await _inspectionService.firestore.collection('inspections')
                    .doc(widget.inspectionId).update({
                  'topics': topics,
                  'updated_at': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }
      }

      // Reload
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mídia removida com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover mídia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        // Title and media buttons
        Row(
          children: [
            const Expanded(
              child: Text(
                'Arquivos de Mídia',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.black, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Add media buttons if not in read-only mode
        if (!widget.isReadOnly)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Foto'),
                  onPressed: () => _pickMedia(ImageSource.camera, 'image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Vídeo'),
                  onPressed: () => _pickMedia(ImageSource.camera, 'video'),
                ),
              ),
            ],
          ),

        const SizedBox(height: 8),

        if (!widget.isReadOnly)
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeria'),
            onPressed: () => _pickMedia(ImageSource.gallery, 'image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),

        // Separator
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Loading indicator
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_mediaItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nenhum arquivo de mídia adicionado', 
                style: TextStyle(color: Colors.grey)
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mídias Salvas:',
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final media = _mediaItems[index];
                    final bool isImage = media['type'] == 'image';
                    final bool hasUrl = media['url'] != null;
                    final bool hasLocalPath = media['localPath'] != null;

                    // Determine the widget to show (image local, image remote, video, etc.)
                    Widget mediaWidget;

                    if (isImage) {
                      if (hasLocalPath) {
                        // Local image
                        mediaWidget = Image.file(
                          File(media['localPath']),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          errorBuilder: (ctx, error, _) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        );
                      } else if (hasUrl) {
                        // Remote image
                        mediaWidget = Image.network(
                          media['url'],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, _) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
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
                      // Video (icon with background)
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
                          // Media content
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: mediaWidget,
                          ),

                          // Remove button
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
                                  icon: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeMedia(index, media),
                                ),
                              ),
                            ),

                          // Media type indicator
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
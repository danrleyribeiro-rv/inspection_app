// lib/presentation/widgets/non_conformity_media_widget.dart (simplified)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:inspection_app/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final String nonConformityId;
  final String inspectionId;
  final bool isReadOnly;
  final Function(String) onMediaAdded;

  const NonConformityMediaWidget({
    super.key,
    required this.nonConformityId,
    required this.inspectionId,
    this.isReadOnly = false,
    required this.onMediaAdded,
  });

  @override
  State<NonConformityMediaWidget> createState() =>
      _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;
  bool _isOnline = false;
  final _storage = FirebaseService().storage;
  final _firestore = FirebaseService().firestore;
  final _connectivityService = ConnectivityService();
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadMedia();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('non_conformity_media')
          .where('non_conformity_id', isEqualTo: widget.nonConformityId)
          .orderBy('timestamp', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _mediaItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'url': data['url'],
            'type': data['type'],
            'timestamp': data['timestamp'],
            'localPath': data['localPath'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading media: $e');
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
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileExt = path.extension(pickedFile.path);
        final filename = 'nc_${widget.nonConformityId}_${type}_${_uuid.v4()}$fileExt';
        final localPath = '${mediaDir.path}/$filename';

        // Copy file to media directory for local access
        final file = File(pickedFile.path);
        await file.copy(localPath);

        // For media tracking
        final mediaData = {
          'non_conformity_id': widget.nonConformityId,
          'inspection_id': widget.inspectionId,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
          'localPath': localPath,
        };

        // If online, upload to Firebase Storage
        if (_isOnline) {
          final storagePath = 'non_conformities/${widget.inspectionId}/${widget.nonConformityId}/$filename';
          
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

        // Save reference to Firestore (works offline)
        final docRef = await _firestore.collection('non_conformity_media').add(mediaData);

        // Add to the local list
        if (mounted) {
          setState(() {
            _mediaItems.insert(0, {
              'id': docRef.id,
              'url': mediaData['url'],
              'type': type,
              'timestamp': DateTime.now().toIso8601String(),
              'localPath': localPath,
            });
          });
        }

        // Notify of addition
        widget.onMediaAdded(localPath);

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

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Delete from Firestore
      await _firestore.collection('non_conformity_media').doc(media['id']).delete();

      // If online and URL exists, try to delete from storage
      if (_isOnline && media['url'] != null) {
        try {
          // Get storage reference from URL
          final uri = Uri.parse(media['url']);
          final pathSegments = uri.pathSegments;
          final storagePath = pathSegments.skip(1).join('/');
          
          await _storage.ref(storagePath).delete();
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

      setState(() {
        _mediaItems.removeWhere((item) => item['id'] == media['id']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mídia removida com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error removing media: $e');
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
    // Your existing build method
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Add explicitly the media buttons, even if not in read-only mode
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
              child: Text('Nenhum arquivo de mídia adicionado'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mídias Salvas:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  onPressed: () => _removeMedia(media),
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
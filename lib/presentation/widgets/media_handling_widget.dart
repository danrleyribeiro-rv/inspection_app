import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/image_watermark_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/offline_inspection_service.dart';

class MediaHandlingWidget extends StatefulWidget {
  final String inspectionId;
  final String topicId;
  final String itemId;
  final String detailId;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;
  final Function(String, String, String, String) onMediaMoved;

  const MediaHandlingWidget({
    super.key,
    required this.inspectionId,
    required this.topicId,
    required this.itemId,
    required this.detailId,
    required this.onMediaAdded,
    required this.onMediaDeleted,
    required this.onMediaMoved,
  });

  @override
  State<MediaHandlingWidget> createState() => _MediaHandlingWidgetState();
}

class _MediaHandlingWidgetState extends State<MediaHandlingWidget> {
  final _firestore = FirebaseService().firestore;
  final _storage = FirebaseService().storage;
  final _uuid = Uuid();
  final _watermarkService = ImageWatermarkService();

  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;
  bool _isProcessingVideo = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void didUpdateWidget(MediaHandlingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload media if any of the IDs changed
    if (oldWidget.inspectionId != widget.inspectionId ||
        oldWidget.topicId != widget.topicId ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.detailId != widget.detailId) {
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .orderBy('created_at', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _mediaItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
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
      // Obter a localização atual
      final position = await _watermarkService.getCurrentLocation();
      String? address;

      // Obter endereço legível se tivermos a posição
      if (position != null) {
        address = await _watermarkService.getAddressFromPosition(position);
      }

      // Create a unique local path for the file
      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now();
      final filename = p.basename(pickedFile.path);
      final newFilename =
          'img_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      // Get original file
      final file = File(pickedFile.path);

      // Add watermark to image
      final watermarkedFile = await _watermarkService.addWatermarkToImage(
        file,
        isFromGallery: source == ImageSource.gallery,
        timestamp: timestamp,
        location: position,
        locationAddress: address,
      );

      // Add metadata
      final finalFile = await _watermarkService.addMetadataToImage(
        watermarkedFile,
        source == ImageSource.gallery,
        timestamp,
        location: position,
        locationAddress: address,
      );

      // Copy to local path
      await finalFile.copy(localPath);

      // Prepare media data
      final mediaData = <String, dynamic>{
        'type': 'image',
        'localPath': localPath,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Try to upload to Firebase Storage
      try {
        final storagePath =
            'inspections/${widget.inspectionId}/${widget.topicId}/${widget.itemId}/${widget.detailId}/$newFilename';
        final uploadTask = await _storage.ref(storagePath).putFile(
              File(localPath),
              SettableMetadata(
                  contentType:
                      'image/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
            );

        final downloadUrl = await uploadTask.ref.getDownloadURL();
        mediaData['url'] = downloadUrl;
      } catch (e) {
        debugPrint('Error uploading to Firebase Storage: $e');
      }

      // Save to Firestore
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .add(mediaData);

      // Call callback
      widget.onMediaAdded(localPath);

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
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

    // Mostra uma mensagem de processamento (pode demorar mais para vídeos)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      // Obter a localização atual
      final position = await _watermarkService.getCurrentLocation();
      String? address;

      // Obter endereço legível se tivermos a posição
      if (position != null) {
        address = await _watermarkService.getAddressFromPosition(position);
      }

      // Create a unique local path for the file
      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now();
      final filename = p.basename(pickedFile.path);
      final newFilename =
          'vid_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      // Get original file
      final file = File(pickedFile.path);

      // Add watermark to video
      final watermarkedFile = await _watermarkService.addWatermarkToVideo(
        file,
        isFromGallery: source == ImageSource.gallery,
        timestamp: timestamp,
        location: position,
        locationAddress: address,
      );

      // Copy to local path if needed
      if (watermarkedFile.path != localPath) {
        await watermarkedFile.copy(localPath);
      }

      // Prepare media data
      final mediaData = <String, dynamic>{
        'type': 'video',
        'localPath': localPath,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Try to upload to Firebase Storage
      try {
        final storagePath =
            'inspections/${widget.inspectionId}/${widget.topicId}/${widget.itemId}/${widget.detailId}/$newFilename';
        final uploadTask = await _storage.ref(storagePath).putFile(
              File(localPath),
              SettableMetadata(
                  contentType:
                      'video/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
            );

        final downloadUrl = await uploadTask.ref.getDownloadURL();
        mediaData['url'] = downloadUrl;
      } catch (e) {
        debugPrint('Error uploading to Firebase Storage: $e');
      }

      // Save to Firestore
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .add(mediaData);

      // Call callback
      widget.onMediaAdded(localPath);

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving video: $e')),
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

  Future<void> _deleteMedia(String mediaId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Are you sure you want to delete this media file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Get the media document
      final docSnapshot = await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .doc(mediaId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Media not found');
      }

      final data = docSnapshot.data()!;
      final localPath = data['localPath'] as String?;
      final url = data['url'] as String?;

      // Try to delete from storage if URL exists
      if (url != null) {
        try {
          // Get reference from URL is more robust than trying to parse the path
          final storageRef = FirebaseStorage.instance.refFromURL(url);
          await storageRef.delete();
        } catch (e) {
          debugPrint('Error deleting from storage: $e');
        }
      }

      // Try to delete local file
      if (localPath != null) {
        try {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting local file: $e');
        }
      }

      // Delete from Firestore
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .doc(mediaId)
          .delete();

      // Call callback
      if (localPath != null) {
        widget.onMediaDeleted(localPath);
      }

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Media deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _moveMedia(String mediaId) async {
    // Show topic selection dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MoveMediaDialog(
        inspectionId: widget.inspectionId,
        currentTopicId: widget.topicId,
        currentItemId: widget.itemId,
        currentDetailId: widget.detailId,
      ),
    );

    if (result == null) return;

    final newTopicId = result['topicId'] as String?;
    final newItemId = result['itemId'] as String?;
    final newDetailId = result['detailId'] as String?;

    if (newTopicId == null || newItemId == null || newDetailId == null) {
      return;
    }

    // Don't move if the destination is the same as the source
    if (newTopicId == widget.topicId &&
        newItemId == widget.itemId &&
        newDetailId == widget.detailId) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the media document
      final docSnapshot = await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .doc(mediaId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Media not found');
      }

      final data = docSnapshot.data()!;
      final localPath = data['localPath'] as String?;

      // Copy the media document to the new location
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(newTopicId)
          .collection('topic_items')
          .doc(newItemId)
          .collection('item_details')
          .doc(newDetailId)
          .collection('media')
          .doc(mediaId)
          .set(data);

      // Delete the old media document
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(widget.topicId)
          .collection('topic_items')
          .doc(widget.itemId)
          .collection('item_details')
          .doc(widget.detailId)
          .collection('media')
          .doc(mediaId)
          .delete();

      // Call callback
      if (localPath != null) {
        widget.onMediaMoved(localPath, newTopicId, newItemId, newDetailId);
      }

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Media moved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Get the application's media directory
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
    final overlayColor = Colors.black.withAlpha((255 * 0.6).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media capture buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : () => _pickVideo(ImageSource.camera),
                icon: const Icon(Icons.videocam),
                label: const Text('Record Video'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : () => _pickVideo(ImageSource.gallery),
                icon: const Icon(Icons.video_library),
                label: const Text('Video Gallery'),
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
                    final hasUrl = media['url'] != null &&
                        (media['url'] as String).isNotEmpty;
                    final hasLocalPath = media['localPath'] != null &&
                        (media['localPath'] as String).isNotEmpty;
                    final mediaId = media['id'] as String;

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
                              child: const Icon(Icons.broken_image,
                                  color: Colors.red),
                            ),
                          );
                        } else if (hasUrl) {
                          displayWidget = Image.network(
                            media['url'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (ctx, error, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error_outline,
                                  color: Colors.red),
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
                                  Text('No Image',
                                      style: TextStyle(fontSize: 10))
                                ]),
                          );
                        }
                      } else if (hasUrl) {
                        displayWidget = Image.network(
                          media['url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (ctx, error, _) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.cloud_off,
                                color: Colors.orange),
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
                                Text('No Source',
                                    style: TextStyle(fontSize: 10))
                              ]),
                        );
                      }
                    } else {
                      // isVideo
                      displayWidget = Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.video_file,
                            size: 50,
                            color: Colors.grey,
                          ),
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
                                Text('No Source',
                                    style: TextStyle(fontSize: 10))
                              ]),
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
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: overlayColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _deleteMedia(mediaId),
                                    tooltip: 'Delete Media',
                                    constraints: const BoxConstraints.tightFor(
                                        width: 30, height: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: overlayColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.drive_file_move,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _moveMedia(mediaId),
                                    tooltip: 'Move Media',
                                    constraints: const BoxConstraints.tightFor(
                                        width: 30, height: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Media type indicator
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: overlayColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isImage ? 'Photo' : 'Video',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
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

class MoveMediaDialog extends StatefulWidget {
  final String inspectionId;
  final String currentTopicId;
  final String currentItemId;
  final String currentDetailId;

  const MoveMediaDialog({
    super.key,
    required this.inspectionId,
    required this.currentTopicId,
    required this.currentItemId,
    required this.currentDetailId,
  });

  @override
  State<MoveMediaDialog> createState() => _MoveMediaDialogState();
}

class _MoveMediaDialogState extends State<MoveMediaDialog> {
  final OfflineInspectionService _offlineService = OfflineInspectionService();

  List<Topic> _topics = [];
  List<Item> _items = [];
  List<Detail> _details = [];

  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _offlineService.initialize();
    _loadTopics();
  }

  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final topics = await _offlineService.getTopics(widget.inspectionId);

      if (!mounted) return;

      setState(() {
        _topics = topics;
        _isLoading = false;
        _items = [];
        _details = [];
        _selectedItemId = null;
        _selectedDetailId = null;

        if (_topics.any((topic) => topic.id == widget.currentTopicId)) {
          _selectedTopicId = widget.currentTopicId;
        } else if (_topics.isNotEmpty) {
          _selectedTopicId = _topics.first.id;
        } else {
          _selectedTopicId = null;
        }

        if (_selectedTopicId != null) {
          _loadItems(_selectedTopicId!);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading topics: $e')),
        );
      }
    }
  }

  Future<void> _loadItems(String topicId) async {
    if (_items.isEmpty || _selectedTopicId != topicId) {
      setState(() => _isLoading = true);
    }

    try {
      final items =
          await _offlineService.getItems(widget.inspectionId, topicId);

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
        _details = [];
        _selectedDetailId = null;

        if (widget.currentTopicId == topicId &&
            _items.any((item) => item.id == widget.currentItemId)) {
          _selectedItemId = widget.currentItemId;
        } else if (_items.isNotEmpty) {
          _selectedItemId = _items.first.id;
        } else {
          _selectedItemId = null;
        }

        if (_selectedItemId != null) {
          _loadDetails(topicId, _selectedItemId!);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    }
  }

  Future<void> _loadDetails(String topicId, String itemId) async {
    if (_details.isEmpty || _selectedItemId != itemId) {
      setState(() => _isLoading = true);
    }
    try {
      final details = await _offlineService.getDetails(
          widget.inspectionId, topicId, itemId);

      if (!mounted) return;

      setState(() {
        _details = details;
        _isLoading = false;

        if (widget.currentTopicId == topicId &&
            widget.currentItemId == itemId &&
            _details.any((detail) => detail.id == widget.currentDetailId)) {
          _selectedDetailId = widget.currentDetailId;
        } else if (_details.isNotEmpty) {
          _selectedDetailId = _details.first.id;
        } else {
          _selectedDetailId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mover Mídia Para'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading &&
                (_topics.isEmpty || _items.isEmpty || _details.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tópico:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedTopicId,
                      isExpanded: true,
                      hint: const Text('Selecione o tópico'),
                      items: _topics.map((topic) {
                        return DropdownMenuItem<String>(
                          value: topic.id,
                          child: Text(topic.topicName,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null && value != _selectedTopicId) {
                          setState(() {
                            _selectedTopicId = value;
                            _selectedItemId = null;
                            _selectedDetailId = null;
                            _items = [];
                            _details = [];
                            _isLoading = true;
                          });
                          _loadItems(value);
                        }
                      },
                      validator: (value) => value == null
                          ? 'Por favor, selecione um tópico'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Item:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedItemId,
                      isExpanded: true,
                      hint: const Text('Selecione um item'),
                      items: _items.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.itemName,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _selectedTopicId == null
                          ? null
                          : (value) {
                              if (value != null &&
                                  _selectedTopicId != null &&
                                  value != _selectedItemId) {
                                setState(() {
                                  _selectedItemId = value;
                                  _selectedDetailId = null;
                                  _details = [];
                                  _isLoading = true;
                                });
                                _loadDetails(_selectedTopicId!, value);
                              }
                            },
                      validator: (value) =>
                          value == null ? 'Por favor, selecione um item' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Detalhe:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDetailId,
                      isExpanded: true,
                      hint: const Text('Selecione o detalhe'),
                      items: _details.map((detail) {
                        return DropdownMenuItem<String>(
                          value: detail.id,
                          child: Text(detail.detailName,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _selectedItemId == null
                          ? null
                          : (value) {
                              if (value != null && value != _selectedDetailId) {
                                setState(() {
                                  _selectedDetailId = value;
                                });
                              }
                            },
                      validator: (value) => value == null
                          ? 'Por favor, selecione um detalhe'
                          : null,
                    ),
                    if (_isLoading &&
                        !(_topics.isEmpty ||
                            _items.isEmpty ||
                            _details.isEmpty))
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3))),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedTopicId != null &&
                  _selectedItemId != null &&
                  _selectedDetailId != null &&
                  !_isLoading
              ? () => Navigator.of(context).pop({
                    'topicId': _selectedTopicId,
                    'itemId': _selectedItemId,
                    'detailId': _selectedDetailId,
                  })
              : null,
          child: const Text('Mover'),
        ),
      ],
    );
  }
}

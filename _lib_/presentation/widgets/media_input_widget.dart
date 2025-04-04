// lib/presentation/widgets/media_input_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:inspection_app/services/storage/media_storage_service.dart';

class MediaInputWidget extends StatefulWidget {
  final int inspectionId;
  final int roomId;
  final int itemId;
  final int detailId;
  final String detailName;
  final Map<String, dynamic> mediaRequirements;
  final bool readOnly;

  const MediaInputWidget({
    Key? key,
    required this.inspectionId,
    required this.roomId,
    required this.itemId,
    required this.detailId,
    required this.detailName,
    this.mediaRequirements = const {
      'images': {'max': 5},
      'videos': {'max': 2}
    },
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<MediaInputWidget> createState() => _MediaInputWidgetState();
}

class _MediaInputWidgetState extends State<MediaInputWidget> {
  final MediaStorageService _mediaStorageService = MediaStorageService();
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final mediaList = await _mediaStorageService.getMediaByDetail(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
      );

      if (mounted) {
        setState(() {
          _mediaItems = mediaList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading media: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final int maxImages = widget.mediaRequirements['images']?['max'] ?? 5;
    final int currentImages = _mediaItems.where((item) => item['type'] == 'image').length;
    
    if (currentImages >= maxImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum number of images reached ($maxImages)')),
        );
      }
      return;
    }

    try {
      // Force landscape orientation for capture
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      // Reset orientation
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      final mediaPath = await _mediaStorageService.saveMedia(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
        File(pickedFile.path),
        widget.detailName,
        'image',
      );

      if (mediaPath != null) {
        setState(() {
          _mediaItems.add({
            'path': mediaPath,
            'type': 'image',
            'timestamp': DateTime.now().toIso8601String(),
            'isLocal': true,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final int maxVideos = widget.mediaRequirements['videos']?['max'] ?? 2;
    final int currentVideos = _mediaItems.where((item) => item['type'] == 'video').length;
    
    if (currentVideos >= maxVideos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum number of videos reached ($maxVideos)')),
        );
      }
      return;
    }

    try {
      // Force landscape orientation for capture
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 1),
      );

      // Reset orientation
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      final mediaPath = await _mediaStorageService.saveMedia(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
        File(pickedFile.path),
        widget.detailName,
        'video',
      );

      if (mediaPath != null) {
        setState(() {
          _mediaItems.add({
            'path': mediaPath,
            'type': 'video',
            'timestamp': DateTime.now().toIso8601String(),
            'isLocal': true,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing video: $e')),
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
        title: const Text('Remove Media'),
        content: const Text('Are you sure you want to remove this media file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      if (media.containsKey('path')) {
        await _mediaStorageService.deleteMedia(
          widget.inspectionId,
          widget.roomId,
          widget.itemId,
          widget.detailId,
          media['path'],
        );
        
        setState(() {
          _mediaItems.removeWhere((item) => item['path'] == media['path']);
        });
      } else if (media.containsKey('url')) {
        await _mediaStorageService.deleteRemoteMedia(media['url']);
        setState(() {
          _mediaItems.removeWhere((item) => item['url'] == media['url']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                'Media:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Media capture buttons
        if (!widget.readOnly) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickVideo(ImageSource.camera),
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
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Loading indicator
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_mediaItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('No media added'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Media Files:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final media = _mediaItems[index];
                    final bool isImage = media['type'] == 'image';
                    
                    // Determine the widget to show
                    Widget mediaWidget;
                    
                    if (isImage) {
                      if (media.containsKey('path')) {
                        // Local image
                        final file = File(media['path']);
                        mediaWidget = Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: 150,
                          height: 150,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 150,
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        );
                      } else if (media.containsKey('url')) {
                        // Remote image
                        mediaWidget = Image.network(
                          media['url'],
                          fit: BoxFit.cover,
                          width: 150,
                          height: 150,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 150,
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        );
                      } else {
                        // Fallback
                        mediaWidget = Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        );
                      }
                    } else {
                      // Video placeholder
                      mediaWidget = Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          // Media content
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: mediaWidget,
                          ),
                          
                          // Delete button
                          if (!widget.readOnly)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                  onPressed: () => _removeMedia(media),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          
                          // Media type indicator
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isImage ? 'Photo' : 'Video',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
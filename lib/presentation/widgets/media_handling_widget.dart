// lib/presentation/widgets/media_handling_widget.dart (simplified)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class MediaHandlingWidget extends StatefulWidget {
  final String inspectionId;
  final int roomId;
  final int itemId;
  final int detailId;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;
  final Function(String, int, int, int) onMediaMoved;

  const MediaHandlingWidget({
    super.key,
    required this.inspectionId,
    required this.roomId,
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
  
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = true;

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
        oldWidget.roomId != widget.roomId ||
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
          .collection('media')
          .where('inspection_id', isEqualTo: widget.inspectionId)
          .where('room_id', isEqualTo: widget.roomId)
          .where('room_item_id', isEqualTo: widget.itemId)
          .where('detail_id', isEqualTo: widget.detailId)
          .orderBy('created_at', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _mediaItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'url': data['url'],
            'type': data['type'],
            'localPath': data['localPath'],
            'created_at': data['created_at'],
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Create a unique local path for the file
      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = p.basename(pickedFile.path);
      final newFilename = 'img_${timestamp}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      // Copy file to our app's media directory
      final file = File(pickedFile.path);
      await file.copy(localPath);

      // Prepare media data
      final mediaData = {
        'inspection_id': widget.inspectionId,
        'room_id': widget.roomId,
        'room_item_id': widget.itemId,
        'detail_id': widget.detailId,
        'type': 'image',
        'localPath': localPath,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Try to upload to Firebase Storage if possible
      try {
        final storagePath = 'inspections/${widget.inspectionId}/${widget.roomId}/${widget.itemId}/${widget.detailId}/$newFilename';
        final uploadTask = await _storage.ref(storagePath).putFile(
              file,
              SettableMetadata(contentType: 'image/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
            );
            
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        mediaData['url'] = downloadUrl;
      } catch (e) {
        print('Error uploading to Firebase Storage: $e');
        // Continue anyway, as we'll save the local path
      }

      // Save reference to Firestore (works offline)
      final docRef = await _firestore.collection('media').add(mediaData);

      // Call callback
      widget.onMediaAdded(localPath);

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

    setState(() => _isLoading = true);

    try {
      // Create a unique local path for the file
      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = p.basename(pickedFile.path);
      final newFilename = 'vid_${timestamp}_${_uuid.v4()}${p.extension(filename)}';
      final localPath = '${mediaDir.path}/$newFilename';

      // Copy file to our app's media directory
      final file = File(pickedFile.path);
      await file.copy(localPath);

      // Prepare media data
      final mediaData = {
        'inspection_id': widget.inspectionId,
        'room_id': widget.roomId,
        'room_item_id': widget.itemId,
        'detail_id': widget.detailId,
        'type': 'video',
        'localPath': localPath,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Try to upload to Firebase Storage if possible
      try {
        final storagePath = 'inspections/${widget.inspectionId}/${widget.roomId}/${widget.itemId}/${widget.detailId}/$newFilename';
        final uploadTask = await _storage.ref(storagePath).putFile(
              file,
              SettableMetadata(contentType: 'video/${p.extension(filename).toLowerCase().replaceAll(".", "")}'),
            );
            
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        mediaData['url'] = downloadUrl;
      } catch (e) {
        print('Error uploading to Firebase Storage: $e');
        // Continue anyway, as we'll save the local path
      }

      // Save reference to Firestore (works offline)
      final docRef = await _firestore.collection('media').add(mediaData);

      // Call callback
      widget.onMediaAdded(localPath);

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        setState(() => _isLoading = false);
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
      final docSnapshot = await _firestore.collection('media').doc(mediaId).get();
      
      if (!docSnapshot.exists) {
        throw Exception('Media not found');
      }
      
      final data = docSnapshot.data()!;
      final localPath = data['localPath'] as String?;
      final url = data['url'] as String?;
      
      // Try to delete from storage if URL exists
      if (url != null) {
        try {
          // Extract path from URL
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          final storagePath = pathSegments.skip(1).join('/');
          
          await _storage.ref(storagePath).delete();
        } catch (e) {
          print('Error deleting from storage: $e');
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
          print('Error deleting local file: $e');
        }
      }
      
      // Delete from Firestore
      await _firestore.collection('media').doc(mediaId).delete();
      
      // Call callback
      if (localPath != null) {
        widget.onMediaDeleted(localPath);
      }

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
    // Show room selection dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MoveMediaDialog(
        inspectionId: widget.inspectionId,
        currentRoomId: widget.roomId,
        currentItemId: widget.itemId,
        currentDetailId: widget.detailId,
      ),
    );

    if (result == null) return;

    final newRoomId = result['roomId'];
    final newItemId = result['itemId'];
    final newDetailId = result['detailId'];

    if (newRoomId == null || newItemId == null || newDetailId == null) {
      return;
    }

    // Don't move if the destination is the same as the source
    if (newRoomId == widget.roomId &&
        newItemId == widget.itemId &&
        newDetailId == widget.detailId) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the media document
      final docSnapshot = await _firestore.collection('media').doc(mediaId).get();
      
      if (!docSnapshot.exists) {
        throw Exception('Media not found');
      }
      
      final data = docSnapshot.data()!;
      final localPath = data['localPath'] as String?;
      
      // Update document
      await _firestore.collection('media').doc(mediaId).update({
        'room_id': newRoomId,
        'room_item_id': newItemId,
        'detail_id': newDetailId,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Call callback
      if (localPath != null) {
        widget.onMediaMoved(localPath, newRoomId, newItemId, newDetailId);
      }

      // Refresh the list
      await _loadMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media capture buttons
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
        const SizedBox(height: 16),

        // Media display
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_mediaItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No media attached'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Media Files:',
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
                    final hasUrl = media['url'] != null;
                    final hasLocalPath = media['localPath'] != null;

                    // Determine what to display
                    Widget displayWidget;
                    if (isImage) {
                      if (hasLocalPath) {
                        // Local image file
                        displayWidget = Image.file(
                          File(media['localPath']),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, _) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        );
                      } else if (hasUrl) {
                        // Remote image URL
                        displayWidget = Image.network(
                          media['url'],
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, _) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        );
                      } else {
                        // Fallback
                        displayWidget = Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        );
                      }
                    } else {
                      // Video icon
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
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          // Media display
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
                                // Delete button
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _deleteMedia(media['id']),
                                    constraints: const BoxConstraints.tightFor(
                                        width: 30, height: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Move button
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.drive_file_move,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _moveMedia(media['id']),
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
                                color: Colors.black.withOpacity(0.6),
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

// Keep the MoveMediaDialog class with Firebase adaptations
class MoveMediaDialog extends StatefulWidget {
  final String inspectionId;
  final int currentRoomId;
  final int currentItemId;
  final int currentDetailId;

  const MoveMediaDialog({
    super.key,
    required this.inspectionId,
    required this.currentRoomId,
    required this.currentItemId,
    required this.currentDetailId,
  });

  @override
  State<MoveMediaDialog> createState() => _MoveMediaDialogState();
}

class _MoveMediaDialogState extends State<MoveMediaDialog> {
  final _firestore = FirebaseService().firestore;
  final _inspectionService = FirebaseInspectionService();
  
  List<Room> _rooms = [];
  List<Item> _items = [];
  List<Detail> _details = [];

  int? _selectedRoomId;
  int? _selectedItemId;
  int? _selectedDetailId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _inspectionService.getRooms(widget.inspectionId);

      setState(() {
        _rooms = rooms;
        _isLoading = false;

        // Pre-select current room
        if (_rooms.isNotEmpty) {
          for (var room in _rooms) {
            if (room.id == widget.currentRoomId) {
              _selectedRoomId = room.id;
              break;
            }
          }

          // If current room wasn't found, select first room
          if (_selectedRoomId == null && _rooms.isNotEmpty) {
            _selectedRoomId = _rooms.first.id;
          }

          // Load items for selected room
          if (_selectedRoomId != null) {
            _loadItems(_selectedRoomId!);
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rooms: $e')),
        );
      }
    }
  }

  Future<void> _loadItems(dynamic roomId) async {
    setState(() => _isLoading = true);
    try {
      final items = await _inspectionService.getItems(widget.inspectionId, roomId);

      setState(() {
        _items = items;
        _isLoading = false;

        // Pre-select current item if in the same room
        if (widget.currentRoomId == roomId) {
          for (var item in _items) {
            if (item.id == widget.currentItemId) {
              _selectedItemId = item.id;
              break;
            }
          }
        }

        // If no item was selected and items exist, select first item
        if (_selectedItemId == null && _items.isNotEmpty) {
          _selectedItemId = _items.first.id;
        }

        // Load details for selected item
        if (_selectedItemId != null) {
          _loadDetails(roomId, _selectedItemId!);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    }
  }

  Future<void> _loadDetails(dynamic roomId, dynamic itemId) async {
    setState(() => _isLoading = true);
    try {
      final details = await _inspectionService.getDetails(
          widget.inspectionId, roomId, itemId);

      setState(() {
        _details = details;
        _isLoading = false;

        // Pre-select current detail if in the same item
        if (widget.currentRoomId == roomId && widget.currentItemId == itemId) {
          for (var detail in _details) {
            if (detail.id == widget.currentDetailId) {
              _selectedDetailId = detail.id;
              break;
            }
          }
        }

        // If no detail was selected and details exist, select first detail
        if (_selectedDetailId == null && _details.isNotEmpty) {
          _selectedDetailId = _details.first.id;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move Media To'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Room:'),
                  DropdownButtonFormField<int>(
                    value: _selectedRoomId,
                    isExpanded: true,
                    items: _rooms.map((room) {
                      return DropdownMenuItem<int>(
                        value: room.id,
                        child: Text(room.roomName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRoomId = value;
                          _selectedItemId = null;
                          _selectedDetailId = null;
                          _items = [];
                          _details = [];
                        });
                        _loadItems(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Item:'),
                  DropdownButtonFormField<int>(
                    value: _selectedItemId,
                    isExpanded: true,
                    items: _items.map((item) {
                      return DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(item.itemName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && _selectedRoomId != null) {
                        setState(() {
                          _selectedItemId = value;
                          _selectedDetailId = null;
                          _details = [];
                        });
                        _loadDetails(_selectedRoomId!, value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Detail:'),
                  DropdownButtonFormField<int>(
                    value: _selectedDetailId,
                    isExpanded: true,
                    items: _details.map((detail) {
                      return DropdownMenuItem<int>(
                        value: detail.id,
                        child: Text(detail.detailName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDetailId = value;
                        });
                      }
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedRoomId != null &&
                  _selectedItemId != null &&
                  _selectedDetailId != null
              ? () => Navigator.of(context).pop({
                    'roomId': _selectedRoomId,
                    'itemId': _selectedItemId,
                    'detailId': _selectedDetailId,
                  })
              : null,
          child: const Text('Move'),
        ),
      ],
    );
  }
}
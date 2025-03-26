// lib/presentation/widgets/media_handling_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MediaHandlingWidget extends StatefulWidget {
  final int inspectionId;
  final int roomId;
  final int itemId;
  final int detailId;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;
  final Function(String, int, int, int) onMediaMoved;

  const MediaHandlingWidget({
    Key? key,
    required this.inspectionId,
    required this.roomId,
    required this.itemId,
    required this.detailId,
    required this.onMediaAdded,
    required this.onMediaDeleted,
    required this.onMediaMoved,
  }) : super(key: key);

  @override
  State<MediaHandlingWidget> createState() => _MediaHandlingWidgetState();
}

class _MediaHandlingWidgetState extends State<MediaHandlingWidget> {
  List<String> _mediaItems = [];
  bool _isLoading = false;

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
    setState(() => _isLoading = true);
    try {
      final mediaList = await LocalDatabaseService.getMediaByDetail(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
      );
      
      setState(() {
        _mediaItems = mediaList;
        _isLoading = false;
      });
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
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile == null) return;
    
    setState(() => _isLoading = true);

    try {
      // Create a unique local path for the file
      final mediaDir = await LocalDatabaseService.getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = path.basename(pickedFile.path);
      final newFilename = '${timestamp}_$filename';
      final localPath = '${mediaDir.path}/$newFilename';
      
      // Copy file to our app's media directory
      final file = File(pickedFile.path);
      await file.copy(localPath);
      
      // Generate a key based on the IDs
      final mediaKey = '${widget.inspectionId}_${widget.roomId}_${widget.itemId}_${widget.detailId}_$timestamp';
      
      // Save in local database
      await LocalDatabaseService.saveMedia(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
        localPath,
      );
      
      // Call callback
      widget.onMediaAdded(localPath);
      
      // Refresh the list
      await _loadMedia();
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
      final mediaDir = await LocalDatabaseService.getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = path.basename(pickedFile.path);
      final newFilename = '${timestamp}_$filename';
      final localPath = '${mediaDir.path}/$newFilename';
      
      // Copy file to our app's media directory
      final file = File(pickedFile.path);
      await file.copy(localPath);
      
      // Generate a key based on the IDs
      final mediaKey = '${widget.inspectionId}_${widget.roomId}_${widget.itemId}_${widget.detailId}_$timestamp';
      
      // Save in local database
      await LocalDatabaseService.saveMedia(
        widget.inspectionId,
        widget.roomId,
        widget.itemId,
        widget.detailId,
        localPath,
      );
      
      // Call callback
      widget.onMediaAdded(localPath);
      
      // Refresh the list
      await _loadMedia();
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

  Future<void> _deleteMedia(String mediaPath) async {
    final mediaKey = '${widget.inspectionId}_${widget.roomId}_${widget.itemId}_${widget.detailId}_${path.basename(mediaPath).split('_').first}';
    
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
      // Delete from local database
      await LocalDatabaseService.deleteMedia(mediaKey);
      
      // Call callback
      widget.onMediaDeleted(mediaPath);
      
      // Refresh the list
      await _loadMedia();
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

  Future<void> _moveMedia(String mediaPath) async {
    // Structure to hold data from the move dialog
    int? selectedRoomId;
    int? selectedItemId;
    int? selectedDetailId;
    List<dynamic> allRooms = [];
    
    // Show room selection dialog
    final selectedRoom = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MoveMediaDialog(
        inspectionId: widget.inspectionId,
        currentRoomId: widget.roomId,
        currentItemId: widget.itemId,
        currentDetailId: widget.detailId,
      ),
    );
    
    if (selectedRoom == null) return;
    
    selectedRoomId = selectedRoom['roomId'];
    selectedItemId = selectedRoom['itemId'];
    selectedDetailId = selectedRoom['detailId'];
    
    if (selectedRoomId == null || selectedItemId == null || selectedDetailId == null) {
      return;
    }
    
    // Don't move if the destination is the same as the source
    if (selectedRoomId == widget.roomId && 
        selectedItemId == widget.itemId && 
        selectedDetailId == widget.detailId) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final mediaKey = '${widget.inspectionId}_${widget.roomId}_${widget.itemId}_${widget.detailId}_${path.basename(mediaPath).split('_').first}';
      
      // Move media in local database
      await LocalDatabaseService.moveMedia(
        mediaKey,
        selectedRoomId,
        selectedItemId,
        selectedDetailId,
      );
      
      // Call callback
      widget.onMediaMoved(mediaPath, selectedRoomId, selectedItemId, selectedDetailId);
      
      // Refresh the list
      await _loadMedia();
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
                    final mediaPath = _mediaItems[index];
                    final bool isImage = path.extension(mediaPath).toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'));
                    
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
                            child: isImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(mediaPath),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.video_file,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                    onPressed: () => _deleteMedia(mediaPath),
                                    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.drive_file_move, color: Colors.white, size: 20),
                                    onPressed: () => _moveMedia(mediaPath),
                                    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
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

// Dialog to select destination for moving media
class MoveMediaDialog extends StatefulWidget {
  final int inspectionId;
  final int currentRoomId;
  final int currentItemId;
  final int currentDetailId;

  const MoveMediaDialog({
    Key? key,
    required this.inspectionId,
    required this.currentRoomId,
    required this.currentItemId,
    required this.currentDetailId,
  }) : super(key: key);

  @override
  State<MoveMediaDialog> createState() => _MoveMediaDialogState();
}

class _MoveMediaDialogState extends State<MoveMediaDialog> {
  List<dynamic> _rooms = [];
  List<dynamic> _items = [];
  List<dynamic> _details = [];
  
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
      final rooms = await LocalDatabaseService.getRoomsByInspection(widget.inspectionId);
      
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

  Future<void> _loadItems(int roomId) async {
    setState(() => _isLoading = true);
    try {
      final items = await LocalDatabaseService.getItemsByRoom(widget.inspectionId, roomId);
      
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

  Future<void> _loadDetails(int roomId, int itemId) async {
    setState(() => _isLoading = true);
    try {
      final details = await LocalDatabaseService.getDetailsByItem(widget.inspectionId, roomId, itemId);
      
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
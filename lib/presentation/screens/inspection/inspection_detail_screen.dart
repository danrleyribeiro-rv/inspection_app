// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InspectionDetailScreen extends StatefulWidget {
  final int inspectionId;

  const InspectionDetailScreen({
    Key? key,
    required this.inspectionId,
  }) : super(key: key);

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isOnline = true;
  Map<String, dynamic>? _inspection;
  List<Room> _rooms = [];
  int _expandedRoomIndex = -1;
  
  // For the landscape mode
  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadInspection();
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _loadInspection() async {
    setState(() => _isLoading = true);

    try {
      // First, try to get local inspection data
      final localInspection = await _inspectionService.getInspection(widget.inspectionId);
      
      if (localInspection != null) {
        // We have local data, use it
        setState(() {
          _inspection = localInspection.toJson();
        });
        
        // Load rooms
        await _loadRooms();
        
        setState(() => _isLoading = false);
      } else {
        // No local data, try to download if online
        if (_isOnline) {
          await _downloadInspection();
        } else {
          // Offline with no local data
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No local data and offline. Cannot load inspection.')),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print('Error in _loadInspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inspection: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadInspection() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot download while offline')),
      );
      return;
    }
    
    setState(() => _isDownloading = true);
    
    try {
      // Show download message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading inspection data...')),
      );
      
      // Try to download from server using the improved SyncService
      final success = await _inspectionService.downloadInspection(widget.inspectionId);
      
      if (success) {
        // Get the local inspection
        final inspection = await _inspectionService.getInspection(widget.inspectionId);
        
        if (inspection != null) {
          setState(() {
            _inspection = inspection.toJson();
          });
          
          // Load rooms
          await _loadRooms();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspection downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load downloaded inspection')),
          );
        }
      } else {
        // If download fails, try to get basic info from Supabase
        try {
          final inspectionData = await _supabase
              .from('inspections')
              .select('*')
              .eq('id', widget.inspectionId)
              .single();
          
          setState(() {
            _inspection = inspectionData;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only basic inspection data was loaded. Try again later for complete data.'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download inspection')),
          );
        }
      }
    } catch (e) {
      print('Error downloading inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading inspection: $e')),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);

    try {
      // Use the improved getRooms method which now checks both local and server
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
      
      // If no rooms and we're online, try to download complete data
      if (_rooms.isEmpty && _isOnline) {
        _promptForDownload();
      }
    } catch (e) {
      print('Error loading rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rooms: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _promptForDownload() {
    // Only show if online
    if (!_isOnline) return;
    
    // Show dialog asking to download complete data
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No rooms found'),
        content: const Text(
          'Would you like to download the complete inspection data from the server?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadInspection();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadItemsForRoom(int roomIndex) async {
    if (roomIndex < 0 || roomIndex >= _rooms.length) return;
    
    final roomId = _rooms[roomIndex].id;
    if (roomId == null) return;
    
    try {
      // Use the improved getItems method
      final items = await _inspectionService.getItems(widget.inspectionId, roomId);
      setState(() {
        _selectedRoomItems = items;
        _selectedRoomIndex = roomIndex;
        _selectedItemIndex = -1; // Reset item selection
        _selectedItemDetails = [];
      });
    } catch (e) {
      print('Error loading items: $e');
    }
  }

  Future<void> _loadDetailsForItem(int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= _selectedRoomItems.length) return;
    
    final item = _selectedRoomItems[itemIndex];
    if (item.id == null || item.roomId == null) return;
    
    try {
      // Use the improved getDetails method
      final details = await _inspectionService.getDetails(
        widget.inspectionId,
        item.roomId!,
        item.id!
      );
      
      setState(() {
        _selectedItemDetails = details;
        _selectedItemIndex = itemIndex;
      });
    } catch (e) {
      print('Error loading details: $e');
    }
  }

  // Add a new room
  Future<void> _addRoom() async {
    final name = await _showTextInputDialog('Add Room', 'Room name');
    if (name == null || name.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final newRoom = await _inspectionService.addRoom(
        widget.inspectionId,
        name,
      );
      
      await _loadRooms();
      
      // Expand the new room
      setState(() {
        _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
        _isLoading = false;
      });
    } catch (e) {
      print('Error adding room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding room: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to duplicate a room
  Future<void> _duplicateRoom(Room room) async {
    setState(() => _isLoading = true);
    
    try {
      // Create a copy of the room with a new name
      final copyName = "${room.roomName} (copy)";
      
      // Add the new room
      final newRoom = await _inspectionService.addRoom(
        widget.inspectionId,
        copyName,
        label: room.roomLabel,
      );
      
      // Duplicate all items if original room has an ID
      if (room.id != null) {
        // Get items from the original room
        final items = await _inspectionService.getItems(
          widget.inspectionId,
          room.id!
        );
        
        // Add each item to the new room
        for (final item in items) {
          final newItem = await _inspectionService.addItem(
            widget.inspectionId,
            newRoom.id!,
            item.itemName,
            label: item.itemLabel,
          );
          
          // Update item with the same observation as original
          if (item.observation != null) {
            await _inspectionService.updateItem(
              newItem.copyWith(observation: item.observation)
            );
          }
          
          // If the original item has an ID, duplicate its details
          if (item.id != null) {
            // Get details from the original item
            final details = await _inspectionService.getDetails(
              widget.inspectionId,
              room.id!,
              item.id!
            );
            
            // Add each detail to the new item
            for (final detail in details) {
              final newDetail = await _inspectionService.addDetail(
                widget.inspectionId,
                newRoom.id!,
                newItem.id!,
                detail.detailName,
                value: detail.detailValue,
              );
              
              // Update detail with the same observation as original
              if (detail.observation != null) {
                await _inspectionService.updateDetail(
                  newDetail.copyWith(observation: detail.observation)
                );
              }
            }
          }
        }
      }
      
      // Reload rooms
      await _loadRooms();
      
      // Expand the new room
      setState(() {
        _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room duplicated successfully!'))
      );
    } catch (e) {
      print('Error duplicating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating room: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to save changes to the inspection
  Future<void> _saveInspection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Do you want to save the changes made to the inspection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Update inspection status to "in_progress" if it's "pending"
      if (_inspection?['status'] == 'pending') {
        await _supabase
            .from('inspections')
            .update({'status': 'in_progress', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', widget.inspectionId);
        
        _inspection?['status'] = 'in_progress';
      }
      
      // Try to sync if online
      if (_isOnline) {
        await _inspectionService.syncInspection(widget.inspectionId);
      }
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving inspection: $e')),
        );
      }
    }
  }

  // Method to complete the inspection
  Future<void> _completeInspection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Inspection'),
        content: const Text('Are you sure you want to complete this inspection?\n\nOnce completed, you won\'t be able to make further changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('inspections')
          .update({
            'status': 'completed',
            'finished_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.inspectionId);
      
      _inspection?['status'] = 'completed';
      
      // Try to sync if online
      if (_isOnline) {
        await _inspectionService.syncInspection(widget.inspectionId);
      }
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to previous screen
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing inspection: $e')),
        );
      }
    }
  }

  // Helper to show an input dialog
  Future<String?> _showTextInputDialog(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result;
  }

  // Go to non-conformities screen
  void _navigateToNonConformities() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NonConformityScreen(inspectionId: widget.inspectionId),
      ),
    );
  }

  void _handleRoomUpdate(Room updatedRoom) {
    setState(() {
      final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
      if (index >= 0) {
        _rooms[index] = updatedRoom;
      }
    });
    
    _inspectionService.updateRoom(updatedRoom);
  }

  Future<void> _handleRoomDelete(int roomId) async {
    try {
      await _inspectionService.deleteRoom(widget.inspectionId, roomId);
      
      await _loadRooms();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing room: $e')),
        );
      }
    }
  }

  // Manually sync the inspection
  Future<void> _syncInspection() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot sync while offline')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _inspectionService.syncInspection(widget.inspectionId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload rooms after sync in case server had updates
        await _loadRooms();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync partially failed, check logs for details')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if inspection is completed
    final bool isCompleted = _inspection?['status'] == 'completed';
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background color
      appBar: AppBar(
        title: Text(_inspection?['title'] ?? 'Inspection'),
        backgroundColor: const Color(0xFF1E293B), // Slate app bar color
        actions: [
          if (!isCompleted) // Only show if not completed
            IconButton(
              icon: const Icon(Icons.report_problem),
              tooltip: 'Non-Conformities',
              onPressed: _navigateToNonConformities,
            ),
          if (_isOnline && !isCompleted) // Only show sync button if online and not completed
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync',
              onPressed: _syncInspection,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading || isCompleted ? null : _saveInspection,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading || _isDownloading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isDownloading 
                        ? 'Downloading inspection data...' 
                        : 'Loading...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return _buildLandscapeLayout();
                } else {
                  return _buildPortraitLayout();
                }
              },
            ),
      floatingActionButton: isCompleted 
          ? null // No FAB for completed inspections
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _addRoom,
                  heroTag: 'addRoom',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  onPressed: _completeInspection,
                  heroTag: 'complete',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                ),
              ],
            ),
    );
  }

  Widget _buildPortraitLayout() {
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No rooms added',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click the + button to add rooms',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addRoom,
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        
        return RoomWidget(
          room: room,
          onRoomUpdated: _handleRoomUpdate,
          onRoomDeleted: _handleRoomDelete,
          onRoomDuplicated: _duplicateRoom,
          isExpanded: index == _expandedRoomIndex,
          onExpansionChanged: () {
            setState(() {
              _expandedRoomIndex = _expandedRoomIndex == index ? -1 : index;
            });
          },
        );
      },
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Rooms column
        Expanded(
          flex: 2,
          child: _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_work_outlined, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No rooms', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addRoom,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return ListTile(
                      title: Text(room.roomName, style: const TextStyle(color: Colors.white)),
                      selected: _selectedRoomIndex == index,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                      onTap: () => _loadItemsForRoom(index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white),
                            onPressed: () => _duplicateRoom(room),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: () async {
                              if (room.id != null) {
                                await _handleRoomDelete(room.id!);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Vertical divider
        VerticalDivider(thickness: 1, width: 1, color: Colors.grey[700]),

        // Items column
        Expanded(
          flex: 3,
          child: _selectedRoomIndex < 0
              ? const Center(child: Text('Select a room', style: TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    // Header with add item button
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Items - ${_rooms[_selectedRoomIndex].roomName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.white),
                            onPressed: () async {
                              // Logic to add item
                              if (_selectedRoomIndex >= 0 && _rooms[_selectedRoomIndex].id != null) {
                                final name = await _showTextInputDialog('Add Item', 'Item name');
                                if (name != null && name.isNotEmpty) {
                                  await _inspectionService.addItem(
                                    widget.inspectionId,
                                    _rooms[_selectedRoomIndex].id!,
                                    name,
                                  );
                                  await _loadItemsForRoom(_selectedRoomIndex);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Items list
                    Expanded(
                      child: _selectedRoomItems.isEmpty
                          ? const Center(child: Text('No items in this room', style: TextStyle(color: Colors.white)))
                          : ListView.builder(
                              itemCount: _selectedRoomItems.length,
                              itemBuilder: (context, index) {
                                final item = _selectedRoomItems[index];
                                return ListTile(
                                  title: Text(item.itemName, style: const TextStyle(color: Colors.white)),
                                  selected: _selectedItemIndex == index,
                                  selectedTileColor: Colors.blue.withOpacity(0.1),
                                  onTap: () => _loadDetailsForItem(index),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.white),
                                    onPressed: () async {
                                      // Logic to delete item
                                      if (item.id != null && item.roomId != null) {
                                        await _inspectionService.deleteItem(
                                          widget.inspectionId,
                                          item.roomId!,
                                          item.id!,
                                        );
                                        await _loadItemsForRoom(_selectedRoomIndex);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),

        // Vertical divider
        VerticalDivider(thickness: 1, width: 1, color: Colors.grey[700]),

        // Details column
        Expanded(
          flex: 5,
          child: _selectedItemIndex < 0
              ? const Center(child: Text('Select an item', style: TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    // Header with add detail button
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Details - ${_selectedRoomItems[_selectedItemIndex].itemName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.white),
                            onPressed: () async {
                              // Logic to add detail
                              if (_selectedItemIndex >= 0) {
                                final item = _selectedRoomItems[_selectedItemIndex];
                                if (item.id != null && item.roomId != null) {
                                  final name = await _showTextInputDialog('Add Detail', 'Detail name');
                                  if (name != null && name.isNotEmpty) {
                                    await _inspectionService.addDetail(
                                      widget.inspectionId,
                                      item.roomId!,
                                      item.id!,
                                      name,
                                    );
                                    await _loadDetailsForItem(_selectedItemIndex);
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Details list
                    Expanded(
                      child: _selectedItemDetails.isEmpty
                          ? const Center(child: Text('No details in this item', style: TextStyle(color: Colors.white)))
                          : ListView.builder(
                              itemCount: _selectedItemDetails.length,
                              itemBuilder: (context, index) {
                                final detail = _selectedItemDetails[index];
                                return Card(
                                  margin: const EdgeInsets.all(8),
                                  color: Colors.grey[800],
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                detail.detailName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.white),
                                              onPressed: () async {
                                                // Logic to delete detail
                                                if (detail.id != null && detail.roomId != null && detail.itemId != null) {
                                                  await _inspectionService.deleteDetail(
                                                    widget.inspectionId,
                                                    detail.roomId!,
                                                    detail.itemId!,
                                                    detail.id!,
                                                  );
                                                  await _loadDetailsForItem(_selectedItemIndex);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // "Damaged" checkbox
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: detail.isDamaged ?? false,
                                              onChanged: (value) async {
                                                // Update the detail
                                                final updatedDetail = detail.copyWith(
                                                  isDamaged: value,
                                                  updatedAt: DateTime.now(),
                                                );
                                                await _inspectionService.updateDetail(updatedDetail);
                                                await _loadDetailsForItem(_selectedItemIndex);
                                              },
                                            ),
                                            const Text('Damaged', style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                        
                                        // Value field
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          initialValue: detail.detailValue,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            labelText: 'Value',
                                            border: OutlineInputBorder(),
                                            labelStyle: TextStyle(color: Colors.white70),
                                            fillColor: Colors.white10,
                                            filled: true,
                                          ),
                                          onChanged: (value) async {
                                            // Update the detail after a delay
                                            final updatedDetail = detail.copyWith(
                                              detailValue: value,
                                              updatedAt: DateTime.now(),
                                            );
                                            await _inspectionService.updateDetail(updatedDetail);
                                          },
                                        ),
                                        
                                        // Observation field
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          initialValue: detail.observation,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            labelText: 'Observation',
                                            border: OutlineInputBorder(),
                                            labelStyle: TextStyle(color: Colors.white70),
                                            fillColor: Colors.white10,
                                            filled: true,
                                          ),
                                          maxLines: 3,
                                          onChanged: (value) async {
                                            // Update the detail after a delay
                                            final updatedDetail = detail.copyWith(
                                              observation: value,
                                              updatedAt: DateTime.now(),
                                            );
                                            await _inspectionService.updateDetail(updatedDetail);
                                          },
                                        ),
                                        
                                        // Add non-conformity button
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            // Navigate to non-conformity screen with this detail pre-selected
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => NonConformityScreen(
                                                  inspectionId: widget.inspectionId,
                                                  preSelectedRoom: detail.roomId,
                                                  preSelectedItem: detail.itemId,
                                                  preSelectedDetail: detail.id,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.report_problem),
                                          label: const Text('Add Non-Conformity'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
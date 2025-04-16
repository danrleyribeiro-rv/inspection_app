// lib/presentation/screens/inspection/offline_inspection_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/inspection/components/empty_room_state.dart';
import 'package:inspection_app/presentation/screens/inspection/components/offline_inspection_header.dart';
import 'package:inspection_app/presentation/screens/inspection/components/rooms_list.dart';

class OfflineInspectionScreen extends StatefulWidget {
  final int inspectionId;

  const OfflineInspectionScreen({
    Key? key,
    required this.inspectionId,
  }) : super(key: key);

  @override
  State<OfflineInspectionScreen> createState() =>
      _OfflineInspectionScreenState();
}

class _OfflineInspectionScreenState extends State<OfflineInspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  Inspection? _inspection;
  List<Room> _rooms = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOffline = false;
  int _expandedRoomIndex = -1;
  double _completionPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInspection();
    _checkConnectivity();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });

      // If we're back online and have pending changes, try to sync
      if (result != ConnectivityResult.none) {
        _syncInspection(showSuccess: false);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _loadInspection() async {
    setState(() => _isLoading = true);

    try {
      // Load inspection from local database
      final inspection =
          await _inspectionService.getInspection(widget.inspectionId);

      if (inspection == null) {
        // Try to download if online
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          final downloaded =
              await _syncService.downloadInspection(widget.inspectionId);

          if (!downloaded) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Inspection not found and could not be downloaded')),
              );
              Navigator.of(context).pop();
            }
            return;
          }

          // Now load the downloaded inspection
          final downloadedInspection =
              await _inspectionService.getInspection(widget.inspectionId);
          if (downloadedInspection == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Error loading downloaded inspection')),
              );
              Navigator.of(context).pop();
            }
            return;
          }

          _inspection = downloadedInspection;
        } else {
          // Offline and no local data
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Inspection not found in offline storage')),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      } else {
        _inspection = inspection;
      }

      // Load rooms
      await _loadRooms();

      // Calculate completion percentage
      await _updateCompletionPercentage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inspection: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    
    try {
      // Limpar lista existente para evitar duplicações
      _rooms.clear();
      
      // Verificar se já existem ambientes
      final existingRooms = await _inspectionService.getRooms(widget.inspectionId);
      
      if (existingRooms.isNotEmpty) {
        // Usar os ambientes existentes
        setState(() {
          _rooms = existingRooms;
          _isLoading = false;
        });
        return;
      }
      
      // Se não houver ambientes, deixar a lista vazia
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar ambientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ambientes: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCompletionPercentage() async {
    try {
      final percentage = await _inspectionService
          .calculateCompletionPercentage(widget.inspectionId);
      setState(() {
        _completionPercentage = percentage;
      });
    } catch (e) {
      // Just ignore errors here
    }
  }

  Future<void> _syncInspection({bool showSuccess = true}) async {
    if (_isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot sync while offline')),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final success =
          await _inspectionService.syncInspection(widget.inspectionId);

      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Inspection synced successfully'
                : 'Error syncing inspection'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sync: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _duplicateRoom(Room room) async {
    setState(() => _isLoading = true);
    
    try {
      // Create a copy of the room with a new name
      final copyName = "${room.roomName} (cópia)";
      
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
        const SnackBar(content: Text('Ambiente duplicado com sucesso!'))
      );
    } catch (e) {
      print('Erro ao duplicar ambiente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar ambiente: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

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
      if (_inspection?.status == 'pending') {
        final updatedInspection = _inspection!.copyWith(
          status: 'in_progress', 
          updatedAt: DateTime.now()
        );
        
        await _inspectionService.saveInspection(updatedInspection, syncNow: !_isOffline);
        
        setState(() {
          _inspection = updatedInspection;
        });
      } else {
        // Just mark as updated
        final updatedInspection = _inspection!.copyWith(
          updatedAt: DateTime.now()
        );
        
        await _inspectionService.saveInspection(updatedInspection, syncNow: !_isOffline);
      }
      
      // Try to sync if online
      if (!_isOffline) {
        await _syncInspection(showSuccess: false);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection saved successfully!'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      print('Error saving inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving inspection: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleRoomUpdate(Room updatedRoom) {
    setState(() {
      final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
      if (index >= 0) {
        _rooms[index] = updatedRoom;
      }
    });

    _inspectionService.updateRoom(updatedRoom);

    // Mark inspection as modified
    if (_inspection != null) {
      _inspectionService.saveInspection(
        _inspection!.copyWith(updatedAt: DateTime.now()),
        syncNow: false,
      );

      // Try to sync if online
      if (!_isOffline) {
        _syncInspection(showSuccess: false);
      }

      // Update completion percentage
      _updateCompletionPercentage();
    }
  }

  Future<void> _handleRoomDelete(int roomId) async {
    try {
      await _inspectionService.deleteRoom(widget.inspectionId, roomId);

      setState(() {
        _rooms.removeWhere((r) => r.id == roomId);
      });

      // Mark inspection as modified
      if (_inspection != null) {
        await _inspectionService.saveInspection(
          _inspection!.copyWith(updatedAt: DateTime.now()),
          syncNow: false,
        );

        // Try to sync if online
        if (!_isOffline) {
          _syncInspection(showSuccess: false);
        }

        // Update completion percentage
        _updateCompletionPercentage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting room: $e')),
        );
      }
    }
  }

  Future<void> _completeInspection() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Inspection'),
        content: const Text(
            'Are you sure you want to mark this inspection as completed?\n\nOnce completed, you won\'t be able to make further changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.green),
            child:
                const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Update inspection status and add completion timestamp
      final updatedInspection = _inspection!.copyWith(
        status: 'completed',
        finishedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to local database
      await _inspectionService.saveInspection(updatedInspection,
          syncNow: false);

      // Update state
      setState(() {
        _inspection = updatedInspection;
      });

      // Try to sync immediately
      await _syncInspection();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to the previous screen
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    // Check if inspection is completed
    final bool isCompleted = _inspection?.status == 'completed';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspection'),
        actions: [
          // Add room button
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _addRoom,
              tooltip: 'Add Room',
            ),
          
          // Sync button
          if (!isCompleted)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed:
                      _isSyncing || _isOffline ? null : () => _syncInspection(),
                  tooltip: _isOffline ? 'Offline' : 'Sync',
                ),
                if (_isSyncing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
            
          // Save button
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveInspection,
              tooltip: 'Save',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status indicator and progress bar
                if (_inspection != null)
                  OfflineInspectionHeader(
                    inspection: _inspection!,
                    completionPercentage: _completionPercentage,
                    isOffline: _isOffline,
                  ),
                
                // Rooms list
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
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
  
  Widget _buildMainContent() {
    if (_rooms.isEmpty) {
      return EmptyRoomState(onAddRoom: _addRoom);
    }

    return RoomsList(
      rooms: _rooms,
      expandedRoomIndex: _expandedRoomIndex,
      onRoomUpdated: _handleRoomUpdate,
      onRoomDeleted: _handleRoomDelete,
      onRoomDuplicated: _duplicateRoom,
      onExpansionChanged: (index) {
        setState(() {
          _expandedRoomIndex = _expandedRoomIndex == index ? -1 : index;
        });
      },
    );
  }
}
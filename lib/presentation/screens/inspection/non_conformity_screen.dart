// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_form.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_list.dart';

class NonConformityScreen extends StatefulWidget {
  final int inspectionId;
  final int? preSelectedRoom;
  final int? preSelectedItem;
  final int? preSelectedDetail;

  const NonConformityScreen({
    Key? key,
    required this.inspectionId,
    this.preSelectedRoom,
    this.preSelectedItem,
    this.preSelectedDetail,
  }) : super(key: key);

  @override
  State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
    with SingleTickerProviderStateMixin {
  final _inspectionService = InspectionService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isOffline = false;
  List<Room> _rooms = [];
  List<Item> _items = [];
  List<Detail> _details = [];
  List<Map<String, dynamic>> _nonConformities = [];

  Room? _selectedRoom;
  Item? _selectedItem;
  Detail? _selectedDetail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkConnectivity();
    _loadData();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Replace the problematic code in _loadData method
Future<void> _loadData() async {
  setState(() => _isLoading = true);

  try {
    // Load rooms
    final rooms = await _inspectionService.getRooms(widget.inspectionId);
    setState(() => _rooms = rooms);

    // If there's a pre-selection, load items and details
    if (widget.preSelectedRoom != null) {
      // Find the room in the loaded rooms
      Room? foundRoom;
      for (var room in _rooms) {
        if (room.id == widget.preSelectedRoom) {
          foundRoom = room;
          break;
        }
      }
      
      // If room is found, use it; otherwise use first room if available
      if (foundRoom != null) {
        await _roomSelected(foundRoom);
      } else if (_rooms.isNotEmpty) {
        await _roomSelected(_rooms.first);
      }

      if (widget.preSelectedItem != null && _items.isNotEmpty) {
        // Similar approach for item
        Item? foundItem;
        for (var item in _items) {
          if (item.id == widget.preSelectedItem) {
            foundItem = item;
            break;
          }
        }
        
        if (foundItem != null) {
          await _itemSelected(foundItem);
        } else if (_items.isNotEmpty) {
          await _itemSelected(_items.first);
        }

        if (widget.preSelectedDetail != null && _details.isNotEmpty) {
          // And for detail
          Detail? foundDetail;
          for (var detail in _details) {
            if (detail.id == widget.preSelectedDetail) {
              foundDetail = detail;
              break;
            }
          }
          
          if (foundDetail != null) {
            _detailSelected(foundDetail);
          } else if (_details.isNotEmpty) {
            _detailSelected(_details.first);
          }
        }
      }
    }

    // Load existing non-conformities
    await _loadNonConformities();

    setState(() => _isLoading = false);
  } catch (e) {
    print('Error loading data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _loadNonConformities() async {
    try {
      if (_isOffline) {
        // Load from local storage
        final localNCs = await LocalDatabaseService.getNonConformitiesByInspection(widget.inspectionId);

        // Convert to expected format
        List<Map<String, dynamic>> formattedNCs = [];
        for (var nc in localNCs) {
          Room? room = await LocalDatabaseService.getRoomById(nc['room_id']);
          Item? item = await LocalDatabaseService.getItemById(nc['item_id']);
          Detail? detail = await LocalDatabaseService.getDetailById(nc['detail_id']);

          if (room != null && item != null && detail != null) {
            formattedNCs.add({
              ...nc,
              'rooms': {
                'room_name': room.roomName,
                'id': room.id,
              },
              'room_items': {
                'item_name': item.itemName,
                'id': item.id,
              },
              'item_details': {
                'detail_name': detail.detailName,
                'id': detail.id,
              },
            });
          }
        }

        setState(() {
          _nonConformities = formattedNCs;
        });
      } else {
        // Try to load from service
        _nonConformities = await _loadNonConformitiesFromService();
      }
    } catch (e) {
      print('Error loading non-conformities: $e');
      try {
        // Fallback to local
        final localNCs = await LocalDatabaseService.getNonConformitiesByInspection(widget.inspectionId);
        setState(() {
          _nonConformities = localNCs;
        });
      } catch (localError) {
        print('Error loading local non-conformities: $localError');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadNonConformitiesFromService() async {
    // This would be implemented in a real service
    // For now, simulating with local data
    return [];
  }

  Future<void> _roomSelected(Room room) async {
    setState(() {
      _selectedRoom = room;
      _selectedItem = null;
      _selectedDetail = null;
      _items = [];
      _details = [];
    });

    if (room.id != null) {
      try {
        final items = await _inspectionService.getItems(widget.inspectionId, room.id!);
        setState(() => _items = items);
      } catch (e) {
        print('Error loading items: $e');
      }
    }
  }

  Future<void> _itemSelected(Item item) async {
    setState(() {
      _selectedItem = item;
      _selectedDetail = null;
      _details = [];
    });

    if (item.id != null && item.roomId != null) {
      try {
        final details = await _inspectionService.getDetails(
            widget.inspectionId, item.roomId!, item.id!);
        setState(() => _details = details);
      } catch (e) {
        print('Error loading details: $e');
      }
    }
  }

  void _detailSelected(Detail detail) {
    setState(() => _selectedDetail = detail);
  }

  Future<void> _updateNonConformityStatus(int id, String newStatus) async {
    try {
      await LocalDatabaseService.updateNonConformityStatus(id, newStatus);
      
      // Reload list
      await _loadNonConformities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _onNonConformitySaved() {
    // Reload the list of non-conformities
    _loadNonConformities();
    
    // Switch to the list tab
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-Conformities'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Register New'),
            Tab(text: 'Existing Non-Conformities'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                NonConformityForm(
                  rooms: _rooms,
                  items: _items,
                  details: _details,
                  selectedRoom: _selectedRoom,
                  selectedItem: _selectedItem,
                  selectedDetail: _selectedDetail,
                  inspectionId: widget.inspectionId,
                  isOffline: _isOffline,
                  onRoomSelected: _roomSelected,
                  onItemSelected: _itemSelected,
                  onDetailSelected: _detailSelected,
                  onNonConformitySaved: _onNonConformitySaved,
                ),
                NonConformityList(
                  nonConformities: _nonConformities,
                  inspectionId: widget.inspectionId,
                  onStatusUpdate: _updateNonConformityStatus,
                ),
              ],
            ),
    );
  }
}
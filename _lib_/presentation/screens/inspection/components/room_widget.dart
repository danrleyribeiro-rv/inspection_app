// lib/presentation/screens/inspection/components/room_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_event.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/presentation/screens/inspection/components/item_widget.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'dart:async';

class RoomWidget extends StatefulWidget {
  final Room room;
  final Function(Room) onRoomUpdated;
  final Function(int) onRoomDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const RoomWidget({
    Key? key,
    required this.room,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<RoomWidget> createState() => _RoomWidgetState();
}

class _RoomWidgetState extends State<RoomWidget> {
  List<Item> _items = [];
  bool _isLoading = true;
  int _expandedItemIndex = -1;
  final TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.room.observation ?? '';
    _isDamaged = widget.room.isDamaged ?? false;
    
    if (widget.isExpanded) {
      _loadItems();
    }
  }

  @override
  void didUpdateWidget(RoomWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update local state if room properties have changed
    if (oldWidget.room.observation != widget.room.observation) {
      _observationController.text = widget.room.observation ?? '';
    }
    
    if (oldWidget.room.isDamaged != widget.room.isDamaged) {
      _isDamaged = widget.room.isDamaged ?? false;
    }
    
    // Load items if expanded
    if (!oldWidget.isExpanded && widget.isExpanded) {
      _loadItems();
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      // Check if room.id is null
      if (widget.room.id == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Load items from repository through bloc
      final inspectionBloc = context.read<InspectionBloc>();
      final items = await inspectionBloc.inspectionRepository.getItems(
        widget.room.inspectionId,
        widget.room.id!,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    }
  }

  void _updateRoom() {
    final updatedRoom = widget.room.copyWith(
      observation: _observationController.text.isEmpty
          ? null
          : _observationController.text,
      isDamaged: _isDamaged,
      updatedAt: DateTime.now(),
    );

    widget.onRoomUpdated(updatedRoom);
  }

  Future<void> _addItem() async {
    // Check if room.id is null
    if (widget.room.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Room ID not found')),
      );
      return;
    }

    // Show template selector dialog
    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Add Item',
        type: 'item',
        parentName: widget.room.roomName,
      ),
    );
    
    if (template == null) return;
    
    setState(() => _isLoading = true);

    try {
      // Name of the item comes from the template or custom name
      final itemName = template['name'] as String;
      String? itemLabel = template['label'] as String?;
      
      // Add the item via bloc
      context.read<InspectionBloc>().add(AddItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemName,
        itemLabel: itemLabel,
      ));
      
      // Reload items
      await _loadItems();
      
      // Expand the new item
      setState(() {
        _expandedItemIndex = _items.indexWhere((i) => i.itemName == itemName);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding item: $e')),
        );
      }
    }
  }

  void _handleItemUpdate(Item updatedItem) {
    setState(() {
      final index = _items.indexWhere((i) => i.id == updatedItem.id);
      if (index >= 0) {
        _items[index] = updatedItem;
      }
    });

    context.read<InspectionBloc>().add(UpdateItem(updatedItem));
  }

  Future<void> _handleItemDelete(int itemId) async {
    if (widget.room.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Room ID not found')),
      );
      return;
    }
    
    context.read<InspectionBloc>().add(DeleteItem(
      widget.room.inspectionId,
      widget.room.id!,
      itemId,
    ));
    
    // Update local state
    setState(() {
      _items.removeWhere((item) => item.id == itemId);
    });
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
            'Are you sure you want to delete "${widget.room.roomName}"?\n\nAll items, details, and media associated with this room will be permanently deleted.'),
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

    if (confirmed == true && widget.room.id != null) {
      widget.onRoomDeleted(widget.room.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isDamaged ? Colors.red : Colors.grey.shade300,
          width: _isDamaged ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Card header (always visible)
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.roomName,
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (widget.room.roomLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.room.roomLabel!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmation,
                    tooltip: 'Delete Room',
                  ),
                  Icon(
                    widget.isExpanded 
                        ? Icons.expand_less 
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Damaged checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _isDamaged,
                        onChanged: (value) {
                          setState(() {
                            _isDamaged = value ?? false;
                          });
                          _updateRoom();
                        },
                      ),
                      const Text('Room damaged'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Observations field
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      border: OutlineInputBorder(),
                      hintText: 'Add observations about this room...',
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      // Use debounce to not update the database on every keystroke
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        _updateRoom();
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Items section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Items list
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No items added yet'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return ItemWidget(
                          item: _items[index],
                          onItemUpdated: _handleItemUpdate,
                          onItemDeleted: _handleItemDelete,
                          isExpanded: index == _expandedItemIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedItemIndex = _expandedItemIndex == index ? -1 : index;
                            });
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
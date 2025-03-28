// lib/presentation/screens/inspection/room_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/presentation/screens/inspection/item_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';

class RoomWidget extends StatefulWidget {
  final Room room;
  final dynamic roomTemplate; // Template configuration from inspection
  final Function(Room) onRoomUpdated;
  final Function(int) onRoomDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const RoomWidget({
    Key? key,
    required this.room,
    required this.roomTemplate,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<RoomWidget> createState() => _RoomWidgetState();
}

class _RoomWidgetState extends State<RoomWidget> {
  final InspectionService _inspectionService = InspectionService();
  List<Item> _items = [];
  bool _isLoading = true;
  int _expandedItemIndex = -1;
  TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observationController.text = widget.room.observation ?? '';
    _isDamaged = widget.room.isDamaged ?? false;
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      // Load items from local database
      final items = await _inspectionService.getItems(
        widget.room.inspectionId,
        widget.room.id!,
      );

      setState(() {
        _items = items;
        _isLoading = false;
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
    // Find an item template that's not already implemented
    List<dynamic> itemTemplates = widget.roomTemplate['items'] ?? [];
    List<String> existingItemNames = _items.map((i) => i.itemName).toList();

    List<dynamic> availableTemplates = itemTemplates
        .where((t) => !existingItemNames.contains(t['name']))
        .toList();

    if (availableTemplates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All available items have been added')),
        );
      }
      return;
    }

    // Show dialog to select an item to add
    final selectedTemplate = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTemplates.length,
            itemBuilder: (context, index) {
              final template = availableTemplates[index];
              return ListTile(
                title: Text(template['name']),
                subtitle: Text(template['description'] ?? ''),
                onTap: () => Navigator.of(context).pop(template),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedTemplate == null) return;

    setState(() => _isLoading = true);

    try {
      // Add the item to local database
      final newItem = await _inspectionService.addItem(
        widget.room.inspectionId,
        widget.room.id!,
        selectedTemplate['name'],
        label: selectedTemplate['description'],
      );

      // Refresh items list
      await _loadItems();

      // Expand the new item
      setState(() {
        _expandedItemIndex = _items.indexWhere((i) => i.id == newItem.id);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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

    _inspectionService.updateItem(updatedItem);
  }

  Future<void> _handleItemDelete(int itemId) async {
    try {
      await _inspectionService.deleteItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemId,
      );

      setState(() {
        _items.removeWhere((i) => i.id == itemId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
            'Are you sure you want to delete "${widget.room.roomName}"?\n\nAll items, details, and media associated with this room will also be deleted.'),
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

    if (confirmed == true) {
      widget.onRoomDeleted(widget.room.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    int totalItems = _items.length;
    int filledItems = _items
        .where((i) => (i.observation != null && i.observation!.isNotEmpty))
        .length;

    double progress = totalItems > 0 ? filledItems / totalItems : 0.0;

    // Check if room itself has data filled
    bool isRoomFilled = (widget.room.observation != null &&
        widget.room.observation!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRoomFilled ? Colors.purple : Colors.grey,
          width: isRoomFilled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isRoomFilled
                  ? Colors.purple.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.room.roomName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _showDeleteConfirmation,
                      tooltip: 'Delete Room',
                    ),
                    IconButton(
                      icon: Icon(
                        widget.isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed: widget.onExpansionChanged,
                      tooltip: widget.isExpanded ? 'Collapse' : 'Expand',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Only show content when expanded
          if (widget.isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room description if available
                  if (widget.room.roomLabel != null &&
                      widget.room.roomLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.room.roomLabel!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  // Room general observation
                  const Text(
                    'General Observations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),

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
                      const Text('Room is damaged'),
                    ],
                  ),

                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      hintText: 'Enter any observations about this room...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (_) => _updateRoom(),
                  ),

                  const SizedBox(height: 24),

                  // Items section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'No items added yet. Click "Add Item" to begin.'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        // Find the template for this item
                        final itemTemplate =
                            (widget.roomTemplate['items'] as List?)?.firstWhere(
                          (t) => t['name'] == item.itemName,
                          orElse: () => <String,
                              Object>{}, // Modificado para Map<String, Object>
                        );

                        return ItemWidget(
                          item: item,
                          itemTemplate: itemTemplate,
                          onItemUpdated: _handleItemUpdate,
                          onItemDeleted: _handleItemDelete,
                          isExpanded: index == _expandedItemIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedItemIndex =
                                  _expandedItemIndex == index ? -1 : index;
                            });
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

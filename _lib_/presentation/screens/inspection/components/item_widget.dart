// lib/presentation/screens/inspection/components/item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_event.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/data/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/components/detail_widget.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';

class ItemWidget extends StatefulWidget {
  final Item item;
  final Function(Item) onItemUpdated;
  final Function(int) onItemDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const ItemWidget({
    Key? key,
    required this.item,
    required this.onItemUpdated,
    required this.onItemDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  List<Detail> _details = [];
  bool _isLoading = true;
  int _expandedDetailIndex = -1;
  final TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.item.observation ?? '';
    _isDamaged = widget.item.isDamaged ?? false;
    
    if (widget.isExpanded) {
      _loadDetails();
    }
  }

  @override
  void didUpdateWidget(ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update local state if item properties have changed
    if (oldWidget.item.observation != widget.item.observation) {
      _observationController.text = widget.item.observation ?? '';
    }
    
    if (oldWidget.item.isDamaged != widget.item.isDamaged) {
      _isDamaged = widget.item.isDamaged ?? false;
    }
    
    // Load details if expanded
    if (!oldWidget.isExpanded && widget.isExpanded) {
      _loadDetails();
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    try {
      // Check if item.id and room.id are not null
      if (widget.item.id == null || widget.item.roomId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Load details from repository through bloc
      final inspectionBloc = context.read<InspectionBloc>();
      final details = await inspectionBloc.inspectionRepository.getDetails(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
      );

      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  void _updateItem() {
    final updatedItem = widget.item.copyWith(
      observation: _observationController.text.isEmpty
          ? null
          : _observationController.text,
      isDamaged: _isDamaged,
      updatedAt: DateTime.now(),
    );

    widget.onItemUpdated(updatedItem);
  }

  Future<void> _addDetail() async {
    // Check if item.id and room.id are not null
    if (widget.item.id == null || widget.item.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Item ID or Room ID not found')),
      );
      return;
    }

    // Show template selector dialog
    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Add Detail',
        type: 'detail',
        parentName: widget.item.itemName,
      ),
    );
    
    if (template == null) return;
    
    setState(() => _isLoading = true);

    try {
      // Name of the detail comes from the template or custom name
      final detailName = template['name'] as String;
      String? detailValue = template['value'] as String?;
      
      // Add the detail via bloc
      context.read<InspectionBloc>().add(AddDetail(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
        detailName,
        detailValue: detailValue,
      ));
      
      // Reload details
      await _loadDetails();
      
      // Expand the new detail
      setState(() {
        _expandedDetailIndex = _details.indexWhere((d) => d.detailName == detailName);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding detail: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleDetailUpdate(Detail updatedDetail) {
    setState(() {
      final index = _details.indexWhere((d) => d.id == updatedDetail.id);
      if (index >= 0) {
        _details[index] = updatedDetail;
      }
    });

    context.read<InspectionBloc>().add(UpdateDetail(updatedDetail));
  }

  Future<void> _handleDetailDelete(int detailId) async {
    if (widget.item.id == null || widget.item.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Item ID or Room ID not found')),
      );
      return;
    }
    
    context.read<InspectionBloc>().add(DeleteDetail(
      widget.item.inspectionId,
      widget.item.roomId!,
      widget.item.id!,
      detailId,
    ));
    
    // Update local state
    setState(() {
      _details.removeWhere((detail) => detail.id == detailId);
    });
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
            'Are you sure you want to delete "${widget.item.itemName}"?\n\nAll details and media associated with this item will be permanently deleted.'),
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

    if (confirmed == true && widget.item.id != null) {
      widget.onItemDeleted(widget.item.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
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
                          widget.item.itemName,
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (widget.item.itemLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.item.itemLabel!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmation,
                    tooltip: 'Delete Item',
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
                          _updateItem();
                        },
                      ),
                      const Text('Item damaged'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Observations field
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      border: OutlineInputBorder(),
                      hintText: 'Add observations about this item...',
                    ),
                    maxLines: 3,
                    onChanged: (value) => _updateItem(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Details section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Detail'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Details list
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_details.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No details added yet'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _details.length,
                      itemBuilder: (context, index) {
                        return DetailWidget(
                          detail: _details[index],
                          onDetailUpdated: _handleDetailUpdate,
                          onDetailDeleted: _handleDetailDelete,
                          isExpanded: index == _expandedDetailIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedDetailIndex = _expandedDetailIndex == index ? -1 : index;
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
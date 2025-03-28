// lib/presentation/screens/inspection/_item_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';

class ItemWidget extends StatefulWidget {
  final Item item;
  final dynamic itemTemplate; // Template configuration from inspection
  final Function(Item) onItemUpdated;
  final Function(int) onItemDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const ItemWidget({
    Key? key,
    required this.item,
    required this.itemTemplate,
    required this.onItemUpdated,
    required this.onItemDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  final InspectionService _inspectionService = InspectionService();
  List<Detail> _details = [];
  bool _isLoading = true;
  int _expandedDetailIndex = -1;
  TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _observationController.text = widget.item.observation ?? '';
    _isDamaged = widget.item.isDamaged ?? false;
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    try {
      // Load details from local database
      final details = await _inspectionService.getDetails(
          widget.item.inspectionId, widget.item.roomId!, widget.item.id!);

      setState(() {
        _details = details;
        _isLoading = false;
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
    // Find a detail template that's not already implemented
    List<dynamic> detailTemplates = widget.itemTemplate['details'] ?? [];
    List<String> existingDetailNames =
        _details.map((d) => d.detailName).toList();

    List<dynamic> availableTemplates = detailTemplates
        .where((t) => !existingDetailNames.contains(t['name']))
        .toList();

    if (availableTemplates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All available details have been added')),
        );
      }
      return;
    }

    // Show dialog to select a detail to add
    final selectedTemplate = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Detail'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTemplates.length,
            itemBuilder: (context, index) {
              final template = availableTemplates[index];
              return ListTile(
                title: Text(template['name']),
                subtitle: Text(template['type'] ?? 'text'),
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
      // Add the detail to local database
      final newDetail = await _inspectionService.addDetail(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
        selectedTemplate['name'],
      );

      // Refresh details list
      await _loadDetails();

      // Expand the new detail
      setState(() {
        _expandedDetailIndex = _details.indexWhere((d) => d.id == newDetail.id);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding detail: $e')),
        );
      }
    }
  }

  void _handleDetailUpdate(Detail updatedDetail) {
    setState(() {
      final index = _details.indexWhere((d) => d.id == updatedDetail.id);
      if (index >= 0) {
        _details[index] = updatedDetail;
      }
    });

    _inspectionService.updateDetail(updatedDetail);
  }

  Future<void> _handleDetailDelete(int detailId) async {
    try {
      await _inspectionService.deleteDetail(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
        detailId,
      );

      setState(() {
        _details.removeWhere((d) => d.id == detailId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting detail: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
            'Are you sure you want to delete "${widget.item.itemName}"?\n\nAll details and media associated with this item will also be deleted.'),
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
      widget.onItemDeleted(widget.item.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    int totalDetails = _details.length;
    int filledDetails = _details
        .where((d) =>
            (d.detailValue != null && d.detailValue!.isNotEmpty) ||
            (d.observation != null && d.observation!.isNotEmpty))
        .length;

    double progress = totalDetails > 0 ? filledDetails / totalDetails : 0.0;

    // Check if item itself has data filled
    bool isItemFilled = (widget.item.observation != null &&
        widget.item.observation!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isItemFilled ? Colors.blue : Colors.grey,
          width: isItemFilled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isItemFilled
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _showDeleteConfirmation,
                      tooltip: 'Delete Item',
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
                  // Item description if available
                  if (widget.item.itemLabel != null &&
                      widget.item.itemLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.item.itemLabel!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  // Item general observation
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
                          _updateItem();
                        },
                      ),
                      const Text('Item is damaged'),
                    ],
                  ),

                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      hintText: 'Enter any observations about this item...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (_) => _updateItem(),
                  ),

                  const SizedBox(height: 24),

                  // Details section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Detail'),
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
                  else if (_details.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'No details added yet. Click "Add Detail" to begin.'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _details.length,
                      itemBuilder: (context, index) {
                        final detail = _details[index];

                        final detailTemplate =
                            (widget.itemTemplate['details'] as List?)
                                ?.firstWhere(
                          (t) => t['name'] == detail.detailName,
                          orElse: () => <String, Object>{
                            'type': 'text'
                          }, // Se precisar de valores padrão
                        );

                        return DetailWidget(
                          detail: detail,
                          detailTemplate: detailTemplate,
                          onDetailUpdated: _handleDetailUpdate,
                          onDetailDeleted: _handleDetailDelete,
                          isExpanded: index == _expandedDetailIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedDetailIndex =
                                  _expandedDetailIndex == index ? -1 : index;
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

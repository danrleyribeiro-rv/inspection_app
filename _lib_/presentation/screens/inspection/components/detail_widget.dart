// lib/presentation/screens/inspection/components/detail_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/data/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media_input_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';

class DetailWidget extends StatefulWidget {
  final Detail detail;
  final Function(Detail) onDetailUpdated;
  final Function(int) onDetailDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const DetailWidget({
    Key? key,
    required this.detail,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;

  @override
  void initState() {
    super.initState();
    _valueController.text = widget.detail.detailValue ?? '';
    _observationController.text = widget.detail.observation ?? '';
    _isDamaged = widget.detail.isDamaged ?? false;
  }

  @override
  void didUpdateWidget(DetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update controllers if detail properties have changed
    if (oldWidget.detail.detailValue != widget.detail.detailValue) {
      _valueController.text = widget.detail.detailValue ?? '';
    }
    
    if (oldWidget.detail.observation != widget.detail.observation) {
      _observationController.text = widget.detail.observation ?? '';
    }
    
    if (oldWidget.detail.isDamaged != widget.detail.isDamaged) {
      _isDamaged = widget.detail.isDamaged ?? false;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  void _updateDetail() {
    final updatedDetail = widget.detail.copyWith(
      detailValue: _valueController.text.isEmpty ? null : _valueController.text,
      observation: _observationController.text.isEmpty ? null : _observationController.text,
      isDamaged: _isDamaged,
      updatedAt: DateTime.now(),
    );

    widget.onDetailUpdated(updatedDetail);
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Detail'),
        content: Text(
            'Are you sure you want to delete "${widget.detail.detailName}"?\n\nAll associated media will be permanently deleted.'),
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

    if (confirmed == true && widget.detail.id != null) {
      widget.onDetailDeleted(widget.detail.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
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
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_isDamaged)
                    const Icon(
                      Icons.warning,
                      color: Colors.red,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.detail.detailName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDamaged ? Colors.red : null,
                      ),
                    ),
                  ),
                  if (_valueController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _valueController.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: _showDeleteConfirmation,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Detail',
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
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
                          _updateDetail();
                        },
                      ),
                      const Text('Detail damaged'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Value field
                  TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _updateDetail(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Observations field
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      border: OutlineInputBorder(),
                      hintText: 'Add observations about this detail...',
                    ),
                    maxLines: 3,
                    onChanged: (value) => _updateDetail(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Media widget
                  if (widget.detail.id != null && 
                      widget.detail.roomId != null && 
                      widget.detail.itemId != null)
                    MediaInputWidget(
                      inspectionId: widget.detail.inspectionId,
                      roomId: widget.detail.roomId!,
                      itemId: widget.detail.itemId!,
                      detailId: widget.detail.id!,
                      itemKey: "room_${widget.detail.roomId}-item_${widget.detail.itemId}",
                      detailName: widget.detail.detailName,
                      mediaRequirements: {
                        'images': {'max': 10},
                        'videos': {'max': 2}
                      },
                      rooms: const [],
                      roomIndexToIdMap: const {},
                      itemIndexToIdMap: const {},
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Non-conformity button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to non-conformity screen
                      if (widget.detail.id != null && 
                          widget.detail.roomId != null && 
                          widget.detail.itemId != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NonConformityScreen(
                              inspectionId: widget.detail.inspectionId,
                              preSelectedRoom: widget.detail.roomId,
                              preSelectedItem: widget.detail.itemId,
                              preSelectedDetail: widget.detail.id,
                            ),
                          ),
                        );
                      }
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
          ],
        ],
      ),
    );
  }
}
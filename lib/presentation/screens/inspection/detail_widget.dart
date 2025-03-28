// lib/presentation/screens/inspection/_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media_handling_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';

class DetailWidget extends StatefulWidget {
  final Detail detail;
  final dynamic detailTemplate; // Template configuration from inspection JSON
  final Function(Detail) onDetailUpdated;
  final Function(int) onDetailDeleted;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const DetailWidget({
    Key? key,
    required this.detail,
    required this.detailTemplate,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  final InspectionService _inspectionService = InspectionService();
  TextEditingController? _textController;
  String? _selectedValue;
  double? _startMeasure;
  double? _endMeasure;
  String? _observation;
  bool _isDamaged = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFromDetail();
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the detail has changed, reinitialize
    if (oldWidget.detail != widget.detail) {
      _initializeFromDetail();
    }
  }

  void _initializeFromDetail() {
    final detail = widget.detail;

    // Initialize fields based on the type of detail
    if (widget.detailTemplate['type'] == 'select') {
      _selectedValue = detail.detailValue;
    } else if (widget.detailTemplate['type'] == 'measure') {
      if (detail.detailValue != null && detail.detailValue!.contains('-')) {
        final parts = detail.detailValue!.split('-');
        _startMeasure = double.tryParse(parts[0]);
        _endMeasure = double.tryParse(parts[1]);
      }
    } else {
      // Text input
      _textController = TextEditingController(text: detail.detailValue ?? '');
    }

    // Set other properties
    _observation = detail.observation;
    _isDamaged = detail.isDamaged ?? false;

    _isInitialized = true;
  }

  void _updateDetail() {
    if (!_isInitialized) return;

    // Create updated detail value based on type
    String? detailValue;

    if (widget.detailTemplate['type'] == 'select') {
      detailValue = _selectedValue;
    } else if (widget.detailTemplate['type'] == 'measure') {
      if (_startMeasure != null || _endMeasure != null) {
        detailValue = '${_startMeasure ?? ''}-${_endMeasure ?? ''}';
      }
    } else {
      detailValue = _textController?.text;
    }

    // Create updated detail
    final updatedDetail = widget.detail.copyWith(
      detailValue: detailValue,
      observation: _observation,
      isDamaged: _isDamaged,
      updatedAt: DateTime.now(),
    );

    // Call callback
    widget.onDetailUpdated(updatedDetail);
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Detail'),
        content: Text(
            'Are you sure you want to delete "${widget.detail.detailName}"?'),
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
      widget.onDetailDeleted(widget.detail.id!);
    }
  }

  Widget _buildSelectInput() {
    // Get options from template
    List<String> options = [];
    if (widget.detailTemplate['options'] != null) {
      options = List<String>.from(widget.detailTemplate['options']);
    }

    return DropdownButtonFormField<String>(
      value: _selectedValue,
      decoration: const InputDecoration(
        labelText: 'Select an option',
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedValue = value;
        });
        _updateDetail();
      },
    );
  }

  Widget _buildMeasureInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _startMeasure?.toString(),
            decoration: const InputDecoration(
              labelText: 'Initial',
              border: OutlineInputBorder(),
              suffixText: 'm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                _startMeasure = double.tryParse(value);
              });
              _updateDetail();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            initialValue: _endMeasure?.toString(),
            decoration: const InputDecoration(
              labelText: 'Final',
              border: OutlineInputBorder(),
              suffixText: 'm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                _endMeasure = double.tryParse(value);
              });
              _updateDetail();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return TextFormField(
      controller: _textController,
      decoration: const InputDecoration(
        labelText: 'Value',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        _updateDetail();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if detail is filled to show indicator
    final isFilled = (widget.detail.detailValue != null &&
            widget.detail.detailValue!.isNotEmpty) ||
        (widget.detail.observation != null &&
            widget.detail.observation!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isFilled ? Colors.green : Colors.grey,
          width: isFilled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isFilled
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                if (isFilled)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.detail.detailName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _showDeleteConfirmation(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: widget.onExpansionChanged,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content (only visible when expanded)
          if (widget.isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Required indicator if needed
                  if (widget.detailTemplate['required'] == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '* Required',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

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
                      const Text('Damaged'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Detail input based on type
                  if (widget.detailTemplate['type'] == 'select')
                    _buildSelectInput()
                  else if (widget.detailTemplate['type'] == 'measure')
                    _buildMeasureInput()
                  else
                    _buildTextInput(),

                  const SizedBox(height: 16),

                  // Observation field
                  TextFormField(
                    initialValue: _observation,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      setState(() {
                        _observation = value;
                      });
                      _updateDetail();
                    },
                  ),

                  const SizedBox(height: 16),

                  // Media handling
                  MediaHandlingWidget(
                    inspectionId: widget.detail.inspectionId,
                    roomId: widget.detail.roomId!,
                    itemId: widget.detail.itemId!,
                    detailId: widget.detail.id!,
                    onMediaAdded: (String _) {
                      // Just update UI state, media is saved separately
                      setState(() {});
                    },
                    onMediaDeleted: (String _) {
                      // Just update UI state, media is deleted separately
                      setState(() {});
                    },
                    onMediaMoved: (String _, int __, int ___, int ____) {
                      // Just update UI state, media is moved separately
                      setState(() {});
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

// lib/presentation/screens/inspection/detail_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/inspection/media_input_widget.dart';

class DetailWidget extends StatefulWidget {
  final dynamic detail;
  final String itemKey;
  final int inspectionId;
  final Function(String, String, Map<String, dynamic>) onDataChanged;
  final Map<String, Map<String, dynamic>> inspectionData;
  final List<dynamic> rooms;
  final Map<int, int> roomIndexToIdMap;
  final Map<String, int> itemIndexToIdMap;
  final bool isExpanded; // Added isExpanded
  final VoidCallback onExpansionChanged; // Added onExpansionChanged

  const DetailWidget({
    super.key,
    required this.detail,
    required this.itemKey,
    required this.inspectionId,
    required this.onDataChanged,
    required this.inspectionData,
    required this.rooms,
    required this.roomIndexToIdMap,
    required this.itemIndexToIdMap,
    required this.isExpanded, // Initialize isExpanded
    required this.onExpansionChanged, // Initialize onExpansionChanged
  });

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  String? _selectedValue;
  final _textController = TextEditingController();
  bool _isDamaged = false;
  String? _observations;
  double? _startMeasure;
  double? _endMeasure;

  @override
  void initState() {
    super.initState();
    _loadInitialValue();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadInitialValue() {
    final detailKey = '${widget.itemKey}-detail_${widget.detail['name']}';
    final roomData = widget.inspectionData[widget.itemKey.split('-item_')[0]];
    final itemData = roomData?[widget.itemKey];

    if (itemData != null) {
      final savedDetail = itemData;

      if (widget.detail['type'] == 'select') {
        _selectedValue = savedDetail['detail_value'] as String?;
      } else if (widget.detail['type'] == 'measure') {
        final valueString = savedDetail['detail_value'] as String?;
        if (valueString != null && valueString.contains('-')) {
          final parts = valueString.split('-');
          _startMeasure = double.tryParse(parts[0]);
          _endMeasure = double.tryParse(parts[1]);
        }
      } else {
        _textController.text = savedDetail['detail_value'] as String? ?? '';
      }
      _isDamaged = savedDetail['is_damaged'] as bool? ?? false;
      _observations = savedDetail['observation'] as String?;
    }
  }

  void _onChanged(dynamic value) {
    String finalValue;
    if (widget.detail['type'] == 'measure') {
      finalValue = '${_startMeasure ?? ''}-${_endMeasure ?? ''}';
    } else {
      finalValue = value.toString();
    }

    widget.onDataChanged(
      widget.itemKey.split('-item_')[0],
      widget.itemKey,
      {
        'roomName': widget.itemKey.split('-item_')[0].split('_')[1],
        'itemName': widget.itemKey.split('-item_')[1],
        'detail_name': widget.detail['name'] ?? '',
        'detail_value': finalValue,
        'is_damaged': _isDamaged,
        'observation': _observations
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailName = widget.detail['name'] ?? 'Unnamed Detail';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('$detailName:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Checkbox(
                    value: _isDamaged,
                    onChanged: (newValue) {
                      setState(() {
                        _isDamaged = newValue ?? false;
                      });
                      _onChanged(widget.detail['type'] == 'select'
                          ? _selectedValue
                          : (widget.detail['type'] == 'measure')
                              ? '$_startMeasure-$_endMeasure'
                              : _textController.text);
                    },
                  ),
                  const Text('Danificado?'),
                ],
              ),
              if (widget.detail['required'] == true)
                const Text('* Campo Obrigatório',
                    style: TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              if (widget.detail['type'] == 'select') ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedValue,
                  items: widget.detail['options'] != null
                      ? (widget.detail['options'] as List<dynamic>)
                          .map<DropdownMenuItem<String>>((option) {
                          final optionText = option?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: optionText,
                            child: Text(optionText),
                          );
                        }).toList()
                      : [],
                  onChanged: (newValue) {
                    setState(() {
                      _selectedValue = newValue;
                    });
                    _onChanged(newValue);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Selecione uma opção',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (widget.detail['type'] == 'measure') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Medida Inicial',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _startMeasure = double.tryParse(value);
                          });
                          _onChanged('$_startMeasure-$_endMeasure');
                        },
                        controller: TextEditingController(
                            text: _startMeasure?.toString()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Medida Final',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _endMeasure = double.tryParse(value);
                          });
                          _onChanged('$_startMeasure-$_endMeasure');
                        },
                        controller:
                            TextEditingController(text: _endMeasure?.toString()),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextFormField(
                  controller: _textController,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    labelText: 'Digite $detailName',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                onChanged: (newValue) {
                  setState(() {
                    _observations = newValue;
                  });
                  _onChanged(widget.detail['type'] == 'select'
                      ? _selectedValue
                      : (widget.detail['type'] == 'measure')
                          ? '$_startMeasure-$_endMeasure'
                          : _textController.text);
                },
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
                initialValue: _observations,
              ),
              const SizedBox(height: 8),
              if (widget.detail['media_requirements'] != null)
                MediaInputWidget(
                  mediaRequirements: widget.detail['media_requirements'],
                  itemKey: widget.itemKey,
                  detailName: widget.detail['name'],
                  inspectionId: widget.inspectionId,
                  rooms: widget.rooms,
                  roomIndexToIdMap: widget.roomIndexToIdMap,
                  itemIndexToIdMap: widget.itemIndexToIdMap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
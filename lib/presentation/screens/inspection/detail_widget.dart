// lib/presentation/screens/inspection/detail_widget.dart (updated with rename)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media/media_handling_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';

class DetailWidget extends StatefulWidget {
  final Detail detail;
  final Function(Detail) onDetailUpdated;
  final Function(String) onDetailDeleted;
  final Function(Detail) onDetailDuplicated;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const DetailWidget({
    super.key,
    required this.detail,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.onDetailDuplicated,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _valueController.text = widget.detail.detailValue ?? '';
    _observationController.text = widget.detail.observation ?? '';
    _isDamaged = widget.detail.isDamaged ?? false;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateDetail() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedDetail = widget.detail.copyWith(
        detailValue:
            _valueController.text.isEmpty ? null : _valueController.text,
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        isDamaged: _isDamaged,
        updatedAt: DateTime.now(),
      );
      widget.onDetailUpdated(updatedDetail);
    });
  }

  Future<void> _renameDetail() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Detalhe',
        label: 'Nome do Detalhe',
        initialValue: widget.detail.detailName,
      ),
    );

    if (newName != null && newName != widget.detail.detailName) {
      final updatedDetail = widget.detail.copyWith(
        detailName: newName,
        updatedAt: DateTime.now(),
      );
      widget.onDetailUpdated(updatedDetail);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Detalhe'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.detail.detailName}"?\n\nTodas as mídias associadas serão excluídas permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
            color: _isDamaged ? Colors.red : Colors.grey.shade300,
            width: _isDamaged ? 2 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_isDamaged)
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.detail.detailName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isDamaged ? Colors.red : null,
                      ),
                    ),
                  ),
                  if (_valueController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _valueController.text,
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: _renameDetail,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Renomear Detalhe',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => widget.onDetailDuplicated(widget.detail),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Duplicate Detail',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: _showDeleteConfirmation,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Detail',
                  ),
                  const SizedBox(width: 4),
                  Icon(
                      widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      const Text('Com NC'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (widget.detail.type == 'select' &&
                      widget.detail.options != null &&
                      widget.detail.options!.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _valueController.text.isNotEmpty
                          ? _valueController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                        hintText: 'Select a value',
                      ),
                      items: widget.detail.options!.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _valueController.text = value;
                          });
                          _updateDetail();
                        }
                      },
                    )
                  else
                    TextFormField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                        hintText: 'Enter a value',
                      ),
                      onChanged: (_) => _updateDetail(),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      border: OutlineInputBorder(),
                      hintText: 'Add observations about this detail...',
                    ),
                    maxLines: 3,
                    onChanged: (_) => _updateDetail(),
                  ),
                  const SizedBox(height: 16),
                  if (widget.detail.id != null &&
                      widget.detail.topicId != null &&
                      widget.detail.itemId != null)
                    MediaHandlingWidget(
                      inspectionId: widget.detail.inspectionId,
                      topicIndex: int.parse(
                          widget.detail.topicId!.replaceFirst('topic_', '')),
                      itemIndex: int.parse(
                          widget.detail.itemId!.replaceFirst('item_', '')),
                      detailIndex: int.parse(
                          widget.detail.id!.replaceFirst('detail_', '')),
                      onMediaAdded: (_) => setState(() {}),
                      onMediaDeleted: (_) => setState(() {}),
                    ),
                  const SizedBox(height: 5),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (widget.detail.id != null &&
                          widget.detail.topicId != null &&
                          widget.detail.itemId != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NonConformityScreen(
                              inspectionId: widget.detail.inspectionId,
                              preSelectedTopic: widget.detail.topicId,
                              preSelectedItem: widget.detail.itemId,
                              preSelectedDetail: widget.detail.id,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Não foi possível abrir a tela de não-conformidade. IDs ausentes.'),
                            backgroundColor: Colors.red,
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

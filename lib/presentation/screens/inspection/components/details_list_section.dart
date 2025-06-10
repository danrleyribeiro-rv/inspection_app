import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/media/media_handling_widget.dart';

class DetailsListSection extends StatefulWidget {
  final List<Detail> details;
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Detail) onDetailUpdated;
  final VoidCallback onDetailAction;

  const DetailsListSection({
    super.key,
    required this.details,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onDetailUpdated,
    required this.onDetailAction,
  });

  @override
  State<DetailsListSection> createState() => _DetailsListSectionState();
}

class _DetailsListSectionState extends State<DetailsListSection> {
  int _expandedDetailIndex = -1;
  List<Detail> _localDetails = [];

  @override
  void initState() {
    super.initState();
    _localDetails = List.from(widget.details);
  }

  @override
  void didUpdateWidget(DetailsListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.details != oldWidget.details) {
      _localDetails = List.from(widget.details);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha((255 * 0.2).round())),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _localDetails.length,
        itemBuilder: (context, index) {
          final detail = _localDetails[index];
          final isExpanded = index == _expandedDetailIndex;
          
          return DetailListItem(
            key: ValueKey(detail.id),
            detail: detail,
            item: widget.item,
            topic: widget.topic,
            inspectionId: widget.inspectionId,
            isExpanded: isExpanded,
            onExpansionChanged: () {
              setState(() {
                _expandedDetailIndex = isExpanded ? -1 : index;
              });
            },
            onDetailUpdated: (updatedDetail) {
              setState(() {
                _localDetails[index] = updatedDetail;
              });
              widget.onDetailUpdated(updatedDetail);
            },
            onDetailDeleted: () => _deleteDetail(detail, index),
            onDetailDuplicated: () => _duplicateDetail(detail),
          );
        },
      ),
    );
  }

  Future<void> _deleteDetail(Detail detail, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Detalhe'),
        content: Text('Tem certeza que deseja excluir "${detail.detailName}"?\n\nEsta ação não pode ser desfeita.'),
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

    if (confirmed != true) return;

    try {
      await ServiceFactory().coordinator.deleteDetail(
        widget.inspectionId,
        widget.topic.id!,
        widget.item.id!,
        detail.id!,
      );
      
      setState(() {
        _localDetails.removeAt(index);
        if (_expandedDetailIndex == index) {
          _expandedDetailIndex = -1;
        } else if (_expandedDetailIndex > index) {
          _expandedDetailIndex--;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detalhe excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir detalhe: $e')),
        );
      }
    }
    widget.onDetailAction();
  }

  Future<void> _duplicateDetail(Detail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicar Detalhe'),
        content: Text('Deseja duplicar o detalhe "${detail.detailName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final duplicatedDetail = await ServiceFactory().coordinator.duplicateDetail(
        widget.inspectionId,
        widget.topic.id!,
        widget.item.id!,
        detail,
      );
      
      setState(() {
        _localDetails.add(duplicatedDetail);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detalhe duplicado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar detalhe: $e')),
        );
      }
    }
    widget.onDetailAction();
  }
}

class DetailListItem extends StatefulWidget {
  final Detail detail;
  final Item item;
  final Topic topic;
  final String inspectionId;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
  final Function(Detail) onDetailUpdated;
  final VoidCallback onDetailDeleted;
  final VoidCallback onDetailDuplicated;

  const DetailListItem({
    super.key,
    required this.detail,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.onDetailDuplicated,
  });

  @override
  State<DetailListItem> createState() => _DetailListItemState();
}

class _DetailListItemState extends State<DetailListItem> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  bool _isDamaged = false;
  String _currentDetailName = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(DetailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detail.detailName != _currentDetailName ||
        widget.detail.detailValue != _valueController.text ||
        widget.detail.observation != _observationController.text) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    _valueController.text = widget.detail.detailValue ?? '';
    _observationController.text = widget.detail.observation ?? '';
    _isDamaged = widget.detail.isDamaged ?? false;
    _currentDetailName = widget.detail.detailName;
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
        detailValue: _valueController.text.isEmpty ? null : _valueController.text,
        observation: _observationController.text.isEmpty ? null : _observationController.text,
        isDamaged: _isDamaged,
        updatedAt: DateTime.now(),
      );
      
      _serviceFactory.coordinator.updateDetail(updatedDetail);
      widget.onDetailUpdated(updatedDetail);
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Detalhe'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextFormField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Digite suas observações...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _observationController.text = result;
      });
      _updateDetail();
    }
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
      
      setState(() {
        _currentDetailName = newName;
      });
      
      await _serviceFactory.coordinator.updateDetail(updatedDetail);
      widget.onDetailUpdated(updatedDetail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: _isDamaged ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isDamaged ? Colors.red : Colors.green.withAlpha((255 * 0.3).round()),
          width: _isDamaged ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDamaged 
                    ? Colors.red.withAlpha((255 * 0.1).round())
                    : null,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_isDamaged) 
                        const Icon(Icons.warning, color: Colors.red, size: 18),
                      if (_isDamaged) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentDetailName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isDamaged ? Colors.red : Colors.green.shade300,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: _renameDetail,
                        tooltip: 'Renomear',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: widget.onDetailDuplicated,
                        tooltip: 'Duplicar',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        onPressed: widget.onDetailDeleted,
                        tooltip: 'Excluir',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                      Icon(
                        widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.green.shade300,
                        size: 20,
                      ),
                    ],
                  ),
                  if (_valueController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Valor: ${_valueController.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.detail.type == 'select' && 
                      widget.detail.options != null && 
                      widget.detail.options!.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _valueController.text.isNotEmpty ? _valueController.text : null,
                      decoration: InputDecoration(
                        labelText: 'Valor',
                        border: const OutlineInputBorder(),
                        hintText: 'Selecione um valor',
                        labelStyle: TextStyle(color: Colors.green.shade300),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        isDense: true,
                      ),
                      dropdownColor: const Color(0xFF2A3749),
                      style: const TextStyle(color: Colors.white),
                      items: widget.detail.options!.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _valueController.text = value);
                          _updateDetail();
                        }
                      },
                    )
                  else
                    TextFormField(
                      controller: _valueController,
                      decoration: InputDecoration(
                        labelText: 'Valor',
                        border: const OutlineInputBorder(),
                        hintText: 'Digite um valor',
                        labelStyle: TextStyle(color: Colors.green.shade300),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => _updateDetail(),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  GestureDetector(
                    onTap: _editObservationDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.withAlpha((255 * 0.3).round())),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_alt, size: 16, color: Colors.green.shade300),
                              const SizedBox(width: 8),
                              Text(
                                'Observações',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade300,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.edit, size: 16, color: Colors.green.shade300),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _observationController.text.isEmpty 
                                ? 'Toque para adicionar observações...'
                                : _observationController.text,
                            style: TextStyle(
                              color: _observationController.text.isEmpty 
                                  ? Colors.green.shade200
                                  : Colors.white,
                              fontStyle: _observationController.text.isEmpty 
                                  ? FontStyle.italic 
                                  : FontStyle.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Mídia', style: TextStyle(fontSize: 12)),
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.report_problem, size: 16),
                          label: const Text('NC', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            if (widget.detail.id != null && 
                                widget.detail.topicId != null && 
                                widget.detail.itemId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NonConformityScreen(
                                    inspectionId: widget.inspectionId,
                                    preSelectedTopic: widget.detail.topicId,
                                    preSelectedItem: widget.detail.itemId,
                                    preSelectedDetail: widget.detail.id,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  if (widget.detail.id != null && 
                      widget.detail.topicId != null && 
                      widget.detail.itemId != null)
                    MediaHandlingWidget(
                      inspectionId: widget.inspectionId,
                      topicIndex: int.parse(widget.detail.topicId!.replaceFirst('topic_', '')),
                      itemIndex: int.parse(widget.detail.itemId!.replaceFirst('item_', '')),
                      detailIndex: int.parse(widget.detail.id!.replaceFirst('detail_', '')),
                      onMediaAdded: (_) => setState(() {}),
                      onMediaDeleted: (_) => setState(() {}),
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
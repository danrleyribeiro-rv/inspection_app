// lib/presentation/screens/inspection/detail_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media/media_handling_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/widgets/media/media_capture_popup.dart';
import 'package:image_picker/image_picker.dart';

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
        detailValue: _valueController.text.isEmpty ? null : _valueController.text,
        observation: _observationController.text.isEmpty ? null : _observationController.text,
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

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Detalhe'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.4, // Altura fixa
            child: SingleChildScrollView(
              child: TextFormField(
                controller: controller,
                maxLines: null,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Digite suas observações...',
                  border: OutlineInputBorder(),
                ),
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
      _observationController.text = result;
      _updateDetail();
      setState(() {});
    }
  }

  void _showMediaCapturePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaCapturePopup(
        onMediaSelected: _captureDetailMedia,
      ),
    );
  }

  Future<void> _captureDetailMedia(ImageSource source, String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} capturado via ${source == ImageSource.camera ? 'câmera' : 'galeria'}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Detalhe'),
        content: Text('Tem certeza que deseja excluir "${widget.detail.detailName}"?\n\nTodas as mídias associadas serão excluídas permanentemente.'),
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
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isDamaged ? Colors.red : Colors.grey.shade300,
          width: _isDamaged ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isDamaged 
              ? Colors.red.withAlpha((255 * 0.05).round())
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Importante para evitar overflow
            children: [
              // Cabeçalho do detalhe
              Row(
                children: [
                  if (_isDamaged) 
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                  if (_isDamaged) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.detail.detailName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isDamaged ? Colors.red : null,
                          ),
                        ),
                        if (_valueController.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _valueController.text,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _renameDetail();
                          break;
                        case 'duplicate':
                          widget.onDetailDuplicated(widget.detail);
                          break;
                        case 'delete':
                          _showDeleteConfirmation();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Renomear'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 16),
                            SizedBox(width: 8),
                            Text('Duplicar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Checkbox de dano
              Row(
                children: [
                  Checkbox(
                    value: _isDamaged,
                    onChanged: (value) {
                      setState(() => _isDamaged = value ?? false);
                      _updateDetail();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('Com Não Conformidade'),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Campo de valor
              if (widget.detail.type == 'select' && 
                  widget.detail.options != null && 
                  widget.detail.options!.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _valueController.text.isNotEmpty ? _valueController.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _updateDetail(),
                ),
              
              const SizedBox(height: 12),
              
              // Campo de observação
              GestureDetector(
                onTap: _editObservationDialog,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _observationController,
                    decoration: InputDecoration(
                      labelText: 'Observações',
                      border: const OutlineInputBorder(),
                      hintText: _observationController.text.isEmpty 
                          ? 'Toque para adicionar observações...' 
                          : null,
                      suffixIcon: const Icon(Icons.edit, size: 16),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Mídia', style: TextStyle(fontSize: 12)),
                      onPressed: _showMediaCapturePopup,
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
                                inspectionId: widget.detail.inspectionId,
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
              
              // Widget de mídia existente (com altura limitada)
              if (widget.detail.id != null && 
                  widget.detail.topicId != null && 
                  widget.detail.itemId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 200, // Altura fixa para evitar overflow
                  child: MediaHandlingWidget(
                    inspectionId: widget.detail.inspectionId,
                    topicIndex: int.parse(widget.detail.topicId!.replaceFirst('topic_', '')),
                    itemIndex: int.parse(widget.detail.itemId!.replaceFirst('item_', '')),
                    detailIndex: int.parse(widget.detail.id!.replaceFirst('detail_', '')),
                    onMediaAdded: (_) => setState(() {}),
                    onMediaDeleted: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
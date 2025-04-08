// lib/presentation/screens/inspection/detail_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media_handling_widget.dart';
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
      margin: EdgeInsets.zero, // Remove margin
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0), // Remove rounded corners
        side: BorderSide(
          color: _isDamaged ? Colors.red : Colors.grey.shade300,
          width: _isDamaged ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho do card (sempre visível)
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(8),
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
                    tooltip: 'Excluir Detalhe',
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
          
          // Conteúdo expandido
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox para "Danificado"
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
                      const Text('Detalhe danificado'),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Campo de valor
                  TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _updateDetail(),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Campo de observação
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      hintText: 'Adicione observações sobre este detalhe...',
                    ),
                    maxLines: 3,
                    onChanged: (value) => _updateDetail(),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Media Handling Widget
                  if (widget.detail.id != null && 
                      widget.detail.roomId != null && 
                      widget.detail.itemId != null)
                    MediaHandlingWidget(
                      inspectionId: widget.detail.inspectionId,
                      roomId: widget.detail.roomId!,
                      itemId: widget.detail.itemId!,
                      detailId: widget.detail.id!,
                      onMediaAdded: (path) {
                        // Apenas para atualizar a interface
                        setState(() {});
                      },
                      onMediaDeleted: (path) {
                        // Apenas para atualizar a interface
                        setState(() {});
                      },
                      onMediaMoved: (path, newRoomId, newItemId, newDetailId) {
                        // Apenas para atualizar a interface
                        setState(() {});
                      },
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Botão de adicionar não conformidade
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navegar para tela de não conformidade
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
                    label: const Text('Adicionar Não Conformidade'),
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
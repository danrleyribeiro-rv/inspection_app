// lib/presentation/screens/inspection/item_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
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
  final InspectionService _inspectionService = InspectionService();
  List<Detail> _details = [];
  bool _isLoading = true;
  int _expandedDetailIndex = -1;
  final TextEditingController _observationController = TextEditingController();
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
      // Verificar se o item.id e room.id não são null
      if (widget.item.id == null || widget.item.roomId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Carregar detalhes do banco de dados
      final details = await _inspectionService.getDetails(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
      );

      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
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
  // Verificar se o item.id e room.id não são null
  if (widget.item.id == null || widget.item.roomId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro: ID do item ou ambiente não encontrado')),
    );
    return;
  }

  // Mostrar dialog de seleção de templates
  final template = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => TemplateSelectorDialog(
      title: 'Adicionar Detalhe',
      type: 'detail',
      parentName: widget.item.itemName,
    ),
  );
  
  if (template == null) return;
  
  setState(() => _isLoading = true);

  try {
    // Nome do detalhe vem do template selecionado ou de um nome personalizado
    final detailName = template['name'] as String;
    String? detailValue = template['value'] as String?;
    
    // Adicionar o detalhe no banco de dados local
    final newDetail = await _inspectionService.addDetail(
      widget.item.inspectionId,
      widget.item.roomId!,
      widget.item.id!,
      detailName,
      value: detailValue,
    );

    // Atualizar o detalhe com campos adicionais do template, se não for personalizado
    if (template['isCustom'] != true && template['observation'] != null) {
      final updatedDetail = newDetail.copyWith(
        detailValue: detailValue,
        observation: template['observation'] as String?,
      );
      await _inspectionService.updateDetail(updatedDetail);
    }

    // Recarregar lista de detalhes
    await _loadDetails();

    // Expandir o novo detalhe
    setState(() {
      _expandedDetailIndex = _details.indexWhere((d) => d.id == newDetail.id);
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar detalhe: $e')),
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
      // Verificar se o item.id e room.id não são null
      if (widget.item.id == null || widget.item.roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do item ou ambiente não encontrado')),
        );
        return;
      }
      
      await _inspectionService.deleteDetail(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
        detailId,
      );

      // Recarregar os detalhes após deletar
      await _loadDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detalhe removido com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover detalhe: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.item.itemName}"?\n\nTodos os detalhes e mídias associados serão excluídos permanentemente.'),
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

    if (confirmed == true && widget.item.id != null) {
      widget.onItemDeleted(widget.item.id!);
    }
  }

  // Helper para mostrar input dialog
  Future<String?> _showTextInputDialog(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result;
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
          // Cabeçalho do card (sempre visível)
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
                    tooltip: 'Excluir Item',
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
          
          // Conteúdo expandido
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            
            Padding(
              padding: const EdgeInsets.all(16),
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
                          _updateItem();
                        },
                      ),
                      const Text('Item danificado'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Campo de observação
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      hintText: 'Adicione observações sobre este item...',
                    ),
                    maxLines: 3,
                    onChanged: (value) => _updateItem(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Seção de detalhes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalhes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar Detalhe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Lista de detalhes
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_details.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum detalhe adicionado ainda'),
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
// lib/presentation/screens/inspection/room_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/presentation/screens/inspection/item_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'dart:async'; // Para debounce
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';

class RoomWidget extends StatefulWidget {
  final Room room;
  final Function(Room) onRoomUpdated;
  final Function(int) onRoomDeleted;
  final Function(Room) onRoomDuplicated; // Add duplicate functionality
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const RoomWidget({
    Key? key,
    required this.room,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.onRoomDuplicated, // Add this parameter
    required this.isExpanded,
    required this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<RoomWidget> createState() => _RoomWidgetState();
}

class _RoomWidgetState extends State<RoomWidget> {
  final InspectionService _inspectionService = InspectionService();
  List<Item> _items = [];
  bool _isLoading = true;
  int _expandedItemIndex = -1;
  final TextEditingController _observationController = TextEditingController();
  late bool _isDamaged;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observationController.text = widget.room.observation ?? '';
    _isDamaged = widget.room.isDamaged ?? false;
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      // Verificar se o room.id não é null
      if (widget.room.id == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Carregar itens do banco de dados
      final items = await _inspectionService.getItems(
        widget.room.inspectionId,
        widget.room.id!,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar itens: $e')),
        );
      }
    }
  }

  void _updateRoom() {
    final updatedRoom = widget.room.copyWith(
      observation: _observationController.text.isEmpty
          ? null
          : _observationController.text,
      isDamaged: _isDamaged,
      updatedAt: DateTime.now(),
    );

    widget.onRoomUpdated(updatedRoom);
  }

  Future<void> _addItem() async {
    // Verificar se o room.id não é null
    if (widget.room.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID do ambiente não encontrado')),
      );
      return;
    }

    // Mostrar dialog de seleção de templates
    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Item',
        type: 'item',
        parentName: widget.room.roomName,
      ),
    );
    
    if (template == null) return;
    
    setState(() => _isLoading = true);

    try {
      // Nome do item vem do template selecionado ou de um nome personalizado
      final itemName = template['name'] as String;
      String? itemLabel = template['label'] as String?;
      
      // Adicionar o item no banco de dados local
      final newItem = await _inspectionService.addItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemName,
        label: itemLabel,
      );

      // Atualizar o item com campos adicionais do template, se não for personalizado
      if (template['isCustom'] != true && template['description'] != null) {
        final updatedItem = newItem.copyWith(
          itemLabel: itemLabel,
          observation: template['description'] as String?,
        );
        await _inspectionService.updateItem(updatedItem);
      }

      // Recarregar lista de itens
      await _loadItems();

      // Expandir o novo item
      if (mounted) {
        setState(() {
          _expandedItemIndex = _items.indexWhere((i) => i.id == newItem.id);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar item: $e')),
        );
      }
    }
  }

  void _duplicateRoom() {
    widget.onRoomDuplicated(widget.room);
  }

  void _handleItemUpdate(Item updatedItem) {
    setState(() {
      final index = _items.indexWhere((i) => i.id == updatedItem.id);
      if (index >= 0) {
        _items[index] = updatedItem;
      }
    });

    _inspectionService.updateItem(updatedItem);
  }

  Future<void> _handleItemDelete(int itemId) async {
    try {
      // Verificar se o room.id não é null
      if (widget.room.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do ambiente não encontrado')),
        );
        return;
      }
      
      await _inspectionService.deleteItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemId,
      );

      // Recarregar os itens após deletar
      await _loadItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removido com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover item: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Ambiente'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.room.roomName}"?\n\nTodos os itens, detalhes e mídias associados serão excluídos permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.room.id != null) {
      widget.onRoomDeleted(widget.room.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero, // Remove margin
      elevation: 2,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.roomName,
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (widget.room.roomLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.room.roomLabel!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _duplicateRoom,
                    tooltip: 'Duplicar Ambiente',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmation,
                    tooltip: 'Excluir Ambiente',
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
                          _updateRoom();
                        },
                      ),
                      const Text('Ambiente danificado'),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Campo de observação
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      hintText: 'Adicione observações sobre este ambiente...',
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      // Usar debounce para não atualizar o banco a cada digitação
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        _updateRoom();
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Seção de itens
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Itens',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Lista de itens
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum item adicionado ainda'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return ItemWidget(
                          item: _items[index],
                          onItemUpdated: _handleItemUpdate,
                          onItemDeleted: _handleItemDelete,
                          isExpanded: index == _expandedItemIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedItemIndex = _expandedItemIndex == index ? -1 : index;
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
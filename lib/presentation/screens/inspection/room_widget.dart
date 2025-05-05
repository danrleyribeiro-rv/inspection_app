// lib/presentation/screens/inspection/room_widget.dart (updated with rename)
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/presentation/screens/inspection/item_widget.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'dart:async';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/presentation/widgets/rename_dialog.dart';

class RoomWidget extends StatefulWidget {
  final Room room;
  final Function(Room) onRoomUpdated;
  final Function(String) onRoomDeleted;
  final Function(Room) onRoomDuplicated; 
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const RoomWidget({
    super.key,
    required this.room,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.onRoomDuplicated, 
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<RoomWidget> createState() => _RoomWidgetState();
}

class _RoomWidgetState extends State<RoomWidget> {
  final FirebaseInspectionService _inspectionService = FirebaseInspectionService();
  List<Item> _items = [];
  bool _isLoading = true;
  int _expandedItemIndex = -1;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observationController.text = widget.room.observation ?? '';
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (widget.room.id == null) {
        setState(() => _isLoading = false);
        return;
      }

      final items = await _inspectionService.getItems(
        widget.room.inspectionId,
        widget.room.id!,
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });

      if (_scrollController?.hasClients ?? false) {
        _scrollController?.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar itens: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar itens: $e')),
      );
    }
  }

  void _updateRoom() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (!mounted) return;

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final updatedRoom = widget.room.copyWith(
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        updatedAt: DateTime.now(),
      );
      widget.onRoomUpdated(updatedRoom);
    });
  }

  Future<void> _renameRoom() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Tópico',
        label: 'Nome do Tópico',
        initialValue: widget.room.roomName,
      ),
    );

    if (newName != null && newName != widget.room.roomName) {
      final updatedRoom = widget.room.copyWith(
        roomName: newName,
        updatedAt: DateTime.now(),
      );
      widget.onRoomUpdated(updatedRoom);
    }
  }

  Future<void> _addItem() async {
    if (widget.room.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID do tópico não encontrado')),
      );
      return;
    }

    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Item',
        type: 'item',
        parentName: widget.room.roomName,
      ),
    );

    if (template == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final itemName = template['name'] as String;
      String? itemLabel = template['value'] as String?;

      final newItem = await _inspectionService.addItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemName,
        label: itemLabel,
      );

      if (template['isCustom'] != true && template['observation'] != null) {
        final updatedItem = newItem.copyWith(
          itemLabel: itemLabel,
          observation: template['observation'] as String?,
        );
        await _inspectionService.updateItem(updatedItem);
      }

      await _loadItems();

      if (!mounted) return;
      setState(() {
        _expandedItemIndex = _items.indexWhere((i) => i.id == newItem.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar item: $e')),
      );
    }
  }

  void _duplicateRoom() {
    widget.onRoomDuplicated(widget.room);
  }

  Future<void> _duplicateItem(Item item) async {
    if (widget.room.id == null || item.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Não é possível duplicar item com IDs ausentes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newItem = await _inspectionService.isItemDuplicate(
        widget.room.inspectionId,
        widget.room.id!,
        item.itemName,
      );

      await _loadItems();

      if (!mounted) return;
      setState(() {
        _expandedItemIndex = _items.indexWhere((i) => i.itemName == item.itemName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item "${item.itemName}" duplicado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao duplicar item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleItemUpdate(Item updatedItem) {
    final index = _items.indexWhere((i) => i.id == updatedItem.id);
    if (index >= 0) {
      setState(() => _items[index] = updatedItem);
      _inspectionService.updateItem(updatedItem);
    }
  }

  Future<void> _handleItemDelete(dynamic itemId) async {
    try {
      if (widget.room.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do tópico não encontrado')),
        );
        return;
      }

      await _inspectionService.deleteItem(
        widget.room.inspectionId,
        widget.room.id!,
        itemId,
      );

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
        title: const Text('Excluir Tópico'),
        content: Text(
            'Tem certeza de que deseja excluir "${widget.room.roomName}"?\n\nTodos os itens, detalhes e mídias associados serão excluídos permanentemente.'),
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.roomName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (widget.room.roomLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(widget.room.roomLabel!, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _renameRoom,
                    tooltip: 'Renomear Tópico',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _duplicateRoom,
                    tooltip: 'Duplicar Tópico',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmation,
                    tooltip: 'Excluir Tópico',
                  ),
                  Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more),
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
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      hintText: 'Adicione observações sobre este tópico...',
                    ),
                    maxLines: 3,
                    onChanged: (_) => _updateRoom(),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
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
                      controller: _scrollController,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return ItemWidget(
                          item: _items[index],
                          onItemUpdated: _handleItemUpdate,
                          onItemDeleted: _handleItemDelete,
                          onItemDuplicated: _duplicateItem,
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
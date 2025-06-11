import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';

class ItemDetailsSection extends StatefulWidget {
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Item) onItemUpdated;
  final VoidCallback onItemAction;

  const ItemDetailsSection({
    super.key,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onItemUpdated,
    required this.onItemAction,
  });

  @override
  State<ItemDetailsSection> createState() => _ItemDetailsSectionState();
}

class _ItemDetailsSectionState extends State<ItemDetailsSection> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  String _currentItemName = '';

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.item.observation ?? '';
    _currentItemName = widget.item.itemName;
  }

  @override
  void didUpdateWidget(ItemDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.itemName != _currentItemName) {
      _currentItemName = widget.item.itemName;
    }
    if (widget.item.observation != _observationController.text) {
      _observationController.text = widget.item.observation ?? '';
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateItem() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedItem = widget.item.copyWith(
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        updatedAt: DateTime.now(),
      );
      
      _serviceFactory.coordinator.updateItem(updatedItem);
      widget.onItemUpdated(updatedItem);
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Item'),
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
      _updateItem();
    }
  }

Future<void> _renameItem() async {
  final newName = await showDialog<String>(
    context: context,
    builder: (context) => RenameDialog(
      title: 'Renomear Item',
      label: 'Nome do Item',
      initialValue: widget.item.itemName,
    ),
  );

  if (newName != null && newName != widget.item.itemName) {
    final updatedItem = widget.item.copyWith(
      itemName: newName,
      updatedAt: DateTime.now(),
    );
    
    // Atualizar estado local imediatamente
    setState(() {
      _currentItemName = newName;
    });
    
    // Notificar o pai imediatamente
    widget.onItemUpdated(updatedItem);
    
    // Salvar no backend
    await _serviceFactory.coordinator.updateItem(updatedItem);
  }
}

  Future<void> _duplicateItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicar Item'),
        content: Text('Deseja duplicar o item "${widget.item.itemName}"?'),
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
      await _serviceFactory.coordinator.duplicateItem(
        widget.inspectionId, 
        widget.topic.id!, 
        widget.item,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item duplicado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar item: $e')),
        );
      }
    }
    widget.onItemAction();
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item'),
        content: Text('Tem certeza que deseja excluir "${widget.item.itemName}"?\n\nTodos os detalhes serão excluídos permanentemente.'),
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
      await _serviceFactory.coordinator.deleteItem(
        widget.inspectionId, 
        widget.topic.id!, 
        widget.item.id!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir item: $e')),
        );
      }
    }
    widget.onItemAction();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha((255 * 0.2).round())),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.edit,
                label: 'Renomear',
                onPressed: _renameItem,
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Duplicar',
                onPressed: _duplicateItem,
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Excluir',
                onPressed: _deleteItem,
                color: Colors.red,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.withAlpha((255 * 0.3).round())),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, size: 16, color: Colors.orange.shade300),
                      const SizedBox(width: 8),
                      Text(
                        'Observações',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade300,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, size: 16, color: Colors.orange.shade300),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _observationController.text.isEmpty 
                        ? 'Toque para adicionar observações...'
                        : _observationController.text,
                    style: TextStyle(
                      color: _observationController.text.isEmpty 
                          ? Colors.orange.shade200
                          : Colors.white,
                      fontStyle: _observationController.text.isEmpty 
                          ? FontStyle.italic 
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
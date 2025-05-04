// lib/presentation/screens/inspection/item_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'dart:async';

class ItemWidget extends StatefulWidget {
  final Item item;
  final Function(Item) onItemUpdated;
  final Function(String) onItemDeleted;
  final Function(Item) onItemDuplicated;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const ItemWidget({
    super.key,
    required this.item,
    required this.onItemUpdated,
    required this.onItemDeleted,
    required this.onItemDuplicated,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  final _inspectionService = FirebaseInspectionService();
  List<Detail> _details = [];
  bool _isLoading = true;
  int _expandedDetailIndex = -1;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _observationController.text = widget.item.observation ?? '';
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

Future<void> _loadDetails() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    if (widget.item.id == null || widget.item.roomId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final details = await _inspectionService.getDetails(
      widget.item.inspectionId,
      widget.item.roomId!,
      widget.item.id!,
    );

    if (!mounted) return;
    setState(() {
      _details = details;
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading details: $e');
    if (!mounted) return;
    setState(() => _isLoading = false);
  }
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
      widget.onItemUpdated(updatedItem);
    });
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


Future<void> _addDetail() async {
  if (widget.item.id == null || widget.item.roomId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Item or Room ID not found')),
    );
    return;
  }

  // Primeiro, precisamos buscar o nome da sala usando o roomId
  String roomName = "";
  try {
    final roomDoc = await _inspectionService.firestore
        .collection('rooms')
        .doc(widget.item.roomId)
        .get();
    
    if (roomDoc.exists && roomDoc.data() != null) {
      roomName = roomDoc.data()!['room_name'] ?? '';
    }
  } catch (e) {
    print('Erro ao buscar nome da sala: $e');
  }

  final template = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => TemplateSelectorDialog(
      title: 'Add Detail',
      type: 'detail',
      parentName: roomName,  // Agora usando o nome da sala obtido
      itemName: widget.item.itemName,
    ),
  );

  if (template == null || !mounted) return;

  setState(() => _isLoading = true);

  try {
    final detailName = template['name'] as String;
    final isCustom = template['isCustom'] as bool? ?? false;
    
    // Determinar tipo e opções
    String? detailType = 'text';  // Padrão
    List<String>? options;
    
    if (!isCustom) {
      // Se não for personalizado, obter informações do template
      detailType = template['type'] as String?;
      if (template['options'] is List) {
        options = List<String>.from(template['options']);
      }
    }

    final newDetail = await _inspectionService.addDetail(
      widget.item.inspectionId,
      widget.item.roomId!,
      widget.item.id!,
      detailName,
      type: detailType,
      options: options,
    );

    await _loadDetails();

    if (!mounted) return;

    final newIndex = _details.indexWhere((d) => d.id == newDetail.id);
    if (newIndex >= 0) {
      setState(() {
        _expandedDetailIndex = newIndex;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detail "$detailName" added successfully')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error adding detail: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _duplicateDetail(Detail detail) async {
    if (widget.item.id == null ||
        widget.item.roomId == null ||
        detail.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Cannot duplicate detail with missing IDs')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newDetail = await _inspectionService.isDetailDuplicate(
        widget.item.inspectionId,
        widget.item.roomId!,
        widget.item.id!,
        detail.detailName,
      );

      if (newDetail == null) {
        throw Exception('Failed to duplicate detail');
      }

      await _loadDetails();

      if (!mounted) return;

      final newIndex =
          _details.indexWhere((d) => d.detailName == detail.detailName);
      if (newIndex >= 0) {
        setState(() {
          _expandedDetailIndex = newIndex;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Detail "${detail.detailName}" duplicated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error duplicating detail: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showTextInputDialog(String title, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(context).pop(text.isNotEmpty ? text : null);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  @override
Widget build(BuildContext context) {
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 1,
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
                        widget.item.itemName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (widget.item.itemLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(widget.item.itemLabel!, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => widget.onItemDuplicated(widget.item),
                  tooltip: 'Duplicate Item',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _showDeleteConfirmation,
                  tooltip: 'Delete Item',
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
                    labelText: 'Observations',
                    border: OutlineInputBorder(),
                    hintText: 'Add observations about this item...',
                  ),
                  maxLines: 3,
                  onChanged: (_) => _updateItem(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addDetail,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Detail'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_details.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No details added yet'),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _scrollController,
                    itemCount: _details.length,
                    itemBuilder: (context, index) {
                      return DetailWidget(
                        detail: _details[index],
                        onDetailUpdated: (updatedDetail) {
                          final idx = _details.indexWhere((d) => d.id == updatedDetail.id);
                          if (idx >= 0) {
                            setState(() => _details[idx] = updatedDetail);
                            _inspectionService.updateDetail(updatedDetail);
                          }
                        },
                        onDetailDeleted: (detailId) async {
                          if (widget.item.id != null && widget.item.roomId != null) {
                            await _inspectionService.deleteDetail(
                              widget.item.inspectionId,
                              widget.item.roomId!,
                              widget.item.id!,
                              detailId,
                            );
                            await _loadDetails();
                          }
                        },
                        onDetailDuplicated: _duplicateDetail,
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
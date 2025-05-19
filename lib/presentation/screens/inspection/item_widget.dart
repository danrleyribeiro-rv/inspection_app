// lib/presentation/screens/inspection/item_widget.dart (updated with rename)
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/presentation/widgets/rename_dialog.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/service_factory.dart';
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
  final ServiceFactory _serviceFactory = ServiceFactory();

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
      if (widget.item.id == null || widget.item.topicId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final details = await _inspectionService.getDetails(
        widget.item.inspectionId,
        widget.item.topicId!,
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
      widget.onItemUpdated(updatedItem);
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

  Future<void> _addDetail() async {
    if (widget.item.id == null || widget.item.topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: ID do Item ou do Tópico não encontrado')),
      );
      return;
    }

    // Obter nome do tópico através do coordinator
    String topicName = "";
    try {
      final topics =
          await _serviceFactory.coordinator.getTopics(widget.item.inspectionId);
      final topic = topics.firstWhere((t) => t.id == widget.item.topicId,
          orElse: () =>
              Topic(id: '', inspectionId: '', topicName: '', position: 0));
      topicName = topic.topicName;
    } catch (e) {
      print('Erro ao buscar nome do tópico: $e');
    }

    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Detalhe',
        type: 'detail',
        parentName: topicName,
        itemName: widget.item.itemName,
      ),
    );

    if (template == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final detailName = template['name'] as String;
      final isCustom = template['isCustom'] as bool? ?? false;

      String? detailType = 'text';
      List<String>? options;

      if (!isCustom) {
        detailType = template['type'] as String?;
        if (template['options'] is List) {
          options = List<String>.from(template['options']);
        }
      }

      final newDetail = await _inspectionService.addDetail(
        widget.item.inspectionId,
        widget.item.topicId!,
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
        SnackBar(content: Text('Detalhe "$detailName" adicionado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar detalhe: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _duplicateDetail(Detail detail) async {
    if (widget.item.id == null ||
        widget.item.topicId == null ||
        detail.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Erro: Não é possível duplicar detalhe com IDs ausentes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newDetail = await _inspectionService.isDetailDuplicate(
        widget.item.inspectionId,
        widget.item.topicId!,
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
                Text('Detalhe "${detail.detailName}" duplicado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao duplicar detalhe: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (widget.item.itemLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(widget.item.itemLabel!,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _renameItem,
                    tooltip: 'Renomear Item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => widget.onItemDuplicated(widget.item),
                    tooltip: 'Duplicar Item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmation,
                    tooltip: 'Excluir Item',
                  ),
                  Icon(widget.isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more),
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
                      hintText: 'Adicione observações sobre este item...',
                    ),
                    maxLines: 1,
                    onChanged: (_) => _updateItem(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalhes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Detalhe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      controller: _scrollController,
                      itemCount: _details.length,
                      itemBuilder: (context, index) {
                        return DetailWidget(
                          detail: _details[index],
                          onDetailUpdated: (updatedDetail) {
                            final idx = _details
                                .indexWhere((d) => d.id == updatedDetail.id);
                            if (idx >= 0) {
                              setState(() => _details[idx] = updatedDetail);
                              _inspectionService.updateDetail(updatedDetail);
                            }
                          },
                          onDetailDeleted: (detailId) async {
                            if (widget.item.id != null &&
                                widget.item.topicId != null) {
                              await _inspectionService.deleteDetail(
                                widget.item.inspectionId,
                                widget.item.topicId!,
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
                              _expandedDetailIndex =
                                  _expandedDetailIndex == index ? -1 : index;
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

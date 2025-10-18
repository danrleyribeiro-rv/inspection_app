import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class NonConformityFilterDialog extends StatefulWidget {
  final String inspectionId;
  final String? initialTopicId;
  final String? initialItemId;
  final String? initialDetailId;

  const NonConformityFilterDialog({
    super.key,
    required this.inspectionId,
    this.initialTopicId,
    this.initialItemId,
    this.initialDetailId,
  });

  @override
  State<NonConformityFilterDialog> createState() =>
      _NonConformityFilterDialogState();
}

class _NonConformityFilterDialogState
    extends State<NonConformityFilterDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  bool _isLoading = true;
  List<Topic> _topics = [];
  List<Item> _items = [];
  List<Detail> _details = [];

  Topic? _selectedTopic;
  Item? _selectedItem;
  Detail? _selectedDetail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);
      setState(() => _topics = topics);

      // Se há filtro inicial de tópico, carregar itens/detalhes
      if (widget.initialTopicId != null) {
        final topic = topics.firstWhere(
          (t) => t.id == widget.initialTopicId,
          orElse: () => topics.first,
        );
        await _onTopicSelected(topic, loadInitial: true);
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados para filtro: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTopicSelected(Topic topic, {bool loadInitial = false}) async {
    setState(() {
      _selectedTopic = topic;
      _selectedItem = null;
      _selectedDetail = null;
      _items = [];
      _details = [];
    });

    try {
      if (topic.directDetails == true) {
        // Carregar detalhes diretos
        final details =
            await _serviceFactory.dataService.getDirectDetails(topic.id);
        setState(() => _details = details);

        // Se há filtro inicial de detalhe
        if (loadInitial && widget.initialDetailId != null) {
          final detail = details.firstWhere(
            (d) => d.id == widget.initialDetailId,
            orElse: () => details.first,
          );
          _onDetailSelected(detail);
        }
      } else {
        // Carregar itens
        final items = await _serviceFactory.dataService.getItems(topic.id);
        setState(() => _items = items);

        // Se há filtro inicial de item
        if (loadInitial && widget.initialItemId != null) {
          final item = items.firstWhere(
            (i) => i.id == widget.initialItemId,
            orElse: () => items.first,
          );
          await _onItemSelected(item, loadInitial: loadInitial);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar hierarquia: $e');
    }
  }

  Future<void> _onItemSelected(Item item, {bool loadInitial = false}) async {
    setState(() {
      _selectedItem = item;
      _selectedDetail = null;
      _details = [];
    });

    try {
      final details = await _serviceFactory.dataService.getDetails(item.id);
      setState(() => _details = details);

      // Se há filtro inicial de detalhe
      if (loadInitial && widget.initialDetailId != null) {
        final detail = details.firstWhere(
          (d) => d.id == widget.initialDetailId,
          orElse: () => details.first,
        );
        _onDetailSelected(detail);
      }
    } catch (e) {
      debugPrint('Erro ao carregar detalhes: $e');
    }
  }

  void _onDetailSelected(Detail detail) {
    setState(() => _selectedDetail = detail);
  }

  void _clearFilters() {
    setState(() {
      _selectedTopic = null;
      _selectedItem = null;
      _selectedDetail = null;
      _items = [];
      _details = [];
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop({
      'topicId': _selectedTopic?.id,
      'itemId': _selectedItem?.id,
      'detailId': _selectedDetail?.id,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDirectHierarchy = _selectedTopic?.directDetails == true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filtrar Não Conformidades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tópico
                          const Text(
                            'Tópico',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Topic>(
                            initialValue: _selectedTopic,
                            decoration: InputDecoration(
                              hintText: 'Selecione um tópico',
                              hintStyle: const TextStyle(fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              prefixIcon:
                                  const Icon(Icons.topic, size: 20),
                            ),
                            items: _topics.map((topic) {
                              return DropdownMenuItem<Topic>(
                                value: topic,
                                child: Text(
                                  topic.topicName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (topic) {
                              if (topic != null) {
                                _onTopicSelected(topic);
                              }
                            },
                            isExpanded: true,
                          ),

                          // Item (apenas se não for hierarquia direta)
                          if (_selectedTopic != null && !isDirectHierarchy) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Item',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<Item>(
                              initialValue: _selectedItem,
                              decoration: InputDecoration(
                                hintText: 'Selecione um item',
                                hintStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                prefixIcon:
                                    const Icon(Icons.list_alt, size: 20),
                              ),
                              items: _items.map((item) {
                                return DropdownMenuItem<Item>(
                                  value: item,
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _items.isEmpty
                                  ? null
                                  : (item) {
                                      if (item != null) {
                                        _onItemSelected(item);
                                      }
                                    },
                              isExpanded: true,
                            ),
                          ],

                          // Detalhe
                          if (_selectedTopic != null &&
                              (isDirectHierarchy || _selectedItem != null)) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Detalhe',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<Detail>(
                              initialValue: _selectedDetail,
                              decoration: InputDecoration(
                                hintText: 'Selecione um detalhe',
                                hintStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                prefixIcon:
                                    const Icon(Icons.details, size: 20),
                              ),
                              items: _details.map((detail) {
                                return DropdownMenuItem<Detail>(
                                  value: detail,
                                  child: Text(
                                    detail.detailName,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _details.isEmpty
                                  ? null
                                  : (detail) {
                                      if (detail != null) {
                                        _onDetailSelected(detail);
                                      }
                                    },
                              isExpanded: true,
                            ),
                          ],

                          // Info sobre filtros ativos
                          if (_selectedTopic != null ||
                              _selectedItem != null ||
                              _selectedDetail != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Filtros Ativos:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_selectedTopic != null)
                                    Text(
                                      '• Tópico: ${_selectedTopic!.topicName}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  if (_selectedItem != null)
                                    Text(
                                      '• Item: ${_selectedItem!.itemName}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  if (_selectedDetail != null)
                                    Text(
                                      '• Detalhe: ${_selectedDetail!.detailName}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  // Botão Limpar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Limpar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botão Aplicar
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aplicar Filtros'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

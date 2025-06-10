import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/components/swipeable_level_header.dart';
import 'package:inspection_app/presentation/screens/inspection/components/topic_details_section.dart';
import 'package:inspection_app/presentation/screens/inspection/components/item_details_section.dart';
import 'package:inspection_app/presentation/screens/inspection/components/details_list_section.dart';
import 'package:inspection_app/presentation/widgets/common/progress_circle.dart';
import 'package:inspection_app/services/service_factory.dart';

class HierarchicalInspectionView extends StatefulWidget {
  final String inspectionId;
  final List<Topic> topics;
  final Map<String, List<Item>> itemsCache;
  final Map<String, List<Detail>> detailsCache;
  final VoidCallback onUpdateCache;

  const HierarchicalInspectionView({
    super.key,
    required this.inspectionId,
    required this.topics,
    required this.itemsCache,
    required this.detailsCache,
    required this.onUpdateCache,
  });

  @override
  State<HierarchicalInspectionView> createState() =>
      _HierarchicalInspectionViewState();
}

class _HierarchicalInspectionViewState extends State<HierarchicalInspectionView> {
  final ServiceFactory _serviceFactory = ServiceFactory();

  int _currentTopicIndex = 0;
  int _currentItemIndex = 0;

  bool _isTopicExpanded = false;
  bool _isItemExpanded = false;
  bool _isDetailsExpanded = false;

  PageController? _topicPageController;
  PageController? _itemPageController;

  @override
  void initState() {
    super.initState();
    _topicPageController = PageController();
    _itemPageController = PageController();
  }

  @override
  void dispose() {
    _topicPageController?.dispose();
    _itemPageController?.dispose();
    super.dispose();
  }

  List<Item> get _currentItems {
    if (_currentTopicIndex >= widget.topics.length) return [];
    final topicId = widget.topics[_currentTopicIndex].id;
    return topicId != null ? (widget.itemsCache[topicId] ?? []) : [];
  }

  // REMOVIDO: Este getter não estava sendo utilizado.
  // List<Detail> get _currentDetails { ... }

  void _onTopicChanged(int index) {
    setState(() {
      _currentTopicIndex = index;
      _currentItemIndex = 0;
    });

    if (_itemPageController?.hasClients ?? false) {
      _itemPageController?.animateToPage(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  void _onItemChanged(int index) {
    setState(() => _currentItemIndex = index);
  }

  Future<void> _reloadCurrentData() async {
    widget.onUpdateCache();
    if (mounted) setState(() {});
  }

  Future<void> _reorderTopics(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    // Atualização otimista da UI
    final Topic item = widget.topics.removeAt(oldIndex);
    widget.topics.insert(newIndex, item);
    setState(() {});

    // Persiste a mudança
    await _serviceFactory.coordinator.reorderTopics(
        widget.inspectionId, widget.topics.map((t) => t.id!).toList());
    
    // Recarrega para garantir consistência
    await _reloadCurrentData();
  }

  Future<void> _reorderItems(String topicId, int oldIndex, int newIndex) async {
    final items = widget.itemsCache[topicId] ?? [];
    if (items.isEmpty) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    // Atualização otimista da UI
    final Item item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    widget.itemsCache[topicId] = items;
    setState(() {});

    // Persiste a mudança
    await _serviceFactory.coordinator
        .reorderItems(widget.inspectionId, topicId, oldIndex, newIndex);

    // Recarrega para garantir consistência
    await _handleItemUpdate();
  }

  Future<void> _handleTopicUpdate() async {
    await _reloadCurrentData();
  }

  Future<void> _handleItemUpdate() async {
    if (widget.topics[_currentTopicIndex].id != null) {
      final topicId = widget.topics[_currentTopicIndex].id!;
      final items =
          await _serviceFactory.coordinator.getItems(widget.inspectionId, topicId);
      widget.itemsCache[topicId] = items;

      if (_currentItemIndex >= items.length && items.isNotEmpty) {
        _currentItemIndex = items.length - 1;
      }
    }

    await _reloadCurrentData();
  }

  Future<void> _handleDetailUpdate() async {
    if (widget.topics[_currentTopicIndex].id != null &&
        _currentItems.isNotEmpty &&
        _currentItemIndex < _currentItems.length) {
      final topicId = widget.topics[_currentTopicIndex].id!;
      final itemId = _currentItems[_currentItemIndex].id!;
      final details = await _serviceFactory.coordinator
          .getDetails(widget.inspectionId, topicId, itemId);
      widget.detailsCache['${topicId}_$itemId'] = details;
    }

    await _reloadCurrentData();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topics.isEmpty) {
      return const Center(
        child: Text('Nenhum tópico encontrado',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
      );
    }

    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _topicPageController,
              itemCount: widget.topics.length,
              onPageChanged: _onTopicChanged,
              itemBuilder: (context, topicIndex) {
                final topic = widget.topics[topicIndex];
                final topicItems =
                    topic.id != null ? (widget.itemsCache[topic.id!] ?? []) : <Item>[];

                return Column(
                  children: [
                    // MODIFICADO: Usa FutureBuilder para obter o progresso do Tópico
                    FutureBuilder<double>(
                      key: ValueKey('topic_progress_${topic.id}'),
                      future: _serviceFactory.coordinator
                          .getTopicProgress(widget.inspectionId, topic.id!),
                      builder: (context, snapshot) {
                        return SwipeableLevelHeader(
                          title: topic.topicName,
                          subtitle: topic.topicLabel,
                          currentIndex: topicIndex,
                          totalCount: widget.topics.length,
                          progress: snapshot.data ?? 0.0, // Passa o progresso
                          items: widget.topics.map((t) => t.topicName).toList(),
                          onIndexChanged: (index) {
                            _topicPageController?.animateToPage(index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                          },
                          onReorder: _reorderTopics, // ADICIONADO
                          onExpansionChanged: () {
                            setState(() {
                              _isTopicExpanded = !_isTopicExpanded;
                              if (_isTopicExpanded) {
                                _isItemExpanded = false;
                                _isDetailsExpanded = false;
                              }
                            });
                          },
                          isExpanded:
                              _isTopicExpanded && topicIndex == _currentTopicIndex,
                          level: 1,
                          icon: Icons.home_work_outlined,
                        );
                      },
                    ),

                    if (_isTopicExpanded && topicIndex == _currentTopicIndex)
                      TopicDetailsSection(
                        topic: topic,
                        inspectionId: widget.inspectionId,
                        onTopicUpdated: (updatedTopic) {
                          final index = widget.topics
                              .indexWhere((t) => t.id == updatedTopic.id);
                          if (index >= 0) {
                            widget.topics[index] = updatedTopic;
                          }
                        },
                        onTopicAction: _handleTopicUpdate,
                      ),

                    if (topicItems.isNotEmpty)
                      Expanded(
                        child: PageView.builder(
                          controller: topicIndex == _currentTopicIndex
                              ? _itemPageController
                              : null,
                          itemCount: topicItems.length,
                          onPageChanged: topicIndex == _currentTopicIndex
                              ? _onItemChanged
                              : null,
                          itemBuilder: (context, itemIndex) {
                            final item = topicItems[itemIndex];
                            final itemDetails =
                                (topic.id != null && item.id != null)
                                    ? (widget.detailsCache[
                                            '${topic.id!}_${item.id!}'] ??
                                        [])
                                    : <Detail>[];

                            return Column(
                              children: [
                                // MODIFICADO: Usa FutureBuilder para obter o progresso do Item
                                FutureBuilder<double>(
                                  key: ValueKey('item_progress_${item.id}'),
                                  future: _serviceFactory.coordinator
                                      .getItemProgress(widget.inspectionId,
                                          topic.id!, item.id!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        snapshot.data == null) {
                                      // Retorna um cabeçalho com um placeholder de progresso
                                      return SwipeableLevelHeader(
                                        title: item.itemName,
                                        subtitle: item.itemLabel,
                                        currentIndex: itemIndex,
                                        totalCount: topicItems.length,
                                        progress: 0,
                                        items: topicItems
                                            .map((i) => i.itemName)
                                            .toList(),
                                        onIndexChanged: (_) {},
                                        onExpansionChanged: () {},
                                        isExpanded: false,
                                        level: 2,
                                        icon: Icons.list_alt,
                                      );
                                    }
                                    return SwipeableLevelHeader(
                                      title: item.itemName,
                                      subtitle: item.itemLabel,
                                      currentIndex: itemIndex,
                                      totalCount: topicItems.length,
                                      progress: snapshot.data ?? 0.0,
                                      items: topicItems
                                          .map((i) => i.itemName)
                                          .toList(),
                                      onIndexChanged: (index) {
                                        if (topicIndex == _currentTopicIndex) {
                                          _itemPageController?.animateToPage(
                                              index,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut);
                                        }
                                      },
                                      onReorder: (oldIdx, newIdx) =>
                                          _reorderItems(topic.id!, oldIdx, newIdx), // ADICIONADO
                                      onExpansionChanged: () {
                                        setState(() {
                                          _isItemExpanded = !_isItemExpanded;
                                          if (_isItemExpanded) {
                                            _isTopicExpanded = false;
                                            _isDetailsExpanded = false;
                                          }
                                        });
                                      },
                                      isExpanded: _isItemExpanded &&
                                          topicIndex == _currentTopicIndex &&
                                          itemIndex == _currentItemIndex,
                                      level: 2,
                                      icon: Icons.list_alt,
                                    );
                                  },
                                ),

                                if (_isItemExpanded &&
                                    topicIndex == _currentTopicIndex &&
                                    itemIndex == _currentItemIndex)
                                  ItemDetailsSection(
                                    item: item,
                                    topic: topic,
                                    inspectionId: widget.inspectionId,
                                    onItemUpdated: (updatedItem) {
                                      final topicId = topic.id!;
                                      final items =
                                          widget.itemsCache[topicId] ?? [];
                                      final index = items.indexWhere(
                                          (i) => i.id == updatedItem.id);
                                      if (index >= 0) {
                                        items[index] = updatedItem;
                                        widget.itemsCache[topicId] = items;
                                      }
                                    },
                                    onItemAction: _handleItemUpdate,
                                  ),

                                if (itemDetails.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green
                                                .withAlpha((255 * 0.1).round()),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.green.withAlpha(
                                                    (255 * 0.3).round())),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _isDetailsExpanded =
                                                      !_isDetailsExpanded;
                                                  if (_isDetailsExpanded) {
                                                    _isTopicExpanded = false;
                                                    _isItemExpanded = false;
                                                  }
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.details,
                                                        color: Colors.green,
                                                        size: 18),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Detalhes (${itemDetails.length})',
                                                        style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.green),
                                                      ),
                                                    ),
                                                    Icon(
                                                      _isDetailsExpanded &&
                                                              topicIndex ==
                                                                  _currentTopicIndex &&
                                                              itemIndex ==
                                                                  _currentItemIndex
                                                          ? Icons.expand_less
                                                          : Icons.expand_more,
                                                      color: Colors.green,
                                                      size: 24,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_isDetailsExpanded &&
                                            topicIndex == _currentTopicIndex &&
                                            itemIndex == _currentItemIndex)
                                          Expanded(
                                            child: DetailsListSection(
                                              key: ValueKey(
                                                  '${topic.id}_${item.id}_details'),
                                              details: itemDetails,
                                              item: item,
                                              topic: topic,
                                              inspectionId: widget.inspectionId,
                                              onDetailUpdated:
                                                  (updatedDetail) {
                                                final topicId = topic.id!;
                                                final itemId = item.id!;
                                                final cacheKey =
                                                    '${topicId}_$itemId';
                                                final details = widget
                                                        .detailsCache[
                                                    cacheKey] ??
                                                    [];
                                                final index = details.indexWhere(
                                                    (d) =>
                                                        d.id ==
                                                        updatedDetail.id);
                                                if (index >= 0) {
                                                  details[index] =
                                                      updatedDetail;
                                                  widget.detailsCache[
                                                      cacheKey] = details;
                                                }
                                                // Dispara uma atualização de UI para refletir o progresso
                                                setState(() {});
                                              },
                                              onDetailAction:
                                                  _handleDetailUpdate,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                if (!_isDetailsExpanded && itemDetails.isEmpty)
                                  const Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.details,
                                              size: 48, color: Colors.white30),
                                          SizedBox(height: 16),
                                          Text('Nenhum detalhe encontrado',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                    if (topicItems.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox,
                                  size: 48, color: Colors.white30),
                              SizedBox(height: 16),
                              Text('Nenhum item encontrado',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/swipeable_level_header.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/topic_details_section.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/item_details_section.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/details_list_section.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/navigation_state_service.dart';

class HierarchicalInspectionView extends StatefulWidget {
  final String inspectionId;
  final List<Topic> topics;
  final Map<String, List<Item>> itemsCache;
  final Map<String, List<Detail>> detailsCache;
  final Future<void> Function() onUpdateCache;

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

class _HierarchicalInspectionViewState
    extends State<HierarchicalInspectionView> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  int _currentTopicIndex = 0;
  int _currentItemIndex = 0;

  bool _isTopicExpanded = false;
  bool _isItemExpanded = false;
  bool _isDetailsExpanded = false;
  
  String? _expandedDetailId;

  PageController? _topicPageController;
  PageController? _itemPageController;
  
  final Map<String, double> _progressCache = {};
  final Map<String, List<double>> _itemProgressCache = {};

  @override
  void initState() {
    super.initState();
    _topicPageController = PageController();
    _itemPageController = PageController();
    _loadNavigationState();
  }
  
  /// Carrega o estado de navegação persistido
  Future<void> _loadNavigationState() async {
    final savedState = await NavigationStateService.loadNavigationState(widget.inspectionId);
    if (savedState != null && mounted) {
      setState(() {
        // Valida os índices para evitar IndexOutOfBounds
        _currentTopicIndex = savedState.currentTopicIndex.clamp(0, widget.topics.length - 1);
        
        // Valida o item index baseado no tópico atual
        if (_currentTopicIndex < widget.topics.length) {
          final topicId = widget.topics[_currentTopicIndex].id;
          final items = topicId != null ? (widget.itemsCache[topicId] ?? []) : [];
          _currentItemIndex = savedState.currentItemIndex.clamp(0, (items.length - 1).clamp(0, items.length));
        } else {
          _currentItemIndex = 0;
        }
        
        _isTopicExpanded = savedState.isTopicExpanded;
        _isItemExpanded = savedState.isItemExpanded;
        _isDetailsExpanded = savedState.isDetailsExpanded;
        _expandedDetailId = savedState.expandedDetailId;
      });
      
      // Anima para a posição salva
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _topicPageController?.hasClients == true) {
          _topicPageController?.animateToPage(
            _currentTopicIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
        
        // Também anima para o item correto se necessário
        if (mounted && _itemPageController?.hasClients == true && _currentItemIndex > 0) {
          _itemPageController?.animateToPage(
            _currentItemIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
      
      debugPrint('HierarchicalInspectionView: Restored navigation state: $savedState');
    }
  }
  
  /// Salva o estado atual de navegação
  Future<void> _saveNavigationState() async {
    await NavigationStateService.saveNavigationState(
      inspectionId: widget.inspectionId,
      currentTopicIndex: _currentTopicIndex,
      currentItemIndex: _currentItemIndex,
      isTopicExpanded: _isTopicExpanded,
      isItemExpanded: _isItemExpanded,
      isDetailsExpanded: _isDetailsExpanded,
      expandedDetailId: _expandedDetailId,
    );
  }

  @override
  void didUpdateWidget(HierarchicalInspectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Verificar se a lista de tópicos mudou (ex: após deleção)
    if (oldWidget.topics.length != widget.topics.length) {
      debugPrint('HierarchicalInspectionView: Topics list changed from ${oldWidget.topics.length} to ${widget.topics.length}');
      
      // Se o índice atual está fora dos limites, ajustar
      if (_currentTopicIndex >= widget.topics.length) {
        final newIndex = (widget.topics.length - 1).clamp(0, widget.topics.length - 1);
        debugPrint('HierarchicalInspectionView: Adjusting topic index from $_currentTopicIndex to $newIndex');
        
        setState(() {
          _currentTopicIndex = newIndex;
          _currentItemIndex = 0;
          // Reset expansion states to ensure the new topic can be expanded
          _isTopicExpanded = false;
          _isItemExpanded = false;
          _isDetailsExpanded = false;
          _expandedDetailId = null;
        });
        
        // Animar para o novo índice
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _topicPageController?.hasClients == true && widget.topics.isNotEmpty) {
            _topicPageController?.animateToPage(
              _currentTopicIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
        
        // Salvar o novo estado
        _saveNavigationState();
      }
    }
  }

  @override
  void dispose() {
    // Salva o estado antes de destruir o widget
    _saveNavigationState();
    _topicPageController?.dispose();
    _itemPageController?.dispose();
    super.dispose();
  }


  void _onTopicChanged(int index) {
    setState(() {
      _currentTopicIndex = index;
      _currentItemIndex = 0;
      // Reset expansion states when changing topics
      _isTopicExpanded = false;
      _isItemExpanded = false;
      _isDetailsExpanded = false;
      _expandedDetailId = null;
    });

    if (_itemPageController?.hasClients ?? false) {
      _itemPageController?.animateToPage(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
    
    // Salva o estado quando o tópico muda
    _saveNavigationState();
  }

  Future<void> _reloadCurrentData() async {
    await widget.onUpdateCache();
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

    // Persiste a mudança - pass the reordered topic IDs
    final topicIds = widget.topics
        .map((t) => t.id ?? 'topic_${widget.topics.indexOf(t)}')
        .toList();
    await _serviceFactory.dataService
        .reorderTopics(widget.inspectionId, topicIds);

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

    // Persiste a mudança - pass the reordered item IDs
    final itemIds =
        items.map((i) => i.id ?? 'item_${items.indexOf(i)}').toList();
    await _serviceFactory.dataService.reorderItems(topicId, itemIds);

    // Light refresh without triggering parent cache updates
    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    if (widget.topics.isEmpty) {
      return const Center(
        child: Text('Nenhum tópico encontrado',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    return Container(
      color: const Color(0xFF312456),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _topicPageController,
              itemCount: widget.topics.length,
              onPageChanged: _onTopicChanged,
              itemBuilder: (context, topicIndex) {
                final topic = widget.topics[topicIndex];
                final topicId = topic.id ?? 'topic_$topicIndex';
                final topicItems = widget.itemsCache[topicId] ?? <Item>[];

                return Column(
                  children: [
                    // MODIFICADO: Usa progresso calculado diretamente com progresso individual
                    SwipeableLevelHeader(
                      title: topic.topicName,
                      subtitle: topic.topicLabel,
                      currentIndex: topicIndex,
                      totalCount: widget.topics.length,
                      progress: _calculateTopicProgress(topic),
                      items: widget.topics.map((t) => t.topicName).toList(),
                      itemProgresses: widget.topics.map((t) => _calculateTopicProgress(t)).toList(),
                      hasObservation: topic.observation != null &&
                          topic.observation!.isNotEmpty,
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
                            // Para tópicos com detalhes diretos, colapsar detalhes expandidos
                            if (_shouldUseDirectDetails(topic, topicIndex)) {
                              _expandedDetailId = null;
                            }
                          }
                        });
                        // Salva o estado quando a expansão do tópico muda
                        _saveNavigationState();
                      },
                      isExpanded:
                          _isTopicExpanded && topicIndex == _currentTopicIndex,
                      level: 1,
                      icon: Icons.home_work_outlined,
                    ),

                    if (_isTopicExpanded && topicIndex == _currentTopicIndex)
                      Flexible(
                        child: TopicDetailsSection(
                          topic: topic,
                          inspectionId: widget.inspectionId,
                          onTopicUpdated: (updatedTopic) {
                            final index = widget.topics
                                .indexWhere((t) => t.id == updatedTopic.id);
                            if (index >= 0) {
                              widget.topics[index] = updatedTopic;
                              debugPrint('HierarchicalInspectionView: Topic ${updatedTopic.id} updated locally, triggering setState');
                              setState(() {}); // Atualização instantânea local
                            }
                          },
                          onTopicAction: () async {
                            _invalidateProgressCache();
                            await widget.onUpdateCache();
                            // Force UI update after cache reload  
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),

                    // HIERARQUIA FLEXÍVEL: Verificar se tópico tem detalhes diretos
                    // Usar uma condição mais robusta - verificar tanto a propriedade quanto o cache
                    if (_shouldUseDirectDetails(topic, topicIndex))
                      // Hierarquia direta: Tópico → Detalhe
                      Expanded(
                        child: _buildDirectDetailsView(topic, topicIndex),
                      )
                    else if (topicItems.isNotEmpty)
                      // Hierarquia normal: Tópico → Item → Detalhe  
                      Expanded(
                        child: PageView.builder(
                          controller: topicIndex == _currentTopicIndex
                              ? _itemPageController
                              : null,
                          itemCount: topicItems.length,
                          onPageChanged: topicIndex == _currentTopicIndex
                              ? (index) {
                                  setState(() => _currentItemIndex = index);
                                  // Salva o estado quando o item muda
                                  _saveNavigationState();
                                }
                              : null,
                          itemBuilder: (context, itemIndex) {
                            final item = topicItems[itemIndex];
                            final itemId = item.id ?? 'item_$itemIndex';
                            final itemDetails =
                                widget.detailsCache['${topicId}_$itemId'] ??
                                    <Detail>[];

                            return SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwipeableLevelHeader(
                                    title: item.itemName,
                                    subtitle: item.itemLabel,
                                    currentIndex: itemIndex,
                                    totalCount: topicItems.length,
                                    progress: _calculateItemProgressSync(item),
                                    items: topicItems
                                        .map((i) => i.itemName)
                                        .toList(),
                                    itemProgresses: _getCachedItemProgresses(topicItems),
                                    hasObservation:
                                        item.observation != null &&
                                            item.observation!.isNotEmpty,
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
                                        _reorderItems(topicId, oldIdx, newIdx),
                                    onExpansionChanged: () {
                                      setState(() {
                                        _isItemExpanded = !_isItemExpanded;
                                        if (_isItemExpanded) {
                                          _isTopicExpanded = false;
                                          _isDetailsExpanded = false;
                                        }
                                      });
                                      _saveNavigationState();
                                    },
                                    isExpanded: _isItemExpanded &&
                                        topicIndex == _currentTopicIndex &&
                                        itemIndex == _currentItemIndex,
                                    level: 2,
                                    icon: Icons.list_alt,
                                  ),

                                  if (_isItemExpanded &&
                                      topicIndex == _currentTopicIndex &&
                                      itemIndex == _currentItemIndex)
                                    ItemDetailsSection(
                                      item: item,
                                      topic: topic,
                                      inspectionId: widget.inspectionId,
                                      onItemUpdated: (updatedItem) {
                                        final items =
                                            widget.itemsCache[topicId] ?? [];
                                        final index = items.indexWhere(
                                            (i) => i.id == updatedItem.id);
                                        if (index >= 0) {
                                          items[index] = updatedItem;
                                          widget.itemsCache[topicId] = items;
                                          setState(
                                              () {}); // Atualização instantânea local
                                        }
                                      },
                                      onItemAction: () async {
                                        _invalidateProgressCache();
                                        await widget.onUpdateCache();
                                        // Force UI update after cache reload
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      },
                                    ),

                                  if (itemDetails.isNotEmpty)
                                    Column(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
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
                                                // Salva o estado quando a expansão dos detalhes muda
                                                _saveNavigationState();
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.details,
                                                        color: Colors.green,
                                                        size: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Detalhes (${itemDetails.length})',
                                                        style: const TextStyle(
                                                            fontSize: 12,
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
                                          DetailsListSection(
                                            key: ValueKey(
                                                '${topic.id}_${item.id}_details'),
                                            details: itemDetails,
                                            item: item,
                                            topic: topic,
                                            inspectionId: widget.inspectionId,
                                            topicIndex: topicIndex,
                                            itemIndex: itemIndex,
                                            expandedDetailId: _expandedDetailId, // Passa o ID do detalhe expandido
                                            onDetailUpdated: (updatedDetail) {
                                              final cacheKey =
                                                  '${topicId}_$itemId';
                                              final details = widget
                                                      .detailsCache[cacheKey] ??
                                                  [];
                                              final index = details.indexWhere(
                                                  (d) =>
                                                      d.id == updatedDetail.id);
                                              if (index >= 0) {
                                                details[index] = updatedDetail;
                                                widget.detailsCache[cacheKey] =
                                                    details;
                                              }
                                              setState(() {});
                                            },
                                            onDetailAction: () async {
                                              _invalidateProgressCache();
                                              await widget.onUpdateCache();
                                              // Force UI update after cache reload
                                              if (mounted) {
                                                setState(() {});
                                              }
                                            },
                                            onDetailExpanded: (detailId) {
                                              // Salva qual detalhe foi expandido
                                              setState(() {
                                                _expandedDetailId = detailId;
                                              });
                                              _saveNavigationState();
                                            },
                                          ),
                                      ],
                                    ),

                                  if (!_isDetailsExpanded &&
                                      itemDetails.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.details,
                                                size: 48,
                                                color: Colors.white30),
                                            SizedBox(height: 4),
                                            Text('Nenhum detalhe encontrado',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Verifica se o tópico deve usar detalhes diretos
  bool _shouldUseDirectDetails(Topic topic, int topicIndex) {
    final topicId = topic.id ?? 'topic_$topicIndex';
    final directDetailsKey = '${topicId}_direct';
    final hasDirectDetailsInCache = widget.detailsCache.containsKey(directDetailsKey) && 
                                    (widget.detailsCache[directDetailsKey]?.isNotEmpty ?? false);
    final hasDirectDetailsProperty = topic.directDetails == true;
    
    debugPrint('HierarchicalInspectionView: Topic ${topic.id} - directDetails property = $hasDirectDetailsProperty, cache has details = $hasDirectDetailsInCache');
    
    // Use direct details if either condition is true
    return hasDirectDetailsProperty || hasDirectDetailsInCache;
  }

  // Progress calculation methods
  double _calculateTopicProgress(Topic topic) {
    if (topic.id == null) return 0.0;

    // Hierarquia flexível: Verificar se tem detalhes diretos
    if (topic.directDetails == true) {
      // Para tópicos com detalhes diretos, calcular progresso baseado nos detalhes
      final directDetailsKey = '${topic.id}_direct';
      final details = widget.detailsCache[directDetailsKey] ?? [];
      if (details.isEmpty) return 0.0;

      int totalDetails = details.length;
      int completedDetails = details.where((d) => 
          d.detailValue != null && d.detailValue!.isNotEmpty).length;

      return totalDetails > 0 ? (completedDetails / totalDetails) : 0.0;
    }

    // Hierarquia normal: Calcular progresso baseado nos itens
    final items = widget.itemsCache[topic.id] ?? [];
    if (items.isEmpty) return 0.0;

    int totalItems = items.length;
    int completedItems = 0;

    for (final item in items) {
      if (item.id != null) {
        final details = widget.detailsCache['${topic.id}_${item.id}'] ?? [];
        if (details.isNotEmpty) {
          final requiredDetails =
              details.where((d) => d.isRequired == true).toList();
          if (requiredDetails.isNotEmpty) {
            // Se tem detalhes obrigatórios, todos devem estar completos
            final completedRequired = requiredDetails.where((d) => 
                d.detailValue != null && d.detailValue!.isNotEmpty).toList();
            if (completedRequired.length == requiredDetails.length) {
              completedItems++;
            }
          } else {
            // Se não tem detalhes obrigatórios, considera completo se tem pelo menos um detalhe preenchido
            final completedDetails = details.where((d) => 
                d.detailValue != null && d.detailValue!.isNotEmpty).toList();
            if (completedDetails.isNotEmpty) {
              completedItems++;
            }
          }
        }
      }
    }

    return totalItems > 0 ? (completedItems / totalItems) : 0.0;
  }

  double _calculateItemProgressSync(Item item) {
    if (item.id == null || item.topicId == null) return 0.0;
    
    final cacheKey = '${item.topicId}_${item.id}';
    if (_progressCache.containsKey(cacheKey)) {
      return _progressCache[cacheKey]!;
    }

    final details = widget.detailsCache[cacheKey] ?? [];
    double progress = 0.0;
    
    if (details.isEmpty) {
      if (item.evaluable == true) {
        progress = (item.evaluationValue != null && item.evaluationValue!.isNotEmpty) ? 1.0 : 0.0;
      }
    } else {
      int totalUnits = details.length;
      int completedUnits = details.where((d) => 
          d.detailValue != null && d.detailValue!.isNotEmpty).length;
      
      if (item.evaluable == true) {
        totalUnits++;
        if (item.evaluationValue != null && item.evaluationValue!.isNotEmpty) {
          completedUnits++;
        }
      }
      
      progress = totalUnits > 0 ? (completedUnits / totalUnits) : 0.0;
    }
    
    _progressCache[cacheKey] = progress;
    return progress;
  }

  List<double> _getCachedItemProgresses(List<Item> items) {
    final itemsKey = items.map((i) => i.id).join('_');
    if (_itemProgressCache.containsKey(itemsKey)) {
      return _itemProgressCache[itemsKey]!;
    }
    
    final progresses = items.map((item) => _calculateItemProgressSync(item)).toList();
    _itemProgressCache[itemsKey] = progresses;
    return progresses;
  }

  void _invalidateProgressCache() {
    _progressCache.clear();
    _itemProgressCache.clear();
  }

  /// Constrói a view para tópicos com detalhes diretos (sem itens intermediários)
  Widget _buildDirectDetailsView(Topic topic, int topicIndex) {
    final topicId = topic.id ?? 'topic_$topicIndex';
    // Usar chave especial para detalhes diretos
    final directDetailsKey = '${topicId}_direct';
    final topicDetails = widget.detailsCache[directDetailsKey] ?? <Detail>[];
    
    debugPrint('HierarchicalInspectionView: _buildDirectDetailsView for topic ${topic.id}');
    debugPrint('HierarchicalInspectionView: directDetailsKey = $directDetailsKey');
    debugPrint('HierarchicalInspectionView: topicDetails.length = ${topicDetails.length}');
    debugPrint('HierarchicalInspectionView: available cache keys = ${widget.detailsCache.keys.toList()}');
    debugPrint('HierarchicalInspectionView: topic.directDetails = ${topic.directDetails}');

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // REMOVIDO: Não mostrar header de item para direct_details, mostrar detalhes diretamente

          // Lista de detalhes diretos - mostrar sempre, não dependente de _isDetailsExpanded
          if (topicDetails.isNotEmpty) ...[
            // Debug antes de criar DetailsListSection
            Builder(
              builder: (context) {
                debugPrint('HierarchicalInspectionView: About to create DetailsListSection with ${topicDetails.length} details');
                debugPrint('HierarchicalInspectionView: Topic ID = ${topic.id}, hashCode = ${topic.hashCode}');
                return const SizedBox.shrink();
              }
            ),
            DetailsListSection(
              key: ValueKey('details_${topic.id}_${topicDetails.length}'), // Stable key
              details: topicDetails,
              item: null, // null para detalhes diretos
              topic: topic,
              inspectionId: widget.inspectionId,
              expandedDetailId: _expandedDetailId,
              topicIndex: topicIndex,
              itemIndex: 0, // Para detalhes diretos, usar 0 como índice
              onDetailUpdated: (detail) {
                _invalidateProgressCache();
                // OFFLINE-FIRST: Don't call onUpdateCache() automatically on detail updates
                // This was causing automatic sync every time a detail was changed
              },
              onDetailAction: () async {
                _invalidateProgressCache();
                await widget.onUpdateCache();
                // Force UI update after cache reload
                if (mounted) {
                  setState(() {});
                }
              },
              onDetailExpanded: (detailId) {
                // Para tópicos com detalhes diretos, colapsar o tópico quando um detalhe é expandido
                final currentTopic = widget.topics[topicIndex];
                final isDirectDetails = _shouldUseDirectDetails(currentTopic, topicIndex);
                
                setState(() {
                  _expandedDetailId = detailId;
                  if (isDirectDetails && detailId != null) {
                    _isTopicExpanded = false; // Colapsar tópico quando detalhe é expandido
                  } else if (detailId == null && isDirectDetails) {
                    // Se nenhum detalhe está expandido, permitir que o tópico seja expandido
                  }
                });
                _saveNavigationState();
              },
            ),
          ],

          // Mensagem quando não há detalhes
          if (topicDetails.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.details, size: 48, color: Colors.white30),
                    SizedBox(height: 4),
                    Text('Nenhum detalhe encontrado',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // REMOVIDO: Método não utilizado após remoção do header de item para direct_details
}

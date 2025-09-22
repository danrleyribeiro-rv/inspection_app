// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/non_conformity_form.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/non_conformity_list.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class NonConformityScreen extends StatefulWidget {
  final String inspectionId;
  final dynamic preSelectedTopic;
  final dynamic preSelectedItem;
  final dynamic preSelectedDetail;
  final List<String>? selectedMediaIds;
  final int initialTabIndex;

  const NonConformityScreen({
    super.key,
    required this.inspectionId,
    this.preSelectedTopic,
    this.preSelectedItem,
    this.preSelectedDetail,
    this.selectedMediaIds,
    this.initialTabIndex = 0,
  });

  @override
  State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
    with SingleTickerProviderStateMixin {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  late TabController _tabController;

  bool _isLoading = true;
  bool _isOffline = false;
  List<Topic> _topics = [];
  List<Item> _items = [];
  List<Detail> _details = [];
  List<Map<String, dynamic>> _nonConformities = [];

  Topic? _selectedTopic;
  Item? _selectedItem;
  Detail? _selectedDetail;

  bool _isProcessing = false;
  String? _filterByDetailId;
  
  // New filter properties for search and level filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _levelFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Call checkConnectivity to get the initial state
    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() {
          // THE FIX: Check if the List<ConnectivityResult> contains .none
          _isOffline = result.contains(ConnectivityResult.none);
        });
      }
    });

    // It's also good practice to listen for future changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOffline = result.contains(ConnectivityResult.none);
        });
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);
      setState(() => _topics = topics);

      setState(() {
        _items = [];
        _details = [];
      });

      if (widget.preSelectedTopic != null) {
        Topic? selectedTopic;
        for (var topic in _topics) {
          if (topic.id != null &&
              topic.id.toString() == widget.preSelectedTopic.toString()) {
            selectedTopic = topic;
            break;
          }
        }

        if (selectedTopic != null) {
          await _topicSelected(selectedTopic);
          
          // Handle direct details (topic has direct details and no preSelectedItem)
          if (selectedTopic.directDetails == true && widget.preSelectedItem == null && widget.preSelectedDetail != null) {
            debugPrint('NonConformityScreen: Handling direct detail preselection for topic ${selectedTopic.topicName}');
            Detail? selectedDetail;
            for (var detail in _details) {
              if (detail.id != null &&
                  detail.id.toString() == widget.preSelectedDetail.toString()) {
                selectedDetail = detail;
                break;
              }
            }

            if (selectedDetail != null) {
              _detailSelected(selectedDetail);
              debugPrint('NonConformityScreen: Preselected direct detail: ${selectedDetail.detailName}');
            } else if (_details.isNotEmpty) {
              _detailSelected(_details.first);
              debugPrint('NonConformityScreen: Fallback to first direct detail');
            }
          }
          // Handle normal hierarchy (topic has items)
          else if (widget.preSelectedItem != null && _items.isNotEmpty) {
            Item? selectedItem;
            for (var item in _items) {
              if (item.id != null &&
                  item.id.toString() == widget.preSelectedItem.toString()) {
                selectedItem = item;
                break;
              }
            }

            if (selectedItem != null) {
              await _itemSelected(selectedItem);
            } else if (_items.isNotEmpty) {
              await _itemSelected(_items.first);
            }

            if (widget.preSelectedDetail != null && _details.isNotEmpty) {
              Detail? selectedDetail;
              for (var detail in _details) {
                if (detail.id != null &&
                    detail.id.toString() == widget.preSelectedDetail.toString()) {
                  selectedDetail = detail;
                  break;
                }
              }

              if (selectedDetail != null) {
                _detailSelected(selectedDetail);
              } else if (_details.isNotEmpty) {
                _detailSelected(_details.first);
              }
            }
          }
        } else if (_topics.isNotEmpty) {
          await _topicSelected(_topics.first);
        }
      }

      await _loadNonConformities();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNonConformities() async {
    try {
      final nonConformitiesObjects = await _serviceFactory.dataService
          .getNonConformities(widget.inspectionId);

      final enrichedNonConformities = <Map<String, dynamic>>[];
      
      for (final nc in nonConformitiesObjects) {
        final ncData = nc.toMap();
        
        ncData['id'] = nc.id;
        ncData['inspection_id'] = nc.inspectionId;
        ncData['topic_id'] = nc.topicId;
        ncData['item_id'] = nc.itemId;
        ncData['detail_id'] = nc.detailId;
        ncData['title'] = nc.title;
        ncData['description'] = nc.description;
        ncData['severity'] = nc.severity;
        ncData['status'] = nc.status;
        ncData['corrective_action'] = nc.correctiveAction;
        ncData['deadline'] = nc.deadline?.toIso8601String();
        ncData['is_resolved'] = nc.isResolved;
        ncData['resolved_at'] = nc.resolvedAt?.toIso8601String();
        ncData['created_at'] = nc.createdAt.toIso8601String();
        ncData['updated_at'] = nc.updatedAt.toIso8601String();

        // Carregar nome do tópico
        if (nc.topicId != null) {
          final topic = _topics.firstWhere((t) => t.id == nc.topicId,
              orElse: () => Topic(
                    inspectionId: widget.inspectionId,
                    position: 0,
                    topicName: 'Tópico não especificado',
                  ));
          ncData['topic_name'] = topic.topicName;
          
          // Carregar nome do item se existir
          if (nc.itemId != null) {
            try {
              final items = await _serviceFactory.dataService.getItems(nc.topicId!);
              final item = items.firstWhere((i) => i.id == nc.itemId, orElse: () => Item(
                inspectionId: widget.inspectionId,
                topicId: nc.topicId!,
                position: 0,
                itemName: 'Item não especificado',
              ));
              ncData['item_name'] = item.itemName;
              debugPrint('NonConformityScreen: Loaded item name: ${item.itemName} for NC ${nc.id}');
              
              // Carregar nome do detalhe se existir
              if (nc.detailId != null) {
                try {
                  List<Detail> details;
                  if (topic.directDetails == true) {
                    // Para tópicos com detalhes diretos
                    details = await _serviceFactory.dataService.getDirectDetails(nc.topicId!);
                  } else {
                    // Para hierarquia normal (item -> detalhes)
                    details = await _serviceFactory.dataService.getDetails(nc.itemId!);
                  }
                  
                  final detail = details.firstWhere((d) => d.id == nc.detailId, orElse: () => Detail(
                    inspectionId: widget.inspectionId,
                    topicId: nc.topicId!,
                    itemId: nc.itemId,
                    position: 0,
                    detailName: 'Detalhe não especificado',
                  ));
                  ncData['detail_name'] = detail.detailName;
                  debugPrint('NonConformityScreen: Loaded detail name: ${detail.detailName} for NC ${nc.id}');
                } catch (e) {
                  debugPrint('Erro ao carregar detalhe ${nc.detailId}: $e');
                  ncData['detail_name'] = 'Detalhe não especificado';
                }
              } else {
                ncData['detail_name'] = null;
              }
            } catch (e) {
              debugPrint('Erro ao carregar item ${nc.itemId}: $e');
              ncData['item_name'] = 'Item não especificado';
              ncData['detail_name'] = nc.detailId != null ? 'Detalhe não especificado' : null;
            }
          } else {
            ncData['item_name'] = null;
            
            // Para tópicos com detalhes diretos (sem item)
            if (nc.detailId != null) {
              try {
                final details = await _serviceFactory.dataService.getDirectDetails(nc.topicId!);
                final detail = details.firstWhere((d) => d.id == nc.detailId, orElse: () => Detail(
                  inspectionId: widget.inspectionId,
                  topicId: nc.topicId!,
                  position: 0,
                  detailName: 'Detalhe não especificado',
                ));
                ncData['detail_name'] = detail.detailName;
              } catch (e) {
                debugPrint('Erro ao carregar detalhe direto ${nc.detailId}: $e');
                ncData['detail_name'] = 'Detalhe não especificado';
              }
            } else {
              ncData['detail_name'] = null;
            }
          }
        } else {
          ncData['topic_name'] = 'Tópico não especificado';
          ncData['item_name'] = null;
          ncData['detail_name'] = null;
        }

        enrichedNonConformities.add(ncData);
      }

      if (mounted) {
        setState(() {
          _nonConformities = enrichedNonConformities;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar não conformidades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar não conformidades: $e')),
        );
      }
    }
  }

  Future<void> _topicSelected(Topic topic) async {
    setState(() {
      _selectedTopic = topic;
      _selectedItem = null;
      _selectedDetail = null;
      _items = [];
      _details = [];
    });

    if (topic.id != null) {
      try {
        if (topic.directDetails == true) {
          // Load direct details for topics with direct details
          final directDetails = await _serviceFactory.dataService.getDirectDetails(topic.id!);
          setState(() => _details = directDetails);
          debugPrint('NonConformityScreen: _topicSelected - Loaded ${directDetails.length} direct details for topic ${topic.topicName}');
        } else {
          // Load items for topics with normal hierarchy
          final items = await _serviceFactory.dataService.getItems(topic.id!);
          setState(() => _items = items);
          debugPrint('NonConformityScreen: _topicSelected - Loaded ${items.length} items for topic ${topic.topicName}');
        }
      } catch (e) {
        debugPrint('Erro ao carregar dados para tópico ${topic.topicName}: $e');
      }
    }
  }

  Future<void> _itemSelected(Item item) async {
    setState(() {
      _selectedItem = item;
      _selectedDetail = null;
      _details = [];
    });

    if (item.id != null && item.topicId != null) {
      try {
        final details = await _serviceFactory.dataService.getDetails(item.id!);
        setState(() => _details = details);
      } catch (e) {
        debugPrint('Erro ao carregar detalhes: $e');
      }
    }
  }

  void _detailSelected(Detail detail) {
    setState(() => _selectedDetail = detail);
  }

  Future<void> _updateNonConformityStatus(String id, String newStatus) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await _serviceFactory.dataService
          .updateNonConformityStatus(id, newStatus);

      await _loadNonConformities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateNonConformity(Map<String, dynamic> updatedData) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      String nonConformityId = updatedData['id'];
      if (!nonConformityId.contains('-')) {
        nonConformityId =
            '${widget.inspectionId}-${updatedData['topic_id']}-${updatedData['item_id']}-${updatedData['detail_id']}-$nonConformityId';
      }

      // Convert updatedData to NonConformity object
      debugPrint('NonConformityScreen: Updating NC with data: $updatedData');
      debugPrint('NonConformityScreen: NonConformity ID: $nonConformityId');
      
      DateTime? parsedResolvedAt;
      try {
        if (updatedData['resolved_at'] != null) {
          final resolvedAtValue = updatedData['resolved_at'];
          if (resolvedAtValue is String) {
            parsedResolvedAt = DateTime.parse(resolvedAtValue);
          }
        }
      } catch (e) {
        debugPrint('NonConformityScreen: Error parsing resolved_at: $e');
      }
      
      DateTime? parsedDeadline;
      try {
        if (updatedData['deadline'] != null) {
          final deadlineValue = updatedData['deadline'];
          if (deadlineValue is String) {
            parsedDeadline = DateTime.parse(deadlineValue);
          }
        }
      } catch (e) {
        debugPrint('NonConformityScreen: Error parsing deadline: $e');
      }
      
      final isResolvedValue = updatedData['is_resolved'] == true || updatedData['is_resolved'] == 1;
      final statusValue = updatedData['status'] ?? 'open';
      
      debugPrint('NonConformityScreen: isResolved = $isResolvedValue, status = $statusValue, resolvedAt = $parsedResolvedAt');
      
      final nonConformity = NonConformity(
        id: nonConformityId,
        inspectionId: updatedData['inspection_id'] ?? widget.inspectionId,
        topicId: updatedData['topic_id'],
        itemId: updatedData['item_id'],
        detailId: updatedData['detail_id'],
        title: updatedData['title'] ?? '',
        description: updatedData['description'] ?? '',
        severity: updatedData['severity'] ?? 'medium',
        status: statusValue,
        correctiveAction: updatedData['corrective_action'],
        deadline: parsedDeadline,
        isResolved: isResolvedValue,
        resolvedAt: parsedResolvedAt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        needsSync: true,
        isDeleted: false,
      );
      debugPrint('NonConformityScreen: About to call updateNonConformity on data service');
      await _serviceFactory.dataService.updateNonConformity(nonConformity);
      debugPrint('NonConformityScreen: updateNonConformity completed successfully');

      debugPrint('NonConformityScreen: About to reload non-conformities');
      await _loadNonConformities();
      debugPrint('NonConformityScreen: Non-conformities reloaded');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar não conformidade: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deleteNonConformity(String id) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await _serviceFactory.dataService.deleteNonConformity(id);

      await _loadNonConformities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade excluída com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir não conformidade: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onNonConformitySaved() {
    _loadNonConformities();
    _tabController.animateTo(1);
  }


  String _determineLevel() {
    // Determine the appropriate level based on preselected parameters
    if (widget.preSelectedDetail != null) {
      return 'detail';
    } else if (widget.preSelectedItem != null) {
      return 'item';
    } else if (widget.preSelectedTopic != null) {
      return 'topic';
    }
    return 'detail'; // Default level
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Não Conformidades',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                NonConformityForm(
                  topics: _topics,
                  items: _items,
                  details: _details,
                  selectedTopic: _selectedTopic,
                  selectedItem: _selectedItem,
                  selectedDetail: _selectedDetail,
                  inspectionId: widget.inspectionId,
                  isOffline: _isOffline,
                  level: _determineLevel(),
                  onTopicSelected: _topicSelected,
                  onItemSelected: _itemSelected,
                  onDetailSelected: _detailSelected,
                  onNonConformitySaved: _onNonConformitySaved,
                ),
                Column(
                  children: [
                    // Search and Filter Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: theme.scaffoldBackgroundColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Bar
                          TextField(
                            controller: _searchController,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Pesquisar não conformidades...',
                              hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(fontSize: 12),
                              prefixIcon: Icon(Icons.search, color: theme.inputDecorationTheme.hintStyle?.color),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: theme.inputDecorationTheme.hintStyle?.color),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: theme.inputDecorationTheme.fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Level Filter
                          Row(
                            children: [
                              Text(
                                'Nível:',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _levelFilter,
                                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 12),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: theme.inputDecorationTheme.fillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                  ),
                                  dropdownColor: theme.cardColor,
                                  items: const [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Todos os níveis', style: TextStyle(fontSize: 12)),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'topic',
                                      child: Text('Apenas Tópicos', style: TextStyle(fontSize: 12)),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'item',
                                      child: Text('Apenas Itens', style: TextStyle(fontSize: 12)),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'detail',
                                      child: Text('Apenas Detalhes', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _levelFilter = value);
                                  },
                                  icon: Icon(Icons.arrow_drop_down, color: theme.inputDecorationTheme.hintStyle?.color),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Lista de não conformidades
                    Expanded(
                      child: NonConformityList(
                        nonConformities: _nonConformities,
                        inspectionId: widget.inspectionId,
                        onStatusUpdate: _updateNonConformityStatus,
                        onDeleteNonConformity: _deleteNonConformity,
                        onEditNonConformity: _updateNonConformity,
                        filterByDetailId: _filterByDetailId,
                        onNonConformityUpdated: _loadNonConformities,
                        searchQuery: _searchQuery,
                        levelFilter: _levelFilter,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: _tabController.index,
            onTap: (index) {
              setState(() {
                _tabController.index = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.unselectedWidgetColor,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: _tabController.index == 0
                      ? BoxDecoration(
                          color: theme.colorScheme.primary
                              .withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: const Icon(Icons.add_box_outlined),
                ),
                label: 'Nova NC',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: _tabController.index == 1
                      ? BoxDecoration(
                          color: theme.colorScheme.primary
                              .withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: const Icon(Icons.list_alt_outlined),
                ),
                label: 'Listagem',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

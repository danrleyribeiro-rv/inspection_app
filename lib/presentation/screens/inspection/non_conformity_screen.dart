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

  const NonConformityScreen({
    super.key,
    required this.inspectionId,
    this.preSelectedTopic,
    this.preSelectedItem,
    this.preSelectedDetail,
    this.selectedMediaIds,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);
      setState(() => _topics = topics);

      // Load all items and details for enrichment
      final allItems = <Item>[];
      final allDetails = <Detail>[];

      for (final topic in topics) {
        if (topic.id != null) {
          final items = await _serviceFactory.dataService.getItems(topic.id!);
          allItems.addAll(items);

          for (final item in items) {
            if (item.id != null) {
              final details =
                  await _serviceFactory.dataService.getDetails(item.id!);
              allDetails.addAll(details);
            }
          }
        }
      }

      setState(() {
        _items = allItems;
        _details = allDetails;
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
        } else if (_topics.isNotEmpty) {
          await _topicSelected(_topics.first);
        }

        if (widget.preSelectedItem != null && _items.isNotEmpty) {
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

      // Enrich non-conformities with topic, item, and detail names
      final enrichedNonConformities = <Map<String, dynamic>>[];

      for (final nc in nonConformitiesObjects) {
        final ncData = nc.toJson();

        // Load topic name if available
        if (nc.topicId != null) {
          final topic = _topics.firstWhere((t) => t.id == nc.topicId,
              orElse: () => Topic(
                    inspectionId: widget.inspectionId,
                    position: 0,
                    topicName: 'Tópico não especificado',
                  ));
          ncData['topic_name'] = topic.topicName;
        }

        // Load item name if available
        if (nc.itemId != null) {
          final item = _items.firstWhere((i) => i.id == nc.itemId,
              orElse: () => Item(
                    inspectionId: widget.inspectionId,
                    position: 0,
                    itemName: 'Item não especificado',
                  ));
          ncData['item_name'] = item.itemName;
        }

        // Load detail name if available
        if (nc.detailId != null) {
          final detail = _details.firstWhere((d) => d.id == nc.detailId,
              orElse: () => Detail(
                    inspectionId: widget.inspectionId,
                    detailName: 'Detalhe não especificado',
                  ));
          ncData['detail_name'] = detail.detailName;
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
        final items = await _serviceFactory.dataService.getItems(topic.id!);
        setState(() => _items = items);
      } catch (e) {
        debugPrint('Erro ao carregar itens: $e');
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
      final nonConformity = NonConformity(
        id: nonConformityId,
        inspectionId: updatedData['inspection_id'] ?? widget.inspectionId,
        topicId: updatedData['topic_id'],
        itemId: updatedData['item_id'],
        detailId: updatedData['detail_id'],
        title: updatedData['title'] ?? '',
        description: updatedData['description'] ?? '',
        severity: updatedData['severity'] ?? 'medium',
        status: updatedData['status'] ?? 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        needsSync: true,
        isDeleted: false,
      );
      await _serviceFactory.dataService.updateNonConformity(nonConformity);

      await _loadNonConformities();

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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        topics: _topics,
        items: _items,
        details: _details,
        onFilterSelected: (detailId) {
          setState(() => _filterByDetailId = detailId);
        },
        currentFilterId: _filterByDetailId,
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF312456),
      appBar: AppBar(
        title: const Text(
          'Não Conformidades',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF312456),
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
                    // Filtros
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFF312456),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtros:',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      setState(() => _filterByDetailId = null),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _filterByDetailId == null
                                        ? const Color(0xFFBB8FEB)
                                        : Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Todas',
                                      style: TextStyle(fontSize: 10)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showFilterDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _filterByDetailId != null
                                        ? const Color(0xFFBB8FEB)
                                        : Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text(
                                    'Filtrar por Local',
                                    style: TextStyle(fontSize: 10),
                                  ),
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF312456),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
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
            selectedItemColor: const Color(0xFFBB8FEB),
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                label: 'Nova NC',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                label: 'Listagem',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final List<Topic> topics;
  final List<Item> items;
  final List<Detail> details;
  final Function(String?) onFilterSelected;
  final String? currentFilterId;

  const _FilterDialog({
    required this.topics,
    required this.items,
    required this.details,
    required this.onFilterSelected,
    this.currentFilterId,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  Topic? _selectedTopic;
  Item? _selectedItem;
  Detail? _selectedDetail;
  List<Item> _filteredItems = [];
  List<Detail> _filteredDetails = [];

  @override
  void initState() {
    super.initState();
    _initializeFromCurrentFilter();
  }

  void _initializeFromCurrentFilter() {
    if (widget.currentFilterId != null) {
      final detail = widget.details.firstWhere(
        (d) => d.id == widget.currentFilterId,
        orElse: () => Detail(inspectionId: '', detailName: ''),
      );
      
      if (detail.id != null) {
        _selectedDetail = detail;
        
        final item = widget.items.firstWhere(
          (i) => i.id == detail.itemId,
          orElse: () => Item(inspectionId: '', position: 0, itemName: ''),
        );
        
        if (item.id != null) {
          _selectedItem = item;
          
          final topic = widget.topics.firstWhere(
            (t) => t.id == item.topicId,
            orElse: () => Topic(inspectionId: '', position: 0, topicName: ''),
          );
          
          if (topic.id != null) {
            _selectedTopic = topic;
            _filterItemsByTopic();
            _filterDetailsByItem();
          }
        }
      }
    }
  }

  void _filterItemsByTopic() {
    if (_selectedTopic?.id != null) {
      _filteredItems = widget.items.where((item) => item.topicId == _selectedTopic!.id).toList();
    } else {
      _filteredItems = [];
    }
  }

  void _filterDetailsByItem() {
    if (_selectedItem?.id != null) {
      _filteredDetails = widget.details.where((detail) => detail.itemId == _selectedItem!.id).toList();
    } else {
      _filteredDetails = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar por Local'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seleção de Tópico
            const Text('Tópico:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Topic>(
              value: _selectedTopic,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Selecione um tópico',
              ),
              items: widget.topics.map((topic) {
                return DropdownMenuItem(
                  value: topic,
                  child: Text(topic.topicName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (topic) {
                setState(() {
                  _selectedTopic = topic;
                  _selectedItem = null;
                  _selectedDetail = null;
                  _filterItemsByTopic();
                  _filteredDetails = [];
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Seleção de Item
            const Text('Item:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Item>(
              value: _selectedItem,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Selecione um item',
              ),
              items: _filteredItems.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item.itemName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _filteredItems.isNotEmpty ? (item) {
                setState(() {
                  _selectedItem = item;
                  _selectedDetail = null;
                  _filterDetailsByItem();
                });
              } : null,
            ),
            
            const SizedBox(height: 16),
            
            // Seleção de Detalhe
            const Text('Detalhe:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Detail>(
              value: _selectedDetail,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Selecione um detalhe',
              ),
              items: _filteredDetails.map((detail) {
                return DropdownMenuItem(
                  value: detail,
                  child: Text(detail.detailName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _filteredDetails.isNotEmpty ? (detail) {
                setState(() {
                  _selectedDetail = detail;
                });
              } : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            widget.onFilterSelected(_selectedDetail?.id);
            Navigator.of(context).pop();
          },
          child: const Text('Aplicar Filtro'),
        ),
      ],
    );
  }
}

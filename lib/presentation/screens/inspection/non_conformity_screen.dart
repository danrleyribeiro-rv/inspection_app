// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_form.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_list.dart';
import 'package:inspection_app/services/service_factory.dart';

class NonConformityScreen extends StatefulWidget {
  final String inspectionId;
  final dynamic preSelectedTopic;
  final dynamic preSelectedItem;
  final dynamic preSelectedDetail;

  const NonConformityScreen({
    super.key,
    required this.inspectionId,
    this.preSelectedTopic,
    this.preSelectedItem,
    this.preSelectedDetail,
  });

  @override
  State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
    with SingleTickerProviderStateMixin {
  final ServiceFactory _serviceFactory = ServiceFactory();
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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
          await _serviceFactory.coordinator.getTopics(widget.inspectionId);
      setState(() => _topics = topics);

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
      final nonConformities = await _serviceFactory.coordinator
          .getNonConformitiesByInspection(widget.inspectionId);

      if (mounted) {
        setState(() {
          _nonConformities = nonConformities;
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
        final items = await _serviceFactory.coordinator
            .getItems(widget.inspectionId, topic.id!);
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
        final details = await _serviceFactory.coordinator
            .getDetails(widget.inspectionId, item.topicId!, item.id!);
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
      await _serviceFactory.coordinator
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

      await _serviceFactory.coordinator
          .updateNonConformity(nonConformityId, updatedData);

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
      await _serviceFactory.coordinator
          .deleteNonConformity(id, widget.inspectionId);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Não Conformidades'),
        backgroundColor: const Color(0xFF1E293B),
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
                  onTopicSelected: _topicSelected,
                  onItemSelected: _itemSelected,
                  onDetailSelected: _detailSelected,
                  onNonConformitySaved: _onNonConformitySaved,
                ),
                NonConformityList(
                  nonConformities: _nonConformities,
                  inspectionId: widget.inspectionId,
                  onStatusUpdate: _updateNonConformityStatus,
                  onDeleteNonConformity: _deleteNonConformity,
                  onEditNonConformity: _updateNonConformity,
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
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
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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

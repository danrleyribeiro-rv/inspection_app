// lib/presentation/widgets/dialogs/move_media_dialog.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';

class MoveMediaDialog extends StatefulWidget {
  final String inspectionId;
  final String mediaId;
  final String currentLocation;
  final bool isOfflineMode;

  const MoveMediaDialog({
    super.key,
    required this.inspectionId,
    required this.mediaId,
    required this.currentLocation,
    this.isOfflineMode = false,
  });

  @override
  State<MoveMediaDialog> createState() => _MoveMediaDialogState();
}

class _MoveMediaDialogState extends State<MoveMediaDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _nonConformities = [];

  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  String? _selectedNonConformityId;
  
  // Destination options
  String _destinationType = 'topic'; // 'topic', 'item', 'detail', 'nc', 'any'
  bool _isLoading = true;
  
  // For "any" destination type - all available options
  List<Map<String, dynamic>> _allTopics = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _allDetails = [];
  
  // New NC fields
  final _newNCTitleController = TextEditingController();
  final _newNCDescriptionController = TextEditingController();
  final _newNCActionController = TextEditingController();
  String _newNCSeverity = 'medium';

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  @override
  void dispose() {
    _newNCTitleController.dispose();
    _newNCDescriptionController.dispose();
    _newNCActionController.dispose();
    super.dispose();
  }

  Future<void> _loadHierarchy() async {
    try {
      debugPrint('MoveMediaDialog: Loading hierarchy for inspection ${widget.inspectionId}');
      
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        final topics = <Map<String, dynamic>>[];
        final allTopics = <Map<String, dynamic>>[];
        final allItems = <Map<String, dynamic>>[];
        final allDetails = <Map<String, dynamic>>[];

        for (int i = 0; i < inspection!.topics!.length; i++) {
          final topicData = inspection.topics![i];
          final topicId = topicData['id'] ?? 'topic_$i';
          final topicName = topicData['name'] ??
              topicData['topic_name'] ??
              topicData['topicName'] ??
              'Tópico ${i + 1}';
              
          final topicEntry = {
            'id': topicId,
            'name': topicName,
            'data': topicData,
          };
          
          topics.add(topicEntry);
          allTopics.add(topicEntry);
          
          // Load all items for "any" destination
          final itemsList = topicData['items'] as List<dynamic>? ?? [];
          for (int j = 0; j < itemsList.length; j++) {
            final itemData = itemsList[j];
            final itemId = itemData['id'] ?? 'item_${i}_$j';
            final itemName = itemData['name'] ?? 
                itemData['item_name'] ?? 
                itemData['itemName'] ?? 
                'Item ${j + 1}';
                
            final itemEntry = {
              'id': itemId,
              'name': '$topicName → $itemName',
              'topicId': topicId,
              'topicName': topicName,
              'itemName': itemName,
              'data': itemData,
            };
            
            allItems.add(itemEntry);
            
            // Load all details for "any" destination
            final detailsList = itemData['details'] as List<dynamic>? ?? [];
            for (int k = 0; k < detailsList.length; k++) {
              final detailData = detailsList[k];
              final detailId = detailData['id'] ?? 'detail_${i}_${j}_$k';
              final detailName = detailData['name'] ??
                  detailData['detail_name'] ??
                  detailData['detailName'] ??
                  'Detalhe ${k + 1}';
                  
              allDetails.add({
                'id': detailId,
                'name': '$topicName → $itemName → $detailName',
                'topicId': topicId,
                'itemId': itemId,
                'topicName': topicName,
                'itemName': itemName,
                'detailName': detailName,
                'data': detailData,
              });
            }
          }
          
          debugPrint('MoveMediaDialog: Added topic $topicId - $topicName');
        }

        if (mounted) {
          setState(() {
            _topics = topics;
            _allTopics = allTopics;
            _allItems = allItems;
            _allDetails = allDetails;
            _isLoading = false;
          });
        }
        debugPrint('MoveMediaDialog: Loaded ${topics.length} topics, ${allItems.length} items, ${allDetails.length} details');
      } else {
        if (mounted) {
          setState(() {
            _topics = [];
            _allTopics = [];
            _allItems = [];
            _allDetails = [];
            _isLoading = false;
          });
        }
        debugPrint('MoveMediaDialog: No topics found in inspection');
      }
    } catch (e) {
      debugPrint('MoveMediaDialog: Error loading hierarchy: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar hierarquia: $e')),
        );
      }
    }
  }

  Future<void> _loadItems(String topicId) async {
    try {
      debugPrint('MoveMediaDialog: Loading items for topic $topicId');
      
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0;
            topicIndex < inspection!.topics!.length;
            topicIndex++) {
          final topicData = inspection.topics![topicIndex];
          final currentTopicId = topicData['id'] ?? 'topic_$topicIndex';

          if (currentTopicId == topicId) {
            final items = <Map<String, dynamic>>[];
            final itemsList = topicData['items'] as List<dynamic>? ?? [];

            for (int i = 0; i < itemsList.length; i++) {
              final itemData = itemsList[i];
              final itemId = itemData['id'] ?? 'item_${topicIndex}_$i';
              final itemName = itemData['name'] ?? 
                  itemData['item_name'] ?? 
                  itemData['itemName'] ?? 
                  'Item ${i + 1}';
                  
              items.add({
                'id': itemId,
                'name': itemName,
                'data': itemData,
              });
              
              debugPrint('MoveMediaDialog: Added item $itemId - $itemName');
            }

            if (mounted) {
              setState(() {
                _items = items;
                _selectedItemId = null;
                _details = [];
                _selectedDetailId = null;
                _nonConformities = [];
                _selectedNonConformityId = null;
              });
            }
            debugPrint('MoveMediaDialog: Loaded ${items.length} items for topic $topicId');
            return;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _items = [];
          _selectedItemId = null;
          _details = [];
          _selectedDetailId = null;
          _nonConformities = [];
          _selectedNonConformityId = null;
        });
      }
    } catch (e) {
      debugPrint('MoveMediaDialog: Error loading items: $e');
    }
  }

  Future<void> _loadDetails(String itemId) async {
    try {
      debugPrint('MoveMediaDialog: Loading details for item $itemId');
      
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0;
            topicIndex < inspection!.topics!.length;
            topicIndex++) {
          final topicData = inspection.topics![topicIndex];
          final itemsList = topicData['items'] as List<dynamic>? ?? [];

          for (int itemIndex = 0; itemIndex < itemsList.length; itemIndex++) {
            final itemData = itemsList[itemIndex];
            final currentItemId = itemData['id'] ?? 'item_${topicIndex}_$itemIndex';

            if (currentItemId == itemId) {
              final details = <Map<String, dynamic>>[];
              final detailsList = itemData['details'] as List<dynamic>? ?? [];

              for (int i = 0; i < detailsList.length; i++) {
                final detailData = detailsList[i];
                final detailId = detailData['id'] ?? 'detail_${topicIndex}_${itemIndex}_$i';
                final detailName = detailData['name'] ??
                    detailData['detail_name'] ??
                    detailData['detailName'] ??
                    'Detalhe ${i + 1}';
                    
                details.add({
                  'id': detailId,
                  'name': detailName,
                  'data': detailData,
                });
                
                debugPrint('MoveMediaDialog: Added detail $detailId - $detailName');
              }

              if (mounted) {
                setState(() {
                  _details = details;
                  _selectedDetailId = null;
                  _nonConformities = [];
                  _selectedNonConformityId = null;
                });
              }
              return;
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _details = [];
          _selectedDetailId = null;
          _nonConformities = [];
          _selectedNonConformityId = null;
        });
      }
    } catch (e) {
      debugPrint('MoveMediaDialog: Error loading details: $e');
    }
  }

  Future<void> _loadNonConformities(String detailId) async {
    try {
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0;
            topicIndex < inspection!.topics!.length;
            topicIndex++) {
          final topicData = inspection.topics![topicIndex];
          final itemsList = topicData['items'] as List<dynamic>? ?? [];

          for (int itemIndex = 0; itemIndex < itemsList.length; itemIndex++) {
            final itemData = itemsList[itemIndex];
            final detailsList = itemData['details'] as List<dynamic>? ?? [];

            for (int detailIndex = 0;
                detailIndex < detailsList.length;
                detailIndex++) {
              final detailData = detailsList[detailIndex];
              final currentDetailId = detailData['id'] ??
                  'detail_${topicIndex}_${itemIndex}_$detailIndex';

              if (currentDetailId == detailId) {
                final nonConformities = <Map<String, dynamic>>[];
                final ncList =
                    detailData['non_conformities'] as List<dynamic>? ?? [];

                for (int i = 0; i < ncList.length; i++) {
                  final ncData = ncList[i];
                  final ncId = ncData['id'] ??
                      'nc_${topicIndex}_${itemIndex}_${detailIndex}_$i';
                  final title = ncData['title'] ??
                      ncData['description'] ??
                      'Não Conformidade';
                  final description = ncData['description'] ?? '';
                  final severity = ncData['severity'] ?? 'medium';
                  final status =
                      ncData['is_resolved'] == true ? 'Resolvida' : 'Pendente';

                  final displayTitle = '${i + 1}. $title';
                  final displaySubtitle =
                      '${_getSeverityText(severity)} • $status${description.isNotEmpty ? ' • $description' : ''}';

                  nonConformities.add({
                    'id': ncId,
                    'title': title,
                    'displayTitle': displayTitle,
                    'displaySubtitle': displaySubtitle,
                    'description': description,
                    'severity': severity,
                    'status': status,
                    'index': i + 1,
                    'data': ncData,
                  });
                }

                setState(() {
                  _nonConformities = nonConformities;
                  _selectedNonConformityId = null;
                });
                return;
              }
            }
          }
        }
      }
      setState(() {
        _nonConformities = [];
        _selectedNonConformityId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar não conformidades: $e')),
        );
      }
    }
  }

  String _getSeverityText(String severity) {
    switch (severity) {
      case 'low': return 'Baixa';
      case 'medium': return 'Média';
      case 'high': return 'Alta';
      case 'critical': return 'Crítica';
      default: return 'Média';
    }
  }

  String _getDestinationDescription() {
    List<String> parts = [];

    if (_destinationType == 'any') {
      // For "any" destination, use the hierarchy info from the selected items
      if (_selectedDetailId != null) {
        final detail = _allDetails.firstWhere((d) => d['id'] == _selectedDetailId, orElse: () => {});
        if (detail.isNotEmpty) {
          return detail['name'] as String;
        }
      } else if (_selectedItemId != null) {
        final item = _allItems.firstWhere((i) => i['id'] == _selectedItemId, orElse: () => {});
        if (item.isNotEmpty) {
          return item['name'] as String;
        }
      } else if (_selectedTopicId != null) {
        final topic = _allTopics.firstWhere((t) => t['id'] == _selectedTopicId, orElse: () => {});
        if (topic.isNotEmpty) {
          return 'Tópico: ${topic['name']}';
        }
      }
      return 'Nenhum destino selecionado';
    }

    if (_selectedTopicId != null) {
      final topic = _topics.firstWhere((t) => t['id'] == _selectedTopicId,
          orElse: () => {});
      if (topic.isNotEmpty) {
        parts.add('Tópico: ${topic['name']}');
      }
    }

    if (_destinationType != 'topic' && _selectedItemId != null) {
      final item = _items.firstWhere((i) => i['id'] == _selectedItemId,
          orElse: () => {});
      if (item.isNotEmpty) {
        parts.add('Item: ${item['name']}');
      }
    }

    if (_destinationType == 'detail' || _destinationType == 'nc') {
      if (_selectedDetailId != null) {
        final detail = _details.firstWhere((d) => d['id'] == _selectedDetailId,
            orElse: () => {});
        if (detail.isNotEmpty) {
          parts.add('Detalhe: ${detail['name']}');
        }
      }
    }

    if (_destinationType == 'nc') {
      if (_selectedNonConformityId != null) {
        final nc = _nonConformities.firstWhere(
            (n) => n['id'] == _selectedNonConformityId,
            orElse: () => {});
        if (nc.isNotEmpty) {
          parts.add('NC: ${nc['title']}');
        }
      } else if (_newNCTitleController.text.isNotEmpty) {
        parts.add('NC: ${_newNCTitleController.text}');
      } else {
        parts.add('(Nova Não Conformidade)');
      }
    }

    return parts.isEmpty ? 'Nenhum destino selecionado' : parts.join(' → ');
  }

  bool _isValidSelection() {
    switch (_destinationType) {
      case 'topic':
        return _selectedTopicId != null;
      case 'item':
        return _selectedTopicId != null && _selectedItemId != null;
      case 'detail':
        return _selectedTopicId != null && _selectedItemId != null && _selectedDetailId != null;
      case 'nc':
        return _selectedTopicId != null && 
               _selectedItemId != null && 
               _selectedDetailId != null &&
               (_selectedNonConformityId != null || _newNCTitleController.text.isNotEmpty);
      case 'any':
        return _selectedTopicId != null || _selectedItemId != null || _selectedDetailId != null;
      default:
        return false;
    }
  }

  Future<void> _moveMedia() async {
    try {
      if (!_isValidSelection()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, complete a seleção do destino'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? nonConformityId;
      
      // Create new NC if needed
      if (_destinationType == 'nc' && _selectedNonConformityId == null) {
        if (_newNCTitleController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, insira o título da nova não conformidade'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Create new non-conformity
        final newNC = NonConformity(
          id: 'nc_${DateTime.now().millisecondsSinceEpoch}',
          inspectionId: widget.inspectionId,
          topicId: _selectedTopicId,
          itemId: _selectedItemId,
          detailId: _selectedDetailId,
          title: _newNCTitleController.text,
          description: _newNCDescriptionController.text,
          severity: _newNCSeverity,
          status: 'open',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
          isDeleted: false,
        );

        await _serviceFactory.dataService.saveNonConformity(newNC);
        nonConformityId = newNC.id;
      } else if (_destinationType == 'nc') {
        nonConformityId = _selectedNonConformityId;
      }

      // For "any" destination, extract the IDs from the selected entry
      String? finalTopicId = _selectedTopicId;
      String? finalItemId = _selectedItemId;
      String? finalDetailId = _selectedDetailId;
      
      if (_destinationType == 'any') {
        if (_selectedDetailId != null) {
          // Detail selected - extract all IDs
          final detail = _allDetails.firstWhere((d) => d['id'] == _selectedDetailId, orElse: () => {});
          if (detail.isNotEmpty) {
            finalTopicId = detail['topicId'];
            finalItemId = detail['itemId'];
            finalDetailId = detail['id'];
          }
        } else if (_selectedItemId != null) {
          // Item selected - extract topic and item IDs
          final item = _allItems.firstWhere((i) => i['id'] == _selectedItemId, orElse: () => {});
          if (item.isNotEmpty) {
            finalTopicId = item['topicId'];
            finalItemId = item['id'];
            finalDetailId = null;
          }
        }
        // Topic ID is already correct for topic-only selection
      }

      // Move media using the media service
      final success = await _serviceFactory.mediaService.moveMedia(
        mediaId: widget.mediaId,
        inspectionId: widget.inspectionId,
        newTopicId: finalTopicId,
        newItemId: (_destinationType != 'topic' && _destinationType != 'any') ? _selectedItemId : finalItemId,
        newDetailId: (_destinationType == 'detail' || _destinationType == 'nc') ? _selectedDetailId : finalDetailId,
        newNonConformityId: nonConformityId,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isOfflineMode
                  ? 'Mídia offline movida com sucesso!'
                  : 'Mídia movida com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao mover mídia'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao mover mídia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF6F4B99),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.move_to_inbox, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mover Mídia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
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
                          Text(
                            'Localização atual: ${widget.currentLocation}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Destination Type Selection
                          const Text('Destino:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Tópico', style: TextStyle(fontSize: 12)),
                                selected: _destinationType == 'topic',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _destinationType = 'topic';
                                      _selectedItemId = null;
                                      _selectedDetailId = null;
                                      _selectedNonConformityId = null;
                                      _items = [];
                                      _details = [];
                                      _nonConformities = [];
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Item', style: TextStyle(fontSize: 12)),
                                selected: _destinationType == 'item',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _destinationType = 'item';
                                      _selectedDetailId = null;
                                      _selectedNonConformityId = null;
                                      _details = [];
                                      _nonConformities = [];
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Detalhe', style: TextStyle(fontSize: 12)),
                                selected: _destinationType == 'detail',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _destinationType = 'detail';
                                      _selectedNonConformityId = null;
                                      _nonConformities = [];
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Não Conformidade', style: TextStyle(fontSize: 12)),
                                selected: _destinationType == 'nc',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _destinationType = 'nc';
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Qualquer Local', style: TextStyle(fontSize: 12)),
                                selected: _destinationType == 'any',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _destinationType = 'any';
                                      _selectedItemId = null;
                                      _selectedDetailId = null;
                                      _selectedNonConformityId = null;
                                      _items = [];
                                      _details = [];
                                      _nonConformities = [];
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Topic Selection
                          const Text('Tópico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedTopicId,
                            hint: const Text('Selecione um tópico', style: TextStyle(fontSize: 12)),
                            isExpanded: true,
                            items: _topics.map((topic) {
                              return DropdownMenuItem<String>(
                                value: topic['id'] as String,
                                child: Text(topic['name'] as String, style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (topicId) async {
                              setState(() {
                                _selectedTopicId = topicId;
                                _items = [];
                                _selectedItemId = null;
                                _details = [];
                                _selectedDetailId = null;
                                _nonConformities = [];
                                _selectedNonConformityId = null;
                              });
                              if (topicId != null && _destinationType != 'topic') {
                                await _loadItems(topicId);
                              }
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // "Any" destination selection
                          if (_destinationType == 'any') ...[
                            const Text('Selecione o destino:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            
                            // Topics dropdown for "any"
                            const Text('Tópicos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedTopicId,
                              hint: const Text('Selecionar tópico', style: TextStyle(fontSize: 12)),
                              isExpanded: true,
                              items: _allTopics.map((topic) {
                                return DropdownMenuItem<String>(
                                  value: topic['id'] as String,
                                  child: Text('📁 ${topic['name'] as String}', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (topicId) {
                                setState(() {
                                  _selectedTopicId = topicId;
                                  _selectedItemId = null;
                                  _selectedDetailId = null;
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Items dropdown for "any"
                            const Text('Itens:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedItemId,
                              hint: const Text('Selecionar item', style: TextStyle(fontSize: 12)),
                              isExpanded: true,
                              items: _allItems.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item['id'] as String,
                                  child: Text('📋 ${item['name'] as String}', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (itemId) {
                                setState(() {
                                  _selectedItemId = itemId;
                                  _selectedDetailId = null;
                                  // Update topic selection based on item
                                  if (itemId != null) {
                                    final item = _allItems.firstWhere((i) => i['id'] == itemId, orElse: () => {});
                                    if (item.isNotEmpty) {
                                      _selectedTopicId = item['topicId'];
                                    }
                                  }
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Details dropdown for "any"
                            const Text('Detalhes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedDetailId,
                              hint: const Text('Selecionar detalhe', style: TextStyle(fontSize: 12)),
                              isExpanded: true,
                              items: _allDetails.map((detail) {
                                return DropdownMenuItem<String>(
                                  value: detail['id'] as String,
                                  child: Text('🔍 ${detail['name'] as String}', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (detailId) {
                                setState(() {
                                  _selectedDetailId = detailId;
                                  // Update topic and item selection based on detail
                                  if (detailId != null) {
                                    final detail = _allDetails.firstWhere((d) => d['id'] == detailId, orElse: () => {});
                                    if (detail.isNotEmpty) {
                                      _selectedTopicId = detail['topicId'];
                                      _selectedItemId = detail['itemId'];
                                    }
                                  }
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Item Selection (if needed)
                          if (_destinationType != 'topic' && _destinationType != 'any') ...[
                            const Text('Item:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedItemId,
                              hint: const Text('Selecione um item', style: TextStyle(fontSize: 12)),
                              isExpanded: true,
                              items: _items.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item['id'] as String,
                                  child: Text(item['name'] as String, style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: _selectedTopicId == null
                                  ? null
                                  : (itemId) async {
                                      setState(() {
                                        _selectedItemId = itemId;
                                        _details = [];
                                        _selectedDetailId = null;
                                        _nonConformities = [];
                                        _selectedNonConformityId = null;
                                      });
                                      if (itemId != null && (_destinationType == 'detail' || _destinationType == 'nc')) {
                                        await _loadDetails(itemId);
                                      }
                                    },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Detail Selection (if needed)
                          if ((_destinationType == 'detail' || _destinationType == 'nc') && _destinationType != 'any') ...[
                            const Text('Detalhe:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedDetailId,
                              hint: const Text('Selecione um detalhe', style: TextStyle(fontSize: 12)),
                              isExpanded: true,
                              items: _details.map((detail) {
                                return DropdownMenuItem<String>(
                                  value: detail['id'] as String,
                                  child: Text(detail['name'] as String, style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: _selectedItemId == null
                                  ? null
                                  : (detailId) async {
                                      setState(() {
                                        _selectedDetailId = detailId;
                                        _nonConformities = [];
                                        _selectedNonConformityId = null;
                                      });
                                      if (detailId != null && _destinationType == 'nc') {
                                        await _loadNonConformities(detailId);
                                      }
                                    },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Non-Conformity Selection (if needed)
                          if (_destinationType == 'nc' && _destinationType != 'any') ...[
                            const Text('Não Conformidade:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            
                            if (_nonConformities.isNotEmpty) ...[
                              const Text('Não conformidades existentes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedNonConformityId,
                                hint: const Text('Selecionar existente (opcional)', style: TextStyle(fontSize: 12)),
                                isExpanded: true,
                                items: _nonConformities.map((nc) {
                                  return DropdownMenuItem<String>(
                                    value: nc['id'] as String,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          nc['displayTitle'] as String,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if ((nc['displaySubtitle'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            nc['displaySubtitle'] as String,
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (ncId) {
                                  setState(() {
                                    _selectedNonConformityId = ncId;
                                    if (ncId != null) {
                                      // Clear new NC fields when selecting existing
                                      _newNCTitleController.clear();
                                      _newNCDescriptionController.clear();
                                      _newNCActionController.clear();
                                    }
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                itemHeight: null,
                                menuMaxHeight: 200,
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                            ],

                            // New NC Creation Form
                            const Text('Ou criar nova não conformidade:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newNCTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Título da NC *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    _selectedNonConformityId = null; // Clear existing selection
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newNCDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Descrição',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newNCActionController,
                              decoration: const InputDecoration(
                                labelText: 'Ação Corretiva (opcional)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            const Text('Severidade:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _newNCSeverity,
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Baixa', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'medium', child: Text('Média', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'high', child: Text('Alta', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'critical', child: Text('Crítica', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _newNCSeverity = value ?? 'medium';
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Destination Summary
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destino:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDestinationDescription(),
                                  style: const TextStyle(fontSize: 11, color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: !_isValidSelection() ? null : _moveMedia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4B99),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mover', style: TextStyle(fontSize: 12)),
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
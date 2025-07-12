// lib/presentation/widgets/dialogs/bulk_move_media_dialog.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class BulkMoveMediaDialog extends StatefulWidget {
  final String inspectionId;
  final List<String> selectedMediaIds;
  final String initialDestinationType;

  const BulkMoveMediaDialog({
    super.key,
    required this.inspectionId,
    required this.selectedMediaIds,
    required this.initialDestinationType,
  });

  @override
  State<BulkMoveMediaDialog> createState() => _BulkMoveMediaDialogState();
}

class _BulkMoveMediaDialogState extends State<BulkMoveMediaDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _details = [];

  // For "any" destination type - all available options
  List<Map<String, dynamic>> _allTopics = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _allDetails = [];

  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  
  late String _destinationType;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _destinationType = widget.initialDestinationType;
    _loadHierarchy();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadHierarchy() async {
    try {
      debugPrint('BulkMoveMediaDialog: Loading hierarchy for inspection ${widget.inspectionId}');
      
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
        debugPrint('BulkMoveMediaDialog: Loaded ${topics.length} topics, ${allItems.length} items, ${allDetails.length} details');
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
      }
    } catch (e) {
      debugPrint('BulkMoveMediaDialog: Error loading hierarchy: $e');
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
            }

            if (mounted) {
              setState(() {
                _items = items;
                _selectedItemId = null;
                _details = [];
                _selectedDetailId = null;
              });
            }
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
        });
      }
    } catch (e) {
      debugPrint('BulkMoveMediaDialog: Error loading items: $e');
    }
  }

  Future<void> _loadDetails(String itemId) async {
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
              }

              if (mounted) {
                setState(() {
                  _details = details;
                  _selectedDetailId = null;
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
        });
      }
    } catch (e) {
      debugPrint('BulkMoveMediaDialog: Error loading details: $e');
    }
  }


  String _getDestinationDescription() {
    List<String> parts = [];

    if (_destinationType == 'any') {
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

    if (_destinationType == 'detail') {
      if (_selectedDetailId != null) {
        final detail = _details.firstWhere((d) => d['id'] == _selectedDetailId,
            orElse: () => {});
        if (detail.isNotEmpty) {
          parts.add('Detalhe: ${detail['name']}');
        }
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
      case 'any':
        return _selectedTopicId != null || _selectedItemId != null || _selectedDetailId != null;
      default:
        return false;
    }
  }

  Future<void> _bulkMoveMedia() async {
    if (!_isValidSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, complete a seleção do destino'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // For "any" destination, extract the IDs from the selected entry
      String? finalTopicId = _selectedTopicId;
      String? finalItemId = _selectedItemId;
      String? finalDetailId = _selectedDetailId;
      
      if (_destinationType == 'any') {
        if (_selectedDetailId != null) {
          final detail = _allDetails.firstWhere((d) => d['id'] == _selectedDetailId, orElse: () => {});
          if (detail.isNotEmpty) {
            finalTopicId = detail['topicId'];
            finalItemId = detail['itemId'];
            finalDetailId = detail['id'];
          }
        } else if (_selectedItemId != null) {
          final item = _allItems.firstWhere((i) => i['id'] == _selectedItemId, orElse: () => {});
          if (item.isNotEmpty) {
            finalTopicId = item['topicId'];
            finalItemId = item['id'];
            finalDetailId = null;
          }
        }
      }

      int successCount = 0;
      int failCount = 0;

      // Move each media individually
      for (final mediaId in widget.selectedMediaIds) {
        try {
          final success = await _serviceFactory.mediaService.moveMedia(
            mediaId: mediaId,
            inspectionId: widget.inspectionId,
            newTopicId: finalTopicId,
            newItemId: (_destinationType != 'topic' && _destinationType != 'any') ? _selectedItemId : finalItemId,
            newDetailId: (_destinationType == 'detail') ? _selectedDetailId : finalDetailId,
            newNonConformityId: null,
          );

          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          debugPrint('Error moving media $mediaId: $e');
          failCount++;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(successCount > 0);
        
        if (successCount > 0 && failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount mídia(s) movida(s) com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (successCount > 0 && failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount mídia(s) movida(s), $failCount falharam'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao mover mídias'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao mover mídias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _getDestinationTypeTitle() {
    switch (_destinationType) {
      case 'topic': return 'Mover para Tópico';
      case 'item': return 'Mover para Item';
      case 'detail': return 'Mover para Detalhe';
      case 'any': return 'Mover para Qualquer Local';
      default: return 'Mover Mídias';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  const Icon(Icons.drive_file_move, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDestinationTypeTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.selectedMediaIds.length} mídia(s) selecionada(s)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                          ] else ...[
                            // Traditional hierarchical selection
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
                            
                            if (_destinationType == 'item' || _destinationType == 'detail') ...[
                              const SizedBox(height: 12),
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
                                        });
                                        if (itemId != null && _destinationType == 'detail') {
                                          await _loadDetails(itemId);
                                        }
                                      },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                            
                            if (_destinationType == 'detail') ...[
                              const SizedBox(height: 12),
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
                                    : (detailId) {
                                        setState(() {
                                          _selectedDetailId = detailId;
                                        });
                                      },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
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
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (!_isValidSelection() || _isProcessing) ? null : _bulkMoveMedia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4B99),
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Mover Todas', style: TextStyle(fontSize: 12)),
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
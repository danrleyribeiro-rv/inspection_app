// lib/presentation/widgets/dialogs/move_media_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/enhanced_offline_service_factory.dart';

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
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _nonConformities = [];
  
  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  String? _selectedNonConformityId;
  bool _isNonConformity = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  Future<void> _loadHierarchy() async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        final topics = <Map<String, dynamic>>[];
        
        for (int i = 0; i < inspection!.topics!.length; i++) {
          final topicData = inspection.topics![i];
          topics.add({
            'id': topicData['id'] ?? 'topic_$i',
            'name': topicData['name'] ?? topicData['topic_name'] ?? 'Tópico ${i + 1}',
            'data': topicData,
          });
        }
        
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
      } else {
        setState(() {
          _topics = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar hierarquia: $e')),
        );
      }
    }
  }

  Future<void> _loadItems(String topicId) async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
          final topicData = inspection.topics![topicIndex];
          final currentTopicId = topicData['id'] ?? 'topic_$topicIndex';
          
          if (currentTopicId == topicId) {
            final items = <Map<String, dynamic>>[];
            final itemsList = topicData['items'] as List<dynamic>? ?? [];
            
            for (int i = 0; i < itemsList.length; i++) {
              final itemData = itemsList[i];
              items.add({
                'id': itemData['id'] ?? 'item_${topicIndex}_$i',
                'name': itemData['name'] ?? itemData['item_name'] ?? 'Item ${i + 1}',
                'data': itemData,
              });
            }
            
            setState(() {
              _items = items;
              _selectedItemId = null;
              _details = [];
              _selectedDetailId = null;
              _nonConformities = [];
              _selectedNonConformityId = null;
            });
            return;
          }
        }
      }
      setState(() {
        _items = [];
        _selectedItemId = null;
        _details = [];
        _selectedDetailId = null;
        _nonConformities = [];
        _selectedNonConformityId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar itens: $e')),
        );
      }
    }
  }

  Future<void> _loadDetails(String itemId) async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
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
                details.add({
                  'id': detailData['id'] ?? 'detail_${topicIndex}_${itemIndex}_$i',
                  'name': detailData['name'] ?? detailData['detail_name'] ?? 'Detalhe ${i + 1}',
                  'data': detailData,
                });
              }
              
              setState(() {
                _details = details;
                _selectedDetailId = null;
                _nonConformities = [];
                _selectedNonConformityId = null;
              });
              return;
            }
          }
        }
      }
      setState(() {
        _details = [];
        _selectedDetailId = null;
        _nonConformities = [];
        _selectedNonConformityId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
        );
      }
    }
  }

  Future<void> _loadNonConformities(String detailId) async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics != null) {
        for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
          final topicData = inspection.topics![topicIndex];
          final itemsList = topicData['items'] as List<dynamic>? ?? [];
          
          for (int itemIndex = 0; itemIndex < itemsList.length; itemIndex++) {
            final itemData = itemsList[itemIndex];
            final detailsList = itemData['details'] as List<dynamic>? ?? [];
            
            for (int detailIndex = 0; detailIndex < detailsList.length; detailIndex++) {
              final detailData = detailsList[detailIndex];
              final currentDetailId = detailData['id'] ?? 'detail_${topicIndex}_${itemIndex}_$detailIndex';
              
              if (currentDetailId == detailId) {
                final nonConformities = <Map<String, dynamic>>[];
                final ncList = detailData['non_conformities'] as List<dynamic>? ?? [];
                
                for (int i = 0; i < ncList.length; i++) {
                  final ncData = ncList[i];
                  final ncId = ncData['id'] ?? 'nc_${topicIndex}_${itemIndex}_${detailIndex}_$i';
                  final title = ncData['title'] ?? ncData['description'] ?? 'Não Conformidade';
                  final description = ncData['description'] ?? '';
                  final severity = ncData['severity'] ?? 'Baixa';
                  final status = ncData['is_resolved'] == true ? 'Resolvida' : 'Pendente';
                  
                  // Criar identificação clara para o usuário
                  final displayTitle = '${i + 1}. $title';
                  final displaySubtitle = '$severity • $status${description.isNotEmpty ? ' • $description' : ''}';
                  
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

  String _getDestinationDescription() {
    List<String> parts = [];
    
    if (_selectedTopicId != null) {
      final topic = _topics.firstWhere((t) => t['id'] == _selectedTopicId, orElse: () => {});
      if (topic.isNotEmpty) {
        parts.add('Tópico: ${topic['name']}');
      }
    }
    
    if (_selectedItemId != null) {
      final item = _items.firstWhere((i) => i['id'] == _selectedItemId, orElse: () => {});
      if (item.isNotEmpty) {
        parts.add('Item: ${item['name']}');
      }
    }
    
    if (_selectedDetailId != null) {
      final detail = _details.firstWhere((d) => d['id'] == _selectedDetailId, orElse: () => {});
      if (detail.isNotEmpty) {
        parts.add('Detalhe: ${detail['name']}');
      }
    }
    
    if (_isNonConformity && _selectedNonConformityId != null) {
      final nc = _nonConformities.firstWhere((n) => n['id'] == _selectedNonConformityId, orElse: () => {});
      if (nc.isNotEmpty) {
        parts.add('NC: ${nc['title']}');
      }
    } else if (_isNonConformity) {
      parts.add('(Nova Não Conformidade)');
    }
    
    return parts.isEmpty ? 'Nenhum destino selecionado' : parts.join(' → ');
  }

  Future<void> _moveMedia() async {
    try {
      // Validate selection
      if (_selectedDetailId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione um detalhe de destino'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Move media using the media service
      final success = await _serviceFactory.mediaService.moveMedia(
        mediaId: widget.mediaId,
        inspectionId: widget.inspectionId,
        newTopicId: _selectedTopicId,
        newItemId: _selectedItemId,
        newDetailId: _selectedDetailId,
        newNonConformityId: _isNonConformity ? _selectedNonConformityId : null,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isOfflineMode 
                  ? 'Mídia offline movida com sucesso!'
                  : 'Imagem movida com sucesso!'
              ),
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
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6F4B99),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.move_to_inbox, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isOfflineMode ? 'Mover Mídia Offline' : 'Mover Imagem',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Seleção de Tópico
                          const Text('Tópico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedTopicId,
                            hint: const Text('Selecione um tópico', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: _topics.map((topic) {
                              return DropdownMenuItem<String>(
                                value: topic['id'] as String,
                                child: Text(topic['name'] as String, style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            onChanged: (topicId) {
                              setState(() {
                                _selectedTopicId = topicId;
                                _items = [];
                                _selectedItemId = null;
                                _details = [];
                                _selectedDetailId = null;
                                _nonConformities = [];
                                _selectedNonConformityId = null;
                                _isNonConformity = false;
                              });
                              if (topicId != null) {
                                _loadItems(topicId);
                              }
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Seleção de Item
                          const Text('Item:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedItemId,
                            hint: const Text('Selecione um item', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: _items.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id'] as String,
                                child: Text(item['name'] as String, style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            onChanged: _selectedTopicId == null ? null : (itemId) {
                              setState(() {
                                _selectedItemId = itemId;
                                _details = [];
                                _selectedDetailId = null;
                                _nonConformities = [];
                                _selectedNonConformityId = null;
                                _isNonConformity = false;
                              });
                              if (itemId != null) {
                                _loadDetails(itemId);
                              }
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Seleção de Detalhe
                          const Text('Detalhe:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedDetailId,
                            hint: const Text('Selecione um detalhe', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: _details.map((detail) {
                              return DropdownMenuItem<String>(
                                value: detail['id'] as String,
                                child: Text(detail['name'] as String, style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            onChanged: _selectedItemId == null ? null : (detailId) {
                              setState(() {
                                _selectedDetailId = detailId;
                                _nonConformities = [];
                                _selectedNonConformityId = null;
                                _isNonConformity = false;
                              });
                              if (detailId != null) {
                                _loadNonConformities(detailId);
                              }
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Checkbox para Não Conformidade
                          CheckboxListTile(
                            title: const Text('Mover para Não Conformidade', style: TextStyle(fontSize: 11)),
                            subtitle: const Text('A imagem será associada a uma não conformidade', style: TextStyle(fontSize: 10)),
                            value: _isNonConformity,
                            onChanged: _selectedDetailId == null ? null : (value) {
                              setState(() {
                                _isNonConformity = value ?? false;
                                if (!_isNonConformity) {
                                  _selectedNonConformityId = null;
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          
                          // Seleção de Não Conformidade (se habilitado)
                          if (_isNonConformity) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Não Conformidade:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 8),
                                Text('(${_nonConformities.length} encontradas)', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_nonConformities.isEmpty) 
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6F4B99).withValues(alpha: 0.1),
                                  border: Border.all(color: Color(0xFF6F4B99).withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Color(0xFF6F4B99)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Será criada uma nova não conformidade para esta imagem',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF6F4B99)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: _selectedNonConformityId,
                                hint: const Text('📝 Criar nova não conformidade', style: TextStyle(fontSize: 11)),
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
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if ((nc['displaySubtitle'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            nc['displaySubtitle'] as String,
                                            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
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
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                itemHeight: null, // Permite altura variável
                                menuMaxHeight: 300, // Limita altura do menu
                              ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Resumo do destino
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDestinationDescription(),
                                  style: const TextStyle(fontSize: 10, color: Colors.black),
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
                    child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedDetailId == null ? null : _moveMedia,
                    child: const Text('Mover', style: TextStyle(fontSize: 11)),
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
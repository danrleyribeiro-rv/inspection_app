import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class MoveMediaDialog extends StatefulWidget {
  final String inspectionId;
  final String? mediaId;
  final List<String>? selectedMediaIds;
  final String currentLocation;
  final bool isOfflineMode;
  final List<String> mediaFiles;

  const MoveMediaDialog({
    super.key,
    required this.inspectionId,
    this.mediaId,
    this.selectedMediaIds,
    required this.currentLocation,
    this.isOfflineMode = false,
    this.mediaFiles = const [],
  }) : assert(mediaId != null || selectedMediaIds != null,
            'Either mediaId or selectedMediaIds must be provided');

  @override
  State<MoveMediaDialog> createState() => _MoveMediaDialogState();
}

class _MoveMediaDialogState extends State<MoveMediaDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  List<Topic> _topics = [];
  List<Item> _items = [];
  List<Detail> _details = [];
  List<Detail> _directDetails = [];
  Topic? _selectedTopic;
  Item? _selectedItem;
  Detail? _selectedDetail;
  Detail? _selectedDirectDetail;

  String _selectedAction = 'move';
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isLoadingNCs = false;

  List<NonConformity> _nonConformities = [];
  NonConformity? _selectedNonConformity;
  final Map<String, Map<String, String>> _ncOriginInfo = {};

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      setState(() => _isLoading = true);
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);

      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tópicos: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadItems(String topicId) async {
    try {
      // First check if topic has direct details
      final topic = _topics.firstWhere((t) => t.id == topicId);
      
      if (topic.directDetails == true) {
        // Load direct details instead of items
        await _loadDirectDetails(topicId);
        if (mounted) {
          setState(() {
            _items = [];
            _selectedItem = null;
            _details = [];
            _selectedDetail = null;
          });
        }
      } else {
        // Load normal items
        final items = await _serviceFactory.dataService.getItems(topicId);
        if (mounted) {
          setState(() {
            _items = items;
            _selectedItem = null;
            _details = [];
            _selectedDetail = null;
            _directDetails = [];
            _selectedDirectDetail = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar itens: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadDetails(String itemId) async {
    try {
      final details = await _serviceFactory.dataService.getDetails(itemId);

      if (mounted) {
        setState(() {
          _details = details;
          _selectedDetail = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar detalhes: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadDirectDetails(String topicId) async {
    try {
      final directDetails = await _serviceFactory.dataService.getDirectDetails(topicId);

      if (mounted) {
        setState(() {
          _directDetails = directDetails;
          _selectedDirectDetail = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar detalhes diretos: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadAllNonConformities() async {
    setState(() => _isLoadingNCs = true);
    try {
      debugPrint('MoveMediaDialog: Loading all non-conformities for inspection ${widget.inspectionId}');
      
      // Carregar todas as não conformidades da inspeção diretamente
      List<NonConformity> allNCs = await _serviceFactory.dataService.getNonConformities(widget.inspectionId);
      
      debugPrint('MoveMediaDialog: Found ${allNCs.length} non-conformities via getNonConformities');
      
      // Enriquecer com informações de origem para cada NC
      for (final nc in allNCs) {
        String topicName = 'Tópico não identificado';
        String itemName = 'Item não identificado';
        String detailName = 'Detalhe não identificado';
        
        // Buscar informações do tópico
        if (nc.topicId != null) {
          final topic = _topics.firstWhere(
            (t) => t.id == nc.topicId,
            orElse: () => Topic(
              id: nc.topicId,
              inspectionId: widget.inspectionId,
              topicName: 'Tópico removido',
              position: 0,
              orderIndex: 0,
            ),
          );
          topicName = topic.topicName;
          
          // Buscar informações do item se existir
          if (nc.itemId != null) {
            try {
              final items = await _serviceFactory.dataService.getItems(nc.topicId!);
              final item = items.firstWhere(
                (i) => i.id == nc.itemId,
                orElse: () => Item(
                  id: nc.itemId,
                  inspectionId: widget.inspectionId,
                  topicId: nc.topicId,
                  itemName: 'Item removido',
                  position: 0,
                  orderIndex: 0,
                ),
              );
              itemName = item.itemName;
            } catch (e) {
              debugPrint('MoveMediaDialog: Error loading item ${nc.itemId}: $e');
              itemName = 'Item não encontrado';
            }
          } else if (topic.directDetails == true) {
            itemName = 'Detalhe';
          } else {
            itemName = 'Nível do tópico';
          }
          
          // Buscar informações do detalhe se existir
          if (nc.detailId != null) {
            try {
              List<Detail> details;
              if (topic.directDetails == true) {
                details = await _serviceFactory.dataService.getDirectDetails(nc.topicId!);
              } else if (nc.itemId != null) {
                details = await _serviceFactory.dataService.getDetails(nc.itemId!);
              } else {
                details = [];
              }
              
              final detail = details.firstWhere(
                (d) => d.id == nc.detailId,
                orElse: () => Detail(
                  id: nc.detailId,
                  inspectionId: widget.inspectionId,
                  itemId: nc.itemId,
                  detailName: 'Detalhe removido',
                  orderIndex: 0,
                ),
              );
              detailName = detail.detailName;
            } catch (e) {
              debugPrint('MoveMediaDialog: Error loading detail ${nc.detailId}: $e');
              detailName = 'Detalhe não encontrado';
            }
          } else {
            detailName = itemName == 'Nível do tópico' ? 'Nível do tópico' : 'Nível do item';
          }
        }
        
        _ncOriginInfo[nc.id] = {
          'topicName': topicName,
          'itemName': itemName,
          'detailName': detailName,
          'severity': nc.severity,
          'status': nc.status,
          'createdAt': nc.createdAt.toString(),
        };
      }

      debugPrint('MoveMediaDialog: Successfully processed ${allNCs.length} non-conformities');
      
      if (mounted) {
        setState(() {
          _nonConformities = allNCs;
          _selectedNonConformity = null;
        });
      }
    } catch (e) {
      debugPrint('MoveMediaDialog: Error loading non-conformities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar não conformidades: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingNCs = false);
      }
    }
  }


  Future<void> _deleteMedia() async {
    setState(() => _isProcessing = true);

    try {
      final List<String> mediaIds =
          widget.selectedMediaIds ?? [widget.mediaId!];
      bool allSuccess = true;

      for (final mediaId in mediaIds) {
        try {
          await _serviceFactory.mediaService.deleteMedia(mediaId);
        } catch (e) {
          allSuccess = false;
          break;
        }
      }

      if (mounted) {
        if (allSuccess) {
          Navigator.of(context).pop(true);
          final count = mediaIds.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(count > 1
                  ? '$count mídias excluídas com sucesso!'
                  : 'Mídia excluída com sucesso!'),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 800),
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao excluir mídia'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao excluir mídia: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _moveMedia() async {
    if (!_isValidSelection()) return;

    setState(() => _isProcessing = true);

    try {
      final List<String> mediaIds =
          widget.selectedMediaIds ?? [widget.mediaId!];
      bool allSuccess = true;

      for (final mediaId in mediaIds) {
        try {
          // For direct_details topics, use selectedDirectDetail instead of selectedDetail
          String? newDetailId;
          if (_selectedTopic?.directDetails == true) {
            newDetailId = _selectedDirectDetail?.id;
          } else {
            newDetailId = _selectedDetail?.id;
          }
          
          final success = await _serviceFactory.mediaService.moveMedia(
            mediaId: mediaId,
            inspectionId: widget.inspectionId,
            newTopicId: _selectedTopic?.id,
            newItemId: _selectedItem?.id,
            newDetailId: newDetailId,
            newNonConformityId: null,
          );

          if (!success) {
            allSuccess = false;
            break;
          }
        } catch (e) {
          allSuccess = false;
          break;
        }
      }

      if (mounted) {
        if (allSuccess) {
          Navigator.of(context).pop(true);
          final count = mediaIds.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(count > 1
                  ? '$count mídias movidas com sucesso!'
                  : 'Mídia movida com sucesso!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao mover mídia'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao mover mídia: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  bool _isValidSelection() {
    if (_selectedAction == 'delete') {
      return true;
    }
    if (_selectedAction == 'move_to_nc') {
      return _selectedNonConformity != null;
    }
    return _selectedTopic != null;
  }

  String _getActionButtonText() {
    final isMultiple =
        widget.selectedMediaIds != null && widget.selectedMediaIds!.length > 1;

    switch (_selectedAction) {
      case 'move':
        return isMultiple ? 'Mover Todas' : 'Mover Mídia';
      case 'delete':
        return isMultiple ? 'Excluir Todas' : 'Excluir Mídia';
      case 'move_to_nc':
        return isMultiple ? 'Duplicar' : 'Duplicar';
      default:
        return 'Executar';
    }
  }

  Future<void> _duplicateToExistingNC() async {
    if (_selectedNonConformity == null) return;

    setState(() => _isProcessing = true);

    try {
      final List<String> mediaIds =
          widget.selectedMediaIds ?? [widget.mediaId!];
      bool allSuccess = true;
      int successCount = 0;

      for (final mediaId in mediaIds) {
        final duplicatedMediaId = await _serviceFactory.mediaService.duplicateMedia(
          mediaId: mediaId,
          inspectionId: widget.inspectionId,
          newTopicId: _selectedNonConformity!.topicId,
          newItemId: _selectedNonConformity!.itemId,
          newDetailId: _selectedNonConformity!.detailId,
          newNonConformityId: _selectedNonConformity!.id,
        );

        if (duplicatedMediaId != null) {
          successCount++;
        } else {
          allSuccess = false;
          break;
        }
      }

      if (mounted) {
        if (allSuccess && successCount > 0) {
          Navigator.of(context).pop(true);
          final count = successCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(count > 1
                  ? '$count mídias duplicadas para NC com sucesso!'
                  : 'Mídia duplicada para NC com sucesso!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successCount > 0 
                  ? 'Duplicação parcial: $successCount de ${mediaIds.length} mídias duplicadas'
                  : 'Erro ao duplicar mídia para NC'),
              backgroundColor: successCount > 0 ? Colors.orange : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao duplicar mídia para NC: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'média':
      case 'media':
        return Colors.orange;
      case 'baixa':
        return Colors.yellow;
      case 'crítica':
      case 'critica':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _executeAction() async {
    switch (_selectedAction) {
      case 'move':
        await _moveMedia();
        break;
      case 'delete':
        await _deleteMedia();
        break;
      case 'move_to_nc':
        await _duplicateToExistingNC();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMultiple =
        widget.selectedMediaIds != null && widget.selectedMediaIds!.length > 1;

    return Dialog(
      backgroundColor: const Color(0xFF312456),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMultiple
                  ? 'Ações para ${widget.selectedMediaIds!.length} Mídias'
                  : 'Ações para Mídia',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha uma ação:',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedAction,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Color(0xFF2D3748),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.white),
              dropdownColor: const Color(0xFF2D3748),
              items: const [
                DropdownMenuItem(value: 'move', child: Text('Mover Foto')),
                DropdownMenuItem(
                    value: 'move_to_nc',
                    child: Text('Duplicar para NC')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAction = value;
                    _selectedTopic = null;
                    _selectedItem = null;
                    _selectedDetail = null;
                    _selectedDirectDetail = null;
                    _selectedNonConformity = null;
                    _items = [];
                    _details = [];
                    _directDetails = [];
                    _nonConformities = [];
                  });

                  // Carregar não conformidades se a ação for mover para NC existente
                  if (value == 'move_to_nc') {
                    _loadAllNonConformities();
                  }
                }
              },
            ),
            const SizedBox(height: 4),
            if (_selectedAction == 'move') ...[
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
              else ...[
                Text(
                  'Tópico:',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<Topic>(
                  initialValue: _selectedTopic,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFF2D3748),
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  dropdownColor: const Color(0xFF2D3748),
                  hint: const Text('Selecione um tópico',
                      style: TextStyle(color: Colors.white70)),
                  items: _topics.map((topic) {
                    return DropdownMenuItem<Topic>(
                      value: topic,
                      child: Text(topic.topicName,
                          style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (topic) async {
                    setState(() {
                      _selectedTopic = topic;
                      _selectedItem = null;
                      _selectedDetail = null;
                      _selectedDirectDetail = null;
                      _items = [];
                      _details = [];
                      _directDetails = [];
                    });

                    if (topic != null) {
                      await _loadItems(topic.id);
                    }
                  },
                ),
                const SizedBox(height: 4),
                // Direct details dropdown for topics with directDetails = true
                if (_selectedTopic != null && _selectedTopic!.directDetails == true) ...[
                  Text(
                    'Detalhe Direto:',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Detail>(
                    initialValue: _selectedDirectDetail,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    dropdownColor: const Color(0xFF2D3748),
                    hint: const Text('Selecione um detalhe',
                        style: TextStyle(color: Colors.white70)),
                    items: _directDetails.map((detail) {
                      return DropdownMenuItem<Detail>(
                        value: detail,
                        child: Text(detail.detailName,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (detail) {
                      setState(() => _selectedDirectDetail = detail);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                // Regular items dropdown for topics with directDetails = false or null
                if (_selectedTopic != null && (_selectedTopic!.directDetails != true)) ...[
                  Text(
                    'Item (opcional):',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Item>(
                    initialValue: _selectedItem,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    dropdownColor: const Color(0xFF2D3748),
                    hint: const Text('Selecione um item',
                        style: TextStyle(color: Colors.white70)),
                    items: _items.map((item) {
                      return DropdownMenuItem<Item>(
                        value: item,
                        child: Text(item.itemName,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (item) async {
                      setState(() {
                        _selectedItem = item;
                        _selectedDetail = null;
                        _details = [];
                      });

                      if (item != null) {
                        await _loadDetails(item.id);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                if (_selectedItem != null) ...[
                  Text(
                    'Detalhe (opcional):',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Detail>(
                    initialValue: _selectedDetail,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    dropdownColor: const Color(0xFF2D3748),
                    hint: const Text('Selecione um detalhe',
                        style: TextStyle(color: Colors.white70)),
                    items: _details.map((detail) {
                      return DropdownMenuItem<Detail>(
                        value: detail,
                        child: Text(detail.detailName,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (detail) {
                      setState(() => _selectedDetail = detail);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ],
            if (_selectedAction == 'move_to_nc') ...[
              if (_isLoadingNCs)
                const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
              else ...[
                Text(
                  'Não Conformidades Existentes:',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                if (_nonConformities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A5568)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nenhuma não conformidade encontrada nesta inspeção.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  )
                else
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _nonConformities.length,
                    itemBuilder: (context, index) {
                      final nc = _nonConformities[index];
                      final isSelected = _selectedNonConformity?.id == nc.id;

                      // Extract origin information from auxiliary structure
                      final originInfo = _ncOriginInfo[nc.id];
                      final topicName = originInfo?['topicName'] ?? 'Tópico não identificado';
                      final itemName = originInfo?['itemName'] ?? 'Item não identificado';
                      final detailName = originInfo?['detailName'] ?? 'Detalhe não identificado';
                      final severity = originInfo?['severity'] ?? 'unknown';
                      final createdAt = originInfo?['createdAt'] ?? 'Data não disponível';
                      
                      final originPath = itemName == 'Detalhe' 
                          ? '$topicName > $detailName'
                          : '$topicName > $itemName > $detailName';

                      return Card(
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFF2D3748),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      nc.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (severity.isNotEmpty && severity != 'unknown')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getSeverityColor(severity),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        severity.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white, 
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Local: $originPath',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Criada: ${createdAt.split(' ')[0]}', // Show only date
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedNonConformity = nc;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isSelected ? Colors.white : Colors.orange,
                                    foregroundColor:
                                        isSelected ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: Text(
                                    isSelected ? 'Selecionado' : 'Selecionar',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _executeAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedAction == 'delete'
                          ? Colors.red
                          : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _getActionButtonText(),
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  Topic? _selectedTopic;
  Item? _selectedItem;
  Detail? _selectedDetail;

  String _selectedAction = 'move';
  bool _isLoading = true;
  bool _isProcessing = false;

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
          SnackBar(content: Text('Erro ao carregar tópicos: $e')),
        );
      }
    }
  }

  Future<void> _loadItems(String topicId) async {
    try {
      final items = await _serviceFactory.dataService.getItems(topicId);

      if (mounted) {
        setState(() {
          _items = items;
          _selectedItem = null;
          _details = [];
          _selectedDetail = null;
        });
      }
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
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
        );
      }
    }
  }

  Future<void> _loadAllNonConformities() async {
    try {
      // Carregar todas as não conformidades da inspeção com informações completas
      List<NonConformity> allNCs = [];

      // Buscar todas as NCs em todos os tópicos
      for (final topic in _topics) {
        final items = await _serviceFactory.dataService.getItems(topic.id!);
        for (final item in items) {
          final details =
              await _serviceFactory.dataService.getDetails(item.id!);
          for (final detail in details) {
            final ncs = await _serviceFactory.dataService
                .getNonConformitiesByDetail(detail.id!);
            // Armazenar informações da origem em estrutura auxiliar
            for (final nc in ncs) {
              _ncOriginInfo[nc.id] = {
                'topicName': topic.topicName,
                'itemName': item.itemName,
                'detailName': detail.detailName,
              };
              allNCs.add(nc);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _nonConformities = allNCs;
          _selectedNonConformity = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar não conformidades: $e')),
        );
      }
    }
  }

  Future<void> _createNewNonConformity() async {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um tópico')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Criar a não conformidade primeiro
      final nonConformity = NonConformity.create(
        inspectionId: widget.inspectionId,
        topicId: _selectedTopic!.id!,
        itemId: _selectedItem?.id,
        detailId: _selectedDetail?.id,
        title: 'Nova Não Conformidade',
        description: 'Criada automaticamente ao',
        severity: 'medium',
        status: 'open',
      );

      // Salvar a não conformidade
      await _serviceFactory.dataService.saveNonConformity(nonConformity);

      // Mover as imagens para a nova não conformidade
      final List<String> mediaIds =
          widget.selectedMediaIds ?? [widget.mediaId!];
      bool allSuccess = true;

      for (final mediaId in mediaIds) {
        final success = await _serviceFactory.mediaService.moveMedia(
          mediaId: mediaId,
          inspectionId: widget.inspectionId,
          newTopicId: _selectedTopic!.id,
          newItemId: _selectedItem?.id,
          newDetailId: _selectedDetail?.id,
          newNonConformityId: nonConformity.id,
        );

        if (!success) {
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
                  ? '$count mídias movidas para nova NC com sucesso!'
                  : 'Mídia movida para nova NC com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao mover mídia para nova NC'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao criar NC e mover mídia: $e'),
              backgroundColor: Colors.red),
        );
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
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao excluir mídia'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao excluir mídia: $e'),
              backgroundColor: Colors.red),
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
          final success = await _serviceFactory.mediaService.moveMedia(
            mediaId: mediaId,
            inspectionId: widget.inspectionId,
            newTopicId: _selectedTopic?.id,
            newItemId: _selectedItem?.id,
            newDetailId: _selectedDetail?.id,
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
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao mover mídia'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao mover mídia: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isValidSelection() {
    if (_selectedAction == 'delete') {
      return true;
    }
    if (_selectedAction == 'create_nc') {
      return _selectedTopic != null;
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
      case 'create_nc':
        return 'Criar NC';
      case 'move_to_nc':
        return isMultiple ? 'Mover para NC' : 'Mover para NC';
      default:
        return 'Executar';
    }
  }

  Future<void> _moveToExistingNC() async {
    if (_selectedNonConformity == null) return;

    setState(() => _isProcessing = true);

    try {
      final List<String> mediaIds =
          widget.selectedMediaIds ?? [widget.mediaId!];
      bool allSuccess = true;

      for (final mediaId in mediaIds) {
        final success = await _serviceFactory.mediaService.moveMedia(
          mediaId: mediaId,
          inspectionId: widget.inspectionId,
          newTopicId: _selectedNonConformity!.topicId,
          newItemId: _selectedNonConformity!.itemId,
          newDetailId: _selectedNonConformity!.detailId,
          newNonConformityId: _selectedNonConformity!.id,
        );

        if (!success) {
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
                  ? '$count mídias movidas para NC com sucesso!'
                  : 'Mídia movida para NC com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao mover mídia para NC'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao mover mídia para NC: $e'),
              backgroundColor: Colors.red),
        );
      }
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
      case 'create_nc':
        await _createNewNonConformity();
        break;
      case 'move_to_nc':
        await _moveToExistingNC();
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha uma ação:',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedAction,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Color(0xFF2D3748),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.white),
              dropdownColor: const Color(0xFF2D3748),
              items: const [
                DropdownMenuItem(value: 'move', child: Text('Mover Foto')),
                DropdownMenuItem(
                    value: 'create_nc', child: Text('Criar Não Conformidade')),
                DropdownMenuItem(
                    value: 'move_to_nc',
                    child: Text('Mover para NC Existente')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAction = value;
                    _selectedTopic = null;
                    _selectedItem = null;
                    _selectedDetail = null;
                    _selectedNonConformity = null;
                    _items = [];
                    _details = [];
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
            if (_selectedAction == 'create_nc') ...[
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
              else ...[
                Text(
                  'Nível da NC:',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<Topic>(
                  value: _selectedTopic,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFF2D3748),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
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
                      _items = [];
                      _details = [];
                    });

                    if (topic != null) {
                      await _loadItems(topic.id!);
                    }
                  },
                ),
                const SizedBox(height: 4),
                if (_selectedTopic != null) ...[
                  Text(
                    'Item (opcional):',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Item>(
                    value: _selectedItem,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
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
                        await _loadDetails(item.id!);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                if (_selectedItem != null) ...[
                  Text(
                    'Detalhe (opcional):',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Detail>(
                    value: _selectedDetail,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
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
            if (_selectedAction == 'move') ...[
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
              else ...[
                Text(
                  'Tópico:',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<Topic>(
                  value: _selectedTopic,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFF2D3748),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
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
                      _items = [];
                      _details = [];
                    });

                    if (topic != null) {
                      await _loadItems(topic.id!);
                    }
                  },
                ),
                const SizedBox(height: 4),
                if (_selectedTopic != null) ...[
                  Text(
                    'Item (opcional):',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Item>(
                    value: _selectedItem,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
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
                        await _loadDetails(item.id!);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                if (_selectedItem != null) ...[
                  Text(
                    'Detalhe (opcional):',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Detail>(
                    value: _selectedDetail,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF2D3748),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
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
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
              else ...[
                Text(
                  'Não Conformidades Existentes:',
                  style: const TextStyle(
                      fontSize: 16,
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
                    child: const Text(
                      'Nenhuma não conformidade encontrada nesta inspeção.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _nonConformities.length,
                    itemBuilder: (context, index) {
                      final nc = _nonConformities[index];
                      final isSelected = _selectedNonConformity?.id == nc.id;

                      // Extract origin information from auxiliary structure
                      final originInfo = _ncOriginInfo[nc.id];
                      final topicName = originInfo?['topicName'] ?? 'Tópico não identificado';
                      final itemName = originInfo?['itemName'] ?? 'Item não identificado';
                      final detailName = originInfo?['detailName'] ?? 'Detalhe não identificado';
                      final originPath = '$topicName > $itemName > $detailName';

                      return Card(
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFF2D3748),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nc.title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Origem: $originPath',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              nc.description,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: ElevatedButton(
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              isSelected ? 'Selecionado' : 'Selecionar',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      );
                    },
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
                        style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                            style: const TextStyle(fontSize: 16),
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

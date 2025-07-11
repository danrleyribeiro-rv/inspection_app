// lib/presentation/widgets/details_list_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/media_capture_dialog.dart';
import 'package:lince_inspecoes/services/navigation_state_service.dart';

// O widget DetailsListSection e seu State permanecem os mesmos.
// A mudança principal está dentro do DetailListItem.
// ... (código do DetailsListSection inalterado)

class DetailsListSection extends StatefulWidget {
  final List<Detail> details;
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Detail) onDetailUpdated;
  final VoidCallback onDetailAction;
  final String? expandedDetailId; // ID do detalhe que deve estar expandido
  final Function(String?)? onDetailExpanded; // Callback quando um detalhe é expandido
  final int topicIndex; // Índice do tópico atual na lista
  final int itemIndex;  // Índice do item atual na lista

  const DetailsListSection({
    super.key,
    required this.details,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onDetailUpdated,
    required this.onDetailAction,
    this.expandedDetailId,
    this.onDetailExpanded,
    required this.topicIndex,
    required this.itemIndex,
  });

  @override
  State<DetailsListSection> createState() => _DetailsListSectionState();
}

class _DetailsListSectionState extends State<DetailsListSection> {
  int _expandedDetailIndex = -1;
  List<Detail> _localDetails = [];

  @override
  void initState() {
    super.initState();
    _localDetails = List.from(widget.details);
    _setInitialExpandedDetail();
  }
  
  void _setInitialExpandedDetail() {
    if (widget.expandedDetailId != null) {
      final index = _localDetails.indexWhere((detail) => detail.id == widget.expandedDetailId);
      if (index >= 0) {
        _expandedDetailIndex = index;
      }
    }
  }

  @override
  void didUpdateWidget(DetailsListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.details != oldWidget.details) {
      _localDetails = List.from(widget.details);
      _setInitialExpandedDetail(); // Reaplica a expansão se os detalhes mudaram
    }
  }

  Future<void> _reorderDetail(int oldIndex, int newIndex) async {
    debugPrint(
        'DetailsListSection: Reordering detail from $oldIndex to $newIndex');

    try {
      if (oldIndex < newIndex) newIndex -= 1;

      // Update local state first
      setState(() {
        final Detail item = _localDetails.removeAt(oldIndex);
        _localDetails.insert(newIndex, item);

        // Update expanded index tracking
        if (_expandedDetailIndex == oldIndex) {
          _expandedDetailIndex = newIndex;
        } else if (_expandedDetailIndex > oldIndex &&
            _expandedDetailIndex <= newIndex) {
          _expandedDetailIndex--;
        } else if (_expandedDetailIndex < oldIndex &&
            _expandedDetailIndex >= newIndex) {
          _expandedDetailIndex++;
        }
      });

      // Use the repository's efficient reorder method
      final itemId = widget.item.id;
      if (itemId != null) {
        final detailIds = _localDetails.map((detail) => detail.id!).toList();
        
        debugPrint('DetailsListSection: Reordering details with IDs: $detailIds');
        await EnhancedOfflineServiceFactory.instance.dataService.reorderDetails(itemId, detailIds);
        debugPrint('DetailsListSection: Details reordered successfully in database');
      }

      debugPrint(
          'DetailsListSection: Successfully reordered ${_localDetails.length} details');

      // Notify parent to refresh - delayed to ensure database is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.onDetailAction();
        }
      });
    } catch (e) {
      debugPrint('DetailsListSection: Error reordering details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reordenar detalhe: $e')),
        );
        
        // Restore original order from widget
        setState(() {
          _localDetails = List.from(widget.details);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha((255 * 0.2).round())),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(4),
        itemCount: _localDetails.length,
        itemBuilder: (context, index) {
          final detail = _localDetails[index];
          final isExpanded = index == _expandedDetailIndex;

          return DetailListItem(
            key: ValueKey(detail.id),
            index: index,
            detail: detail,
            item: widget.item,
            topic: widget.topic,
            inspectionId: widget.inspectionId,
            isExpanded: isExpanded,
            topicIndex: widget.topicIndex,
            itemIndex: widget.itemIndex,
            onExpansionChanged: () {
              setState(() {
                _expandedDetailIndex = isExpanded ? -1 : index;
              });
              
              // Notifica qual detalhe foi expandido
              final expandedDetail = _expandedDetailIndex >= 0 ? _localDetails[_expandedDetailIndex] : null;
              widget.onDetailExpanded?.call(expandedDetail?.id);
            },
            onDetailUpdated: (updatedDetail) {
              setState(() {
                _localDetails[index] = updatedDetail;
              });
              widget.onDetailUpdated(updatedDetail);
            },
            onDetailDeleted: () => _deleteDetail(detail, index),
            onDetailDuplicated: () => _duplicateDetail(detail),
          );
        },
        onReorder: _reorderDetail,
      ),
    );
  }

  Future<void> _deleteDetail(Detail detail, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Detalhe'),
        content: Text(
            'Tem certeza que deseja excluir "${detail.detailName}"?\n\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EnhancedOfflineServiceFactory.instance.dataService.deleteDetail(
        detail.id ?? '',
      );

      setState(() {
        _localDetails.removeAt(index);
        if (_expandedDetailIndex == index) {
          _expandedDetailIndex = -1;
        } else if (_expandedDetailIndex > index) {
          _expandedDetailIndex--;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detalhe excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir detalhe: $e')),
        );
      }
    }
    widget.onDetailAction();
  }

  Future<void> _duplicateDetail(Detail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicar Detalhe'),
        content: Text('Deseja duplicar o detalhe "${detail.detailName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      debugPrint(
          'DetailsListSection: Duplicating detail ${detail.id} with name ${detail.detailName}');

      // Use the new enhanced service method for duplication
      await EnhancedOfflineServiceFactory.instance.dataService
          .duplicateDetailWithChildren(detail.id!);

      // Reload the details to show the duplicated item
      widget.onDetailAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detalhe duplicado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('DetailsListSection: Error duplicating detail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar detalhe: $e')),
        );
      }
    }
    widget.onDetailAction();
  }
}

// AQUI ESTÁ A MUDANÇA PRINCIPAL
class DetailListItem extends StatefulWidget {
  final int index;
  final Detail detail;
  final Item item;
  final Topic topic;
  final String inspectionId;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
  final Function(Detail) onDetailUpdated;
  final VoidCallback onDetailDeleted;
  final VoidCallback onDetailDuplicated;
  final int topicIndex; // Índice do tópico atual
  final int itemIndex;  // Índice do item atual

  const DetailListItem({
    super.key,
    required this.index,
    required this.detail,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.onDetailDuplicated,
    required this.topicIndex,
    required this.itemIndex,
  });

  @override
  State<DetailListItem> createState() => _DetailListItemState();
}

class _DetailListItemState extends State<DetailListItem> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();

  Timer? _debounce;
  bool _isDamaged = false;
  String _booleanValue = 'não_se_aplica'; // 'sim', 'não', 'não_se_aplica'
  String _currentDetailName = '';
  final Map<String, int> _mediaCountCache = {};
  int _mediaCountVersion = 0; // Força rebuild do FutureBuilder

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _observationController.addListener(_updateDetail);
  }

  @override
  void didUpdateWidget(DetailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detail.detailName != _currentDetailName ||
        widget.detail.detailValue != _valueController.text ||
        widget.detail.observation != _observationController.text) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    final detailValue = widget.detail.detailValue ?? '';

    if (widget.detail.type == 'measure') {
      final measurements = detailValue.split(',');
      _heightController.text =
          measurements.isNotEmpty ? measurements[0].trim() : '';
      _widthController.text =
          measurements.length > 1 ? measurements[1].trim() : '';
      _depthController.text =
          measurements.length > 2 ? measurements[2].trim() : '';
    } else if (widget.detail.type == 'boolean') {
      // Suporte para três estados: sim, não, não_se_aplica
      if (detailValue.toLowerCase() == 'true' || detailValue == '1' || detailValue.toLowerCase() == 'sim') {
        _booleanValue = 'sim';
      } else if (detailValue.toLowerCase() == 'false' || detailValue == '0' || detailValue.toLowerCase() == 'não') {
        _booleanValue = 'não';
      } else {
        _booleanValue = 'não_se_aplica';
      }
    } else {
      _valueController.text = detailValue;
    }

    _observationController.text = widget.detail.observation ?? '';
    _isDamaged = widget.detail.isDamaged ?? false;
    _currentDetailName = widget.detail.detailName;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationController.dispose();
    _heightController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateDetail() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    String value = '';

    if (widget.detail.type == 'measure') {
      value =
          '${_heightController.text.trim()},${_widthController.text.trim()},${_depthController.text.trim()}';
      if (value == ',,') value = '';
    } else if (widget.detail.type == 'boolean') {
      value = _booleanValue; // Agora é string: 'sim', 'não', 'não_se_aplica'
    } else {
      value = _valueController.text;
    }

    // Update UI immediately
    final updatedDetail = Detail(
      id: widget.detail.id,
      inspectionId: widget.detail.inspectionId,
      topicId: widget.detail.topicId,
      itemId: widget.detail.itemId,
      detailId: widget.detail.detailId,
      position: widget.detail.position,
      detailName: widget.detail.detailName,
      detailValue: value.isEmpty ? null : value,
      observation: _observationController.text.isEmpty
          ? null
          : _observationController.text,
      isDamaged: _isDamaged,
      tags: widget.detail.tags,
      createdAt: widget.detail.createdAt,
      updatedAt: DateTime.now(),
      type: widget.detail.type,
      options: widget.detail.options,
      status: widget.detail.status,
      isRequired: widget.detail.isRequired,
    );
    widget.onDetailUpdated(updatedDetail);

    // Debounce the actual save operation
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      debugPrint(
          'DetailsListSection: Saving detail ${updatedDetail.id} with observation: ${updatedDetail.observation}');
      await _serviceFactory.dataService.updateDetail(updatedDetail);
      debugPrint(
          'DetailsListSection: Detail ${updatedDetail.id} saved successfully');
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Detalhe',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextFormField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Digite suas observações...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _observationController.text = result;
      });
      _updateDetail();
    }
  }

  Future<void> _renameDetail() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Detalhe',
        label: 'Nome do Detalhe',
        initialValue: widget.detail.detailName,
      ),
    );

    if (newName != null && newName != widget.detail.detailName) {
      final updatedDetail = Detail(
        id: widget.detail.id,
        inspectionId: widget.detail.inspectionId,
        topicId: widget.detail.topicId,
        itemId: widget.detail.itemId,
        detailId: widget.detail.detailId,
        position: widget.detail.position,
        detailName: newName,
        detailValue: widget.detail.detailValue,
        observation: widget.detail.observation,
        isDamaged: widget.detail.isDamaged,
        tags: widget.detail.tags,
        createdAt: widget.detail.createdAt,
        updatedAt: DateTime.now(),
        type: widget.detail.type,
        options: widget.detail.options,
      );

      setState(() {
        _currentDetailName = newName;
      });

      widget.onDetailUpdated(updatedDetail);
      _serviceFactory.dataService.updateDetail(updatedDetail);
    }
  }

  Future<void> _addDetailNonConformity() async {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NonConformityScreen(
            inspectionId: widget.inspectionId,
            preSelectedTopic: widget.detail.topicId,
            preSelectedItem: widget.detail.itemId,
            preSelectedDetail: widget.detail.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao navegar para não conformidade: $e')),
        );
      }
    }
  }

  Future<void> _captureDetailMedia() async {
    try {
      await showDialog(
        context: context,
        builder: (context) => MediaCaptureDialog(
          onMediaCaptured: (filePath, type) async {
            try {
              // Processar e salvar mídia
              await _serviceFactory.mediaService.captureAndProcessMediaSimple(
                inputPath: filePath,
                inspectionId: widget.inspectionId,
                type: type,
                topicId: widget.detail.topicId,
                itemId: widget.detail.itemId,
                detailId: widget.detail.id,
              );

              // Limpar cache para atualizar contador imediatamente
              final cacheKey = '${widget.detail.id}';
              _mediaCountCache.remove(cacheKey);
              
              // Forçar rebuild do widget para mostrar nova contagem
              if (mounted) {
                setState(() {
                  _mediaCountVersion++; // Força rebuild do FutureBuilder
                });
              }

              if (mounted && context.mounted) {
                final message = type == 'image' ? 'Foto salva!' : 'Vídeo salvo!';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );

                // NOVA REGRA: Ir direto para galeria após capturar mídia
                if (widget.detail.id != null) {
                  debugPrint('DetailListItem: Navigating to gallery for detail ${widget.detail.id}');
                  debugPrint('DetailListItem: TopicId=${widget.detail.topicId}, ItemId=${widget.detail.itemId}');
                  
                  // Salva o estado para que este detalhe específico fique expandido quando voltar
                  await NavigationStateService.saveExpandedDetailState(
                    inspectionId: widget.inspectionId,
                    detailId: widget.detail.id!,
                    topicIndex: widget.topicIndex,
                    itemIndex: widget.itemIndex,
                  );
                  
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MediaGalleryScreen(
                          inspectionId: widget.inspectionId,
                          initialTopicId: widget.detail.topicId,
                          initialItemId: widget.detail.itemId,
                          initialDetailId: widget.detail.id,
                          // Força filtro específico do detalhe
                          initialIsNonConformityOnly: false,
                        ),
                      ),
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint('Error processing media: $e');
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao processar mídia: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Error showing capture dialog: $e');
    }
  }

  Future<int> _getDetailMediaCount() async {
    final cacheKey = '${widget.detail.id}';
    if (_mediaCountCache.containsKey(cacheKey)) {
      return _mediaCountCache[cacheKey]!;
    }

    try {
      final medias = await _serviceFactory.mediaService.getMediaByContext(
        inspectionId: widget.inspectionId,
        topicId: widget.detail.topicId,
        itemId: widget.detail.itemId,
        detailId: widget.detail.id,
      );
      final count = medias.length;
      _mediaCountCache[cacheKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting media count for detail ${widget.detail.id}: $e');
      return 0;
    }
  }

  void _openDetailGallery() {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: widget.detail.topicId,
            initialItemId: widget.detail.itemId,
            initialDetailId: widget.detail.id,
            initialIsNonConformityOnly: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir galeria: $e')),
        );
      }
    }
  }

  Widget _buildDetailActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    int? count,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Icon(icon, size: 20),
              ),
              if (count != null && count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6F4B99),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }


  // Métodos _buildValueInput e _getDisplayValue permanecem os mesmos
  // ...

  @override
  Widget build(BuildContext context) {
    final displayValue = _getDisplayValue();

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: _isDamaged ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isDamaged
              ? Colors.red
              : Colors.green.withAlpha((255 * 0.3).round()),
          width: _isDamaged ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isDamaged
                    ? Colors.red.withAlpha((255 * 0.1).round())
                    : null,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_isDamaged)
                        const Icon(Icons.warning, color: Colors.red, size: 18),
                      if (_isDamaged) const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _currentDetailName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isDamaged
                                      ? Colors.red
                                      : Colors.green.shade300,
                                ),
                              ),
                            ),
                            if (_observationController.text.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.note_alt,
                                color: Colors.amber,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(Icons.drag_handle,
                              size: 20, color: Colors.grey.shade400),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 14),
                        onPressed: _renameDetail,
                        tooltip: 'Renomear',
                        style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            padding: const EdgeInsets.all(3)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: widget.onDetailDuplicated,
                        tooltip: 'Duplicar',
                        style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            padding: const EdgeInsets.all(3)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 14, color: Colors.red),
                        onPressed: widget.onDetailDeleted,
                        tooltip: 'Excluir',
                        style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            padding: const EdgeInsets.all(3)),
                      ),
                      Icon(
                          widget.isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.green.shade300,
                          size: 20),
                    ],
                  ),
                  if (displayValue.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              displayValue,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildValueInput(),
                  const SizedBox(height: 2),
                                    // Botões de ação para detalhes
                  if (widget.detail.id != null &&
                      widget.detail.topicId != null &&
                      widget.detail.itemId != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botão Câmera
                        _buildDetailActionButton(
                          icon: Icons.camera_alt,
                          label: 'Câmera',
                          color: Colors.purple,
                          onPressed: () => _captureDetailMedia(),
                        ),
                        // Botão Galeria com contador de mídia
                        FutureBuilder<int>(
                          key: ValueKey('detail_media_${widget.detail.id}_$_mediaCountVersion'),
                          future: _getDetailMediaCount(),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return _buildDetailActionButton(
                              icon: Icons.photo_library,
                              label: 'Galeria',
                              color: Colors.purple,
                              onPressed: () => _openDetailGallery(),
                              count: count,
                            );
                          },
                        ),
                        // Botão Não Conformidade
                        _buildDetailActionButton(
                          icon: Icons.warning_amber_rounded,
                          label: 'NC',
                          color: Colors.orange,
                          onPressed: () => _addDetailNonConformity(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: _editObservationDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.green.withAlpha((255 * 0.3).round())),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_alt,
                                  size: 14, color: Colors.green.shade300),
                              const SizedBox(width: 8),
                              Text('Observações',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade300,
                                      fontSize: 12)),
                              const Spacer(),
                              Icon(Icons.edit,
                                  size: 16, color: Colors.green.shade300),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _observationController.text.isEmpty
                                ? 'Toque para adicionar observações...'
                                : _observationController.text,
                            style: TextStyle(
                              color: _observationController.text.isEmpty
                                  ? Colors.green.shade200
                                  : Colors.white,
                              fontStyle: _observationController.text.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDisplayValue() {
    switch (widget.detail.type) {
      case 'boolean':
        switch (_booleanValue) {
          case 'sim': return 'Sim';
          case 'não': return 'Não';
          case 'não_se_aplica': return 'Não se aplica';
          default: return 'Não se aplica';
        }
      case 'measure':
        final altura = _heightController.text.trim();
        final largura = _widthController.text.trim();
        final profundidade = _depthController.text.trim();

        final parts = <String>[];
        if (altura.isNotEmpty) parts.add('A:$altura');
        if (largura.isNotEmpty) parts.add('L:$largura');
        if (profundidade.isNotEmpty) parts.add('P:$profundidade');

        return parts.join(' ');
      default:
        return _valueController.text;
    }
  }

  Widget _buildValueInput() {
    switch (widget.detail.type) {
      case 'select':
        if (widget.detail.options != null &&
            widget.detail.options!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            value:
                _valueController.text.isNotEmpty ? _valueController.text : null,
            decoration: InputDecoration(
              labelText: 'R',
              border: const OutlineInputBorder(),
              hintText: 'Selecione um valor',
              labelStyle: TextStyle(color: Colors.green.shade300),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green.shade300),
              ),
              isDense: true,
            ),
            dropdownColor: const Color(0xFF4A3B6B),
            style: const TextStyle(color: Colors.white),
            items: widget.detail.options!.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _valueController.text = value);
                _updateDetail();
              }
            },
          );
        }
        break;
      case 'boolean':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ 
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _booleanValue = 'sim');
                      _updateDetail();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'sim' ? Colors.green : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'sim' ? Colors.green : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Sim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'sim' ? Colors.white : Colors.grey.shade300,
                          fontSize: 12,
                          fontWeight: _booleanValue == 'sim' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _booleanValue = 'não');
                      _updateDetail();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'não' ? Colors.red : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'não' ? Colors.red : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Não',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'não' ? Colors.white : Colors.grey.shade300,
                          fontSize: 12,
                          fontWeight: _booleanValue == 'não' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _booleanValue = 'não_se_aplica');
                      _updateDetail();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'não_se_aplica' ? Colors.yellowAccent : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'não_se_aplica' ? Colors.yellowAccent : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'N/A',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'não_se_aplica' ? Colors.grey.shade500 : Colors.grey.shade300,
                          fontSize: 12,
                          fontWeight: _booleanValue == 'não_se_aplica' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'measure':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  hintText: 'Altura',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _updateDetail(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextFormField(
                controller: _widthController,
                decoration: const InputDecoration(
                  hintText: 'Largura',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _updateDetail(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextFormField(
                controller: _depthController,
                decoration: const InputDecoration(
                  hintText: 'Profundidade',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _updateDetail(),
              ),
            ),
          ],
        );

      case 'text':
      default:
        return TextFormField(
          controller: _valueController,
          decoration: InputDecoration(
            labelText: 'R',
            border: const OutlineInputBorder(),
            hintText: 'Digite um valor',
            labelStyle: TextStyle(color: Colors.green.shade300),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green.shade300),
            ),
            isDense: true,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => _updateDetail(),
        );
    }

    return TextFormField(
      controller: _valueController,
      decoration: InputDecoration(
        labelText: 'R',
        border: const OutlineInputBorder(),
        hintText: 'Digite um valor',
        labelStyle: TextStyle(color: Colors.green.shade300),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade300),
        ),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => _updateDetail(),
    );
  }

}

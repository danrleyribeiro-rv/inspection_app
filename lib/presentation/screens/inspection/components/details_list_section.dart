// lib/presentation/widgets/details_list_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/camera/inspection_camera_screen.dart';
import 'package:lince_inspecoes/services/media_counter_notifier.dart';

// O widget DetailsListSection e seu State permanecem os mesmos.
// A mudança principal está dentro do DetailListItem.
// ... (código do DetailsListSection inalterado)

class DetailsListSection extends StatefulWidget {
  final List<Detail> details;
  final Item? item; // Tornado opcional para hierarquias flexíveis
  final Topic topic;
  final String inspectionId;
  final Function(Detail) onDetailUpdated;
  final Future<void> Function() onDetailAction;
  final String? expandedDetailId; // ID do detalhe que deve estar expandido
  final Function(String?)?
      onDetailExpanded; // Callback quando um detalhe é expandido
  final int? topicIndex; // Tornado opcional
  final int? itemIndex; // Tornado opcional
  final bool isDirectDetails; // Nova propriedade para indicar hierarquia direta
  final Function(List<Detail>)? onDetailsUpdated; // Nova propriedade para callback de atualização

  const DetailsListSection({
    super.key,
    required this.details,
    this.item, // Agora opcional
    required this.topic,
    required this.inspectionId,
    required this.onDetailUpdated,
    required this.onDetailAction,
    this.expandedDetailId,
    this.onDetailExpanded,
    this.topicIndex,
    this.itemIndex,
    this.isDirectDetails = false, // Default para hierarquia normal
    this.onDetailsUpdated,
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
    debugPrint('DetailsListSection: initState - Created with ${widget.details.length} details for topic ${widget.topic.id} (hashCode: $hashCode)');
  }

  void _setInitialExpandedDetail() {
    if (widget.expandedDetailId != null) {
      final index = _localDetails
          .indexWhere((detail) => detail.id == widget.expandedDetailId);
      if (index >= 0) {
        _expandedDetailIndex = index;
        // Scroll to ensure the expanded detail is visible after a short delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToExpandedDetail(index);
        });
      }
    }
  }

  void _scrollToExpandedDetail(int index) {
    // Find the context of the expanded detail
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // Calculate the position of the expanded detail
      final double itemHeight = 60.0; // Approximate collapsed item height
      final double expandedHeight = 400.0; // Approximate expanded item height
      final double position = index * itemHeight;
      
      // Find the scrollable ancestor
      final ScrollableState scrollableState = Scrollable.of(context);
      final ScrollController? controller = scrollableState.widget.controller;
      if (controller != null && controller.hasClients && controller.positions.length == 1) {
        // Get current scroll position
        final double currentOffset = controller.offset;
        final double viewportHeight = scrollableState.context.size?.height ?? 600;
        
        // Calculate if we need to scroll
        final double itemBottom = position + expandedHeight;
        final double viewportBottom = currentOffset + viewportHeight;
        
        if (itemBottom > viewportBottom) {
          // Need to scroll down to show the full expanded content
          final double targetOffset = itemBottom - viewportHeight + 50; // 50px padding
          controller.animateTo(
            targetOffset.clamp(0, controller.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(DetailsListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.details != oldWidget.details) {
      _localDetails = List.from(widget.details);
      _setInitialExpandedDetail(); // Reaplica a expansão se os detalhes mudaram
      debugPrint('DetailsListSection: didUpdateWidget - Updated with ${widget.details.length} details for topic ${widget.topic.id} (hashCode: $hashCode)');
    }
  }

  @override
  void dispose() {
    debugPrint('DetailsListSection: dispose() called for topic ${widget.topic.id} (hashCode: $hashCode)');
    super.dispose();
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
      final itemId = widget.item?.id;
      if (itemId != null) {
        final detailIds = _localDetails.map((detail) => detail.id!).toList();

        debugPrint(
            'DetailsListSection: Reordering details with IDs: $detailIds');
        await EnhancedOfflineServiceFactory.instance.dataService
            .reorderDetails(itemId, detailIds);
        debugPrint(
            'DetailsListSection: Details reordered successfully in database');
      } else if (widget.isDirectDetails && widget.topic.id != null) {
        // For direct details, use topic-based reordering
        final detailIds = _localDetails.map((detail) => detail.id!).toList();
        debugPrint(
            'DetailsListSection: Reordering direct details with IDs: $detailIds');
        await EnhancedOfflineServiceFactory.instance.dataService
            .reorderDirectDetails(widget.topic.id!, detailIds);
        debugPrint(
            'DetailsListSection: Direct details reordered successfully in database');
      }

      debugPrint(
          'DetailsListSection: Successfully reordered ${_localDetails.length} details');

      // Notify parent to refresh - delayed to ensure database is updated
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          await widget.onDetailAction();
        }
      });
    } catch (e) {
      debugPrint('DetailsListSection: Error reordering details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reordenar detalhe: $e'),
            duration: const Duration(seconds: 2),
          ),
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
    debugPrint('DetailsListSection: build() called with ${_localDetails.length} details for topic ${widget.topic.id}');
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
              final expandedDetail = _expandedDetailIndex >= 0
                  ? _localDetails[_expandedDetailIndex]
                  : null;
              widget.onDetailExpanded?.call(expandedDetail?.id);

              // Se expandido, fazer scroll para garantir que está visível
              if (!isExpanded && _expandedDetailIndex == index) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToExpandedDetail(index);
                });
              }
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
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir detalhe: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    await widget.onDetailAction();
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
      await widget.onDetailAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detalhe duplicado com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('DetailsListSection: Error duplicating detail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao duplicar detalhe: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    await widget.onDetailAction();
  }
}

// AQUI ESTÁ A MUDANÇA PRINCIPAL
class DetailListItem extends StatefulWidget {
  final int index;
  final Detail detail;
  final Item? item; // Made nullable for direct details
  final Topic topic;
  final String inspectionId;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
  final Function(Detail) onDetailUpdated;
  final VoidCallback onDetailDeleted;
  final VoidCallback onDetailDuplicated;
  final int? topicIndex; // Made nullable for direct details
  final int? itemIndex; // Made nullable for direct details

  const DetailListItem({
    super.key,
    required this.index,
    required this.detail,
    this.item, // Now optional
    required this.topic,
    required this.inspectionId,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onDetailUpdated,
    required this.onDetailDeleted,
    required this.onDetailDuplicated,
    this.topicIndex, // Now optional
    this.itemIndex, // Now optional
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
  String? _currentSelectValue; // Valor atual do dropdown select

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _observationController.addListener(_updateDetail);
    _currentSelectValue = widget.detail.detailValue?.isEmpty == true ? null : widget.detail.detailValue;

    // Escutar mudanças nos contadores de mídia
    MediaCounterNotifier.instance.addListener(_onCounterChanged);
  }

  void _onCounterChanged() {
    // Invalidar cache quando contadores mudam
    final cacheKey = '${widget.detail.id}';
    debugPrint('DetailListItem: Media counter changed for detail ${widget.detail.id}, clearing cache key: $cacheKey');
    _mediaCountCache.remove(cacheKey);

    if (mounted) {
      setState(() {
        _mediaCountVersion++; // Força rebuild do FutureBuilder
      });
      debugPrint('DetailListItem: State updated, media count version incremented to $_mediaCountVersion');
    }
  }

  @override
  void didUpdateWidget(DetailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // For select fields, avoid reinitializing if we have an active debounce timer
    // This prevents the UI from reverting during the save process
    if (widget.detail.type == 'select' && _debounce?.isActive == true) {
      // Only update if the detail name changed (different detail altogether)
      if (widget.detail.detailName != _currentDetailName) {
        _initializeControllers();
      }
      // Don't override _currentSelectValue during active debounce
      return;
    }
    
    // For boolean fields, avoid reinitializing if we have an active debounce timer
    // This prevents the UI from reverting during the save process
    if (widget.detail.type == 'boolean' && _debounce?.isActive == true) {
      // Only reinitialize if the detail name changed (different detail altogether)
      if (widget.detail.detailName != _currentDetailName) {
        _initializeControllers();
      }
      return;
    }
    
    // Standard logic for other field types or when no debounce is active
    if (widget.detail.type == 'measure') {
      // For measure fields, only reinitialize on name change to avoid typing interference
      if (widget.detail.detailName != _currentDetailName) {
        _initializeControllers();
      }
    } else if (widget.detail.type == 'select') {
      // For select fields, check if we need to update from external changes
      if (widget.detail.detailName != _currentDetailName) {
        _initializeControllers();
      } else if (widget.detail.detailValue != _currentSelectValue && 
                 oldWidget.detail.detailValue != widget.detail.detailValue) {
        // Only update if this is a real external change, not our own update
        setState(() {
          _currentSelectValue = widget.detail.detailValue?.isEmpty == true ? null : widget.detail.detailValue;
          _valueController.text = widget.detail.detailValue ?? '';
        });
      }
    } else if (widget.detail.type == 'boolean') {
      // For boolean fields, check if we need to update from external changes
      if (widget.detail.detailName != _currentDetailName) {
        _initializeControllers();
      } else if (widget.detail.detailValue != _booleanValue && 
                 oldWidget.detail.detailValue != widget.detail.detailValue) {
        // Only update if this is a real external change, not our own update
        setState(() {
          if (widget.detail.detailValue?.toLowerCase() == 'true' ||
              widget.detail.detailValue == '1' ||
              widget.detail.detailValue?.toLowerCase() == 'sim') {
            _booleanValue = 'sim';
          } else if (widget.detail.detailValue?.toLowerCase() == 'false' ||
              widget.detail.detailValue == '0' ||
              widget.detail.detailValue?.toLowerCase() == 'não') {
            _booleanValue = 'não';
          } else {
            _booleanValue = 'não_se_aplica';
          }
        });
      }
    } else {
      String currentValue = _valueController.text;
      
      if (widget.detail.detailName != _currentDetailName ||
          widget.detail.detailValue != currentValue ||
          widget.detail.observation != _observationController.text) {
        _initializeControllers();
      }
    }
  }

  bool _isValidSelectValue(String? value) {
    if (value == null) return true;
    
    final options = widget.detail.options ?? [];
    // Always consider the current select value as valid, even if not in options yet
    return options.contains(value) || value == 'Outro' || value == _currentSelectValue;
  }

  void _updateSelectValue(String? value) {
    if (_currentSelectValue == value) return;

    setState(() {
      _currentSelectValue = value;
      _valueController.text = value ?? '';
    });

    _updateDetail();
  }

  void _updateBooleanValue(String value) {
    if (_booleanValue == value) return;

    setState(() {
      _booleanValue = value;
    });

    _updateDetail();
  }

  void _initializeControllers() {
    final detailValue = widget.detail.detailValue ?? '';

    if (widget.detail.type == 'measure') {
      // Parse measurements - support both JSON format and CSV format
      String altura = '';
      String largura = '';
      String profundidade = '';

      if (detailValue.startsWith('{') && detailValue.endsWith('}')) {
        // New JSON format: {largura: 2, altura: 1, profundidade: 5}
        try {
          // Remove braces and split by comma
          final content = detailValue.substring(1, detailValue.length - 1);
          final pairs = content.split(',');

          for (final pair in pairs) {
            final keyValue = pair.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim();
              final value = keyValue[1].trim();

              switch (key) {
                case 'altura':
                  altura = value;
                  break;
                case 'largura':
                  largura = value;
                  break;
                case 'profundidade':
                  profundidade = value;
                  break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing JSON measurement format: $e');
        }
      } else {
        // Old CSV format: "2,1,5"
        final measurements = detailValue.split(',');
        altura = measurements.isNotEmpty ? measurements[0].trim() : '';
        largura = measurements.length > 1 ? measurements[1].trim() : '';
        profundidade = measurements.length > 2 ? measurements[2].trim() : '';
      }

      _heightController.text = altura;
      _widthController.text = largura;
      _depthController.text = profundidade;
    } else if (widget.detail.type == 'boolean') {
      // Suporte para três estados: sim, não, não_se_aplica
      if (detailValue.toLowerCase() == 'true' ||
          detailValue == '1' ||
          detailValue.toLowerCase() == 'sim') {
        _booleanValue = 'sim';
      } else if (detailValue.toLowerCase() == 'false' ||
          detailValue == '0' ||
          detailValue.toLowerCase() == 'não') {
        _booleanValue = 'não';
      } else {
        _booleanValue = 'não_se_aplica';
      }
    } else {
      _valueController.text = detailValue;
      // For select types, also initialize _currentSelectValue
      if (widget.detail.type == 'select') {
        // Always initialize with the current value, even if empty
        _currentSelectValue = detailValue.isEmpty ? null : detailValue;
      }
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
    MediaCounterNotifier.instance.removeListener(_onCounterChanged);
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
    } else if (widget.detail.type == 'select') {
      value = _currentSelectValue ?? '';
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
              maxLines: 3,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Digite suas observações...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
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
          SnackBar(
            content: Text('Erro ao navegar para não conformidade: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _captureDetailMedia() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InspectionCameraScreen(
            inspectionId: widget.inspectionId,
            topicId: widget.detail.topicId,
            itemId: widget.detail.itemId,
            detailId: widget.detail.id,
            source: 'camera',
            onMediaCaptured: (capturedFiles) async {
              try {
                debugPrint('DetailsListSection: ${capturedFiles.length} media files captured for detail ${widget.detail.id}');

                // O contador será atualizado automaticamente via MediaCounterNotifier

                if (mounted && context.mounted) {
                  // Mostrar mensagem de sucesso e navegar para galeria
                  final message = capturedFiles.length == 1
                      ? 'Mídia salva!'
                      : '${capturedFiles.length} mídias salvas!';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                    ),
                  );

                  // Navegar para a galeria após captura com delay para evitar conflitos de BufferQueue
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _openDetailGallery();
                    }
                  });
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
        ),
      );
    } catch (e) {
      debugPrint('Error showing camera screen: $e');
    }
  }

  Future<int> _getDetailMediaCount() async {
    final cacheKey = '${widget.detail.id}';
    if (_mediaCountCache.containsKey(cacheKey)) {
      final cachedCount = _mediaCountCache[cacheKey]!;
      debugPrint('DetailListItem: Using cached media count for detail ${widget.detail.id}: $cachedCount');
      return cachedCount;
    }

    try {
      debugPrint('DetailListItem: Fetching fresh media count for detail ${widget.detail.id}');
      final medias = await _serviceFactory.mediaService.getMediaByContext(
        inspectionId: widget.inspectionId,
        topicId: widget.detail.topicId,
        itemId: widget.detail.itemId,
        detailId: widget.detail.id,
      );
      final count = medias.length;
      _mediaCountCache[cacheKey] = count;
      debugPrint('DetailListItem: Fresh media count for detail ${widget.detail.id}: $count');
      return count;
    } catch (e) {
      debugPrint(
          'Error getting media count for detail ${widget.detail.id}: $e');
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
          SnackBar(
            content: Text('Erro ao abrir galeria: $e'),
            duration: const Duration(seconds: 2),
          ),
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
        // Text(
        //   label,
        //   style: const TextStyle(
        //     fontSize: 11,
        //     color: Colors.white70,
        //   ),
        // ),
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
                                  fontSize: 11,
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
                                  fontSize: 11,
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
                      widget.detail.topicId != null) ...[
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
                          key: ValueKey(
                              'detail_media_${widget.detail.id}_$_mediaCountVersion'),
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
                                      fontSize: 11)),
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
                              fontSize: 11,
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
          case 'sim':
            return 'Sim';
          case 'não':
            return 'Não';
          case 'não_se_aplica':
            return 'Não se aplica';
          default:
            return 'Não se aplica';
        }
      case 'measure':
        final altura = _heightController.text.trim();
        final largura = _widthController.text.trim();
        final profundidade = _depthController.text.trim();

        final parts = <String>[];
        if (altura.isNotEmpty) parts.add(altura);
        if (largura.isNotEmpty) parts.add(largura);
        if (profundidade.isNotEmpty) parts.add(profundidade);

        return parts.join(' x '); // Formato mais limpo: "2 x 1 x 5"
      case 'select':
        return _currentSelectValue ?? '';
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
            value: _isValidSelectValue(_currentSelectValue) ? _currentSelectValue : null,
            decoration: InputDecoration(
              labelText: 'Resposta',
              labelStyle: TextStyle(color: Colors.green.shade300, fontSize: 12),
              border: const OutlineInputBorder(),
              hintText: 'Selecione um valor',
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green.shade300),
              ),
              isDense: true,
            ),
            dropdownColor: const Color(0xFF4A3B6B),
            style: const TextStyle(color: Colors.white, fontSize: 11),
            menuMaxHeight: 200, // Limita altura do menu para mostrar ~4 items
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('(Sem resposta)', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
              ...() {
                final allOptions = List<String>.from(widget.detail.options!);
                // Ensure current value is in the options list
                if (_currentSelectValue != null && 
                    _currentSelectValue!.isNotEmpty && 
                    _currentSelectValue != 'Outro' &&
                    !allOptions.contains(_currentSelectValue!)) {
                  allOptions.add(_currentSelectValue!);
                }
                return allOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: TextStyle(fontSize: 11)),
                  );
                });
              }(),
              // Adicionar opção "Outro"
              const DropdownMenuItem<String>(
                value: 'Outro',
                child: Text('Outro', style: TextStyle(fontSize: 11)),
              ),
            ],
            onChanged: (value) {
              if (value == 'Outro') {
                _showCustomOptionDialog();
              } else {
                _updateSelectValue(value);
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
                    onTap: () => _updateBooleanValue('sim'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'sim'
                            ? Colors.green
                            : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'sim'
                              ? Colors.green
                              : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Sim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'sim'
                              ? Colors.white
                              : Colors.grey.shade300,
                          fontSize: 11,
                          fontWeight: _booleanValue == 'sim'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateBooleanValue('não'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'não'
                            ? Colors.red
                            : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'não'
                              ? Colors.red
                              : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Não',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'não'
                              ? Colors.white
                              : Colors.grey.shade300,
                          fontSize: 11,
                          fontWeight: _booleanValue == 'não'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateBooleanValue('não_se_aplica'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _booleanValue == 'não_se_aplica'
                            ? Colors.yellowAccent
                            : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _booleanValue == 'não_se_aplica'
                              ? Colors.yellowAccent
                              : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'N/A',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _booleanValue == 'não_se_aplica'
                              ? Colors.grey.shade500
                              : Colors.grey.shade300,
                          fontSize: 11,
                          fontWeight: _booleanValue == 'não_se_aplica'
                              ? FontWeight.bold
                              : FontWeight.normal,
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
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => _updateDetail(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextFormField(
                controller: _widthController,
                decoration: const InputDecoration(
                  hintText: 'Largura',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => _updateDetail(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextFormField(
                controller: _depthController,
                decoration: const InputDecoration(
                  hintText: 'Profundidade',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
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
            labelText: 'Resposta',
            border: const OutlineInputBorder(),
            hintText: 'Digite um valor',
            labelStyle: TextStyle(color: Colors.green.shade300, fontSize: 12),
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
        labelText: 'Resposta',
        labelStyle: TextStyle(color: Colors.green.shade300, fontSize: 12),
        border: const OutlineInputBorder(),
        hintText: 'Digite um valor',
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade300),
        ),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      onChanged: (_) => _updateDetail(),
    );
  }

  Future<void> _showCustomOptionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Opção Personalizada',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: TextFormField(
            controller: controller,
            maxLines: 1,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Digite uma opção personalizada...',
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
              border: OutlineInputBorder(),
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

    if (result != null && result.isNotEmpty) {
      // Adicionar a nova opção à lista de opções do detalhe
      final currentOptions = List<String>.from(widget.detail.options ?? []);
      if (!currentOptions.contains(result)) {
        currentOptions.add(result);
        
        // Primeiro atualizar o estado local para evitar erro no dropdown
        setState(() {
          _currentSelectValue = result;
          _valueController.text = result;
        });
        
        // Depois atualizar o detalhe com as novas opções
        final updatedDetail = Detail(
          id: widget.detail.id,
          inspectionId: widget.detail.inspectionId,
          topicId: widget.detail.topicId,
          itemId: widget.detail.itemId,
          detailId: widget.detail.detailId,
          position: widget.detail.position,
          orderIndex: widget.detail.orderIndex,
          detailName: widget.detail.detailName,
          detailValue: result, // Definir o valor customizado
          observation: widget.detail.observation,
          isDamaged: widget.detail.isDamaged,
          tags: widget.detail.tags,
          createdAt: widget.detail.createdAt,
          updatedAt: DateTime.now(),
          type: widget.detail.type,
          options: currentOptions, // Novas opções incluindo a personalizada
          status: widget.detail.status,
          isRequired: widget.detail.isRequired,
        );
        widget.onDetailUpdated(updatedDetail);
        
        // Salvar no banco de dados
        if (_debounce?.isActive ?? false) _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () async {
          debugPrint('DetailsListSection: Saving detail with custom option: $result');
          await _serviceFactory.dataService.updateDetail(updatedDetail);
          debugPrint('DetailsListSection: Detail saved successfully');
        });
      } else {
        // Opção já existe, apenas definir valor
        _updateSelectValue(result);
      }
    }
  }
}

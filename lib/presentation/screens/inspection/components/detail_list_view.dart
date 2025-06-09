// lib/presentation/screens/inspection/components/detail_list_view.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/services/utils/progress_calculation_service.dart';
import 'package:inspection_app/presentation/widgets/common/progress_circle.dart';
import 'package:inspection_app/presentation/widgets/media/media_capture_popup.dart';
import 'package:inspection_app/presentation/widgets/dialogs/template_selector_dialog.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DetailListView extends StatefulWidget {
  final Item item;
  final Function(Item) onItemUpdated;
  final Function(String) onItemDeleted;
  final Function(Item) onItemDuplicated;

  const DetailListView({
    super.key,
    required this.item,
    required this.onItemUpdated,
    required this.onItemDeleted,
    required this.onItemDuplicated,
  });

  @override
  State<DetailListView> createState() => _DetailListViewState();
}

class _DetailListViewState extends State<DetailListView> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final _uuid = Uuid();

  List<Detail> _details = [];
  bool _isLoading = false;
  bool _isAddingMedia = false;
  int _expandedDetailIndex = -1;
  double _itemProgress = 0.0;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _observationController.text = widget.item.observation ?? '';
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;

    try {
      if (widget.item.id == null || widget.item.topicId == null) {
        return;
      }

      final details = await _serviceFactory.coordinator.getDetails(
        widget.item.inspectionId,
        widget.item.topicId!,
        widget.item.id!,
      );
      if (!mounted) return;

      final inspection = await _serviceFactory.coordinator
          .getInspection(widget.item.inspectionId);
      if (!mounted) return;

      final topicIndex =
          int.tryParse(widget.item.topicId!.replaceFirst('topic_', '')) ?? 0;
      final itemIndex =
          int.tryParse(widget.item.id!.replaceFirst('item_', '')) ?? 0;
      final progress = ProgressCalculationService.calculateItemProgress(
        inspection?.toMap(),
        topicIndex,
        itemIndex,
      );

      if (mounted) {
        setState(() {
          _details = details;
          _itemProgress = progress;
        });
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
    }
  }

  void _updateItem() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedItem = widget.item.copyWith(
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        updatedAt: DateTime.now(),
      );
      widget.onItemUpdated(updatedItem);
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Item'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: TextFormField(
                controller: controller,
                maxLines: 6,
                autofocus: true,
                decoration:
                    const InputDecoration(
                      hintText: 'Digite suas observações...',
                      border: OutlineInputBorder(),
                    ),
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
      _observationController.text = result;
      _updateItem();
      setState(() {});
    }
  }

  Future<void> _addDetail() async {
    if (widget.item.id == null || widget.item.topicId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro: ID do Item ou do Tópico não encontrado')),
        );
      }
      return;
    }

    String topicName = "";
    try {
      final topics =
          await _serviceFactory.coordinator.getTopics(widget.item.inspectionId);
      if (!mounted) return;
      final topic = topics.firstWhere((t) => t.id == widget.item.topicId,
          orElse: () => throw Exception('Tópico não encontrado'));
      topicName = topic.topicName;
    } catch (e) {
      debugPrint('Erro ao buscar nome do tópico: $e');
    }

    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Detalhe',
        type: 'detail',
        parentName: topicName,
        itemName: widget.item.itemName,
      ),
    );

    if (template == null || !mounted) return;

    try {
      final detailName = template['name'] as String;
      final isCustom = template['isCustom'] as bool? ?? false;

      String? detailType = 'text';
      List<String>? options;
      if (!isCustom) {
        detailType = template['type'] as String?;
        if (template['options'] is List) {
          options = List<String>.from(template['options']);
        }
      }

      final newDetail = await _serviceFactory.coordinator.addDetail(
        widget.item.inspectionId,
        widget.item.topicId!,
        widget.item.id!,
        detailName,
        type: detailType,
        options: options,
      );
      if (!mounted) return;

      await _loadDetails();
      if (!mounted) return;

      final newIndex = _details.indexWhere((d) => d.id == newDetail.id);
      if (newIndex >= 0) {
        setState(() {
          _expandedDetailIndex = newIndex;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detalhe "$detailName" adicionado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar detalhe: $e')),
      );
    }
  }

  Future<void> _duplicateDetail(Detail detail) async {
    if (widget.item.id == null ||
        widget.item.topicId == null ||
        detail.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Erro: Não é possível duplicar detalhe com IDs ausentes')),
        );
      }
      return;
    }

    try {
      final newDetail = await _serviceFactory.coordinator.isDetailDuplicate(
        widget.item.inspectionId,
        widget.item.topicId!,
        widget.item.id!,
        detail.detailName,
      );

      if (newDetail == null) {
        throw Exception('Failed to duplicate detail');
      }

      await _loadDetails();
      if (!mounted) return;

      final newIndex =
          _details.indexWhere((d) => d.detailName == detail.detailName);
      if (newIndex >= 0) {
        setState(() {
          _expandedDetailIndex = newIndex;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Detalhe "${detail.detailName}" duplicado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao duplicar detalhe: $e')),
      );
    }
  }

  void _showDetailDropdown() {
    if (_details.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle para arrastar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.details, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Selecionar Detalhe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _details.length,
                  itemBuilder: (context, index) {
                    final detail = _details[index];
                    final isSelected = index == _expandedDetailIndex;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.details,
                        color: isSelected ? Colors.orange : null,
                      ),
                      title: Text(
                        detail.detailName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.orange : null,
                        ),
                      ),
                      subtitle: detail.detailValue != null 
                          ? Text('Valor: ${detail.detailValue}') 
                          : null,
                      trailing: isSelected 
                          ? const Icon(Icons.check, color: Colors.orange)
                          : null,
                      onTap: () {
                        setState(() {
                          _expandedDetailIndex = _expandedDetailIndex == index ? -1 : index;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Cabeçalho do item (compacto)
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgressCircle(
                        progress: _itemProgress,
                        size: 24,
                        showPercentage: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.itemName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (widget.item.itemLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.item.itemLabel!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _editObservationDialog,
                    child: AbsorbPointer(
                      child: TextFormField(
                       controller: _observationController,
                       decoration: const InputDecoration(
                         labelText: 'Observações do Item',
                         border: OutlineInputBorder(),
                         hintText: 'Toque para adicionar observações...',
                         isDense: true,
                       ),
                       maxLines: 1,
                     ),
                   ),
                 ),
               ],
             ),
           ),
         ),

         const SizedBox(height: 8),

         // Cabeçalho dos detalhes com dropdown
         Card(
           elevation: 1,
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             child: Row(
               children: [
                 GestureDetector(
                   onTap: _details.isNotEmpty ? _showDetailDropdown : null,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Icon(Icons.details, size: 18),
                       const SizedBox(width: 8),
                       Text(
                         _details.isNotEmpty
                             ? 'Detalhes (${_details.length})'
                             : 'Nenhum detalhe',
                         style: const TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       if (_details.isNotEmpty) ...[
                         const SizedBox(width: 4),
                         const Icon(Icons.arrow_drop_down, size: 18),
                       ],
                     ],
                   ),
                 ),
                 const Spacer(),
                 IconButton(
                   icon: const Icon(Icons.add, size: 18),
                   onPressed: _addDetail,
                   tooltip: 'Adicionar Detalhe',
                   style: IconButton.styleFrom(
                     backgroundColor: Colors.orange,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.all(6),
                   ),
                 ),
               ],
             ),
           ),
         ),

         const SizedBox(height: 8),

         // Lista de detalhes
         Expanded(
           child: _isLoading
               ? const Center(child: CircularProgressIndicator())
               : _details.isEmpty
                   ? Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(
                             Icons.details,
                             size: 48,
                             color: Colors.grey[400],
                           ),
                           const SizedBox(height: 16),
                           const Text(
                             'Nenhum detalhe adicionado',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: Colors.white,
                             ),
                           ),
                           const SizedBox(height: 8),
                           const Text(
                             'Toque no botão + para adicionar detalhes',
                             style: TextStyle(
                               color: Colors.white70,
                             ),
                           ),
                           const SizedBox(height: 16),
                           ElevatedButton.icon(
                             onPressed: _addDetail,
                             icon: const Icon(Icons.add),
                             label: const Text('Adicionar Detalhe'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.orange,
                             ),
                           ),
                         ],
                       ),
                     )
                   : ListView.builder(
                       itemCount: _details.length,
                       itemBuilder: (context, index) {
                         return DetailWidget(
                           detail: _details[index],
                           onDetailUpdated: (updatedDetail) {
                             final idx = _details
                                 .indexWhere((d) => d.id == updatedDetail.id);
                             if (idx >= 0 && mounted) {
                               setState(() => _details[idx] = updatedDetail);
                               _serviceFactory.coordinator
                                   .updateDetail(updatedDetail);
                               _loadDetails();
                             }
                           },
                           onDetailDeleted: (detailId) async {
                             if (widget.item.id != null &&
                                 widget.item.topicId != null) {
                               await _serviceFactory.coordinator.deleteDetail(
                                 widget.item.inspectionId,
                                 widget.item.topicId!,
                                 widget.item.id!,
                                 detailId,
                               );
                               if (mounted) await _loadDetails();
                             }
                           },
                           onDetailDuplicated: _duplicateDetail,
                           isExpanded: index == _expandedDetailIndex,
                           onExpansionChanged: () {
                             setState(() {
                               _expandedDetailIndex =
                                   _expandedDetailIndex == index ? -1 : index;
                             });
                           },
                         );
                       },
                     ),
         ),
       ],
     ),
   );
 }
}
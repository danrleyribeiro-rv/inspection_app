// lib/presentation/screens/inspection/item_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/presentation/widgets/rename_dialog.dart';
import 'package:inspection_app/presentation/widgets/progress_circle.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/services/utils/progress_calculation_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/services/features/watermark_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:io';

class ItemWidget extends StatefulWidget {
  final Item item;
  final Function(Item) onItemUpdated;
  final Function(String) onItemDeleted;
  final Function(Item) onItemDuplicated;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const ItemWidget({
    super.key,
    required this.item,
    required this.onItemUpdated,
    required this.onItemDeleted,
    required this.onItemDuplicated,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  final _serviceFactory = ServiceFactory();
  final _watermarkService = WatermarkService();
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid();
  
  List<Detail> _details = [];
  bool _isLoading = true;
  bool _isAddingMedia = false;
  int _expandedDetailIndex = -1;
  double _itemProgress = 0.0;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _observationController.text = widget.item.observation ?? '';
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (widget.item.id == null || widget.item.topicId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final details = await _serviceFactory.coordinator.getDetails(
        widget.item.inspectionId,
        widget.item.topicId!,
        widget.item.id!,
      );

      if (!mounted) return;

      // Calcular progresso do item
      final inspection = await _serviceFactory.coordinator.getInspection(widget.item.inspectionId);
      final topicIndex = int.tryParse(widget.item.topicId!.replaceFirst('topic_', '')) ?? 0;
      final itemIndex = int.tryParse(widget.item.id!.replaceFirst('item_', '')) ?? 0;
      final progress = ProgressCalculationService.calculateItemProgress(
        inspection?.toMap(),
        topicIndex,
        itemIndex,
      );

      setState(() {
        _details = details;
        _itemProgress = progress;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading details: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _updateItem() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
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

  Future<void> _captureItemImage(ImageSource source) async {
    setState(() => _isAddingMedia = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        setState(() => _isAddingMedia = false);
        return;
      }

      final mediaDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now();
      final filename = 'item_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}.jpg';
      final localPath = '${mediaDir.path}/$filename';

      // Aplicar marca d'água
      final watermarkedFile = await _watermarkService.applyWatermark(
        pickedFile.path,
        localPath,
        isFromCamera: source == ImageSource.camera,
      );

      if (watermarkedFile == null) {
        await File(pickedFile.path).copy(localPath);
      }

      // Upload para Firebase Storage
      try {
        final storagePath = 'inspections/${widget.item.inspectionId}/topics/${widget.item.topicId}/items/${widget.item.id}/$filename';
        final uploadTask = await _storage.ref(storagePath).putFile(
          File(localPath),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagem do item salva com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erro no upload: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagem salva localmente (será sincronizada quando online)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingMedia = false);
      }
    }
  }

  Future<void> _renameItem() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Item',
        label: 'Nome do Item',
        initialValue: widget.item.itemName,
      ),
    );

    if (newName != null && newName != widget.item.itemName) {
      final updatedItem = widget.item.copyWith(
        itemName: newName,
        updatedAt: DateTime.now(),
      );
      widget.onItemUpdated(updatedItem);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.item.itemName}"?\n\nTodos os detalhes e mídias associados serão excluídos permanentemente.'),
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

    if (confirmed == true && widget.item.id != null) {
      widget.onItemDeleted(widget.item.id!);
    }
  }

  Future<void> _addDetail() async {
    if (widget.item.id == null || widget.item.topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: ID do Item ou do Tópico não encontrado')),
      );
      return;
    }

    String topicName = "";
    try {
      final topics =
          await _serviceFactory.coordinator.getTopics(widget.item.inspectionId);
      final topic = topics.firstWhere((t) => t.id == widget.item.topicId,
          orElse: () =>
              Topic(id: '', inspectionId: '', topicName: '', position: 0));
      topicName = topic.topicName;
    } catch (e) {
      print('Erro ao buscar nome do tópico: $e');
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

    setState(() => _isLoading = true);

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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _duplicateDetail(Detail detail) async {
    if (widget.item.id == null ||
        widget.item.topicId == null ||
        detail.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Erro: Não é possível duplicar detalhe com IDs ausentes')),
      );
      return;
    }

    setState(() => _isLoading = true);

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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
                children: [
                  // Círculo de progresso (à esquerda)
                  ProgressCircle(
                    progress: _itemProgress,
                    size: 28,
                    showPercentage: false,
                  ),
                  const SizedBox(width: 12),

                  // Seção central expandida para textos e botões
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Textos (acima)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.itemName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2, // Allow for slightly longer names
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.item.itemLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.item.itemLabel!,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 8), // Espaçador entre textos e botões

                        // Botões de ação (abaixo e centralizados)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center, // <<-- ADICIONADO PARA CENTRALIZAR OS BOTÕES
                          children: [
                            IconButton(
                              icon: _isAddingMedia
                                  ? const SizedBox(
                                      width: 20, // Consistente com o tamanho do ícone
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.camera_alt, size: 18),
                              onPressed: _isAddingMedia ? null : () => _captureItemImage(ImageSource.camera),
                              tooltip: 'Tirar foto do item',
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: _renameItem,
                              tooltip: 'Renomear Item',
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => widget.onItemDuplicated(widget.item),
                              tooltip: 'Duplicar Item',
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: _showDeleteConfirmation,
                              tooltip: 'Excluir Item',
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // Espaçador antes do ícone de expandir

                  // Ícone de expandir/recolher (à direita)
                  Icon(widget.isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      hintText: 'Adicione observações sobre este item...',
                    ),
                    maxLines: 1,
                    onChanged: (_) => _updateItem(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalhes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Detalhe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_details.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum detalhe adicionado ainda'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _scrollController,
                      itemCount: _details.length,
                      itemBuilder: (context, index) {
                        return DetailWidget(
                          detail: _details[index],
                          onDetailUpdated: (updatedDetail) {
                            final idx = _details
                                .indexWhere((d) => d.id == updatedDetail.id);
                            if (idx >= 0) {
                              setState(() => _details[idx] = updatedDetail);
                              _serviceFactory.coordinator.updateDetail(updatedDetail);
                              // Recarregar para atualizar progresso
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
                              await _loadDetails();
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// lib/presentation/screens/inspection/topic_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/presentation/screens/inspection/item_widget.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/services/utils/progress_calculation_service.dart';
import 'package:inspection_app/presentation/widgets/common/progress_circle.dart';
import 'dart:async';
import 'package:inspection_app/presentation/widgets/dialogs/template_selector_dialog.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class TopicWidget extends StatefulWidget {
  final Topic topic;
  final Function(Topic) onTopicUpdated;
  final Function(String) onTopicDeleted;
  final Function(Topic) onTopicDuplicated;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;

  const TopicWidget({
    super.key,
    required this.topic,
    required this.onTopicUpdated,
    required this.onTopicDeleted,
    required this.onTopicDuplicated,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<TopicWidget> createState() => _TopicWidgetState();
}

class _TopicWidgetState extends State<TopicWidget> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final _uuid = Uuid();

  List<Item> _items = [];
  bool _isLoading = true;
  bool _isAddingMedia = false;
  int _expandedItemIndex = -1;
  double _topicProgress = 0.0;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  ScrollController? _scrollController;

  late Topic _localTopic;

  @override
  void initState() {
    super.initState();
    _localTopic = widget.topic;
    _loadItems();
    _observationController.text = widget.topic.observation ?? '';
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (widget.topic.id == null) {
        setState(() => _isLoading = false);
        return;
      }

      final items = await _serviceFactory.coordinator.getItems(
        widget.topic.inspectionId,
        widget.topic.id!,
      );

      if (!mounted) return;

      final inspection = await _serviceFactory.coordinator
          .getInspection(widget.topic.inspectionId);
      final topicIndex =
          int.tryParse(widget.topic.id!.replaceFirst('topic_', '')) ?? 0;
      final progress = ProgressCalculationService.calculateTopicProgress(
        inspection?.toMap(),
        topicIndex,
      );

      setState(() {
        _items = items;
        _topicProgress = progress;
        _isLoading = false;
      });

      if (_scrollController?.hasClients ?? false) {
        _scrollController?.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar itens: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar itens: $e')),
      );
    }
  }

  void _updateTopic() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (!mounted) return;

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final updatedTopic = _localTopic.copyWith(
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        updatedAt: DateTime.now(),
      );
      setState(() {
        _localTopic = updatedTopic;
      });
      widget.onTopicUpdated(updatedTopic);
    });
  }

  Future<void> _captureTopicImage(ImageSource source) async {
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
      final filename =
          'topic_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}.jpg';
      final localPath = '${mediaDir.path}/$filename';

      // Processar imagem para 4:3 em background
      final processedFile = await _serviceFactory.mediaService.processImage43(
        pickedFile.path,
        localPath,
      );

      if (processedFile == null) {
        await File(pickedFile.path).copy(localPath);
      }

      // Obter localização
      final position = await _serviceFactory.mediaService.getCurrentLocation();

      // Criar dados da mídia
      final mediaData = {
        'id': _uuid.v4(),
        'type': 'image',
        'localPath': localPath,
        'aspect_ratio': '4:3',
        'source': source == ImageSource.camera ? 'camera' : 'gallery',
        'created_at': timestamp.toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
        'topic_id': widget.topic.id,
        'topic_name': widget.topic.topicName,
        'item_id': null,
        'item_name': null,
        'detail_id': null,
        'detail_name': null,
        'is_non_conformity': false,
        'metadata': {
          'location': position != null
              ? {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'accuracy': position.accuracy,
                }
              : null,
          'source': source == ImageSource.camera ? 'camera' : 'gallery',
        },
      };

      // Upload para Firebase Storage se online
      try {
        final downloadUrl = await _serviceFactory.mediaService.uploadMedia(
          file: File(localPath),
          inspectionId: widget.topic.inspectionId,
          type: 'image',
          topicId: widget.topic.id,
        );
        mediaData['url'] = downloadUrl;
      } catch (e) {
        debugPrint('Erro no upload: $e');
      }

      await _saveTopicMediaToInspection(mediaData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem do tópico salva com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _saveTopicMediaToInspection(
      Map<String, dynamic> mediaData) async {
    final inspection = await _serviceFactory.coordinator
        .getInspection(widget.topic.inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final topicIndex =
          int.tryParse(widget.topic.id!.replaceFirst('topic_', '')) ?? 0;

      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);

        if (!topic.containsKey('media')) {
          topic['media'] = <Map<String, dynamic>>[];
        }

        final topicMedia =
            List<Map<String, dynamic>>.from(topic['media'] ?? []);
        topicMedia.add(mediaData);
        topic['media'] = topicMedia;
        topics[topicIndex] = topic;

        final updatedInspection = inspection.copyWith(topics: topics);
        await _serviceFactory.coordinator.saveInspection(updatedInspection);
      }
    }
  }

  Future<void> _renameTopic() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Tópico',
        label: 'Nome do Tópico',
        initialValue: _localTopic.topicName,
      ),
    );

    if (newName != null && newName != _localTopic.topicName) {
      final updatedTopic = _localTopic.copyWith(
        topicName: newName,
        updatedAt: DateTime.now(),
      );
      setState(() {
        _localTopic = updatedTopic;
      });
      widget.onTopicUpdated(updatedTopic);
    }
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Editar Observação do Tópico'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: TextFormField(
                controller: controller,
                maxLines: 6,
                decoration:
                    const InputDecoration(hintText: 'Digite a observação...'),
                autofocus: true,
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
      _updateTopic();
      setState(() {});
    }
  }

  Future<void> _addItem() async {
    if (widget.topic.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID do tópico não encontrado')),
      );
      return;
    }

    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Item',
        type: 'item',
        parentName: widget.topic.topicName,
      ),
    );

    if (template == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final itemName = template['name'] as String;
      String? itemLabel = template['value'] as String?;

      final newItem = await _serviceFactory.coordinator.addItem(
        widget.topic.inspectionId,
        widget.topic.id!,
        itemName,
        label: itemLabel,
      );

      if (template['isCustom'] != true && template['observation'] != null) {
        final updatedItem = newItem.copyWith(
          itemLabel: itemLabel,
          observation: template['observation'] as String?,
        );
        await _serviceFactory.coordinator.updateItem(updatedItem);
      }

      await _loadItems();

      if (!mounted) return;
      setState(() {
        _expandedItemIndex = _items.indexWhere((i) => i.id == newItem.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar item: $e')),
      );
    }
  }

  void _duplicateTopic() {
    widget.onTopicDuplicated(widget.topic);
  }

  Future<void> _duplicateItem(Item item) async {
    if (widget.topic.id == null || item.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Erro: Não é possível duplicar item com IDs ausentes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _serviceFactory.coordinator.isItemDuplicate(
        widget.topic.inspectionId,
        widget.topic.id!,
        item.itemName,
      );

      await _loadItems();

      if (!mounted) return;
      setState(() {
        _expandedItemIndex =
            _items.indexWhere((i) => i.itemName == item.itemName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Item "${item.itemName}" duplicado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao duplicar item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleItemUpdate(Item updatedItem) {
    final index = _items.indexWhere((i) => i.id == updatedItem.id);
    if (index >= 0) {
      setState(() => _items[index] = updatedItem);
      _serviceFactory.coordinator.updateItem(updatedItem);
      _loadItems();
    }
  }

  Future<void> _handleItemDelete(dynamic itemId) async {
    try {
      if (widget.topic.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do tópico não encontrado')),
        );
        return;
      }

      await _serviceFactory.coordinator.deleteItem(
        widget.topic.inspectionId,
        widget.topic.id!,
        itemId,
      );

      await _loadItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removido com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover item: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Tópico'),
        content: Text(
            'Tem certeza de que deseja excluir "${widget.topic.topicName}"?\n\nTodos os itens, detalhes e mídias associados serão excluídos permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.topic.id != null) {
      widget.onTopicDeleted(widget.topic.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.grey.shade300, width: 0),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onExpansionChanged,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProgressCircle(
                        progress: _topicProgress,
                        size: 25,
                        showPercentage: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _localTopic.topicName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_localTopic.topicLabel != null &&
                                _localTopic.topicLabel!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _localTopic.topicLabel!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(widget.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: _isAddingMedia
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt, size: 18),
                        onPressed: _isAddingMedia
                            ? null
                            : () => _captureTopicImage(ImageSource.camera),
                        tooltip: 'Tirar foto do tópico',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _renameTopic,
                        tooltip: 'Renomear Tópico',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _duplicateTopic,
                        tooltip: 'Duplicar Tópico',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _showDeleteConfirmation,
                        tooltip: 'Excluir Tópico',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _editObservationDialog,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _observationController,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                          hintText: 'Adicione observações sobre este tópico...',
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Itens',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Nenhum item adicionado ainda'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _scrollController,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return ItemWidget(
                          item: _items[index],
                          onItemUpdated: _handleItemUpdate,
                          onItemDeleted: _handleItemDelete,
                          onItemDuplicated: _duplicateItem,
                          isExpanded: index == _expandedItemIndex,
                          onExpansionChanged: () {
                            setState(() {
                              _expandedItemIndex =
                                  _expandedItemIndex == index ? -1 : index;
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

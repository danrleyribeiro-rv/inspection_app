// lib/presentation/screens/inspection/components/item_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';

class ItemDetailsSection extends StatefulWidget {
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Item) onItemUpdated;
  final VoidCallback onItemAction;

  const ItemDetailsSection({
    super.key,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onItemUpdated,
    required this.onItemAction,
  });

  @override
  State<ItemDetailsSection> createState() => _ItemDetailsSectionState();
}

class _ItemDetailsSectionState extends State<ItemDetailsSection> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  String _currentItemName = '';
  int _processingCount = 0;

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.item.observation ?? '';
    _currentItemName = widget.item.itemName;
    _observationController.addListener(_updateItemObservation);
  }

  @override
  void didUpdateWidget(ItemDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.itemName != _currentItemName) {
      _currentItemName = widget.item.itemName;
    }
    if (widget.item.observation != _observationController.text) {
      _observationController.text = widget.item.observation ?? '';
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateItemObservation() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    // Update UI immediately
    final updatedItem = widget.item.copyWith(
      observation: _observationController.text.isEmpty
          ? null
          : _observationController.text,
      updatedAt: DateTime.now(),
    );
    widget.onItemUpdated(updatedItem);

    // Debounce the actual save operation
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      debugPrint(
          'ItemDetailsSection: Saving item ${updatedItem.id} with observation: ${updatedItem.observation}');
      await _serviceFactory.dataService.updateItem(updatedItem);
      debugPrint(
          'ItemDetailsSection: Item ${updatedItem.id} saved successfully');
    });
  }

  void _openItemGallery() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MediaGalleryScreen(
        inspectionId: widget.inspectionId,
        initialTopicId: widget.topic.id,
        initialItemId: widget.item.id,
        // THE FIX: Passagem explícita do filtro de nível.
        initialItemOnly: true,
      ),
    ));
  }

  void _captureItemMedia() {
    _showMediaSourceDialog();
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Adicionar Mídia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title:
                  const Text('Câmera', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Tirar foto com a câmera',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).pop();
                _captureFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title:
                  const Text('Galeria', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Escolher foto da galeria',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).pop();
                _selectFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image != null) {
        await _handleImagesSelected([image.path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 90,
      );

      if (images.isNotEmpty) {
        final imagePaths = images.map((image) => image.path).toList();
        await _handleImagesSelected(imagePaths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagens: $e')),
        );
      }
    }
  }

  Future<void> _handleImagesSelected(List<String> imagePaths) async {
    if (mounted) setState(() => _processingCount += imagePaths.length);
    for (final path in imagePaths) {
      _processAndSaveMedia(path, 'image').whenComplete(() {
        if (mounted) setState(() => _processingCount--);
      });
    }
    widget.onItemAction();
  }

  Future<void> _processAndSaveMedia(String localPath, String type) async {
    try {
      final position = await _serviceFactory.mediaService.getCurrentLocation();

      // Usar o fluxo offline-first do MediaService
      await _serviceFactory.mediaService.captureAndProcessMedia(
        inputPath: localPath,
        inspectionId: widget.inspectionId,
        type: type,
        topicId: widget.topic.id,
        itemId: widget.item.id,
        metadata: {
          'source': 'camera',
          'is_non_conformity': false,
          'location': position != null
              ? {
                  'latitude': position['latitude'],
                  'longitude': position['longitude'],
                }
              : null,
        },
      );

      // A mídia já foi salva pelo MediaService, não precisa fazer nada mais
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar mídia: $e')));
    }
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Item',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: TextFormField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Digite suas observações...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  border: OutlineInputBorder())),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Salvar')),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _observationController.text = result);
      _updateItemObservation();
    }
  }

  Future<void> _renameItem() async {
    final newName = await showDialog<String>(
        context: context,
        builder: (context) => RenameDialog(
            title: 'Renomear Item',
            label: 'Nome do Item',
            initialValue: widget.item.itemName));
    if (newName != null && newName != widget.item.itemName) {
      final updatedItem =
          widget.item.copyWith(itemName: newName, updatedAt: DateTime.now());
      setState(() => _currentItemName = newName);
      widget.onItemUpdated(updatedItem);
      await _serviceFactory.dataService.updateItem(updatedItem);
    }
  }

  Future<void> _duplicateItem() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Duplicar Item'),
                content: Text(
                    'Deseja duplicar o item "${widget.item.itemName}" com todos os seus detalhes?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Duplicar'))
                ]));

    if (confirmed != true) return;

    try {
      debugPrint(
          'ItemDetailsSection: Duplicating item ${widget.item.id} with name ${widget.item.itemName}');

      if (widget.item.id == null) {
        throw Exception('Item sem ID válido');
      }

      // Use the new recursive duplication method
      await _serviceFactory.dataService
          .duplicateItemWithChildren(widget.item.id!);

      // Only call onItemAction once to avoid double refresh
      widget.onItemAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Item duplicado com sucesso (incluindo detalhes)'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('ItemDetailsSection: Error duplicating item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao duplicar item: $e')));
      }
    }
  }

  Future<void> _addItemNonConformity() async {
    try {
      // Navigate to NonConformityScreen with preselected topic and item
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NonConformityScreen(
            inspectionId: widget.inspectionId,
            preSelectedTopic: widget.topic.id,
            preSelectedItem: widget.item.id,
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

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Excluir Item'),
                content: Text(
                    'Tem certeza que deseja excluir "${widget.item.itemName}"?\n\nTodos os detalhes serão excluídos permanentemente.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Excluir'))
                ]));
    if (confirmed != true) return;
    try {
      if (widget.item.id != null) {
        await _serviceFactory.dataService.deleteItem(widget.item.id!);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Item excluído com sucesso'),
              backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir item: $e')));
    }
    widget.onItemAction();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.orange.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withAlpha(50))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                  icon: Icons.camera_alt,
                  label: 'Capturar',
                  onPressed: _captureItemMedia,
                  color: Colors.purple),
              _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Galeria',
                  onPressed: _openItemGallery,
                  color: Colors.purple),
              _buildActionButton(
                  icon: Icons.warning,
                  label: 'NC',
                  onPressed: _addItemNonConformity,
                  color: Colors.orange),
              _buildActionButton(
                  icon: Icons.edit, label: 'Renomear', onPressed: _renameItem),
              _buildActionButton(
                  icon: Icons.copy,
                  label: 'Duplicar',
                  onPressed: _duplicateItem),
              _buildActionButton(
                  icon: Icons.delete,
                  label: 'Excluir',
                  onPressed: _deleteItem,
                  color: Colors.red),
            ],
          ),
          if (_processingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text("Processando $_processingCount mídia(s)...",
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ]),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withAlpha(75)),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.note_alt,
                        size: 16, color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    Text('Observações',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade300)),
                    const Spacer(),
                    Icon(Icons.edit, size: 16, color: Colors.orange.shade300),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    _observationController.text.isEmpty
                        ? 'Toque para adicionar observações...'
                        : _observationController.text,
                    style: TextStyle(
                        color: _observationController.text.isEmpty
                            ? Colors.orange.shade200
                            : Colors.white,
                        fontStyle: _observationController.text.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
                backgroundColor: color ?? Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

// lib/presentation/screens/inspection/components/item_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/camera/inspection_camera_screen.dart';
import 'package:lince_inspecoes/services/media_counter_notifier.dart';

class ItemDetailsSection extends StatefulWidget {
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Item) onItemUpdated;
  final Future<void> Function() onItemAction;

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
  bool _isDuplicating = false; // Flag to prevent double duplication
  final Map<String, int> _mediaCountCache = {};
  int _mediaCountVersion = 0; // Força rebuild do FutureBuilder
  String? _currentEvaluationValue; // Valor atual da avaliação do item

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.item.observation ?? '';
    _currentItemName = widget.item.itemName;
    _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true ? null : widget.item.evaluationValue;
    _observationController.addListener(_updateItemObservation);
    

    // Escutar mudanças nos contadores
    MediaCounterNotifier.instance.addListener(_onCounterChanged);
  }

  @override
  void didUpdateWidget(ItemDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Avoid reinitializing if we have an active debounce timer for evaluation
    // This prevents the UI from reverting during the save process
    if (_debounce?.isActive == true && 
        widget.item.evaluationValue != _currentEvaluationValue) {
      // Only update if the item name changed (different item altogether)
      if (widget.item.itemName != _currentItemName) {
        _currentItemName = widget.item.itemName;
        _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true ? null : widget.item.evaluationValue;
      }
      // Don't override _currentEvaluationValue during active debounce
      return;
    }
    
    if (widget.item.itemName != _currentItemName) {
      _currentItemName = widget.item.itemName;
    }
    if (widget.item.observation != _observationController.text) {
      _observationController.text = widget.item.observation ?? '';
    }
    
    // For evaluation field, check if we need to update from external changes
    if (widget.item.evaluationValue != _currentEvaluationValue && 
        oldWidget.item.evaluationValue != widget.item.evaluationValue) {
      // Only update if this is a real external change, not our own update
      setState(() {
        _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true ? null : widget.item.evaluationValue;
      });
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    MediaCounterNotifier.instance.removeListener(_onCounterChanged);
    super.dispose();
  }

  void _onCounterChanged() {
    // Invalidar cache quando contadores mudam
    final cacheKey = '${widget.item.id}_item_only';
    _mediaCountCache.remove(cacheKey);

    if (mounted) {
      setState(() {
        _mediaCountVersion++; // Força rebuild do FutureBuilder
      });
    }
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

  Future<int> _getMediaCount() async {
    final cacheKey = '${widget.item.id}_item_only';
    if (_mediaCountCache.containsKey(cacheKey)) {
      return _mediaCountCache[cacheKey]!;
    }

    try {
      // Get all media for this item
      final allItemMedias =
          await _serviceFactory.mediaService.getMediaByContext(
        inspectionId: widget.inspectionId,
        topicId: widget.topic.id,
        itemId: widget.item.id,
      );

      // Filter to show only item-level media (no detail specified)
      final itemOnlyMedias = allItemMedias.where((media) {
        return media.detailId == null;
      }).toList();

      final count = itemOnlyMedias.length;
      _mediaCountCache[cacheKey] = count;
      debugPrint(
          'ItemDetailsSection: Item ${widget.item.id} has $count item-only media (filtered from ${allItemMedias.length} total)');
      return count;
    } catch (e) {
      debugPrint('Error getting media count for item ${widget.item.id}: $e');
      return 0;
    }
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
    _captureFromCamera();
  }

  Future<void> _captureFromCamera() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InspectionCameraScreen(
            inspectionId: widget.inspectionId,
            topicId: widget.topic.id,
            itemId: widget.item.id,
            source: 'camera',
            onMediaCaptured: (capturedFiles) async {
              try {
                // Chamar atualização imediatamente
                await widget.onItemAction();

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

                  // Navegar para a galeria após captura
                  _openItemGallery();
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
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Digite suas observações...',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
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
    // Prevent double execution
    if (_isDuplicating) return;

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

    // Set duplication flag
    setState(() => _isDuplicating = true);

    try {
      debugPrint(
          'ItemDetailsSection: Duplicating item ${widget.item.id} with name ${widget.item.itemName}');

      if (widget.item.id == null) {
        throw Exception('Item sem ID válido');
      }

      // Use the new recursive duplication method
      await _serviceFactory.dataService
          .duplicateItemWithChildren(widget.item.id!);

      // Chamar atualização imediatamente para mostrar nova estrutura
      await widget.onItemAction();

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
    } finally {
      // Reset duplication flag
      if (mounted) {
        setState(() => _isDuplicating = false);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Item excluído com sucesso'),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir item: $e')));
      }
    }
    await widget.onItemAction();
  }

  bool _isValidEvaluationValue(String? value) {
    if (value == null) return true;
    
    final evaluationOptions = widget.item.evaluationOptions ?? [];
    // Always consider the current evaluation value as valid, even if not in options yet
    return evaluationOptions.contains(value) || value == 'Outro' || value == _currentEvaluationValue;
  }

  void _updateItemEvaluation(String? value) {
    if (_currentEvaluationValue == value) return;

    setState(() {
      _currentEvaluationValue = value;
    });

    // Update item immediately - create new item manually to force null value
    final processedValue = value?.isEmpty == true ? null : value;
    final updatedItem = Item(
      id: widget.item.id,
      inspectionId: widget.item.inspectionId,
      topicId: widget.item.topicId,
      itemId: widget.item.itemId,
      position: widget.item.position,
      orderIndex: widget.item.orderIndex,
      itemName: widget.item.itemName,
      itemLabel: widget.item.itemLabel,
      description: widget.item.description,
      evaluable: widget.item.evaluable,
      evaluationOptions: widget.item.evaluationOptions,
      evaluationValue: processedValue, // Force the value, even if null
      evaluation: widget.item.evaluation,
      observation: widget.item.observation,
      isDamaged: widget.item.isDamaged,
      tags: widget.item.tags,
      createdAt: widget.item.createdAt,
      updatedAt: DateTime.now(),
    );
    
    widget.onItemUpdated(updatedItem);

    // Debounced save
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await _serviceFactory.dataService.updateItem(updatedItem);
    });
  }

  Future<void> _showCustomEvaluationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Avaliação Personalizada',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: TextFormField(
            controller: controller,
            maxLines: 1,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Digite uma avaliação personalizada...',
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
      // Adicionar a nova opção à lista de opções (se não for vazia)
      final currentOptions = List<String>.from(widget.item.evaluationOptions ?? []);
      if (!currentOptions.contains(result)) {
        currentOptions.add(result);
        
        // Primeiro atualizar o estado local para evitar erro no dropdown
        setState(() {
          _currentEvaluationValue = result;
        });
        
        // Depois atualizar o item com as novas opções - create manually to force values
        final updatedItem = Item(
          id: widget.item.id,
          inspectionId: widget.item.inspectionId,
          topicId: widget.item.topicId,
          itemId: widget.item.itemId,
          position: widget.item.position,
          orderIndex: widget.item.orderIndex,
          itemName: widget.item.itemName,
          itemLabel: widget.item.itemLabel,
          description: widget.item.description,
          evaluable: widget.item.evaluable,
          evaluationOptions: currentOptions, // Force new options
          evaluationValue: result, // Force new evaluation value
          evaluation: widget.item.evaluation,
          observation: widget.item.observation,
          isDamaged: widget.item.isDamaged,
          tags: widget.item.tags,
          createdAt: widget.item.createdAt,
          updatedAt: DateTime.now(),
        );
        widget.onItemUpdated(updatedItem);
        
        // Salvar no banco de dados
        if (_debounce?.isActive ?? false) _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () async {
          await _serviceFactory.dataService.updateItem(updatedItem);
        });
      } else {
        // Opção já existe, apenas definir valor
        _updateItemEvaluation(result);
      }
    }
  }

  Widget _buildItemEvaluationSection() {
    final evaluationOptions = widget.item.evaluationOptions ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.withAlpha(75)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.withAlpha(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, size: 16, color: Colors.orange.shade300),
              const SizedBox(width: 8),
              Text(
                'Avaliação do Item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (evaluationOptions.isNotEmpty) ...[
            // Dropdown para opções de avaliação
            DropdownButtonFormField<String>(
              value: _isValidEvaluationValue(_currentEvaluationValue) ? _currentEvaluationValue : null,
              decoration: InputDecoration(
                hintText: 'Selecione uma avaliação',
                hintStyle: TextStyle(color: Colors.orange.shade200, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange.withAlpha(100)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange.withAlpha(100)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
                fillColor: Colors.orange.withAlpha(25),
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: const Color.fromARGB(255, 48, 48, 48).withAlpha(250),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              menuMaxHeight: 200, // Limita altura do menu para mostrar ~4 items
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('(Sem avaliação)', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                ),
                ...() {
                  final allOptions = List<String>.from(evaluationOptions);
                  // Ensure current value is in the options list
                  if (_currentEvaluationValue != null && 
                      _currentEvaluationValue!.isNotEmpty && 
                      _currentEvaluationValue != 'Outro' &&
                      !allOptions.contains(_currentEvaluationValue!)) {
                    allOptions.add(_currentEvaluationValue!);
                  }
                  return allOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  });
                }(),
                // Adicionar opção "Outro"
                const DropdownMenuItem<String>(
                  value: 'Outro',
                  child: Text('Outro', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
              onChanged: (value) {
                if (value == 'Outro') {
                  _showCustomEvaluationDialog();
                } else {
                  _updateItemEvaluation(value);
                }
              },
            ),
          ] else ...[
            // Campo de texto livre para avaliação
            TextFormField(
              initialValue: _currentEvaluationValue ?? '',
              decoration: InputDecoration(
                hintText: 'Digite a avaliação do item',
                hintStyle: TextStyle(color: Colors.orange.shade200, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange.withAlpha(100)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange.withAlpha(100)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
                fillColor: Colors.orange.withAlpha(25),
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              onChanged: _updateItemEvaluation,
            ),
          ],
        ],
      ),
    );
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
              FutureBuilder<int>(
                key: ValueKey(
                    'item_media_${widget.item.id}_$_mediaCountVersion'),
                future: _getMediaCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    onPressed: _openItemGallery,
                    color: Colors.purple,
                    count: count,
                  );
                },
              ),
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
          const SizedBox(height: 8),
          
          // AVALIAÇÃO DO ITEM (se for avaliável)
          if (widget.item.evaluable == true) ...[
            _buildItemEvaluationSection(),
            const SizedBox(height: 8),
          ],
          
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
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
                  backgroundColor: color ?? Colors.orange,
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
        const SizedBox(height: 2),
        // Text(label,
        //     style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

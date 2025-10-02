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
  final bool isExpanded;

  const ItemDetailsSection({
    super.key,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onItemUpdated,
    required this.onItemAction,
    required this.isExpanded,
  });

  @override
  State<ItemDetailsSection> createState() => _ItemDetailsSectionState();
}

class _ItemDetailsSectionState extends State<ItemDetailsSection> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  Timer? _evaluationDebounce;
  String _currentItemName = '';
  bool _isDuplicating = false;
  final Map<String, int> _mediaCountCache = {};
  final Map<String, int> _ncCountCache = {};
  int _mediaCountVersion = 0;
  int _ncCountVersion = 0;
  String? _currentEvaluationValue;
  String? _lastSavedObservation;

  // Named listener so we can add/remove it reliably
  void _onObservationControllerChanged() => _updateItemObservation();

  @override
  void initState() {
    super.initState();

    // Set initial values WITHOUT triggering listener
    _currentItemName = widget.item.itemName;
    _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true
        ? null
        : widget.item.evaluationValue;

    // Set observation text BEFORE adding listener to avoid accidental triggers
    _observationController.text = widget.item.observation ?? '';
    _lastSavedObservation = widget.item.observation;

    // Add named listener AFTER setting initial values
    _observationController.addListener(_onObservationControllerChanged);

    // Escutar mudanças nos contadores
    MediaCounterNotifier.instance.addListener(_onCounterChanged);
  }

  @override
  void didUpdateWidget(ItemDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_evaluationDebounce?.isActive == true &&
        widget.item.evaluationValue != _currentEvaluationValue) {
      if (widget.item.itemName != _currentItemName) {
        _currentItemName = widget.item.itemName;
        _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true
            ? null
            : widget.item.evaluationValue;
      }
      return;
    }

    if (widget.item.itemName != _currentItemName) {
      _currentItemName = widget.item.itemName;
    }
    // Only update observation controller if there's a real external change
    // Avoid overwriting when user just cleared the field or during debounce
    if (_debounce?.isActive != true) {
      final currentObservation = widget.item.observation ?? '';
      final controllerText = _observationController.text;
      if (currentObservation != controllerText &&
          !(currentObservation.isEmpty && controllerText.isEmpty)) {
        // Temporarily remove listener to avoid triggering updates
        _observationController.removeListener(_onObservationControllerChanged);
        _observationController.text = currentObservation;
        _observationController.addListener(_onObservationControllerChanged);
      }
    }

    // For evaluation field, check if we need to update from external changes
    if (widget.item.evaluationValue != _currentEvaluationValue &&
        oldWidget.item.evaluationValue != widget.item.evaluationValue) {
      // Only update if this is a real external change, not our own update
      setState(() {
        _currentEvaluationValue = widget.item.evaluationValue?.isEmpty == true
            ? null
            : widget.item.evaluationValue;
      });
    }
  }

  @override
  void dispose() {
    // Force save any pending changes before disposing
    _savePendingChanges();

    _observationController.dispose();
    _debounce?.cancel();
    _evaluationDebounce?.cancel();
    MediaCounterNotifier.instance.removeListener(_onCounterChanged);
    super.dispose();
  }

  void _savePendingChanges() {
    // If there's a pending debounced save, execute it immediately
    if (_debounce?.isActive == true) {
      _debounce?.cancel();
      // Save current state immediately
      // Build an explicit Item so that setting observation to null is reliable
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
        evaluationValue: widget.item.evaluationValue,
        evaluation: widget.item.evaluation,
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        createdAt: widget.item.createdAt,
        updatedAt: DateTime.now(),
      );
      // Synchronous save to ensure it completes before dispose
      _serviceFactory.dataService.updateItem(updatedItem).then((_) {
        debugPrint(
            'ItemDetailsSection: Forced save on dispose for item ${updatedItem.id} with observation: ${updatedItem.observation}');
      }).catchError((error) {
        debugPrint(
            'ItemDetailsSection: Error in forced save on dispose: $error');
      });
    }
  }

  void _onCounterChanged() {
    // Invalidar cache quando contadores mudam
    final mediaCacheKey = '${widget.item.id}_item_only';
    final ncCacheKey = '${widget.item.id}_nc_count';
    _mediaCountCache.remove(mediaCacheKey);
    _ncCountCache.remove(ncCacheKey);

    if (mounted) {
      setState(() {
        _mediaCountVersion++; // Força rebuild do FutureBuilder
        _ncCountVersion++;
      });
    }
  }

  Future<void> _updateItemObservation({String? customObservation}) async {
    final observationText = customObservation ?? _observationController.text;
    debugPrint(
        'ItemDetailsSection: _updateItemObservation called with text: "$observationText"');
    debugPrint(
        'ItemDetailsSection: Original widget.item.observation: "${widget.item.observation}"');

    final newObservation = observationText.isEmpty ? null : observationText;

    // Avoid duplicate saves if we already persisted this exact value
    if (newObservation == _lastSavedObservation) {
      debugPrint('ItemDetailsSection: Observation unchanged (skipping save)');
      return;
    }

    // Update last saved cache immediately to prevent races
    _lastSavedObservation = newObservation;

    // Update UI immediately. Use explicit constructor so we can set observation
    // to null when needed (copyWith would keep old value when passed null).
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
      evaluationValue: widget.item.evaluationValue,
      evaluation: widget.item.evaluation,
      observation: newObservation,
      createdAt: widget.item.createdAt,
      updatedAt: DateTime.now(),
    );

    widget.onItemUpdated(updatedItem);

    // Save immediately to prevent data loss on refresh
    await _saveItemImmediately(updatedItem);
  }

  Future<void> _saveItemImmediately(Item updatedItem) async {
    try {
      await _serviceFactory.dataService.updateItem(updatedItem);
      debugPrint(
          'Item saved immediately: ${updatedItem.id} with observation: ${updatedItem.observation}');
    } catch (e) {
      debugPrint('Error saving item immediately: $e');
    }
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
      return count;
    } catch (e) {
      debugPrint('Error getting media count for item ${widget.item.id}: $e');
      return 0;
    }
  }

  Future<int> _getItemNonConformityCount() async {
    final cacheKey = '${widget.item.id}_nc_count';
    if (_ncCountCache.containsKey(cacheKey)) {
      return _ncCountCache[cacheKey]!;
    }

    try {
      // Get all non-conformities for this item
      final allNCs = await _serviceFactory.dataService
          .getNonConformities(widget.inspectionId);

      // Filter to show ONLY item-level NCs (exclude detail NCs)
      final itemNCs = allNCs.where((nc) {
        return nc.itemId == widget.item.id && nc.detailId == null;
      }).toList();

      final count = itemNCs.length;
      _ncCountCache[cacheKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting NC count for item ${widget.item.id}: $e');
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
        final theme = Theme.of(context);
        final controller =
            TextEditingController(text: _observationController.text);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Observações do Item',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    onChanged: (_) =>
                        setDialogState(() {}), // Atualiza apenas o dialog
                    decoration: InputDecoration(
                      hintText: 'Digite suas observações...',
                      hintStyle:
                          TextStyle(fontSize: 11, color: theme.hintColor),
                      border: const OutlineInputBorder(),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                controller.clear();
                                setDialogState(
                                    () {}); // Atualiza apenas o dialog
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deixe vazio para remover a observação',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(''), // Return empty string for clear
                  child: const Text('Limpar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    // Handle the result properly - including empty string for clearing
    if (result != null) {
      debugPrint('ItemDetailsSection: Dialog returned result: "$result"');

      // Prevent the controller listener from firing while we programmatically
      // change the text; then perform a single update/save call.
      _observationController.removeListener(_onObservationControllerChanged);
      _observationController.text = result;
      // Ensure UI updates if necessary
      if (mounted) setState(() {});

      // Pass the result directly to ensure the correct value is used and await
      // the save to keep ordering predictable.
      await _updateItemObservation(customObservation: result);

      // Re-attach the listener
      _observationController.addListener(_onObservationControllerChanged);
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

      // Use the new recursive duplication method
      await _serviceFactory.dataService
          .duplicateItemWithChildren(widget.item.id);

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
      await _serviceFactory.dataService.deleteItem(widget.item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Item excluído com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800)));
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
    return evaluationOptions.contains(value) ||
        value == 'Outro' ||
        value == _currentEvaluationValue;
  }

  void _updateItemEvaluation(String? value) {
    if (_currentEvaluationValue == value) return;

    setState(() {
      _currentEvaluationValue = value;
    });

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
      evaluationValue: processedValue,
      evaluation: widget.item.evaluation,
      observation: widget.item.observation,
      createdAt: widget.item.createdAt,
      updatedAt: DateTime.now(),
    );

    widget.onItemUpdated(updatedItem);

    _evaluationDebounce?.cancel();
    _evaluationDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _serviceFactory.dataService.updateItem(updatedItem);
    });
  }

  Future<void> _showCustomEvaluationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Avaliação Personalizada',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: TextFormField(
            controller: controller,
            maxLines: 1,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Digite uma avaliação personalizada...',
              hintStyle: TextStyle(fontSize: 11, color: theme.hintColor),
              border: const OutlineInputBorder(),
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
      final currentOptions =
          List<String>.from(widget.item.evaluationOptions ?? []);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final evaluationOptions = widget.item.evaluationOptions ?? [];
    final itemColor =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
    final textColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFFE65100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (evaluationOptions.isNotEmpty) ...[
          Builder(builder: (context) {
            final allOptions = List<String>.from(evaluationOptions);
            if (_currentEvaluationValue != null &&
                _currentEvaluationValue!.isNotEmpty &&
                _currentEvaluationValue != 'Outro' &&
                !allOptions.contains(_currentEvaluationValue!)) {
              allOptions.add(_currentEvaluationValue!);
            }
            return DropdownButtonFormField<String>(
              initialValue: _isValidEvaluationValue(_currentEvaluationValue)
                  ? _currentEvaluationValue
                  : null,
              decoration: InputDecoration(
                labelText: 'Resposta',
                labelStyle: TextStyle(color: textColor, fontSize: 12),
                border: const OutlineInputBorder(),
                hintText: 'Selecione uma avaliação',
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: itemColor),
                ),
                isDense: true,
              ),
              dropdownColor: theme.cardColor,
              selectedItemBuilder: (context) {
                return [
                  Text('(Sem avaliação)',
                      style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic)),
                  ...allOptions.map((option) => Text(option,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold))),
                  const Text('Outro',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ];
              },
              menuMaxHeight: 200,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('(Sem avaliação)',
                      style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic)),
                ),
                ...allOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  );
                }),
                const DropdownMenuItem<String>(
                  value: 'Outro',
                  child: Text('Outro',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
              onChanged: (value) {
                if (value == 'Outro') {
                  _showCustomEvaluationDialog();
                } else {
                  _updateItemEvaluation(value);
                }
              },
            );
          }),
        ] else ...[
          // Campo de texto livre para avaliação
          TextFormField(
            initialValue: _currentEvaluationValue ?? '',
            decoration: InputDecoration(
              labelText: 'Resposta',
              labelStyle: TextStyle(color: textColor, fontSize: 12),
              border: const OutlineInputBorder(),
              hintText: 'Digite a avaliação do item',
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: itemColor),
              ),
              isDense: true,
            ),
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 14,
                fontWeight: FontWeight.bold),
            onChanged: _updateItemEvaluation,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the item is not evaluable and not expanded, don't build anything.
    if (widget.item.evaluable != true && !widget.isExpanded) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Adaptive colors for light/dark theme
    final itemColor =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
    final textColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFFE65100);
    final containerColor = itemColor.withAlpha((0.1 * 255).round());
    final borderColor = isDark
        ? theme.colorScheme.outline.withAlpha((0.3 * 255).round())
        : itemColor.withAlpha((0.2 * 255).round());

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: containerColor,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          border: Border(
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          )),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AVALIAÇÃO DO ITEM (se for avaliável) - always visible
          if (widget.item.evaluable == true) ...[
            _buildItemEvaluationSection(),
            const SizedBox(height: 8),
          ],

          // Other actions are expandable
          if (widget.isExpanded)
            Column(
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
                    ValueListenableBuilder<int>(
                      valueListenable: ValueNotifier(_mediaCountVersion),
                      builder: (context, version, child) {
                        return FutureBuilder<int>(
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
                        );
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: ValueNotifier(_ncCountVersion),
                      builder: (context, version, child) {
                        return FutureBuilder<int>(
                          future: _getItemNonConformityCount(),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return _buildActionButton(
                              icon: Icons.warning,
                              label: 'NC',
                              onPressed: _addItemNonConformity,
                              color: Colors.orange,
                              count: count,
                            );
                          },
                        );
                      },
                    ),
                    _buildActionButton(
                        icon: Icons.edit,
                        label: 'Renomear',
                        onPressed: _renameItem),
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
                GestureDetector(
                  onTap: _editObservationDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: itemColor.withAlpha((0.3 * 255).round())),
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.note_alt, size: 16, color: itemColor),
                          const SizedBox(width: 8),
                          Text('Observações',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: itemColor),
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          _observationController.text.isEmpty
                              ? 'Toque para adicionar observações...'
                              : _observationController.text,
                          style: TextStyle(
                              color: _observationController.text.isEmpty
                                  ? theme.hintColor
                                  : theme.textTheme.bodyLarge?.color,
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
    final theme = Theme.of(context);
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
                  backgroundColor: color ?? theme.colorScheme.primary,
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
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
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
        // Text(label,
        //     style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

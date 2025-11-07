import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/camera/inspection_camera_screen.dart';
import 'package:lince_inspecoes/services/media_counter_notifier.dart';

class TopicDetailsSection extends StatefulWidget {
  final Topic topic;
  final String inspectionId;
  final Function(Topic) onTopicUpdated;
  final Future<void> Function() onTopicAction;

  const TopicDetailsSection({
    super.key,
    required this.topic,
    required this.inspectionId,
    required this.onTopicUpdated,
    required this.onTopicAction,
  });

  @override
  State<TopicDetailsSection> createState() => _TopicDetailsSectionState();
}

class _TopicDetailsSectionState extends State<TopicDetailsSection> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  String _currentTopicName = '';
  bool _isDuplicating = false; // Flag to prevent double duplication
  final Map<String, int> _mediaCountCache = {};
  final Map<String, int> _ncCountCache = {};
  int _mediaCountVersion = 0; // Força rebuild do FutureBuilder
  int _ncCountVersion = 0; // Força rebuild do FutureBuilder para NCs

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.topic.observation ?? '';
    _currentTopicName = widget.topic.topicName;

    // REMOVIDO: listener para atualização a cada letra
    // _observationController.addListener(_updateTopic);

    // Escutar mudanças nos contadores
    MediaCounterNotifier.instance.addListener(_onCounterChanged);
  }

  @override
  void didUpdateWidget(TopicDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.topic.topicName != _currentTopicName) {
      _currentTopicName = widget.topic.topicName;
    }
    if (widget.topic.observation != _observationController.text) {
      _observationController.text = widget.topic.observation ?? '';
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
    final mediaCacheKey = '${widget.topic.id}_topic_only';
    final ncCacheKey = '${widget.topic.id}_nc_count';
    _mediaCountCache.remove(mediaCacheKey);
    _ncCountCache.remove(ncCacheKey);

    if (mounted) {
      setState(() {
        _mediaCountVersion++; // Força rebuild do FutureBuilder
        _ncCountVersion++; // Força rebuild do FutureBuilder para NCs
      });
    }
  }

  Future<int> _getTopicMediaCount() async {
    final cacheKey = '${widget.topic.id}_topic_only';
    if (_mediaCountCache.containsKey(cacheKey)) {
      return _mediaCountCache[cacheKey]!;
    }

    try {
      // Get only media at topic level (no item or detail specified)
      final allTopicMedias =
          await _serviceFactory.mediaService.getMediaByContext(
        inspectionId: widget.inspectionId,
        topicId: widget.topic.id,
      );

      // Filter to show only topic-level media (no item or detail)
      final topicOnlyMedias = allTopicMedias.where((media) {
        return media.itemId == null && media.detailId == null;
      }).toList();

      final count = topicOnlyMedias.length;
      _mediaCountCache[cacheKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting media count for topic ${widget.topic.id}: $e');
      return 0;
    }
  }

  Future<int> _getTopicNonConformityCount() async {
    final cacheKey = '${widget.topic.id}_nc_count';
    if (_ncCountCache.containsKey(cacheKey)) {
      return _ncCountCache[cacheKey]!;
    }

    try {
      // Get all non-conformities for this topic
      final allNCs = await _serviceFactory.dataService.getNonConformities(widget.inspectionId);

      // Filter to show ONLY topic-level NCs (exclude item and detail NCs)
      final topicNCs = allNCs.where((nc) {
        return nc.topicId == widget.topic.id && nc.itemId == null && nc.detailId == null;
      }).toList();

      final count = topicNCs.length;
      _ncCountCache[cacheKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting NC count for topic ${widget.topic.id}: $e');
      return 0;
    }
  }

  void _updateTopic() {
    // Update UI immediately
    final trimmedText = _observationController.text.trim();
    final observationValue = trimmedText.isEmpty ? null : trimmedText;

    final updatedTopic = Topic(
      id: widget.topic.id,
      inspectionId: widget.topic.inspectionId,
      position: widget.topic.position,
      orderIndex: widget.topic.orderIndex,
      topicName: widget.topic.topicName,
      topicLabel: widget.topic.topicLabel,
      directDetails:
          widget.topic.directDetails, // IMPORTANTE: Preservar directDetails
      observation: observationValue,
      createdAt: widget.topic.createdAt,
      updatedAt: DateTime.now(),
    );

    widget.onTopicUpdated(updatedTopic);
    _saveTopicImmediately(updatedTopic);
  }

  Future<void> _saveTopicImmediately(Topic updatedTopic) async {
    try {
      await _serviceFactory.dataService.updateTopic(updatedTopic);
      debugPrint(
          'Topic saved immediately: ${updatedTopic.id} with observation: ${updatedTopic.observation}');
    } catch (e) {
      debugPrint('Error saving topic immediately: $e');
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
              title: const Text('Observações do Tópico',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: controller,
                      maxLines: 3,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}), // Atualiza apenas o dialog
                      decoration: InputDecoration(
                        hintText: 'Digite suas observações...',
                        hintStyle: TextStyle(fontSize: 11, color: theme.hintColor),
                        border: const OutlineInputBorder(),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                controller.clear();
                                setDialogState(() {}); // Atualiza apenas o dialog
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''), // Return empty string for clear
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

    if (result != null) {
      setState(() {
        _observationController.text = result;
      });
      _updateTopic();
    }
  }

  Future<void> _renameTopic() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Tópico',
        label: 'Nome do Tópico',
        initialValue: widget.topic.topicName,
      ),
    );

    if (newName != null && newName != widget.topic.topicName) {
      try {
        final updatedTopic = widget.topic.copyWith(
          topicName: newName,
          updatedAt: DateTime.now(),
        );

        setState(() {
          _currentTopicName = newName;
        });

        await _serviceFactory.dataService.updateTopic(updatedTopic);
        widget.onTopicUpdated(updatedTopic);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tópico renomeado com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao renomear tópico: $e')),
          );
        }
      }
    }
  }

  Future<void> _duplicateTopic() async {
    // Prevent double execution
    if (_isDuplicating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicar Tópico'),
        content: Text(
            'Deseja duplicar o tópico "${widget.topic.topicName}" com todos os seus itens e detalhes?'),
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

    // Set duplication flag
    setState(() => _isDuplicating = true);

    try {
      debugPrint(
          'TopicDetailsSection: Duplicating topic ${widget.topic.id} with name ${widget.topic.topicName}');

      // Validate topic data before duplication
      if (widget.topic.topicName.isEmpty) {
        throw Exception('Nome do tópico não pode estar vazio');
      }

      if (widget.topic.inspectionId.isEmpty) {
        throw Exception('ID da inspeção não pode estar vazio');
      }

      // Use the new recursive duplication method
      await _serviceFactory.dataService
          .duplicateTopicWithChildren(widget.topic.id);

      widget.onTopicAction(); // Remove await to make it non-blocking

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico duplicado com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('TopicDetailsSection: Error duplicating topic: $e');
      if (mounted) {
        String errorMessage = 'Erro ao duplicar tópico';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Tempo limite excedido. Tente novamente.';
        } else if (e.toString().contains('invalid-argument')) {
          errorMessage =
              'Dados inválidos detectados. Aguarde e tente novamente.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Reset duplication flag
      if (mounted) {
        setState(() => _isDuplicating = false);
      }
    }
  }

  Future<void> _deleteTopic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Tópico'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.topic.topicName}"?\n\nTodos os itens e detalhes serão excluídos permanentemente.'),
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
      await _serviceFactory.dataService.deleteTopic(widget.topic.id);
      await widget.onTopicAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico excluído com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir tópico: $e')),
        );
      }
    }
  }

  Future<void> _addNonConformity() async {
    try {
      // Navigate to NonConformityScreen with preselected topic
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NonConformityScreen(
            inspectionId: widget.inspectionId,
            preSelectedTopic: widget.topic.id,
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

  void _showMediaGallery() {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: widget.topic.id,
            initialTopicOnly: true,
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

  Future<void> _captureMedia() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InspectionCameraScreen(
            inspectionId: widget.inspectionId,
            topicId: widget.topic.id,
            source: 'camera',
            onMediaCaptured: (capturedFiles) async {
              try {
                debugPrint(
                    'TopicDetailsSection: ${capturedFiles.length} media files captured for topic ${widget.topic.id}');

                // Cache será invalidado automaticamente pelo MediaCounterNotifier

                // Chamar atualização imediatamente
                await widget.onTopicAction();

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
                  _showMediaGallery();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // Adaptive colors for light/dark theme
    final containerColor = isDark
        ? theme.colorScheme.surface.withAlpha((0.8 * 255).round())
        : primaryColor.withAlpha((0.05 * 255).round());
    final borderColor = isDark
        ? theme.colorScheme.outline.withAlpha((0.3 * 255).round())
        : primaryColor.withAlpha((0.2 * 255).round());
    final textColor = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF4A148C);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
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
                onPressed: _captureMedia,
                color: Colors.purple,
              ),
              ValueListenableBuilder<int>(
                valueListenable: ValueNotifier(_mediaCountVersion),
                builder: (context, version, child) {
                  return FutureBuilder<int>(
                    future: _getTopicMediaCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _buildActionButton(
                        icon: Icons.photo_library,
                        label: 'Galeria',
                        onPressed: _showMediaGallery,
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
                    future: _getTopicNonConformityCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _buildActionButton(
                        icon: Icons.warning_amber,
                        label: 'NC',
                        onPressed: _addNonConformity,
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
                onPressed: _renameTopic,
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Duplicar',
                onPressed: _duplicateTopic,
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Excluir',
                onPressed: _deleteTopic,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, size: 14, color: textColor),
                      const SizedBox(width: 8),
                      Text(
                        'Observações',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, size: 14, color: textColor),
                    ],
                  ),
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
                          : FontStyle.normal,
                    ),
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
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;
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
                  backgroundColor: buttonColor,
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
}

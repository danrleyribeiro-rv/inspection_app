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
  int _mediaCountVersion = 0; // Força rebuild do FutureBuilder

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
    final cacheKey = '${widget.topic.id}_topic_only';
    _mediaCountCache.remove(cacheKey);
    
    if (mounted) {
      setState(() {
        _mediaCountVersion++; // Força rebuild do FutureBuilder
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
      final allTopicMedias = await _serviceFactory.mediaService.getMediaByContext(
        inspectionId: widget.inspectionId,
        topicId: widget.topic.id,
      );
      
      // Filter to show only topic-level media (no item or detail)
      final topicOnlyMedias = allTopicMedias.where((media) {
        return media.itemId == null && media.detailId == null;
      }).toList();
      
      final count = topicOnlyMedias.length;
      _mediaCountCache[cacheKey] = count;
      debugPrint('TopicDetailsSection: Topic ${widget.topic.id} has $count topic-only media (filtered from ${allTopicMedias.length} total)');
      return count;
    } catch (e) {
      debugPrint('Error getting media count for topic ${widget.topic.id}: $e');
      return 0;
    }
  }

  void _updateTopic() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

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
      directDetails: widget.topic.directDetails, // IMPORTANTE: Preservar directDetails
      observation: observationValue,
      isDamaged: widget.topic.isDamaged,
      tags: widget.topic.tags,
      createdAt: widget.topic.createdAt,
      updatedAt: DateTime.now(),
    );
    
    widget.onTopicUpdated(updatedTopic);

    // Debounce the actual save operation
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      debugPrint('TopicDetailsSection: Updating topic ${updatedTopic.id} with observation: "$observationValue"');
      await _serviceFactory.dataService.updateTopic(updatedTopic);
      debugPrint('TopicDetailsSection: Topic ${updatedTopic.id} updated successfully');
      // NÃO chamar onTopicAction() aqui para evitar rebuild desnecessário
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _observationController.text);
        
        return AlertDialog(
          title: const Text('Observações do Tópico', style: TextStyle(color: Colors.white, fontSize: 12)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextFormField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Digite suas observações...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
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
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
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

      if (widget.topic.id == null) {
        throw Exception('Tópico sem ID válido');
      }

      // Use the new recursive duplication method
      await _serviceFactory.dataService
          .duplicateTopicWithChildren(widget.topic.id!);

      // Chamar atualização imediatamente para mostrar nova estrutura
      await widget.onTopicAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Tópico duplicado com sucesso (incluindo itens e detalhes)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('TopicDetailsSection: Error duplicating topic: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar tópico: $e')),
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
      await _serviceFactory.dataService.deleteTopic(widget.topic.id ?? '');
      await widget.onTopicAction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico excluído com sucesso'),
            backgroundColor: Colors.green,
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
                debugPrint('TopicDetailsSection: ${capturedFiles.length} media files captured for topic ${widget.topic.id}');
                
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF6F4B99).withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF6F4B99).withAlpha((255 * 0.2).round())),
      ),
      child: SingleChildScrollView(
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
                FutureBuilder<int>(
                  key: ValueKey('topic_media_${widget.topic.id}_$_mediaCountVersion'),
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
                ),
                _buildActionButton(
                  icon: Icons.warning_amber,
                  label: 'NC',
                  onPressed: _addNonConformity,
                  color: Colors.orange,
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
                  border: Border.all(
                      color: const Color(0xFF6F4B99)
                          .withAlpha((255 * 0.3).round())),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt,
                            size: 14, color: const Color(0xFF6F4B99)),
                        const SizedBox(width: 8),
                        Text(
                          'Observações',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFBB8FEB),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.edit,
                            size: 14, color: const Color(0xFF6F4B99)),
                      ],
                    ),
                    Text(
                      _observationController.text.isEmpty
                          ? 'Toque para adicionar observações...'
                          : _observationController.text,
                      style: TextStyle(
                        color: const Color(0xFFBB8FEB).withAlpha((255 * 0.7).round()), // Same as topic subtitle
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
                  backgroundColor: color ?? const Color(0xFF6F4B99),
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

}

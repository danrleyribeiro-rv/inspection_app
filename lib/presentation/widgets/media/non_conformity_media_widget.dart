// lib/presentation/widgets/media/non_conformity_media_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/enhanced_offline_service_factory.dart';
import 'package:inspection_app/models/non_conformity.dart';
import 'package:inspection_app/presentation/widgets/media/native_camera_widget.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final int ncIndex;
  final bool isReadOnly;
  final Function(String) onMediaAdded;
  final Function()? onNonConformityUpdated;

  const NonConformityMediaWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.ncIndex,
    this.isReadOnly = false,
    required this.onMediaAdded,
    this.onNonConformityUpdated,
  });

  @override
  State<NonConformityMediaWidget> createState() =>
      _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  int _processingCount = 0;

  void _showCameraCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NativeCameraWidget(
          onImagesSelected: _handleImagesSelected,
          allowMultiple: true,
        ),
      ),
    );
  }

  Future<void> _editNonConformity() async {
    try {
      // Buscar a não conformidade específica
      final hierarchyIds = await _getHierarchyIds();
      final nonConformityId = '${widget.inspectionId}-${hierarchyIds['topicId']}-${hierarchyIds['itemId']}-${hierarchyIds['detailId']}-nc_${widget.ncIndex}';
      
      // Buscar todas as não conformidades para encontrar a específica
      final allNonConformitiesObjects = await _serviceFactory.dataService.getNonConformities(widget.inspectionId);
      final allNonConformities = allNonConformitiesObjects.map((nc) => nc.toJson()).toList();
      
      Map<String, dynamic>? targetNC;
      for (final nc in allNonConformities) {
        String currentNcId = nc['id'] ?? '';
        if (!currentNcId.contains('-')) {
          currentNcId = '${widget.inspectionId}-${nc['topic_id']}-${nc['item_id']}-${nc['detail_id']}-$currentNcId';
        }
        if (currentNcId == nonConformityId) {
          targetNC = nc;
          break;
        }
      }
      
      if (targetNC != null && mounted) {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => NonConformityEditDialog(
            nonConformity: targetNC!,
            onSave: (updatedData) {
              Navigator.of(context).pop(updatedData);
            },
          ),
        );
        
        if (result != null) {
          // Atualizar a não conformidade
          final nonConformity = NonConformity(
            id: nonConformityId,
            inspectionId: result['inspection_id'] ?? widget.inspectionId,
            topicId: result['topic_id'],
            itemId: result['item_id'],
            detailId: result['detail_id'],
            title: result['title'] ?? '',
            description: result['description'] ?? '',
            severity: result['severity'] ?? 'medium',
            status: result['status'] ?? 'open',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
            isDeleted: false,
          );
          await _serviceFactory.dataService.updateNonConformity(nonConformity);
          
          // Notificar o parent para atualizar a UI
          widget.onNonConformityUpdated?.call();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não conformidade atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade não encontrada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error editing non-conformity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao editar não conformidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNonConformityMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
          initialTopicId: 'topic_${widget.topicIndex}',
          initialItemId: 'item_${widget.itemIndex}',
          initialDetailId: 'detail_${widget.detailIndex}',
          initialIsNonConformityOnly: true, // Filtro explícito para NC
          initialMediaType: null,
        ),
      ),
    );
  }

  Future<void> _handleImagesSelected(List<String> imagePaths) async {
    if (mounted) {
      setState(() {
        _processingCount += imagePaths.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Iniciando processamento de ${imagePaths.length} imagem(ns) de NC...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    for (final path in imagePaths) {
      _processAndSaveMedia(path, 'image').whenComplete(() {
        if (mounted) {
          setState(() {
            _processingCount--;
          });
        }
      });
    }
  }

  Future<Map<String, String?>> _getHierarchyIds() async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics == null) {
        return {'topicId': 'topic_${widget.topicIndex}', 'itemId': 'item_${widget.itemIndex}', 'detailId': 'detail_${widget.detailIndex}'};
      }

      String? topicId;
      String? itemId;
      String? detailId;

      if (widget.topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![widget.topicIndex];
        topicId = topic['id'] ?? 'topic_${widget.topicIndex}';

        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (widget.itemIndex < items.length) {
          final item = items[widget.itemIndex];
          itemId = item['id'] ?? 'item_${widget.itemIndex}';

          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (widget.detailIndex < details.length) {
            final detail = details[widget.detailIndex];
            detailId = detail['id'] ?? 'detail_${widget.detailIndex}';
          }
        }
      }

      return {
        'topicId': topicId ?? 'topic_${widget.topicIndex}',
        'itemId': itemId ?? 'item_${widget.itemIndex}',
        'detailId': detailId ?? 'detail_${widget.detailIndex}',
      };
    } catch (e) {
      debugPrint('Error getting hierarchy IDs: $e');
      return {'topicId': 'topic_${widget.topicIndex}', 'itemId': 'item_${widget.itemIndex}', 'detailId': 'detail_${widget.detailIndex}'};
    }
  }

  Future<void> _processAndSaveMedia(String localPath, String type) async {
    try {
      final position = await _serviceFactory.mediaService.getCurrentLocation();
      
      // Obter IDs reais da hierarquia
      final hierarchyIds = await _getHierarchyIds();
      
      debugPrint('NonConformityMediaWidget: Processing media');
      debugPrint('  TopicId: ${hierarchyIds['topicId']}');
      debugPrint('  ItemId: ${hierarchyIds['itemId']}');
      debugPrint('  DetailId: ${hierarchyIds['detailId']}');
      debugPrint('  NCIndex: ${widget.ncIndex}');
      
      // Usar o fluxo offline-first do MediaService
      await _serviceFactory.mediaService.captureAndProcessMedia(
        inputPath: localPath,
        inspectionId: widget.inspectionId,
        type: type,
        topicId: hierarchyIds['topicId'],
        itemId: hierarchyIds['itemId'],
        detailId: hierarchyIds['detailId'],
        metadata: {
          'source': 'camera',
          'is_non_conformity': true,
          'nc_index': widget.ncIndex,
          'location': position != null ? {
            'latitude': position['latitude'],
            'longitude': position['longitude'],
          } : null,
        },
      );
      
      // Media already saved by service, just notify callback
      widget.onMediaAdded(localPath);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia de NC: $e')),
        );
      }
    }
  }

  // Method removed - media is now handled directly by the service

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isReadOnly) 
          const SizedBox.shrink()
        else
          Column(
            children: [
              if (_processingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text("Processando $_processingCount NC(s)...", style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Capturar', style: TextStyle(fontSize: 8)),
                      onPressed: _showCameraCapture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Ver Galeria', style: TextStyle(fontSize: 8)),
                      onPressed: _openNonConformityMediaGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar NC', style: TextStyle(fontSize: 8)),
                      onPressed: _editNonConformity,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
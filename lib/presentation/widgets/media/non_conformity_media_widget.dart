// lib/presentation/widgets/media/non_conformity_media_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/media/custom_camera_widget.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final int ncIndex;
  final bool isReadOnly;
  final Function(String) onMediaAdded;

  const NonConformityMediaWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.ncIndex,
    this.isReadOnly = false,
    required this.onMediaAdded,
  });

  @override
  State<NonConformityMediaWidget> createState() =>
      _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  int _processingCount = 0;

  void _showCameraCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomCameraWidget(
          onMediaCaptured: _handleMediaCaptured,
          allowVideo: true,
        ),
      ),
    );
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

  Future<void> _handleMediaCaptured(List<String> localPaths, String type) async {
    if (mounted) {
      setState(() {
        _processingCount += localPaths.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Iniciando processamento de ${localPaths.length} arquivo(s) de NC...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    for (final path in localPaths) {
      _processAndSaveMedia(path, type).whenComplete(() {
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
      final inspection = await _serviceFactory.coordinator.getInspection(widget.inspectionId);
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
      final offlineMedia = await _serviceFactory.mediaService.captureAndProcessMedia(
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
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy
          } : null,
        },
      );
      
      debugPrint('NonConformityMediaWidget: OfflineMedia created with ID: ${offlineMedia.id}');
      
      // Converter OfflineMedia para formato esperado pelo coordinator
      final mediaData = {
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'url': offlineMedia.uploadUrl,
        'aspect_ratio': '4:3',
        'source': 'camera',
        'is_non_conformity': true,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'updated_at': offlineMedia.createdAt.toIso8601String(),
        'metadata': offlineMedia.metadata,
      };

      await _saveMediaToInspection(mediaData);
      debugPrint('NonConformityMediaWidget: Media saved to inspection');
      widget.onMediaAdded(offlineMedia.localPath);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia de NC: $e')),
        );
      }
    }
  }

  Future<void> _saveMediaToInspection(Map<String, dynamic> mediaData) async {
    final inspection = await _serviceFactory.coordinator.getInspection(widget.inspectionId);
    if (inspection?.topics != null && widget.topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = topics[widget.topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (widget.itemIndex < items.length) {
        final item = items[widget.itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        if (widget.detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[widget.detailIndex]);
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          if (widget.ncIndex < nonConformities.length) {
            final nc = Map<String, dynamic>.from(nonConformities[widget.ncIndex]);
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);

            ncMedia.add(mediaData);
            nc['media'] = ncMedia;
            nonConformities[widget.ncIndex] = nc;
            detail['non_conformities'] = nonConformities;
            details[widget.detailIndex] = detail;
            item['details'] = details;
            items[widget.itemIndex] = item;
            topic['items'] = items;
            topics[widget.topicIndex] = topic;

            final updatedInspection = inspection.copyWith(topics: topics);
            await _serviceFactory.coordinator.saveInspection(updatedInspection);
          }
        }
      }
    }
  }

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
                ],
              ),
            ],
          ),
      ],
    );
  }
}
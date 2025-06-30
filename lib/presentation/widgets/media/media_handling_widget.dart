// lib/presentation/widgets/media/media_handling_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/media/custom_camera_widget.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';

class MediaHandlingWidget extends StatefulWidget {
  final String inspectionId;
  final String topicId;
  final String itemId;
  final String detailId;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;

  const MediaHandlingWidget({
    super.key,
    required this.inspectionId,
    required this.topicId,
    required this.itemId,
    required this.detailId,
    required this.onMediaAdded,
    required this.onMediaDeleted,
  });

  @override
  State<MediaHandlingWidget> createState() => _MediaHandlingWidgetState();
}

class _MediaHandlingWidgetState extends State<MediaHandlingWidget> {
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

  void _openDetailMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
          initialTopicId: widget.topicId,
          initialItemId: widget.itemId,
          initialDetailId: widget.detailId,
          // Como este widget lida com mídias normais, o filtro de NC
          // deve ser 'false' por padrão.
          initialIsNonConformityOnly: false,
        ),
      ),
    );
  }

  Future<void> _handleMediaCaptured(
      List<String> localPaths, String type) async {
    if (mounted) {
      setState(() {
        _processingCount += localPaths.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Iniciando processamento de ${localPaths.length} arquivo(s)...'),
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

  Future<void> _processAndSaveMedia(String localPath, String type) async {
    try {
      final position = await _serviceFactory.mediaService.getCurrentLocation();
      
      // Usar o fluxo offline-first do MediaService
      final offlineMedia = await _serviceFactory.mediaService.captureAndProcessMedia(
        inputPath: localPath,
        inspectionId: widget.inspectionId,
        type: type,
        topicId: widget.topicId,
        itemId: widget.itemId,
        detailId: widget.detailId,
        metadata: {
          'source': 'camera',
          'is_non_conformity': false,
          'location': position != null ? {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy
          } : null,
        },
      );
      
      // Converter OfflineMedia para formato esperado pelo coordinator
      final mediaData = {
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'url': offlineMedia.uploadUrl,
        'aspect_ratio': '4:3',
        'source': 'camera',
        'is_non_conformity': false,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'updated_at': offlineMedia.createdAt.toIso8601String(),
        'metadata': offlineMedia.metadata,
      };

      await _addMediaToInspection(mediaData);
      widget.onMediaAdded(offlineMedia.localPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar mídia: $e')),
        );
      }
    }
  }

  Future<void> _addMediaToInspection(Map<String, dynamic> mediaData) async {
    try {
      debugPrint('MediaHandlingWidget: Adding media to detail');
      debugPrint('  InspectionId: ${widget.inspectionId}');
      debugPrint('  TopicId: ${widget.topicId}');
      debugPrint('  ItemId: ${widget.itemId}');
      debugPrint('  DetailId: ${widget.detailId}');
      debugPrint('  MediaData: ${mediaData['id']}');
      
      await _serviceFactory.coordinator.addMediaToDetail(
        widget.inspectionId, 
        widget.topicId, 
        widget.itemId, 
        widget.detailId, 
        mediaData
      );
      
      debugPrint('MediaHandlingWidget: Media added successfully');
    } catch (e) {
      debugPrint('MediaHandlingWidget: Error adding media to detail: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_processingCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text("Processando $_processingCount mídia(s)...",
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _showCameraCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 16),
                    SizedBox(height: 2),
                    Text('Câmera', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _openDetailMediaGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library, size: 16),
                    SizedBox(height: 2),
                    Text('Galeria', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

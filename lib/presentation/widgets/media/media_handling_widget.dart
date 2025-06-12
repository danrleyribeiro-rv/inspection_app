// lib/presentation/widgets/media/media_handling_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/media/custom_camera_widget.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:path_provider/path_provider.dart';

class MediaHandlingWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final Function(String) onMediaAdded;
  final Function(String) onMediaDeleted;

  const MediaHandlingWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.onMediaAdded,
    required this.onMediaDeleted,
  });

  @override
  State<MediaHandlingWidget> createState() => _MediaHandlingWidgetState();
}

class _MediaHandlingWidgetState extends State<MediaHandlingWidget> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final _uuid = Uuid();
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
          initialTopicId: 'topic_${widget.topicIndex}',
          initialItemId: 'item_${widget.itemIndex}',
          initialDetailId: 'detail_${widget.detailIndex}',
          // Como este widget lida com mídias normais, o filtro de NC
          // deve ser 'false' por padrão.
          initialIsNonConformityOnly: false,
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
          content: Text('Iniciando processamento de ${localPaths.length} arquivo(s)...'),
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
      final mediaDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${mediaDir.path}/processed_media');
      if (!await outputDir.exists()) await outputDir.create(recursive: true);

      final fileExt = type == 'image' ? 'jpg' : 'mp4';
      final filename = '${type}_${_uuid.v4()}.$fileExt';
      final outputPath = '${outputDir.path}/$filename';

      final processedFile = await _serviceFactory.mediaService.processMedia43(
        localPath,
        outputPath,
        type
      );

      if (processedFile == null) {
        throw Exception("Falha ao processar mídia.");
      }
      
      final position = await _serviceFactory.mediaService.getCurrentLocation();

      final mediaData = <String, dynamic>{
        'id': _uuid.v4(),
        'type': type,
        'localPath': processedFile.path,
        'aspect_ratio': '4:3',
        'source': 'camera',
        'is_non_conformity': false, // Mídias deste widget nunca são de NC
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': {
          'location': position != null ? {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'accuracy': position.accuracy,
                } : null,
          'source': 'camera',
        },
      };

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        try {
          final downloadUrl = await _serviceFactory.mediaService.uploadMedia(
            file: processedFile,
            inspectionId: widget.inspectionId,
            type: type,
            topicId: 'topic_${widget.topicIndex}',
            itemId: 'item_${widget.itemIndex}',
            detailId: 'detail_${widget.detailIndex}',
          );
          mediaData['url'] = downloadUrl;
        } catch (e) {
          debugPrint('Error uploading to Firebase Storage: $e');
        }
      }

      await _addMediaToInspection(mediaData);
      widget.onMediaAdded(processedFile.path);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar mídia: $e')),
        );
      }
    }
  }

  Future<void> _addMediaToInspection(Map<String, dynamic> mediaData) async {
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
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);

          media.add(mediaData);
          detail['media'] = media;
          details[widget.detailIndex] = detail;
          item['details'] = details;
          items[widget.itemIndex] = item;
          topic['items'] = items;
          topics[widget.topicIndex] = topic;

          await _serviceFactory.coordinator.saveInspection(inspection.copyWith(topics: topics));
        }
      }
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
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text("Processando $_processingCount mídia(s)...", style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCameraCapture,
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('Capturar', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openDetailMediaGallery,
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('Ver Galeria', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
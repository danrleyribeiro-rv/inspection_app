// lib/presentation/widgets/media/non_conformity_media_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> _processAndSaveMedia(String localPath, String type) async {
    try {
      final mediaDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${mediaDir.path}/processed_nc_media');
      if (!await outputDir.exists()) await outputDir.create(recursive: true);

      final fileExt = type == 'image' ? 'jpg' : 'mp4';
      final filename = 'nc_${type}_${_uuid.v4()}.$fileExt';
      final outputPath = '${outputDir.path}/$filename';
      
      final processedFile = await _serviceFactory.mediaService.processMedia43(
        localPath,
        outputPath,
        type
      );
      
      if (processedFile == null) {
        throw Exception("Falha ao processar mídia de NC.");
      }

      final position = await _serviceFactory.mediaService.getCurrentLocation();

      final mediaData = {
        'id': _uuid.v4(),
        'type': type,
        'localPath': processedFile.path,
        'aspect_ratio': '4:3',
        'source': 'camera',
        'is_non_conformity': true, // Mídias deste widget sempre são de NC
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

      await _saveMediaToInspection(mediaData);
      widget.onMediaAdded(processedFile.path);

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
                      label: const Text('Capturar', style: TextStyle(fontSize: 12)),
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
                      label: const Text('Ver Galeria', style: TextStyle(fontSize: 12)),
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
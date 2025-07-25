import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:lince_inspecoes/services/data/offline_data_service.dart';

class OfflineMediaService {
  static OfflineMediaService? _instance;
  static OfflineMediaService get instance =>
      _instance ??= OfflineMediaService._();

  OfflineMediaService._();

  final OfflineDataService _dataService = OfflineDataService.instance;
  final Uuid _uuid = Uuid();

  Directory? _mediaDir;

  // Inicializar o serviço
  Future<void> initialize() async {
    try {
      // Criar diretório para mídias
      final appDir = await getApplicationDocumentsDirectory();
      _mediaDir = Directory(path.join(appDir.path, 'media'));

      if (!await _mediaDir!.exists()) {
        await _mediaDir!.create(recursive: true);
      }

      debugPrint(
          'OfflineMediaService: Initialized with media directory: ${_mediaDir!.path}');
    } catch (e) {
      debugPrint('OfflineMediaService: Error initializing: $e');
      rethrow;
    }
  }

  // Capturar e processar mídia
  Future<Map<String, dynamic>> captureAndProcessMedia({
    required String inputPath,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final mediaId = _uuid.v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(inputPath);
      final fileName = '${mediaId}_$timestamp$extension';
      final localPath = path.join(_mediaDir!.path, fileName);

      // Copiar arquivo para o diretório de mídia
      final inputFile = File(inputPath);
      final outputFile = File(localPath);
      await inputFile.copy(outputFile.path);

      // Skip image processing - use original size

      // Criar dados da mídia
      final mediaData = {
        'id': mediaId,
        'inspection_id': inspectionId,
        'topic_id': topicId,
        'item_id': itemId,
        'detail_id': detailId,
        'type': type,
        'file_name': fileName,
        'local_path': localPath,
        'file_size': await outputFile.length(),
        'is_processed': true,
        'is_uploaded': false,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          ...?metadata,
        },
      };

      // Salvar no banco de dados
      await _dataService.saveMediaFile(
        inspectionId,
        fileName,
        await outputFile.readAsBytes(),
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        fileType: type,
      );

      debugPrint('OfflineMediaService: Captured and processed media $mediaId');
      return mediaData;
    } catch (e) {
      debugPrint('OfflineMediaService: Error capturing media: $e');
      rethrow;
    }
  }


  // Obter arquivo de mídia
  Future<File?> getMediaFile(String mediaId) async {
    try {
      return await _dataService.getMediaFile(mediaId);
    } catch (e) {
      debugPrint('OfflineMediaService: Error getting media file: $e');
      return null;
    }
  }

  // Obter mídias por inspeção
  Future<List<Map<String, dynamic>>> getMediaFilesByInspection(
      String inspectionId) async {
    try {
      return await _dataService.getMediaFilesByInspection(inspectionId);
    } catch (e) {
      debugPrint('OfflineMediaService: Error getting media files: $e');
      return [];
    }
  }

  // Deletar arquivo de mídia
  Future<void> deleteMediaFile(String mediaId) async {
    try {
      final mediaFile = await _dataService.getMediaFile(mediaId);
      if (mediaFile != null && await mediaFile.exists()) {
        await mediaFile.delete();
      }

      await _dataService.deleteMediaFile(mediaId);
      debugPrint('OfflineMediaService: Deleted media file $mediaId');
    } catch (e) {
      debugPrint('OfflineMediaService: Error deleting media file: $e');
      rethrow;
    }
  }

  // Limpar cache de mídia
  Future<void> clearMediaCache() async {
    try {
      if (_mediaDir != null && await _mediaDir!.exists()) {
        await _mediaDir!.delete(recursive: true);
        await _mediaDir!.create(recursive: true);
      }
      debugPrint('OfflineMediaService: Media cache cleared');
    } catch (e) {
      debugPrint('OfflineMediaService: Error clearing media cache: $e');
    }
  }

  // Obter estatísticas de mídia
  Future<Map<String, int>> getMediaStats() async {
    try {
      final stats = await _dataService.getStats();
      return {
        'total_media_files': stats['media_files'] ?? 0,
        'processed_files': stats['processed_media'] ?? 0,
        'pending_upload': stats['pending_upload'] ?? 0,
      };
    } catch (e) {
      debugPrint('OfflineMediaService: Error getting media stats: $e');
      return {};
    }
  }
}

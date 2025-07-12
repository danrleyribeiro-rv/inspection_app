// lib/services/features/media_service.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lince_inspecoes/services/data/offline_data_service.dart';

class MediaService {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._();

  MediaService._();

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
          'MediaService: Initialized offline-first with media directory: ${_mediaDir!.path}');
    } catch (e) {
      debugPrint('MediaService: Error initializing: $e');
      rethrow;
    }
  }

  void dispose() {
    // Cleanup resources if needed
  }

  // Simple image copy without processing - use original quality and size
  Future<File?> processImageFast(String inputPath, String outputPath) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return null;

      // Simply copy the file without any processing to preserve original quality
      final outputFile = await inputFile.copy(outputPath);

      debugPrint(
          'MediaService: Copied image ${path.basename(inputPath)} without processing');
      return outputFile;
    } catch (e) {
      debugPrint('MediaService: Error copying image: $e');
      return null;
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

      // Processar e salvar arquivo
      File? processedFile;
      if (type == 'image') {
        processedFile = await processImageFast(inputPath, localPath);
      } else {
        // Para vídeos, simplesmente copiar
        final inputFile = File(inputPath);
        processedFile = await inputFile.copy(localPath);
      }

      if (processedFile == null) {
        throw Exception('Failed to process media file');
      }

      // Obter localização atual
      final position = await getCurrentLocation();

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
        'file_size': await processedFile.length(),
        'is_processed': true,
        'is_uploaded': false,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          ...?metadata,
          'location': position != null
              ? {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'accuracy': position.accuracy,
                }
              : null,
        },
      };

      // Salvar no banco de dados
      if (detailId != null && topicId != null && itemId != null) {
        // If media is associated with a detail, update the inspection object
        await _dataService.updateDetailMedia(
          inspectionId,
          topicId,
          itemId,
          detailId,
          {
            'id': mediaId,
            'file_name': fileName,
            'local_path': localPath,
            'type': type,
            'file_size': await processedFile.length(),
            'is_processed': true,
            'is_uploaded': false,
            'created_at': DateTime.now().toIso8601String(),
            'metadata': mediaData['metadata'], // Pass along the metadata
          },
        );
      } else {
        // Otherwise, just save the media file metadata
        await _dataService.saveMediaFile(
          inspectionId,
          fileName,
          await processedFile.readAsBytes(),
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
          fileType: type,
        );
      }

      debugPrint('MediaService: Captured and processed media $mediaId');
      return mediaData;
    } catch (e) {
      debugPrint('MediaService: Error capturing media: $e');
      rethrow;
    }
  }

  // Obter localização atual
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('MediaService: Error getting location: $e');
      return null;
    }
  }

  // Obter arquivo de mídia
  Future<File?> getMediaFile(String mediaId) async {
    try {
      return await _dataService.getMediaFile(mediaId);
    } catch (e) {
      debugPrint('MediaService: Error getting media file: $e');
      return null;
    }
  }

  // Obter mídias por inspeção
  Future<List<Map<String, dynamic>>> getMediaFilesByInspection(
      String inspectionId) async {
    try {
      return await _dataService.getMediaFilesByInspection(inspectionId);
    } catch (e) {
      debugPrint('MediaService: Error getting media files: $e');
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
      debugPrint('MediaService: Deleted media file $mediaId');
    } catch (e) {
      debugPrint('MediaService: Error deleting media file: $e');
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
      debugPrint('MediaService: Media cache cleared');
    } catch (e) {
      debugPrint('MediaService: Error clearing media cache: $e');
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
      debugPrint('MediaService: Error getting media stats: $e');
      return {};
    }
  }

  // Método para compatibilidade com UI existente
  Future<void> saveMediaToDetail({
    required String inspectionId,
    required String topicId,
    required String itemId,
    required String detailId,
    required String mediaPath,
    required String mediaType,
    Map<String, dynamic>? metadata,
  }) async {
    await captureAndProcessMedia(
      inputPath: mediaPath,
      inspectionId: inspectionId,
      type: mediaType,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      metadata: metadata,
    );
  }

  // Métodos para compatibilidade com UI
  Future<void> deleteMedia(String mediaId) async {
    await deleteMediaFile(mediaId);
  }

  Future<String?> getDisplayPath(String mediaId) async {
    final file = await getMediaFile(mediaId);
    return file?.path;
  }

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    return await getMediaFilesByInspection(inspectionId);
  }

  Future<void> uploadProfileImage(String imagePath, String userId) async {
    // Para perfil, apenas salvar localmente por enquanto
    debugPrint('MediaService: uploadProfileImage called for user $userId');
  }

  Future<void> uploadAllPendingMedia() async {
    debugPrint('MediaService: Starting upload of all pending media files');
    try {
      final pendingMediaFiles = await _dataService.getMediaFilesNeedingUpload();

      for (final mediaFile in pendingMediaFiles) {
        final mediaId = mediaFile['id'] as String;
        final localPath = mediaFile['local_path'] as String;
        final inspectionId = mediaFile['inspection_id'] as String;
        final fileName = mediaFile['file_name'] as String;

        try {
          final file = File(localPath);
          if (!await file.exists()) {
            debugPrint(
                'MediaService: Local media file not found for $mediaId at $localPath');
            continue;
          }

          final storageRef = FirebaseStorage.instance
              .ref()
              .child('inspections')
              .child(inspectionId)
              .child('media')
              .child(fileName);

          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask.whenComplete(() {});
          final downloadUrl = await snapshot.ref.getDownloadURL();

          await _dataService.markMediaUploaded(mediaId, downloadUrl);
          debugPrint(
              'MediaService: Uploaded media file $mediaId to $downloadUrl');
        } catch (e) {
          debugPrint('MediaService: Error uploading media file $mediaId: $e');
          // Continue to next file even if one fails
        }
      }
      debugPrint('MediaService: Finished uploading all pending media files');
    } catch (e) {
      debugPrint(
          'MediaService: Error getting pending media files for upload: $e');
    }
  }

  Future<List<Map<String, dynamic>>> filterMedia(
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
    String? mediaType,
    bool? isNonConformity,
  }) async {
    try {
      final allMedia =
          await _dataService.getMediaFilesByInspection(inspectionId);

      return allMedia.where((media) {
        if (topicId != null && media['topic_id'] != topicId) return false;
        if (itemId != null && media['item_id'] != itemId) return false;
        if (detailId != null && media['detail_id'] != detailId) return false;
        if (mediaType != null && media['file_type'] != mediaType) {
          return false; // Use file_type from SQLite
        }
        // isNonConformity logic needs to be implemented if non-conformity media is distinct
        return true;
      }).toList();
    } catch (e) {
      debugPrint('MediaService: Error filtering media: $e');
      return [];
    }
  }

  Future<bool> moveMedia({
    required String mediaId,
    required String inspectionId,
    String? currentTopicId,
    String? currentItemId,
    String? currentDetailId,
    String? newTopicId,
    String? newItemId,
    String? newDetailId,
    bool isNonConformity = false,
    String? nonConformityId,
  }) async {
    try {
      final inspection = await _dataService.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint(
            'MediaService.moveMedia: Inspection not found: $inspectionId');
        return false;
      }

      // Find and remove media from current location
      Map<String, dynamic>? mediaToMove;
      List<Map<String, dynamic>> updatedTopics =
          List<Map<String, dynamic>>.from(inspection.topics ?? []);

      // Helper to find and remove media
      void findAndRemoveMedia(List<Map<String, dynamic>> mediaList) {
        mediaList.removeWhere((media) {
          if (media['id'] == mediaId) {
            mediaToMove = Map<String, dynamic>.from(media);
            return true;
          }
          return false;
        });
      }

      // Search in topics, items, details, and non-conformities
      for (var topic in updatedTopics) {
        if (topic['id'] == currentTopicId) {
          findAndRemoveMedia(topic['media'] ?? []);
          for (var item in topic['items'] ?? []) {
            if (item['id'] == currentItemId) {
              findAndRemoveMedia(item['media'] ?? []);
              for (var detail in item['details'] ?? []) {
                if (detail['id'] == currentDetailId) {
                  findAndRemoveMedia(detail['media'] ?? []);
                  for (var nc in detail['non_conformities'] ?? []) {
                    if (nc['id'] == nonConformityId) {
                      findAndRemoveMedia(nc['media'] ?? []);
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (mediaToMove == null) {
        debugPrint(
            'MediaService.moveMedia: Media $mediaId not found in current location.');
        return false;
      }

      // Add media to new location
      bool addedToNewLocation = false;
      for (var topic in updatedTopics) {
        if (topic['id'] == newTopicId) {
          if (newItemId == null) {
            // Add to topic level
            (topic['media'] as List<dynamic>? ?? []).add(mediaToMove);
            addedToNewLocation = true;
            break;
          } else {
            for (var item in topic['items'] ?? []) {
              if (item['id'] == newItemId) {
                if (newDetailId == null) {
                  // Add to item level
                  (item['media'] as List<dynamic>? ?? []).add(mediaToMove);
                  addedToNewLocation = true;
                  break;
                } else {
                  for (var detail in item['details'] ?? []) {
                    if (detail['id'] == newDetailId) {
                      if (isNonConformity && nonConformityId != null) {
                        // Add to non-conformity level
                        for (var nc in detail['non_conformities'] ?? []) {
                          if (nc['id'] == nonConformityId) {
                            (nc['media'] as List<dynamic>? ?? [])
                                .add(mediaToMove);
                            addedToNewLocation = true;
                            break;
                          }
                        }
                      } else {
                        // Add to detail level
                        (detail['media'] as List<dynamic>? ?? [])
                            .add(mediaToMove);
                        addedToNewLocation = true;
                        break;
                      }
                    }
                  }
                }
              }
              if (addedToNewLocation) break;
            }
          }
        }
        if (addedToNewLocation) break;
      }

      if (!addedToNewLocation) {
        debugPrint(
            'MediaService.moveMedia: Failed to add media to new location.');
        return false;
      }

      // Save updated inspection
      await _dataService
          .saveInspection(inspection.copyWith(topics: updatedTopics));
      debugPrint('MediaService.moveMedia: Successfully moved media $mediaId');
      return true;
    } catch (e) {
      debugPrint('MediaService.moveMedia: Error moving media $mediaId: $e');
      return false;
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class MediaRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(OfflineMedia media) async {
    await DatabaseHelper.insertOfflineMedia(media);
    return media.id;
  }

  Future<void> update(OfflineMedia media) async {
    await DatabaseHelper.updateOfflineMedia(media);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteOfflineMedia(id);
  }

  Future<OfflineMedia?> findById(String id) async {
    return await DatabaseHelper.getOfflineMedia(id);
  }

  OfflineMedia fromMap(Map<String, dynamic> map) {
    return OfflineMedia.fromMap(map);
  }

  Map<String, dynamic> toMap(OfflineMedia entity) {
    return entity.toMap();
  }

  // Métodos específicos do OfflineMedia
  Future<List<OfflineMedia>> findByInspectionId(String inspectionId) async {
    return await DatabaseHelper.getOfflineMediaByInspection(inspectionId);
  }

  Future<List<OfflineMedia>> findByTopicId(String topicId) async {
    // Get only media that belongs directly to this topic level
    // Excludes media from items and details that should be handled separately
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        media.topicId == topicId &&
        media.itemId == null &&
        media.detailId == null &&
        media.nonConformityId == null).toList();
  }

  Future<List<OfflineMedia>> findByTopicDirectDetails(String topicId) async {
    // Get media from details that belong directly to a topic (direct_details = true)
    // These are details without an intermediate item
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        media.topicId == topicId &&
        media.itemId == null &&
        media.detailId != null &&
        media.nonConformityId == null).toList();
  }

  Future<List<OfflineMedia>> findByItemId(String itemId) async {
    // Get only media that belongs directly to this item (not its children)
    // Children (details) have their own media associations
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    final result = allMedia.where((media) =>
        media.itemId == itemId &&
        media.detailId == null &&
        media.nonConformityId == null).toList();

    // DEBUG: Check total media in database for this item
    if (result.isEmpty) {
      final totalForItem = allMedia.where((media) => media.itemId == itemId).toList();

      if (totalForItem.isNotEmpty) {
        debugPrint('MediaRepository: ISSUE - Found ${totalForItem.length} total media for item $itemId but 0 after filtering');
        for (final media in totalForItem) {
          debugPrint('MediaRepository: Media ${media.filename}: detail_id=${media.detailId}, nc_id=${media.nonConformityId}');
        }
      }
    }

    return result;
  }

  Future<List<OfflineMedia>> findByDetailId(String detailId) async {
    // Get all media that belongs to this detail or its children
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        media.detailId == detailId &&
        media.nonConformityId == null).toList();
  }

  Future<List<OfflineMedia>> findByNonConformityId(
      String nonConformityId) async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.nonConformityId == nonConformityId).toList();
  }

  Future<List<OfflineMedia>> findByType(String type) async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.type == type).toList();
  }

  Future<List<OfflineMedia>> findImages() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.type == 'image').toList();
  }

  Future<List<OfflineMedia>> findVideos() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.type == 'video').toList();
  }

  Future<List<OfflineMedia>> findProcessed() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia; // All media is considered processed
  }

  Future<List<OfflineMedia>> findUnprocessed() async {
    return []; // No unprocessed media with simplified model
  }

  Future<List<OfflineMedia>> findUploaded() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.isUploaded == true).toList();
  }

  Future<List<OfflineMedia>> findNotUploaded() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.isUploaded != true).toList();
  }

  Future<List<OfflineMedia>> findPendingUpload() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        // media.isProcessed == true && // Field removed
        media.isUploaded != true).toList();
  }

  Future<List<OfflineMedia>> findDeletedPendingSync() async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        media.needsSync == true).toList();
  }

  Future<List<OfflineMedia>> findByInspectionIdAndType(
      String inspectionId, String type) async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) =>
        media.inspectionId == inspectionId &&
        media.type == type).toList();
  }

  Future<void> markAsProcessed(String mediaId, String? processedPath) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        // isProcessed: true, // Field removed
        localPath: processedPath,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> markAsUploaded(String mediaId, String cloudUrl) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        isUploaded: true,
        cloudUrl: cloudUrl,
        uploadProgress: 100.0,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> updateUploadProgress(String mediaId, double progress) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        uploadProgress: progress,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> setThumbnail(String mediaId, String thumbnailPath) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        thumbnailPath: thumbnailPath,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> updateDimensions(String mediaId, int width, int height) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        width: width,
        height: height,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> updateDuration(String mediaId, int duration) async {
    final media = await findById(mediaId);
    if (media != null) {
      final updatedMedia = media.copyWith(
        duration: duration,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedMedia);
    }
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final mediaList = await findByInspectionId(inspectionId);
    for (final media in mediaList) {
      await delete(media.id);
    }
  }

  Future<void> deleteByTopicId(String topicId) async {
    final mediaList = await findByTopicId(topicId);
    for (final media in mediaList) {
      await delete(media.id);
    }
  }

  Future<void> deleteByItemId(String itemId) async {
    final mediaList = await findByItemId(itemId);
    for (final media in mediaList) {
      await delete(media.id);
    }
  }

  Future<void> deleteByDetailId(String detailId) async {
    final mediaList = await findByDetailId(detailId);
    for (final media in mediaList) {
      await delete(media.id);
    }
  }

  Future<void> deleteByNonConformityId(String nonConformityId) async {
    final mediaList = await findByNonConformityId(nonConformityId);
    for (final media in mediaList) {
      await delete(media.id);
    }
  }

  Future<int> countByInspectionId(String inspectionId) async {
    final mediaList = await findByInspectionId(inspectionId);
    return mediaList.length;
  }

  Future<int> countByInspectionIdAndType(
      String inspectionId, String type) async {
    final mediaList = await findByInspectionIdAndType(inspectionId, type);
    return mediaList.length;
  }

  Future<double> getTotalFileSizeByInspectionId(String inspectionId) async {
    final mediaList = await findByInspectionId(inspectionId);
    double totalSize = 0.0;
    for (final media in mediaList) {
      totalSize += media.fileSize ?? 0.0;
    }
    return totalSize;
  }

  Future<Map<String, int>> getMediaStatsByInspectionId(
      String inspectionId) async {
    final allMedia = await findByInspectionId(inspectionId);

    final total = allMedia.length;
    final images = allMedia.where((m) => m.type == 'image').length;
    final videos = allMedia.where((m) => m.type == 'video').length;
    final processed = allMedia.length; // All media considered processed
    final uploaded = allMedia.where((m) => m.isUploaded == true).length;
    final pendingUpload = allMedia.where((m) => m.isUploaded != true).length;

    return {
      'total': total,
      'images': images,
      'videos': videos,
      'processed': processed,
      'uploaded': uploaded,
      'pending_upload': pendingUpload,
    };
  }

  Future<List<OfflineMedia>> findByInspectionIdPaginated(
      String inspectionId, int limit, int offset) async {
    final allMedia = await findByInspectionId(inspectionId);
    allMedia.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final endIndex = (offset + limit).clamp(0, allMedia.length);
    if (offset >= allMedia.length) return [];

    return allMedia.sublist(offset, endIndex);
  }

  Future<List<OfflineMedia>> searchByFilename(String query) async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    final filtered = allMedia.where((media) =>
        media.filename.toLowerCase().contains(query.toLowerCase())).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<List<OfflineMedia>> findByFilename(String filename) async {
    final allMedia = DatabaseHelper.offlineMedia.values.toList();
    return allMedia.where((media) => media.filename == filename).toList();
  }

  Future<File> createLocalFile(String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'media'));

    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final filePath = path.join(mediaDir.path, filename);
    return File(filePath);
  }

  // Additional methods for compatibility
  Future<List<OfflineMedia>> findAll() async {
    return DatabaseHelper.offlineMedia.values.toList();
  }

  // REMOVED: markSynced - Always sync all data on demand

  // ===============================
  // MÉTODOS DE SINCRONIZAÇÃO ADICIONAIS
  // ===============================

  /// Buscar mídias que precisam ser sincronizadas
  Future<List<OfflineMedia>> findPendingSync() async {
    return await findPendingUpload(); // Reutilizar método existente
  }

}
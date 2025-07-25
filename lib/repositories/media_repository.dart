import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';

class MediaRepository extends BaseRepository<OfflineMedia> {
  @override
  String get tableName => 'offline_media';

  @override
  OfflineMedia fromMap(Map<String, dynamic> map) {
    return OfflineMedia.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(OfflineMedia entity) {
    return entity.toMap();
  }

  // Métodos específicos do OfflineMedia
  Future<List<OfflineMedia>> findByInspectionId(String inspectionId) async {
    return await findWhere('inspection_id = ?', [inspectionId]);
  }

  Future<List<OfflineMedia>> findByTopicId(String topicId) async {
    // Get only media that belongs directly to this topic level
    // Excludes media from items and details that should be handled separately
    return await findWhere(
      'topic_id = ? AND item_id IS NULL AND detail_id IS NULL AND non_conformity_id IS NULL', 
      [topicId]
    );
  }

  Future<List<OfflineMedia>> findByTopicDirectDetails(String topicId) async {
    // Get media from details that belong directly to a topic (direct_details = true)
    // These are details without an intermediate item
    return await findWhere(
      'topic_id = ? AND item_id IS NULL AND detail_id IS NOT NULL AND non_conformity_id IS NULL', 
      [topicId]
    );
  }

  Future<List<OfflineMedia>> findByItemId(String itemId) async {
    // Get only media that belongs directly to this item (not its children)
    // Children (details) have their own media associations
    final result = await findWhere(
      'item_id = ? AND detail_id IS NULL AND non_conformity_id IS NULL', 
      [itemId]
    );
    
    // DEBUG: Check total media in database for this item
    if (result.isEmpty) {
      final db = await database;
      final totalCount = await db.query(
        'offline_media',
        where: 'item_id = ?',
        whereArgs: [itemId],
      );
      
      if (totalCount.isNotEmpty) {
        debugPrint('MediaRepository: ISSUE - Found ${totalCount.length} total media for item $itemId but 0 after filtering');
        for (final media in totalCount) {
          debugPrint('MediaRepository: Media ${media['filename']}: deleted=${media['is_deleted']}, detail_id=${media['detail_id']}, nc_id=${media['non_conformity_id']}');
        }
      }
    }
    
    return result;
  }

  Future<List<OfflineMedia>> findByDetailId(String detailId) async {
    // Get all media that belongs to this detail or its children
    return await findWhere(
      'detail_id = ? AND non_conformity_id IS NULL', 
      [detailId]
    );
  }

  Future<List<OfflineMedia>> findByNonConformityId(
      String nonConformityId) async {
    return await findWhere('non_conformity_id = ?', [nonConformityId]);
  }

  Future<List<OfflineMedia>> findByType(String type) async {
    return await findWhere('type = ?', [type]);
  }

  Future<List<OfflineMedia>> findImages() async {
    return await findWhere('type = ?', ['image']);
  }

  Future<List<OfflineMedia>> findVideos() async {
    return await findWhere('type = ?', ['video']);
  }

  Future<List<OfflineMedia>> findProcessed() async {
    return await findWhere('is_processed = 1', []);
  }

  Future<List<OfflineMedia>> findUnprocessed() async {
    return await findWhere('is_processed = 0', []);
  }

  Future<List<OfflineMedia>> findUploaded() async {
    return await findWhere('is_uploaded = 1', []);
  }

  Future<List<OfflineMedia>> findNotUploaded() async {
    return await findWhere('is_uploaded = 0', []);
  }

  Future<List<OfflineMedia>> findPendingUpload() async {
    return await findWhere('is_processed = 1 AND is_uploaded = 0 AND is_deleted = 0', []);
  }

  Future<List<OfflineMedia>> findDeletedPendingSync() async {
    return await findWhere('is_deleted = 1 AND needs_sync = 1', []);
  }

  Future<List<OfflineMedia>> findByInspectionIdAndType(
      String inspectionId, String type) async {
    return await findWhere(
        'inspection_id = ? AND type = ?', [inspectionId, type]);
  }

  Future<void> markAsProcessed(String mediaId, String? processedPath) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_processed': 1,
        'local_path': processedPath,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> markAsUploaded(String mediaId, String cloudUrl) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_uploaded': 1,
        'cloud_url': cloudUrl,
        'upload_progress': 100.0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> updateUploadProgress(String mediaId, double progress) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'upload_progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> setThumbnail(String mediaId, String thumbnailPath) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'thumbnail_path': thumbnailPath,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> updateDimensions(String mediaId, int width, int height) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'width': width,
        'height': height,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> updateDuration(String mediaId, int duration) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'duration': duration,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<void> deleteByTopicId(String topicId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> deleteByItemId(String itemId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteByDetailId(String detailId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'detail_id = ?',
      whereArgs: [detailId],
    );
  }

  Future<void> deleteByNonConformityId(String nonConformityId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'non_conformity_id = ?',
      whereArgs: [nonConformityId],
    );
  }

  Future<int> countByInspectionId(String inspectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
      [inspectionId],
    );
    return result.first['count'] as int;
  }

  Future<int> countByInspectionIdAndType(
      String inspectionId, String type) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND type = ? AND is_deleted = 0',
      [inspectionId, type],
    );
    return result.first['count'] as int;
  }

  Future<double> getTotalFileSizeByInspectionId(String inspectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size) as total_size FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
      [inspectionId],
    );
    return (result.first['total_size'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, int>> getMediaStatsByInspectionId(
      String inspectionId) async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
          [inspectionId]),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND type = ? AND is_deleted = 0',
          [inspectionId, 'image']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND type = ? AND is_deleted = 0',
          [inspectionId, 'video']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_processed = 1 AND is_deleted = 0',
          [inspectionId]),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_uploaded = 1 AND is_deleted = 0',
          [inspectionId]),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_processed = 1 AND is_uploaded = 0 AND is_deleted = 0',
          [inspectionId]),
    ]);

    return {
      'total': results[0].first['count'] as int,
      'images': results[1].first['count'] as int,
      'videos': results[2].first['count'] as int,
      'processed': results[3].first['count'] as int,
      'uploaded': results[4].first['count'] as int,
      'pending_upload': results[5].first['count'] as int,
    };
  }

  Future<List<OfflineMedia>> findByInspectionIdPaginated(
      String inspectionId, int limit, int offset) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND is_deleted = 0',
      whereArgs: [inspectionId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<OfflineMedia>> searchByFilename(String query) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'filename LIKE ? AND is_deleted = 0',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<OfflineMedia>> findByFilename(String filename) async {
    return await findWhere('filename = ? AND is_deleted = 0', [filename]);
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
}

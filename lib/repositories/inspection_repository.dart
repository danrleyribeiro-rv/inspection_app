import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/repositories/base_repository.dart';
import 'package:inspection_app/services/core/firebase_service.dart';

class InspectionRepository extends BaseRepository<Inspection> {
  final FirebaseService _firebaseService;

  InspectionRepository({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  @override
  String get tableName => 'inspections';

  @override
  Inspection fromMap(Map<String, dynamic> map) {
    return Inspection.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Inspection entity) {
    return entity.toMap();
  }

  // Métodos específicos da Inspection
  Future<List<Inspection>> findByInspectorId(String inspectorId) async {
    return await findWhere('inspector_id = ?', [inspectorId]);
  }

  Future<List<Inspection>> findByStatus(String status) async {
    return await findWhere('status = ?', [status]);
  }

  Future<List<Inspection>> findByTemplateId(String templateId) async {
    return await findWhere('template_id = ?', [templateId]);
  }

  Future<List<Inspection>> getInspectionsNeedingSync() async {
    return await findWhere('needs_sync = ?', [1]);
  }

  Future<void> updateProgress(String inspectionId, double progressPercentage, int completedItems, int totalItems) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'progress_percentage': progressPercentage,
        'completed_items': completedItems,
        'total_items': totalItems,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<void> updateStatus(String inspectionId, String status) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<void> updateFirestoreData(String inspectionId, Map<String, dynamic> firestoreData) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'firestore_data': firestoreData.toString(),
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<int> countByStatus(String status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0',
      [status],
    );
    return result.first['count'] as int;
  }

  Future<int> countByInspectorId(String inspectorId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspector_id = ? AND is_deleted = 0',
      [inspectorId],
    );
    return result.first['count'] as int;
  }

  Future<double> getAverageProgress() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(progress_percentage) as avg_progress FROM $tableName WHERE is_deleted = 0',
    );
    return (result.first['avg_progress'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, int>> getInspectionStats() async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE is_deleted = 0'),
      db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0', ['pending']),
      db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0', ['in_progress']),
      db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0', ['completed']),
      db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE needs_sync = 1 AND is_deleted = 0'),
    ]);

    return {
      'total': results[0].first['count'] as int,
      'pending': results[1].first['count'] as int,
      'in_progress': results[2].first['count'] as int,
      'completed': results[3].first['count'] as int,
      'needs_sync': results[4].first['count'] as int,
    };
  }

  // --- Sincronização com Firestore ---

  Future<void> syncInspections() async {
    debugPrint('InspectionRepository: Starting full synchronization');
    await _downloadInspectionsFromCloud();
    await _uploadInspectionsToCloud();
    debugPrint('InspectionRepository: Full synchronization completed');
  }

  Future<void> _downloadInspectionsFromCloud() async {
    debugPrint('InspectionRepository: Downloading inspections from cloud');
    try {
      final List<Map<String, dynamic>> cloudInspectionsData =
          await _firebaseService.getUserInspections();

      for (final inspectionData in cloudInspectionsData) {
        final inspectionId = inspectionData['id'] as String;
        final existingInspection = await findById(inspectionId);

        // Convert Firestore Timestamps to DateTime
        final convertedData = _convertFirestoreTimestamps(inspectionData);
        final cloudInspection = Inspection.fromMap(convertedData);

        if (existingInspection == null) {
          // New inspection from cloud, save it
          await insertOrUpdate(cloudInspection);
          await markSynced(inspectionId);
          debugPrint('InspectionRepository: Downloaded new inspection $inspectionId');
        } else {
          // Existing inspection, check for conflicts or update
          if (cloudInspection.updatedAt.isAfter(existingInspection.updatedAt)) {
            await insertOrUpdate(cloudInspection);
            await markSynced(inspectionId);
            debugPrint('InspectionRepository: Updated existing inspection $inspectionId from cloud');
          } else {
            debugPrint('InspectionRepository: Skipping download for $inspectionId - local is newer');
          }
        }
      }
      debugPrint('InspectionRepository: Finished downloading inspections');
    } catch (e) {
      debugPrint('InspectionRepository: Error downloading inspections: $e');
    }
  }

  Future<void> _uploadInspectionsToCloud() async {
    debugPrint('InspectionRepository: Uploading inspections to cloud');
    try {
      final List<Inspection> pendingInspections = await findPendingSync();

      for (final inspection in pendingInspections) {
        try {
          // Prepare data for Firestore (remove 'id' as it's the doc ID)
          final Map<String, dynamic> dataToUpload = inspection.toJson();
          dataToUpload.remove('id');

          await _firebaseService.firestore
              .collection('inspections')
              .doc(inspection.id)
              .set(dataToUpload, SetOptions(merge: true));

          // Mark as synced in local storage
          await markSynced(inspection.id);
          debugPrint('InspectionRepository: Uploaded inspection ${inspection.id} to cloud');
        } catch (e) {
          debugPrint('InspectionRepository: Error uploading inspection ${inspection.id}: $e');
        }
      }
      debugPrint('InspectionRepository: Finished uploading inspections');
    } catch (e) {
      debugPrint('InspectionRepository: Error getting pending inspections for upload: $e');
    }
  }

  // Helper para converter timestamps do Firestore
  Map<String, dynamic> _convertFirestoreTimestamps(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map) {
        converted[key] = _convertFirestoreTimestamps(Map<String, dynamic>.from(value));
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Map) {
            return _convertFirestoreTimestamps(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });
    
    return converted;
  }
}

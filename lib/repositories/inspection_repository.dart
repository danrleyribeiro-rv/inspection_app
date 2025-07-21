import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';

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
    debugPrint('InspectionRepository: 🔍 Executando query para inspector_id: $inspectorId');
    debugPrint('InspectionRepository: 🔍 Query SQL: SELECT * FROM inspections WHERE inspector_id = ? AND is_deleted = 0');
    final result = await findWhere('inspector_id = ?', [inspectorId]);
    debugPrint('InspectionRepository: 📋 Query retornou ${result.length} inspeções');
    for (final inspection in result) {
      debugPrint('InspectionRepository: 📄 → "${inspection.title}" (ID: ${inspection.id}, Inspector: ${inspection.inspectorId})');
    }
    return result;
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

  Future<void> updateProgress(String inspectionId, double progressPercentage,
      int completedItems, int totalItems) async {
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

  Future<void> updateFirestoreData(
      String inspectionId, Map<String, dynamic> firestoreData) async {
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
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE is_deleted = 0'),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0',
          ['pending']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0',
          ['in_progress']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND is_deleted = 0',
          ['completed']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE needs_sync = 1 AND is_deleted = 0'),
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
          debugPrint(
              'InspectionRepository: Downloaded new inspection $inspectionId');
        } else {
          // Existing inspection, use intelligent merge instead of overwrite
          debugPrint(
              'InspectionRepository: Found existing inspection $inspectionId, using intelligent merge');
          
          // Create merged inspection preserving local changes
          final mergedInspection = _mergeInspectionData(existingInspection, cloudInspection);
          
          // Only update if merge produced changes
          if (mergedInspection != existingInspection) {
            await insertOrUpdate(mergedInspection);
            await markSynced(inspectionId);
            debugPrint(
                'InspectionRepository: Applied intelligent merge for inspection $inspectionId');
          } else {
            debugPrint(
                'InspectionRepository: No changes after merge for inspection $inspectionId');
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
          debugPrint(
              'InspectionRepository: Uploaded inspection ${inspection.id} to cloud');
        } catch (e) {
          debugPrint(
              'InspectionRepository: Error uploading inspection ${inspection.id}: $e');
        }
      }
      debugPrint('InspectionRepository: Finished uploading inspections');
    } catch (e) {
      debugPrint(
          'InspectionRepository: Error getting pending inspections for upload: $e');
    }
  }

  // Helper para converter timestamps do Firestore
  Map<String, dynamic> _convertFirestoreTimestamps(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map) {
        converted[key] =
            _convertFirestoreTimestamps(Map<String, dynamic>.from(value));
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

  // Intelligent merge to preserve local changes while applying cloud updates
  Inspection _mergeInspectionData(Inspection local, Inspection cloud) {
    debugPrint('InspectionRepository: Merging inspection data - preserving local changes');
    
    // Priority: Local filled values > Cloud filled values > Keep unchanged
    return local.copyWith(
      title: _mergeStringField(local.title, cloud.title),
      observation: _mergeStringField(local.observation, cloud.observation),
      status: local.status, // Always preserve local status (user might have progressed)
      
      // Address fields - merge intelligently, preserving cloud address object
      street: _mergeStringField(local.street, cloud.street),
      neighborhood: _mergeStringField(local.neighborhood, cloud.neighborhood),
      city: _mergeStringField(local.city, cloud.city),
      state: _mergeStringField(local.state, cloud.state),
      zipCode: _mergeStringField(local.zipCode, cloud.zipCode),
      addressString: _mergeStringField(local.addressString, cloud.addressString),
      
      // Preserve cloud address object if exists
      address: cloud.address ?? local.address,
      
      // Other fields that might have been updated in cloud
      projectId: cloud.projectId ?? local.projectId,
      templateId: cloud.templateId ?? local.templateId,
      inspectorId: cloud.inspectorId ?? local.inspectorId,
      scheduledDate: cloud.scheduledDate ?? local.scheduledDate,
      
      // Preserve local modification state
      updatedAt: local.updatedAt.isAfter(cloud.updatedAt) ? local.updatedAt : cloud.updatedAt,
      
      // Preserve nested structures (topics should be handled separately)
      topics: local.topics?.isNotEmpty == true ? local.topics : cloud.topics,
    );
  }

  // Helper to merge string fields - preserves filled local values
  String? _mergeStringField(String? localValue, String? cloudValue) {
    // If local has content, keep it (user might have edited)
    if (localValue != null && localValue.trim().isNotEmpty) {
      return localValue;
    }
    
    // If local is empty/null but cloud has content, use cloud
    if (cloudValue != null && cloudValue.trim().isNotEmpty) {
      return cloudValue;
    }
    
    // Both empty/null - return null
    return null;
  }
}

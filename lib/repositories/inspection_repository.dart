import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class InspectionRepository {
  final FirebaseService _firebaseService;

  InspectionRepository({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(Inspection inspection) async {
    await DatabaseHelper.insertInspection(inspection);
    return inspection.id;
  }

  Future<void> update(Inspection inspection) async {
    await DatabaseHelper.updateInspection(inspection);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteInspection(id);
  }

  Future<Inspection?> findById(String id) async {
    return await DatabaseHelper.getInspection(id);
  }

  Future<List<Inspection>> findAll() async {
    return await DatabaseHelper.getAllInspections();
  }

  Inspection fromMap(Map<String, dynamic> map) {
    return Inspection.fromMap(map);
  }

  Map<String, dynamic> toMap(Inspection entity) {
    return entity.toMap();
  }

  // Métodos específicos da Inspection
  Future<List<Inspection>> findByInspectorId(String inspectorId) async {
    debugPrint('InspectionRepository: 🔍 Executando query para inspector_id: $inspectorId');
    final allInspections = DatabaseHelper.inspections.values.toList();
    final result = allInspections.where((inspection) => inspection.inspectorId == inspectorId).toList();
    debugPrint('InspectionRepository: 📋 Query retornou ${result.length} inspeções');
    for (final inspection in result) {
      debugPrint('InspectionRepository: 📄 → "${inspection.title}" (ID: ${inspection.id}, Inspector: ${inspection.inspectorId})');
    }
    return result;
  }

  Future<List<Inspection>> findByStatus(String status) async {
    final allInspections = DatabaseHelper.inspections.values.toList();
    return allInspections.where((inspection) => inspection.status == status).toList();
  }

  Future<List<Inspection>> findByTemplateId(String templateId) async {
    final allInspections = DatabaseHelper.inspections.values.toList();
    return allInspections.where((inspection) => inspection.templateId == templateId).toList();
  }

  Future<List<Inspection>> getInspectionsNeedingSync() async {
    final allInspections = DatabaseHelper.inspections.values.toList();
    return allInspections.where((inspection) => inspection.needsSync == true).toList();
  }

  // Aliases for cloud sync compatibility
  Future<List<Inspection>> findPendingSync() async {
    return await getInspectionsNeedingSync();
  }

  Future<void> insertOrUpdate(Inspection inspection) async {
    final existing = await findById(inspection.id);
    if (existing != null) {
      await update(inspection);
    } else {
      await insert(inspection);
    }
  }

  Future<void> insertOrUpdateFromCloud(Inspection inspection) async {
    final existing = await findById(inspection.id);
    final inspectionToSave = inspection.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(inspectionToSave);
    } else {
      await insert(inspectionToSave);
    }
  }

  // REMOVED: markSynced - Always sync all data on demand

  Future<void> updateProgress(String inspectionId, double progressPercentage,
      int completedItems, int totalItems) async {
    final inspection = await findById(inspectionId);
    if (inspection != null) {
      final updatedInspection = inspection.copyWith(
        updatedAt: DateFormatter.now(),
        needsSync: true,
      );
      await update(updatedInspection);
    }
  }

  Future<void> updateStatus(String inspectionId, String status) async {
    final inspection = await findById(inspectionId);
    if (inspection != null) {
      final updatedInspection = inspection.copyWith(
        status: status,
        updatedAt: DateFormatter.now(),
        needsSync: true,
      );
      await update(updatedInspection);
    }
  }

  Future<void> updateFirestoreData(
      String inspectionId, Map<String, dynamic> firestoreData) async {
    final inspection = await findById(inspectionId);
    if (inspection != null) {
      final updatedInspection = inspection.copyWith(
        updatedAt: DateFormatter.now(),
        needsSync: true,
      );
      await update(updatedInspection);
    }
  }

  Future<void> markAsSynced(String inspectionId, {String? status}) async {
    final inspection = await findById(inspectionId);
    if (inspection != null) {
      final updatedInspection = inspection.copyWith(
        hasLocalChanges: false,
        needsSync: false,
        isSynced: true,
        lastSyncAt: DateTime.now(),
        updatedAt: DateFormatter.now(),
        status: status ?? inspection.status,
      );
      await update(updatedInspection);
    }
    debugPrint('InspectionRepository: Marked inspection $inspectionId as synced');
  }

  Future<int> countByStatus(String status) async {
    final inspectionsByStatus = await findByStatus(status);
    return inspectionsByStatus.length;
  }

  Future<int> countByInspectorId(String inspectorId) async {
    final inspectionsByInspector = await findByInspectorId(inspectorId);
    return inspectionsByInspector.length;
  }

  Future<double> getAverageProgress() async {
    final allInspections = await findAll();
    if (allInspections.isEmpty) return 0.0;

    // Since we don't have a progress field in the model, return 0.0
    // This method can be updated when progress tracking is implemented
    return 0.0;
  }

  Future<Map<String, int>> getInspectionStats() async {
    final allInspections = await findAll();

    final total = allInspections.length;
    final pending = allInspections.where((i) => i.status == 'pending').length;
    final inProgress = allInspections.where((i) => i.status == 'in_progress').length;
    final completed = allInspections.where((i) => i.status == 'completed').length;
    final needsSync = allInspections.where((i) => i.needsSync == true).length;

    return {
      'total': total,
      'pending': pending,
      'in_progress': inProgress,
      'completed': completed,
      'needs_sync': needsSync,
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
          // REMOVED: markSynced - Always sync all data on demand
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
            // REMOVED: markSynced - Always sync all data on demand
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

          // REMOVED: markSynced - Always sync all data on demand
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

  // ===============================
  // MÉTODOS DE SINCRONIZAÇÃO ADICIONAIS
  // ===============================

  // REMOVED: markAllSynced - Always sync all data on demand
}

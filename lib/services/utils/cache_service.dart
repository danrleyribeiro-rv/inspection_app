import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/models/cached_inspection.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/utils/sync_service.dart';
import 'package:inspection_app/services/inspection_coordinator.dart';

class CacheService {
  static const String _inspectionsBoxName = 'inspections';
  
  final InspectionService _inspectionService = InspectionService();
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();
  final InspectionCoordinator _coordinator = InspectionCoordinator();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CachedInspectionAdapter());
    await Hive.openBox<CachedInspection>(_inspectionsBoxName);
  }

  Box<CachedInspection> get _inspectionsBox => Hive.box<CachedInspection>(_inspectionsBoxName);

  void initializeSync() {
    _syncService.initialize();
  }

  void dispose() {
    _syncService.dispose();
  }

  // Cache operations
  Future<void> cacheInspection(String id, Map<String, dynamic> data) async {
    final cached = CachedInspection(
      id: id,
      data: data,
      lastUpdated: DateTime.now(),
      needsSync: false,
    );
    await _inspectionsBox.put(id, cached);
  }

  CachedInspection? getCachedInspection(String id) {
    return _inspectionsBox.get(id);
  }

  Future<void> markForSync(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = true;
      await cached.save();
    }
  }

  List<CachedInspection> getInspectionsNeedingSync() {
    return _inspectionsBox.values.where((inspection) => inspection.needsSync).toList();
  }

  Future<void> markSynced(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> clearCache() async {
    await _inspectionsBox.clear();
  }

  // Offline operations
  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
  }

  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      if (await _isOnline()) {
        final inspection = await _inspectionService.getInspection(inspectionId);
        if (inspection != null) {
          await cacheInspection(inspectionId, inspection.toMap());
          return inspection;
        }
      }

      final cached = getCachedInspection(inspectionId);
      if (cached != null) {
        return Inspection.fromMap({'id': cached.id, ...cached.data});
      }

      return null;
    } catch (e) {
      print('Error getting inspection: $e');
      return null;
    }
  }

  Future<void> saveInspection(Inspection inspection) async {
    try {
      await cacheInspection(inspection.id, inspection.toMap());
      await markForSync(inspection.id);

      if (await _isOnline()) {
        try {
          await _inspectionService.saveInspection(inspection);
          await markSynced(inspection.id);
        } catch (e) {
          print('Error saving to Firebase: $e');
        }
      }
    } catch (e) {
      print('Error saving inspection: $e');
      rethrow;
    }
  }

  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      if (await _isOnline()) {
        return await _coordinator.getTopics(inspectionId);
      }
      final cached = getCachedInspection(inspectionId);
      if (cached != null) {
        return _coordinator.getTopics(inspectionId);
      }
      return [];
    } catch (e) {
      print('Error getting topics: $e');
      return [];
    }
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position}) async {
    return await _coordinator.addTopic(
      inspectionId,
      topicName,
      label: label,
      position: position,
    );
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    await _coordinator.updateTopic(updatedTopic);
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    await _coordinator.deleteTopic(inspectionId, topicId);
  }

  Future<Topic> duplicateTopic(String inspectionId, String topicName) async {
    return await _coordinator.duplicateTopic(inspectionId, topicName);
  }

  Future<void> forceSyncAll() async {
    await _syncService.forceSyncAll();
  }

  bool hasPendingSync() {
    return _syncService.hasPendingSync();
  }
}
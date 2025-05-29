import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/utils/sync_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/inspection_coordinator.dart';
import 'package:inspection_app/models/topic.dart';

class OfflineService {
  final CacheService _cacheService = CacheService();
  final InspectionService _inspectionService = InspectionService();
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();
  final InspectionCoordinator _coordinator = InspectionCoordinator();

  void initialize() {
    _syncService.initialize();
  }

  void dispose() {
    _syncService.dispose();
  }

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
          await _cacheService.cacheInspection(inspectionId, inspection.toMap());
          return inspection;
        }
      }

      final cached = _cacheService.getCachedInspection(inspectionId);
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
      await _cacheService.cacheInspection(inspection.id, inspection.toMap());
      await _cacheService.markForSync(inspection.id);

      if (await _isOnline()) {
        try {
          await _inspectionService.saveInspection(inspection);
          await _cacheService.markSynced(inspection.id);
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
      final cached = _cacheService.getCachedInspection(inspectionId);
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
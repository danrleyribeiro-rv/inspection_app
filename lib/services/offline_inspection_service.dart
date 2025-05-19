import 'package:inspection_app/services/cache_service.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineInspectionService {
  final CacheService _cacheService = CacheService();
  final InspectionDataService _inspectionService = InspectionDataService();
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();

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
      // Try Firebase first if online
      if (await _isOnline()) {
        final inspection = await _inspectionService.getInspection(inspectionId);
        if (inspection != null) {
          await _cacheService.cacheInspection(inspectionId, inspection.toMap());
          return inspection;
        }
      }

      // Fallback to cache
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
      // Always save to cache first
      await _cacheService.cacheInspection(inspection.id, inspection.toMap());
      await _cacheService.markForSync(inspection.id);

      // Try to save to Firebase if online
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

  // Convenience methods para extrair dados da estrutura aninhada
  List<Map<String, dynamic>> getTopics(String inspectionId) {
    final cached = _cacheService.getCachedInspection(inspectionId);
    if (cached?.data['topics'] is List) {
      return List<Map<String, dynamic>>.from(cached!.data['topics']);
    }
    return [];
  }

  Future<void> forceSyncAll() async {
    await _syncService.forceSyncAll();
  }

  bool hasPendingSync() {
    return _syncService.hasPendingSync();
  }
}
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/models/inspection.dart';

class SyncService {
  final CacheService _cacheService = CacheService();
  final InspectionService _inspectionService = InspectionService();
  final Connectivity _connectivity = Connectivity();
  
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result.contains(ConnectivityResult.wifi) || 
                      result.contains(ConnectivityResult.mobile);
      if (isOnline && !_isSyncing) {
        _syncAll();
      }
    });
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) || 
                      connectivityResult.contains(ConnectivityResult.mobile);

      if (!isOnline) {
        _isSyncing = false;
        return;
      }

      final inspectionsToSync = _cacheService.getInspectionsNeedingSync();
      
      for (final cachedInspection in inspectionsToSync) {
        try {
          final inspection = Inspection.fromMap({
            'id': cachedInspection.id,
            ...cachedInspection.data,
          });
          
          await _inspectionService.saveInspection(inspection);
          await _cacheService.markSynced(cachedInspection.id);
        } catch (e) {
          print('Error syncing inspection ${cachedInspection.id}: $e');
        }
      }
    } catch (e) {
      print('Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> forceSyncAll() async {
    await _syncAll();
  }

  bool hasPendingSync() {
    return _cacheService.getInspectionsNeedingSync().isNotEmpty;
  }
}
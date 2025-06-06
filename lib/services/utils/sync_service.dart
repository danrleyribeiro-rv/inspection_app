//lib/services/utils/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/models/inspection.dart';

class SyncService {
  // Recebe a instância do CacheService via injeção de dependência.
  final CacheService _cacheService;
  final InspectionService _inspectionService = InspectionService();
  final Connectivity _connectivity = Connectivity();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;

  // O construtor agora exige uma instância de CacheService.
  SyncService({required CacheService cacheService})
      : _cacheService = cacheService;

  void initialize() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
      if (isOnline && !_isSyncing) {
        _syncAll();
      }
    });
    // Tenta uma sincronização inicial caso já esteja online.
    _syncAll();
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
      if (inspectionsToSync.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('Syncing ${inspectionsToSync.length} inspections...');

      for (final cachedInspection in inspectionsToSync) {
        try {
          final inspection = Inspection.fromMap({
            'id': cachedInspection.id,
            ...cachedInspection.data,
          });

          await _inspectionService.saveInspection(inspection);
          await _cacheService.markSynced(cachedInspection.id);
          debugPrint('Successfully synced inspection ${cachedInspection.id}');
        } catch (e) {
          debugPrint('Error syncing inspection ${cachedInspection.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during sync process: $e');
    } finally {
      _isSyncing = false;
      debugPrint('Sync process finished.');
    }
  }

  Future<void> forceSyncAll() async {
    await _syncAll();
  }

  bool hasPendingSync() {
    return _cacheService.getInspectionsNeedingSync().isNotEmpty;
  }
}

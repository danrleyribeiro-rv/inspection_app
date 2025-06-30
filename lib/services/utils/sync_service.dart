//lib/services/utils/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/models/inspection.dart';

class SyncService {
  // Recebe a instância do CacheService via injeção de dependência.
  final CacheService _cacheService;
  final InspectionService _inspectionService = InspectionService();
  final MediaService _mediaService = MediaService();
  final Connectivity _connectivity = Connectivity();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;
  
  // Controllers para notificar o progresso de sincronização
  final StreamController<SyncProgress> _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

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
    _syncProgressController.close();
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
      _syncProgressController.add(SyncProgress(
        total: inspectionsToSync.length,
        current: 0,
        phase: SyncPhase.starting,
        message: 'Iniciando sincronização...',
      ));

      for (int i = 0; i < inspectionsToSync.length; i++) {
        final cachedInspection = inspectionsToSync[i];
        try {
          // Notificar progresso atual
          _syncProgressController.add(SyncProgress(
            total: inspectionsToSync.length,
            current: i,
            phase: SyncPhase.syncingInspection,
            message: 'Sincronizando inspeção ${cachedInspection.id}...',
          ));

          final inspection = Inspection.fromMap({
            'id': cachedInspection.id,
            ...Map<String, dynamic>.from(cachedInspection.data),
          });

          // Sincronizar dados da inspeção
          await _inspectionService.saveInspection(inspection);
          
          // Sincronizar imagens pendentes da inspeção
          await _syncInspectionMedia(cachedInspection.id);
          
          await _cacheService.markSynced(cachedInspection.id);
          debugPrint('Successfully synced inspection ${cachedInspection.id}');
        } catch (e) {
          debugPrint('Error syncing inspection ${cachedInspection.id}: $e');
        }
      }
      
      // Notificar conclusão
      _syncProgressController.add(SyncProgress(
        total: inspectionsToSync.length,
        current: inspectionsToSync.length,
        phase: SyncPhase.completed,
        message: 'Sincronização concluída!',
      ));
    } catch (e) {
      debugPrint('Error during sync process: $e');
      _syncProgressController.add(SyncProgress(
        total: 0,
        current: 0,
        phase: SyncPhase.error,
        message: 'Erro na sincronização: $e',
      ));
    } finally {
      _isSyncing = false;
      debugPrint('Sync process finished.');
    }
  }
  
  Future<void> _syncInspectionMedia(String inspectionId) async {
    try {
      // Buscar todas as mídias pendentes de upload para esta inspeção
      final pendingMedia = await _cacheService.getPendingMediaForInspection(inspectionId);
      
      for (final mediaItem in pendingMedia) {
        try {
          // Fazer upload da mídia usando o método existente
          final downloadUrl = await _mediaService.uploadCachedMedia(
            localPath: mediaItem['localPath'],
            inspectionId: inspectionId,
            topicId: mediaItem['topicId'],
            itemId: mediaItem['itemId'],
            detailId: mediaItem['detailId'],
          );
          
          // Marcar como sincronizada no cache
          await _cacheService.markMediaSynced(mediaItem['id']);
          
          debugPrint('Successfully uploaded media ${mediaItem['id']}: $downloadUrl');
        } catch (e) {
          debugPrint('Error uploading media ${mediaItem['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error syncing media for inspection $inspectionId: $e');
    }
  }

  Future<void> forceSyncAll() async {
    await _syncAll();
  }
  
  Future<void> syncSingleInspection(String inspectionId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile);

      if (!isOnline) {
        throw Exception('Sem conexão com a internet');
      }
      
      var cachedInspection = _cacheService.getCachedInspection(inspectionId);
      
      // Se não estiver no cache, tentar buscar primeiro
      if (cachedInspection == null) {
        try {
          await _cacheService.getInspection(inspectionId);
          cachedInspection = _cacheService.getCachedInspection(inspectionId);
        } catch (e) {
          debugPrint('Error fetching inspection for sync: $e');
        }
      }
      
      if (cachedInspection == null) {
        throw Exception('Inspeção não encontrada e não pôde ser carregada');
      }
      
      _syncProgressController.add(SyncProgress(
        total: 1,
        current: 0,
        phase: SyncPhase.syncingInspection,
        message: 'Sincronizando inspeção...',
      ));
      
      final inspection = Inspection.fromMap({
        'id': cachedInspection.id,
        ...Map<String, dynamic>.from(cachedInspection.data),
      });
      
      // Sincronizar dados da inspeção
      await _inspectionService.saveInspection(inspection);
      
      // Sincronizar imagens pendentes da inspeção
      await _syncInspectionMedia(inspectionId);
      
      await _cacheService.markSynced(inspectionId);
      
      _syncProgressController.add(SyncProgress(
        total: 1,
        current: 1,
        phase: SyncPhase.completed,
        message: 'Inspeção sincronizada com sucesso!',
      ));
    } catch (e) {
      _syncProgressController.add(SyncProgress(
        total: 1,
        current: 0,
        phase: SyncPhase.error,
        message: 'Erro ao sincronizar: $e',
      ));
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  bool hasPendingSync() {
    return _cacheService.getInspectionsNeedingSync().isNotEmpty;
  }
  
  bool isInspectionSynced(String inspectionId) {
    return _cacheService.isInspectionSynced(inspectionId);
  }
}

class SyncProgress {
  final int total;
  final int current;
  final SyncPhase phase;
  final String message;
  
  SyncProgress({
    required this.total,
    required this.current,
    required this.phase,
    required this.message,
  });
  
  double get progress => total > 0 ? current / total : 0.0;
}

enum SyncPhase {
  starting,
  syncingInspection,
  syncingMedia,
  completed,
  error,
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';
import 'package:lince_inspecoes/services/media_download_verification_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';

class NativeSyncService {
  // Singleton pattern
  static NativeSyncService? _instance;
  static NativeSyncService get instance {
    _instance ??= NativeSyncService._internal();
    return _instance!;
  }
  
  NativeSyncService._internal();
  
  // Stream controller for sync progress
  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  // Initialize service
  Future<void> initialize() async {
    await SimpleNotificationService.instance.initialize();
  }
  
  // Start background sync for specific inspection
  Future<void> startInspectionSync(String inspectionId) async {
    if (_isSyncing) {
      debugPrint('NativeSyncService: Sync already in progress');
      return;
    }
    
    _isSyncing = true;
    
    try {
      // Show starting notification
      await SimpleNotificationService.instance.showSyncProgress(
        title: 'Sincronizando inspeção',
        message: 'Preparando sincronização...',
        indeterminate: true,
      );
      
      // Emit starting progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.starting,
        current: 0,
        total: 1,
        message: 'Preparando sincronização...',
      ));
      
      // Update notification to uploading
      await SimpleNotificationService.instance.showSyncProgress(
        title: 'Sincronizando inspeção',
        message: 'Enviando dados...',
        indeterminate: true,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: 0,
        total: 1,
        message: 'Enviando dados...',
      ));
      
      // Start sync
      final result = await FirestoreSyncService.instance.syncInspection(inspectionId);
      
      if (result['success'] == true) {
        // Success notification
        await SimpleNotificationService.instance.showCompletionNotification(
          title: 'Sincronização concluída',
          message: 'Inspeção sincronizada com sucesso!',
          isSuccess: true,
        );
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.completed,
          current: 1,
          total: 1,
          message: 'Sincronização concluída com sucesso!',
        ));
        
        // Hide notification after 3 seconds
        Timer(const Duration(seconds: 3), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      } else {
        // Error notification
        String errorMessage = result['error'] ?? 'Erro desconhecido';
        await SimpleNotificationService.instance.showErrorNotification(
          title: 'Erro na sincronização',
          message: errorMessage,
        );
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.error,
          current: 1,
          total: 1,
          message: errorMessage,
        ));
        
        // Hide notification after 5 seconds
        Timer(const Duration(seconds: 5), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      }
    } catch (e) {
      // Error notification
      String errorMessage = 'Erro na sincronização: $e';
      await SimpleNotificationService.instance.showErrorNotification(
        title: 'Erro na sincronização',
        message: errorMessage,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 1,
        total: 1,
        message: errorMessage,
      ));
      
      // Hide notification after 5 seconds
      Timer(const Duration(seconds: 5), () {
        SimpleNotificationService.instance.hideAllNotifications();
      });
    } finally {
      _isSyncing = false;
    }
  }
  
  // Start background download for specific inspection
  Future<void> startInspectionDownload(String inspectionId) async {
    if (_isSyncing) {
      debugPrint('NativeSyncService: Download already in progress');
      return;
    }
    
    _isSyncing = true;
    
    try {
      // Show starting notification IMMEDIATELY
      await SimpleNotificationService.instance.showDownloadProgress(
        title: 'Iniciando Download',
        message: 'Download da inspeção iniciado...',
        indeterminate: true,
      );
      
      // Emit starting progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.starting,
        current: 0,
        total: 1,
        message: 'Preparando download...',
      ));
      
      // Update notification to downloading
      await SimpleNotificationService.instance.showDownloadProgress(
        title: 'Baixando inspeção',
        message: 'Recebendo dados e imagens...',
        indeterminate: true,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.downloading,
        current: 0,
        total: 1,
        message: 'Baixando dados e imagens...',
      ));
      
      // Start download
      final result = await FirestoreSyncService.instance.syncInspection(inspectionId);
      
      if (result['success'] == true) {
        // Verificar se todas as mídias foram baixadas
        final mediaStatus = await MediaDownloadVerificationService.instance.checkInspectionMediaDownloadStatus(inspectionId);
        
        String completionMessage;
        if (mediaStatus.totalMedia == 0) {
          completionMessage = 'Inspeção baixada com sucesso!';
        } else if (mediaStatus.isComplete) {
          completionMessage = 'Inspeção baixada com sucesso! ${mediaStatus.downloadedMedia} imagens incluídas.';
        } else {
          completionMessage = 'Inspeção baixada! ${mediaStatus.downloadedMedia}/${mediaStatus.totalMedia} imagens baixadas.';
        }
        
        // Success notification
        await SimpleNotificationService.instance.showCompletionNotification(
          title: 'Download concluído',
          message: completionMessage,
          isSuccess: true,
        );
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.completed,
          current: 1,
          total: 1,
          message: completionMessage,
        ));
        
        // Hide notification after 5 seconds (more time to read media info)
        Timer(const Duration(seconds: 5), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      } else {
        // Error notification
        String errorMessage = result['error'] ?? 'Erro desconhecido';
        await SimpleNotificationService.instance.showErrorNotification(
          title: 'Erro no download',
          message: errorMessage,
        );
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.error,
          current: 1,
          total: 1,
          message: errorMessage,
        ));
        
        // Hide notification after 5 seconds
        Timer(const Duration(seconds: 5), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      }
    } catch (e) {
      // Error notification
      String errorMessage = 'Erro no download: $e';
      await SimpleNotificationService.instance.showErrorNotification(
        title: 'Erro no download',
        message: errorMessage,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 1,
        total: 1,
        message: errorMessage,
      ));
      
      // Hide notification after 5 seconds
      Timer(const Duration(seconds: 5), () {
        SimpleNotificationService.instance.hideAllNotifications();
      });
    } finally {
      _isSyncing = false;
    }
  }
  
  // Start full sync
  Future<void> startFullSync() async {
    if (_isSyncing) {
      debugPrint('NativeSyncService: Full sync already in progress');
      return;
    }
    
    _isSyncing = true;
    
    try {
      // Show starting notification
      await SimpleNotificationService.instance.showSyncProgress(
        title: 'Sincronização completa',
        message: 'Preparando sincronização...',
        indeterminate: true,
      );
      
      // Emit starting progress
      _syncProgressController.add(SyncProgress(
        inspectionId: 'all',
        phase: SyncPhase.starting,
        current: 0,
        total: 1,
        message: 'Preparando sincronização...',
      ));
      
      // Update notification to syncing
      await SimpleNotificationService.instance.showSyncProgress(
        title: 'Sincronização completa',
        message: 'Sincronizando todas as inspeções...',
        indeterminate: true,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'all',
        phase: SyncPhase.uploading,
        current: 0,
        total: 1,
        message: 'Sincronizando todas as inspeções...',
      ));
      
      // Start full sync
      await FirestoreSyncService.instance.performFullSync();
      
      // Success notification
      await SimpleNotificationService.instance.showCompletionNotification(
        title: 'Sincronização completa',
        message: 'Todas as inspeções foram sincronizadas!',
        isSuccess: true,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'all',
        phase: SyncPhase.completed,
        current: 1,
        total: 1,
        message: 'Sincronização completa concluída!',
      ));
      
      // Hide notification after 3 seconds
      Timer(const Duration(seconds: 3), () {
        SimpleNotificationService.instance.hideAllNotifications();
      });
    } catch (e) {
      // Error notification
      String errorMessage = 'Erro na sincronização: $e';
      await SimpleNotificationService.instance.showErrorNotification(
        title: 'Erro na sincronização',
        message: errorMessage,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'all',
        phase: SyncPhase.error,
        current: 1,
        total: 1,
        message: errorMessage,
      ));
      
      // Hide notification after 5 seconds
      Timer(const Duration(seconds: 5), () {
        SimpleNotificationService.instance.hideAllNotifications();
      });
    } finally {
      _isSyncing = false;
    }
  }
  
  // Dispose resources
  void dispose() {
    _syncProgressController.close();
  }
}
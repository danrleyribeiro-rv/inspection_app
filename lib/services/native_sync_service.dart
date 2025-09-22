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
      // Subscribe to detailed progress from FirestoreSyncService
      late StreamSubscription progressSubscription;
      progressSubscription = FirestoreSyncService.instance.syncProgressStream.listen((progress) {
        if (progress.inspectionId == inspectionId || progress.inspectionId == 'multiple') {
          // Forward progress to our stream
          _syncProgressController.add(progress);
          
          // Update native notifications with detailed info
          _updateNativeNotificationFromProgress(progress);
        }
      });
      
      // Start enhanced sync with verification
      final result = await FirestoreSyncService.instance.syncInspection(inspectionId);

      // Clean up subscription safely
      try {
        await progressSubscription.cancel();
      } catch (e) {
        debugPrint('NativeSyncService: Error canceling progress subscription: $e');
      }
      
      if (result['success'] == true) {
        final verification = result['verification'];
        String successMessage = 'Inspeção sincronizada com sucesso!';
        
        if (verification != null) {
          successMessage = 'Sincronização completa e verificada na nuvem!';
        }
        
        // Success notification
        await SimpleNotificationService.instance.showCompletionNotification(
          title: 'Sincronização concluída',
          message: successMessage,
          isSuccess: true,
        );
        
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

  // Start sync for multiple inspections
  Future<void> startMultipleInspectionsSync(List<String> inspectionIds) async {
    if (_isSyncing) {
      debugPrint('NativeSyncService: Multiple sync already in progress');
      return;
    }
    
    _isSyncing = true;
    
    try {
      // Subscribe to detailed progress from FirestoreSyncService
      late StreamSubscription progressSubscription;
      progressSubscription = FirestoreSyncService.instance.syncProgressStream.listen((progress) {
        // Forward progress to our stream
        _syncProgressController.add(progress);
        
        // Update native notifications with detailed info including inspection count
        _updateNativeNotificationFromProgress(progress);
      });
      
      // Start enhanced multiple inspections sync
      final result = await FirestoreSyncService.instance.syncMultipleInspections(inspectionIds);

      // Clean up subscription safely
      try {
        await progressSubscription.cancel();
      } catch (e) {
        debugPrint('NativeSyncService: Error canceling progress subscription: $e');
      }
      
      if (result['success'] == true) {
        final successCount = result['successCount'] ?? 0;
        final totalCount = result['totalInspections'] ?? inspectionIds.length;
        
        // Success notification with count
        await SimpleNotificationService.instance.showCompletionNotification(
          title: 'Sincronização de $totalCount vistorias concluída',
          message: 'Todas as $successCount inspeções foram sincronizadas com sucesso!',
          isSuccess: true,
        );
        
        // Hide notification after 4 seconds
        Timer(const Duration(seconds: 4), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      } else {
        final successCount = result['successCount'] ?? 0;
        final failureCount = result['failureCount'] ?? 0;
        final totalCount = result['totalInspections'] ?? inspectionIds.length;
        
        // Partial success notification
        await SimpleNotificationService.instance.showErrorNotification(
          title: 'Sincronização de $totalCount vistorias concluída',
          message: '$successCount sincronizadas, $failureCount falharam',
        );
        
        // Hide notification after 5 seconds
        Timer(const Duration(seconds: 5), () {
          SimpleNotificationService.instance.hideAllNotifications();
        });
      }
    } catch (e) {
      // Error notification
      String errorMessage = 'Erro na sincronização múltipla: $e';
      await SimpleNotificationService.instance.showErrorNotification(
        title: 'Erro na sincronização',
        message: errorMessage,
      );
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: SyncPhase.error,
        current: 0,
        total: inspectionIds.length,
        message: errorMessage,
        totalInspections: inspectionIds.length,
      ));
      
      // Hide notification after 5 seconds
      Timer(const Duration(seconds: 5), () {
        SimpleNotificationService.instance.hideAllNotifications();
      });
    } finally {
      _isSyncing = false;
    }
  }

  void _updateNativeNotificationFromProgress(SyncProgress progress) {
    switch (progress.phase) {
      case SyncPhase.starting:
        String message = progress.totalInspections != null && progress.totalInspections! > 1
            ? 'Preparando sincronização de ${progress.totalInspections} vistorias...'
            : 'Preparando sincronização...';
        SimpleNotificationService.instance.showSyncProgress(
          title: 'Sincronizando',
          message: message,
          indeterminate: true,
        );
        break;
      
      case SyncPhase.uploading:
        String message = progress.message;
        if (progress.currentItem != null) {
          message += '\n${progress.currentItem}';
        }
        if (progress.totalInspections != null && progress.totalInspections! > 1) {
          message += '\nVistoria ${progress.currentInspectionIndex ?? 1} de ${progress.totalInspections}';
        }
        
        SimpleNotificationService.instance.showSyncProgress(
          title: 'Enviando dados',
          message: message,
          progress: (progress.progress * 100).round(),
          indeterminate: false,
        );
        break;
      
      case SyncPhase.downloading:
        String message = progress.message;
        if (progress.currentItem != null) {
          message += '\n${progress.currentItem}';
        }
        
        SimpleNotificationService.instance.showDownloadProgress(
          title: 'Baixando dados',
          message: message,
          progress: (progress.progress * 100).round(),
          indeterminate: false,
        );
        break;
      
      case SyncPhase.verifying:
        String message = 'Verificação rápida na nuvem...';
        if (progress.currentItem != null) {
          message = progress.currentItem!;
        }
        SimpleNotificationService.instance.showSyncProgress(
          title: 'Verificando na nuvem',
          message: message,
          progress: (progress.progress * 100).round(),
          indeterminate: progress.progress == 0,
        );
        break;
      
      case SyncPhase.completed:
      case SyncPhase.error:
        // These are handled in the main sync methods
        break;
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
        bool isSuccess = true;
        
        if (mediaStatus.totalMedia == 0) {
          completionMessage = 'Inspeção baixada com sucesso!';
        } else if (mediaStatus.isComplete) {
          completionMessage = 'Inspeção baixada com sucesso! ${mediaStatus.downloadedMedia} imagens incluídas.';
        } else {
          // Se há mídias esperadas mas nenhuma foi baixada, isso é um erro
          if (mediaStatus.downloadedMedia == 0) {
            completionMessage = 'Erro no download das imagens! ${mediaStatus.totalMedia} imagens não puderam ser baixadas.';
            isSuccess = false;
          } else {
            // Download parcial - ainda é um problema
            completionMessage = 'Download incompleto! ${mediaStatus.downloadedMedia}/${mediaStatus.totalMedia} imagens baixadas.';
            isSuccess = false;
          }
        }
        
        // Notification with appropriate status
        if (isSuccess) {
          await SimpleNotificationService.instance.showCompletionNotification(
            title: 'Download concluído',
            message: completionMessage,
            isSuccess: true,
          );
        } else {
          await SimpleNotificationService.instance.showErrorNotification(
            title: 'Problema no download',
            message: completionMessage,
          );
        }
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: isSuccess ? SyncPhase.completed : SyncPhase.error,
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
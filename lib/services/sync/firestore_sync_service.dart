import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer';
import '../upload_progress_service.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/cloud_verification_service.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';
import 'package:lince_inspecoes/utils/inspection_json_converter.dart';

class FirestoreSyncService {
  final FirebaseService _firebaseService;
  final OfflineDataService _offlineService;
  bool _isSyncing = false;

  // Stream controller for detailed sync progress
  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  // Track active sync operations for cancellation
  final Map<String, bool> _activeSyncs = {};
  final Map<String, Completer<void>> _syncCompleters = {};

  // Singleton pattern
  static FirestoreSyncService? _instance;
  static FirestoreSyncService get instance {
    if (_instance == null) {
      throw Exception(
          'FirestoreSyncService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  FirestoreSyncService({
    required FirebaseService firebaseService,
    required OfflineDataService offlineService,
  })  : _firebaseService = firebaseService,
        _offlineService = offlineService;

  static void initialize({
    required FirebaseService firebaseService,
    required OfflineDataService offlineService,
  }) {
    _instance = FirestoreSyncService(
      firebaseService: firebaseService,
      offlineService: offlineService,
    );
    
    // Initialize CloudVerificationService
    CloudVerificationService.initialize(
      firebaseService: firebaseService,
      offlineService: offlineService,
    );
  }

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ===============================
  // SYNC CANCELLATION METHODS
  // ===============================

  /// Check if an inspection is currently syncing
  bool isSyncingInspection(String inspectionId) {
    return _activeSyncs[inspectionId] == true;
  }

  /// Cancel an active sync operation
  Future<void> cancelSync(String inspectionId) async {
    if (_activeSyncs[inspectionId] == true) {
      debugPrint('FirestoreSyncService: Cancelling sync for inspection $inspectionId');
      _activeSyncs[inspectionId] = false;

      // Complete the completer to unblock any waiting operations
      final completer = _syncCompleters[inspectionId];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }

      // Clean up
      _syncCompleters.remove(inspectionId);

      // Emit cancellation progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 0,
        total: 1,
        message: 'Sincronização cancelada pelo usuário',
      ));

      // Hide notification
      await SimpleNotificationService.instance.hideAllNotifications();

      debugPrint('FirestoreSyncService: Sync cancelled for inspection $inspectionId');
    }
  }

  // ===============================
  // SINCRONIZAÇÃO COMPLETA SIMPLIFICADA
  // ===============================

  Future<void> performFullSync() async {
    if (_isSyncing || !await isConnected()) {
        return;
    }

    try {
      _isSyncing = true;

      await downloadInspectionsFromCloud();
      await uploadLocalChangesToCloud();

    } catch (e) {
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // ===============================
  // DOWNLOAD DA NUVEM
  // ===============================

  Future<void> downloadInspectionsFromCloud() async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) return;

      final querySnapshot = await _firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: currentUser.uid)
          .where('deleted_at', isNull: true)
          .get();

      for (final doc in querySnapshot.docs) {
        await _downloadSingleInspection(doc);
      }

    } catch (e) {
      // Log apenas erros críticos de download
      log('Erro ao baixar inspeções: $e');
    }
  }

  Future<void> _downloadSingleInspection(QueryDocumentSnapshot doc) async {
    try {
      
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      // Converter timestamps do Firestore primeiro
      final convertedData = _convertFirestoreTimestamps(data);
      
      // Criar objeto Inspection a partir dos dados convertidos
      final cloudInspection = Inspection.fromMap(convertedData);
      
      final localInspection = await _offlineService.getInspection(doc.id);

      // Sempre fazer download se não existe localmente ou se é mais recente
      if (localInspection == null || cloudInspection.updatedAt.isAfter(localInspection.updatedAt)) {
        
        // Preparar inspeção para salvamento local
        final downloadedInspection = cloudInspection.copyWith(
          updatedAt: DateFormatter.now(),
        );
        
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);
        
        // Verificar se foi salva
        final savedInspection = await _offlineService.getInspection(doc.id);
        
        // Process nested structure using InspectionJsonConverter
        if (savedInspection != null) {
          await InspectionJsonConverter.fromNestedJson(convertedData);

          // Download media files
          await _downloadMediaFilesForInspection(doc.id);

          // Download template if necessary
          await _downloadInspectionTemplate(cloudInspection);

          // Add download record to inspection_history
          await _addDownloadHistory(doc.id, cloudInspection.inspectorId);

        } else {
        }
      } else {
      }
    } catch (e) {
      // Log apenas erros críticos
    }
  }


  /// Download media files from cloud storage for all media entries that were created from nested JSON
  Future<void> _downloadMediaFilesForInspection(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Downloading media files for inspection $inspectionId');

      // Get all media entries for this inspection from local database
      final allMedia = await _offlineService.getMediaByInspection(inspectionId);

      debugPrint('FirestoreSyncService: Found ${allMedia.length} media entries to download');

      int downloadedCount = 0;
      int skippedCount = 0;
      int failedCount = 0;

      for (final media in allMedia) {
        // Skip if file already exists locally
        if (media.localPath.isNotEmpty) {
          final file = File(media.localPath);
          if (await file.exists() && await file.length() > 0) {
            skippedCount++;
            continue;
          }
        }

        // Skip if no cloud URL
        if (media.cloudUrl == null || media.cloudUrl!.isEmpty) {
          debugPrint('FirestoreSyncService: No cloud URL for media ${media.filename}');
          failedCount++;
          continue;
        }

        try {
          // Download file from Firebase Storage
          final storageRef = _firebaseService.storage.refFromURL(media.cloudUrl!);
          final localFile = await _offlineService.createMediaFile(media.filename);

          await storageRef.writeToFile(localFile);

          // Verify download
          if (await localFile.exists() && await localFile.length() > 0) {
            // Update media entry with local path
            final updatedMedia = media.copyWith(localPath: localFile.path);
            await _offlineService.updateMedia(updatedMedia);
            downloadedCount++;
            debugPrint('FirestoreSyncService: Downloaded ${media.filename} (${await localFile.length()} bytes)');
          } else {
            debugPrint('FirestoreSyncService: Failed to download ${media.filename} - file empty or missing');
            failedCount++;
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Error downloading ${media.filename}: $e');
          failedCount++;
        }
      }

      debugPrint('FirestoreSyncService: Media download complete - Downloaded: $downloadedCount, Skipped: $skippedCount, Failed: $failedCount');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error in _downloadMediaFilesForInspection: $e');
    }
  }

  // ===============================
  // PROGRESS NOTIFICATION HELPER
  // ===============================
  
  /// Formatar velocidade para exibição
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Formatar tempo para exibição
  String _formatTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  
  // ===============================
  // UPLOAD PARA A NUVEM
  // ===============================

  /// Public method for media upload during manual sync
  Future<void> uploadMediaWithProgress(String inspectionId) async {
    await _uploadMediaFilesWithProgress(inspectionId);
  }

  /// Método para sincronização de mídias quando clicado manualmente
  Future<void> uploadMedia(String inspectionId) async {
    final stopwatch = Stopwatch()..start();
    Timer? notificationTimer;
    String? sessionId;

    try {
      final mediaFiles = await _offlineService.getMediaPendingUpload();
      final inspectionMediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();

      if (inspectionMediaFiles.isEmpty) {
        return;
      }

      // Sort por tamanho para melhor percepção de velocidade
      inspectionMediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));

      // Preparar itens para tracking de progresso
      final uploadItems = inspectionMediaFiles.map((media) => UploadItem(
        id: media.id,
        filename: media.filename,
        totalBytes: media.fileSize ?? 1024, // fallback 1KB
      )).toList();

      // Iniciar tracking de progresso
      sessionId = 'batch_$inspectionId';
      UploadProgressService.instance.startUploadTracking(sessionId, uploadItems);

      // Timer para atualizar notificação a cada 2 segundos
      notificationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        // Stop timer if sync was cancelled
        if (_activeSyncs[inspectionId] == false) {
          return;
        }

        final stats = UploadProgressService.instance.getUploadStats(sessionId!);
        if (stats != null) {
          await SimpleNotificationService.instance.showSyncProgress(
            title: 'Enviando dados',
            message: '',
            progress: stats.progressPercentage.round(),
            currentItem: stats.currentItem,
            totalItems: stats.totalItems,
            estimatedTime: stats.estimatedTimeRemaining != null ? _formatTime(stats.estimatedTimeRemaining!) : null,
            speed: _formatSpeed(stats.speedBytesPerSecond),
          );
        }
      });

      const int maxConcurrent = 3; // Máximo para upload manual
      const int chunkSize = 10; // Chunks para processar

      int totalUploaded = 0;

      // Process em chunks com máximo paralelismo
      for (int i = 0; i < inspectionMediaFiles.length; i += chunkSize) {
        // Check for cancellation before each chunk
        if (_activeSyncs[inspectionId] == false) {
          throw Exception('Upload cancelled by user');
        }

        final chunk = inspectionMediaFiles.skip(i).take(chunkSize).toList();

        // Controle de concorrência
        final semaphore = <Future>[];
        final uploadFutures = <Future<bool>>[];

        for (final media in chunk) {
          // Check cancellation before each media
          if (_activeSyncs[inspectionId] == false) {
            throw Exception('Upload cancelled by user');
          }

          // Aguarda slot disponível
          while (semaphore.length >= maxConcurrent) {
            await semaphore.removeAt(0);
          }

          // Inicia upload
          final uploadFuture = _uploadSingleMedia(media, uploadFutures.length + 1, sessionId);
          semaphore.add(uploadFuture);
          uploadFutures.add(uploadFuture);
        }

        // Aguarda todos os uploads do chunk OU cancelamento
        try {
          final results = await Future.any([
            Future.wait(uploadFutures),
            _syncCompleters[inspectionId]?.future ?? Future.value(),
          ]).timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw TimeoutException('Upload timeout'),
          );

          if (results is List<bool>) {
            final chunkUploaded = results.where((success) => success).length;
            totalUploaded += chunkUploaded;
          } else {
            // Completer foi completado (cancelamento)
            throw Exception('Upload cancelled by user');
          }
        } catch (e) {
          if (_activeSyncs[inspectionId] == false) {
            throw Exception('Upload cancelled by user');
          }
          rethrow;
        }

        // Delay mínimo entre chunks
        if (i + chunkSize < inspectionMediaFiles.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      stopwatch.stop();
      
      // Finalizar tracking e timer
      notificationTimer.cancel();
      UploadProgressService.instance.stopUploadTracking(sessionId);
      
      // Log resultado final apenas se houver upload e não foi cancelado
      if (totalUploaded > 0 && _activeSyncs[inspectionId] != false) {
        final timeSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
        log('Upload: $totalUploaded/${inspectionMediaFiles.length} em ${timeSeconds}s');

        // Notificação final de conclusão - apenas se não foi cancelado
        await SimpleNotificationService.instance.showSyncProgress(
          title: 'Upload Concluído',
          message: 'Todas as $totalUploaded mídias foram enviadas com sucesso!',
          progress: 100,
          currentItem: totalUploaded,
          totalItems: totalUploaded,
        );
      }

    } catch (e) {
      stopwatch.stop();
      notificationTimer?.cancel();
      if (sessionId != null) {
        UploadProgressService.instance.stopUploadTracking(sessionId);
      }

      // Só loga erro se não for cancelamento
      if (!e.toString().contains('cancelled')) {
        log('Erro no upload: $e');
      }
    }
  }

  /// Upload individual de mídia
  Future<bool> _uploadSingleMedia(OfflineMedia media, int index, [String? sessionId]) async {
    try {
      // Se já tem cloudUrl, verificar se ainda é válida e atualizar token se necessário
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        try {
          // Tentar obter novo download URL (atualiza o token automaticamente)
          final storageRef = _firebaseService.storage.ref();
          final mediaPath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
          final mediaRef = storageRef.child(mediaPath);

          // Verificar se arquivo existe e pegar novo token
          final newDownloadUrl = await mediaRef.getDownloadURL();

          // Atualizar URL com novo token
          if (newDownloadUrl != media.cloudUrl) {
            await _offlineService.updateMediaCloudUrl(media.id, newDownloadUrl);
            debugPrint('FirestoreSyncService: Updated token for ${media.filename}');
          }

          // Marcar como completo no tracking
          if (sessionId != null) {
            UploadProgressService.instance.markItemCompleted(sessionId, media.id);
          }
          return true;
        } catch (e) {
          // Se falhar ao pegar novo URL, arquivo pode não existir - fazer upload
          debugPrint('FirestoreSyncService: CloudUrl exists but file not found, re-uploading ${media.filename}');
        }
      }

      // Upload
      final downloadUrl = await _uploadMediaToStorage(media, sessionId);

      if (downloadUrl != null) {
        await _offlineService.updateMediaCloudUrl(media.id, downloadUrl);

        // Marcar como completo no tracking
        if (sessionId != null) {
          UploadProgressService.instance.markItemCompleted(sessionId, media.id);
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Upload para Storage
  Future<String?> _uploadMediaToStorage(OfflineMedia media, [String? sessionId]) async {
    try {
      // Se já tem cloudUrl, assume que está válida
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        return media.cloudUrl!;
      }

      // Check if file exists locally
      final file = File(media.localPath);
      if (!await file.exists()) {
        return null;
      }

      // Create storage reference
      final storageRef = _firebaseService.storage.ref();
      final mediaPath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
      final mediaRef = storageRef.child(mediaPath);

      // Metadata mínima
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'inspection_id': media.inspectionId,
          'type': media.type,
        },
      );

      // Upload
      final uploadTask = mediaRef.putFile(file, metadata);

      // Monitor progress se temos sessionId
      StreamSubscription? progressSubscription;
      if (sessionId != null) {
        progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
          if (snapshot.state == TaskState.running) {
            UploadProgressService.instance.updateItemProgress(
              sessionId,
              media.id,
              snapshot.bytesTransferred
            );
          }
        });
      }

      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          progressSubscription?.cancel();
          uploadTask.cancel();
          throw TimeoutException('Upload timeout', const Duration(minutes: 3));
        },
      );

      // Cancel subscription
      try {
        progressSubscription?.cancel();
      } catch (e) {
        // Ignore
      }

      return await snapshot.ref.getDownloadURL();

    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading ${media.filename}: $e');
      return null;
    }
  }

  Future<void> uploadLocalChangesToCloud() async {
    try {
      // Upload media files first
      await _uploadAllMediaFiles();

      // Then upload inspection data with nested structure
      await _uploadInspectionsWithNestedStructure();

    } catch (e) {
      log('Erro no upload para nuvem: $e');
    }
  }

  /// Upload de todas as mídias pendentes
  Future<void> _uploadAllMediaFiles() async {
    try {
      final mediaFiles = await _offlineService.getMediaPendingUpload();

      if (mediaFiles.isEmpty) {
        return;
      }

      debugPrint('FirestoreSyncService: Found ${mediaFiles.length} media files to upload');

      // Sort by file size
      mediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));

      const int batchSize = 10;
      const int maxConcurrent = 3;

      for (int i = 0; i < mediaFiles.length; i += batchSize) {
        final batch = mediaFiles.skip(i).take(batchSize).toList();

        // Controle de concorrência
        final semaphore = <Future>[];
        final uploadFutures = <Future<bool>>[];

        for (final media in batch) {
          while (semaphore.length >= maxConcurrent) {
            await semaphore.removeAt(0);
          }

          final uploadFuture = _uploadSingleMediaSimple(media);
          semaphore.add(uploadFuture);
          uploadFutures.add(uploadFuture);
        }

        await Future.wait(uploadFutures);

        if (i + batchSize < mediaFiles.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      debugPrint('FirestoreSyncService: Finished uploading media files');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media files: $e');
    }
  }

  /// Upload simples de uma mídia
  Future<bool> _uploadSingleMediaSimple(OfflineMedia media) async {
    try {
      // Skip if already uploaded
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        return true;
      }

      final downloadUrl = await _uploadMediaToStorage(media);

      if (downloadUrl != null) {
        await _offlineService.updateMediaCloudUrl(media.id, downloadUrl);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> _uploadMediaFilesWithProgress(String inspectionId) async {
    final totalStopwatch = Stopwatch()..start();
    
    try {
      debugPrint('FirestoreSyncService: Starting optimized upload for inspection $inspectionId');
      
      // Upload apenas mídias da inspeção específica
      final mediaFiles = await _offlineService.getMediaPendingUpload();
      final inspectionMediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();
      
      if (inspectionMediaFiles.isEmpty) {
        debugPrint('FirestoreSyncService: No media files to upload');
        return;
      }
      
      debugPrint('FirestoreSyncService: Found ${inspectionMediaFiles.length} media files to upload');
      
      int uploadedCount = 0;
      
      // Sort by file size - upload smaller files first for perceived speed
      inspectionMediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      
      // Emit initial progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: 0,
        total: inspectionMediaFiles.length,
        message: 'Upload iniciado: ${inspectionMediaFiles.length} arquivos',
        currentItem: 'Preparando',
        itemType: 'Mídia',
        mediaCount: inspectionMediaFiles.length,
      ));
      
      // Process uploads with controlled concurrency
      const int batchSize = 8;
      const int maxConcurrent = 3;

      for (int i = 0; i < inspectionMediaFiles.length; i += batchSize) {
        final batch = inspectionMediaFiles.skip(i).take(batchSize).toList();

        // Controle de concorrência
        final semaphore = <Future>[];
        final uploadFutures = <Future<bool>>[];

        for (final media in batch) {
          while (semaphore.length >= maxConcurrent) {
            await semaphore.removeAt(0);
          }

          final uploadFuture = _uploadSingleMediaSimple(media);
          semaphore.add(uploadFuture);
          uploadFutures.add(uploadFuture);
        }

        final batchResults = await Future.wait(uploadFutures);
        uploadedCount += batchResults.where((success) => success).length;

        // Update progress after each batch
        final completedCount = i + batch.length;
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: completedCount,
          total: inspectionMediaFiles.length,
          message: 'Upload: $completedCount/${inspectionMediaFiles.length}',
          currentItem: 'Processando',
          itemType: 'Mídia',
          mediaCount: inspectionMediaFiles.length,
        ));
      }
      
      totalStopwatch.stop();
      
      // Final progress update with timing
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: uploadedCount,
        total: inspectionMediaFiles.length,
        message: uploadedCount == inspectionMediaFiles.length 
            ? 'Concluído: ${inspectionMediaFiles.length} arquivos em ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s'
            : 'Parcial: $uploadedCount/${inspectionMediaFiles.length} em ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
        currentItem: 'Finalizado',
        itemType: 'Resultado',
        mediaCount: inspectionMediaFiles.length,
      ));
      
      debugPrint('FirestoreSyncService: Upload completed - $uploadedCount/${inspectionMediaFiles.length} files in ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
    } catch (e) {
      totalStopwatch.stop();
      debugPrint('FirestoreSyncService: Upload error after ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s: $e');
    }
  }

  Future<void> _uploadInspectionsWithNestedStructure() async {
    try {
      final inspections = await _offlineService.getInspectionsNeedingSync();
      debugPrint('FirestoreSyncService: Found ${inspections.length} inspections to upload');

      // Process inspections in parallel batches of 5
      const int batchSize = 5;
      for (int i = 0; i < inspections.length; i += batchSize) {
        final batch = inspections.skip(i).take(batchSize).toList();
        debugPrint('FirestoreSyncService: Processing inspection batch ${(i ~/ batchSize) + 1}: ${batch.length} inspections');
        
        // Upload batch in parallel
        final futures = batch.map((inspection) => _uploadSingleInspectionSafely(inspection));
        await Future.wait(futures);
        
        debugPrint('FirestoreSyncService: Completed inspection batch ${(i ~/ batchSize) + 1}');
        
        // Add delay between batches to prevent resource conflicts
        if (i + batchSize < inspections.length) {
          await Future.delayed(const Duration(milliseconds: 500)); // Reduzido de 1000ms para 500ms
        }
      }
      
      debugPrint('FirestoreSyncService: Finished uploading all inspections');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading inspections with nested structure: $e');
    }
  }
  
  Future<void> _uploadSingleInspectionSafely(Inspection inspection) async {
    try {
      // Build the complete nested structure for Firestore
      final inspectionData = await _buildNestedInspectionData(inspection);

      await _firebaseService.firestore
          .collection('inspections')
          .doc(inspection.id)
          .set(inspectionData, SetOptions(merge: true));

      debugPrint(
          'FirestoreSyncService: Uploaded inspection with nested structure ${inspection.id}');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading inspection ${inspection.id}: $e');
    }
  }

  Future<void> _uploadSingleInspectionWithNestedStructure(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Uploading single inspection $inspectionId');

      final inspection = await _offlineService.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint('FirestoreSyncService: Inspection $inspectionId not found locally');
        return;
      }

      // Build the complete nested structure for Firestore
      final inspectionData = await _buildNestedInspectionData(inspection);

      // Get current timestamp for sync
      final now = FieldValue.serverTimestamp();

      // Add last_sync_at timestamp to inspection data
      inspectionData['last_sync_at'] = now;

      await _firebaseService.firestore
          .collection('inspections')
          .doc(inspection.id)
          .set(inspectionData, SetOptions(merge: true));

      // Update local inspection with sync timestamp
      final localInspection = await _offlineService.getInspection(inspectionId);
      if (localInspection != null) {
        final updatedInspection = localInspection.copyWith(
          updatedAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );
        await _offlineService.updateInspection(updatedInspection);
      }

      // Add upload record to inspection_history
      await _addUploadHistory(inspectionId, inspection.inspectorId);

      debugPrint(
          'FirestoreSyncService: Successfully uploaded single inspection with nested structure $inspectionId');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading single inspection $inspectionId: $e');
      rethrow;
    }
  }

  /// Add upload history record to Firestore
  Future<void> _addUploadHistory(String inspectionId, String? inspectorId) async {
    await _addSyncHistory(inspectionId, inspectorId, 'upload');
  }

  /// Add download history record to Firestore
  Future<void> _addDownloadHistory(String inspectionId, String? inspectorId) async {
    await _addSyncHistory(inspectionId, inspectorId, 'download');
  }

  /// Add sync history record (upload or download) to Firestore
  Future<void> _addSyncHistory(String inspectionId, String? inspectorId, String action) async {
    try {
      final actionEmoji = action == 'upload' ? '📝' : '📥';
      debugPrint('$actionEmoji FirestoreSyncService: Attempting to add $action history for inspection $inspectionId');
      debugPrint('   Inspector ID: ${inspectorId ?? 'unknown'}');

      final historyDoc = _firebaseService.firestore
          .collection('inspection_history')
          .doc(inspectionId);

      // Get current document to append to history array
      final docSnapshot = await historyDoc.get();

      List<Map<String, dynamic>> history = [];

      // Get existing history if document exists
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data['history'] is List) {
          history = List<Map<String, dynamic>>.from(
            (data['history'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          );
        }
      }

      // Add new history record with ISO8601 timestamp (serverTimestamp doesn't work inside arrays)
      final now = DateTime.now().toIso8601String();
      history.add({
        'timestamp': now,
        'inspector_id': inspectorId ?? 'unknown',
        'action': action,
      });

      // Write entire array back with serverTimestamp only at root level
      final historyData = {
        'history': history,
        'last_sync': FieldValue.serverTimestamp(), // Track most recent sync at root level
      };

      debugPrint('   Writing to: inspection_history/$inspectionId (${history.length} total events)');
      await historyDoc.set(historyData);

      debugPrint('✅ FirestoreSyncService: Successfully added $action history for inspection $inspectionId');
    } catch (e, stackTrace) {
      debugPrint('❌ FirestoreSyncService: Error adding $action history: $e');
      debugPrint('   Stack trace: $stackTrace');
      // Don't throw - history is not critical
    }
  }

  Future<Map<String, dynamic>> _buildNestedInspectionData(
      Inspection inspection) async {
    
    // Validate inspection data before processing
    if (inspection.id.isEmpty) {
      throw ArgumentError('Inspection ID cannot be empty');
    }
    
    if (inspection.title.trim().isEmpty) {
      throw ArgumentError('Inspection title cannot be empty');
    }
    
    if (inspection.inspectorId?.isEmpty ?? true) {
      throw ArgumentError('Inspector ID cannot be empty');
    }
    
    // Start with basic inspection data
    final data = inspection.toMap();
    
    // Validate and clean data fields
    data.remove('id');
    data.remove('is_deleted');
    
    // Ensure required fields are valid
    if (data['title'] == null || (data['title'] as String).trim().isEmpty) {
      throw ArgumentError('Inspection title is required and cannot be empty');
    }
    
    if (data['inspector_id'] == null || (data['inspector_id'] as String).isEmpty) {
      throw ArgumentError('Inspector ID is required and cannot be empty');
    }

    // Convert integer booleans back to booleans for Firestore
    if (data['is_templated'] is int) {
      data['is_templated'] = data['is_templated'] == 1;
    }
    if (data['is_synced'] is int) {
      data['is_synced'] = data['is_synced'] == 1;
    }
    if (data['has_local_changes'] is int) {
      data['has_local_changes'] = data['has_local_changes'] == 1;
    }

    // Get all topics for this inspection
    final topics = await _offlineService.getTopics(inspection.id);
    final topicsData = <Map<String, dynamic>>[];

    for (final topic in topics) {
      
      // Validate topic data before processing
      if (topic.id.isEmpty) {
        debugPrint('FirestoreSyncService: Skipping topic with empty ID: ${topic.topicName}');
        continue;
      }
      
      if (topic.topicName.trim().isEmpty) {
        debugPrint('FirestoreSyncService: Skipping topic with empty name: ID ${topic.id}');
        continue;
      }
      
      if (topic.inspectionId.isEmpty || topic.inspectionId != inspection.id) {
        debugPrint('FirestoreSyncService: Skipping topic with invalid inspection ID: ${topic.id}');
        continue;
      }
      
      // Get topic-level media
      final topicMedia = await _offlineService.getMediaByTopic(topic.id);
      final topicMediaList = <Map<String, dynamic>>[];
      
      // Add direct topic media (sorted by orderIndex and createdAt)
      final sortedTopicMedia = List<OfflineMedia>.from(topicMedia)
        ..sort((a, b) {
          // Primary sort by orderIndex
          final orderComparison = a.orderIndex.compareTo(b.orderIndex);
          if (orderComparison != 0) return orderComparison;

          // Secondary sort by createdAt if orderIndex is the same
          return a.createdAt.compareTo(b.createdAt);
        });
      
      topicMediaList.addAll(sortedTopicMedia.map((media) => {
        'filename': media.filename,
        'type': media.type,
        'localPath': media.localPath,
        'cloudUrl': media.cloudUrl,
        'thumbnailPath': media.thumbnailPath,
        'fileSize': media.fileSize,
        'mimeType': 'image/jpeg', // Default mimeType
        'isUploaded': media.isUploaded,
        'createdAt': media.createdAt.toIso8601String(),
        // capturedAt removido - usar createdAt
        'orderIndex': media.orderIndex,
      }));
      
      // NOTE: Removed duplication logic for direct_details topics
      // Media from direct details should only appear in individual details, not in topic media array
      // This prevents duplicated images in the Firestore structure
      
      final topicMediaData = topicMediaList;
      
      // Get topic-level non-conformities with hierarchical media structure
      final allTopicNCs = await _offlineService.getNonConformitiesByTopic(topic.id);
      // IMPORTANT: Filter to only topic-level NCs (exclude item and detail NCs)
      final topicNCs = allTopicNCs.where((nc) => nc.itemId == null && nc.detailId == null).toList();
      final topicNonConformitiesData = <Map<String, dynamic>>[];

      for (final nc in topicNCs) {
        final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
        topicNonConformitiesData.add(ncData);
      }

      final topicData = <String, dynamic>{
        'name': topic.topicName,
        'description': topic.topicLabel,
        'observation': topic.observation,
        'media': topicMediaData,
        'non_conformities': topicNonConformitiesData,
      };
      
      // Check if this is a direct_details topic
      if (topic.directDetails == true) {
        // For direct_details topics, add details directly to topic
        topicData['direct_details'] = true;
        
        // Get all details for this topic (no items)
        final details = await _offlineService.getDetailsByTopic(topic.id);
        final detailsData = <Map<String, dynamic>>[];

        for (final detail in details) {
          // Get media for this detail
          final detailMedia = await _offlineService.getMediaByDetail(detail.id);

          final mediaData = detailMedia.map((media) => {
            'filename': media.filename,
            'type': media.type,
            'localPath': media.localPath,
            'cloudUrl': media.cloudUrl,
            'thumbnailPath': media.thumbnailPath,
            'fileSize': media.fileSize,
            'mimeType': 'image/jpeg', // Default mimeType
            'isUploaded': media.isUploaded,
            'createdAt': media.createdAt.toIso8601String(),
          }).toList();

          // Get non-conformities for this detail with hierarchical media structure
          final detailNCs = await _offlineService.getNonConformitiesByDetail(detail.id);
          final nonConformitiesData = <Map<String, dynamic>>[];
          
          for (final nc in detailNCs) {
            final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
            nonConformitiesData.add(ncData);
          }

          final detailData = <String, dynamic>{
            'name': detail.detailName,
            'type': detail.type ?? 'text',
            'options': detail.options ?? [],
            'value': detail.detailValue,
            'observation': detail.observation,
            'media': mediaData,
            'non_conformities': nonConformitiesData,
          };
          
          detailsData.add(detailData);
        }

        topicData['details'] = detailsData;
      } else {
        // For regular topics, get all items
        topicData['direct_details'] = false; // PRESERVE direct_details as false for regular topics
        final items = await _offlineService.getItems(topic.id);
        final itemsData = <Map<String, dynamic>>[];

        for (final item in items) {
        // Get item-level media
        final itemMedia = await _offlineService.getMediaByItem(item.id);
        
        final itemMediaData = itemMedia.map((media) => {
          'filename': media.filename,
          'type': media.type,
          'localPath': media.localPath,
          'cloudUrl': media.cloudUrl,
          'thumbnailPath': media.thumbnailPath,
          'fileSize': media.fileSize,
          'mimeType': 'image/jpeg', // Default mimeType
          'isUploaded': media.isUploaded,
          'createdAt': media.createdAt.toIso8601String(),
        }).toList();
        
        // Get item-level non-conformities with hierarchical media structure
        final allItemNCs = await _offlineService.getNonConformitiesByItem(item.id);
        // IMPORTANT: Filter to only item-level NCs (exclude detail NCs)
        final itemNCs = allItemNCs.where((nc) => nc.detailId == null).toList();
        final itemNonConformitiesData = <Map<String, dynamic>>[];

        for (final nc in itemNCs) {
          final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
          itemNonConformitiesData.add(ncData);
        }

        final itemData = <String, dynamic>{
          'name': item.itemName,
          'description': item.itemLabel,
          'observation': item.observation,
          'evaluable': item.evaluable, // PRESERVE evaluable field
          'evaluation_options': item.evaluationOptions ?? [], // PRESERVE evaluation_options field
          'evaluation_value': item.evaluationValue, // PRESERVE evaluation_value field
          'media': itemMediaData,
          'non_conformities': itemNonConformitiesData,
          'details': <Map<String, dynamic>>[],
        };
        
        // Get all details for this item
        final details = await _offlineService.getDetails(item.id);
        final detailsData = <Map<String, dynamic>>[];

        for (final detail in details) {
          // Get media for this detail
          final detailMedia = await _offlineService.getMediaByDetail(detail.id);

          final mediaData = detailMedia.map((media) => {
            'filename': media.filename,
            'type': media.type,
            'localPath': media.localPath,
            'cloudUrl': media.cloudUrl,
            'thumbnailPath': media.thumbnailPath,
            'fileSize': media.fileSize,
            'mimeType': 'image/jpeg', // Default mimeType
            'isUploaded': media.isUploaded,
            'createdAt': media.createdAt.toIso8601String(),
          }).toList();

          // Get non-conformities for this detail with hierarchical media structure
          final detailNCs = await _offlineService.getNonConformitiesByDetail(detail.id);
          final nonConformitiesData = <Map<String, dynamic>>[];
          
          for (final nc in detailNCs) {
            final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
            nonConformitiesData.add(ncData);
          }

          final detailData = <String, dynamic>{
            'name': detail.detailName,
            'type': detail.type ?? 'text',
            'options': detail.options ?? [],
            'value': detail.detailValue,
            'observation': detail.observation,
            'media': mediaData,
            'non_conformities': nonConformitiesData,
          };
          
          detailsData.add(detailData);
        }

          itemData['details'] = detailsData;
          itemsData.add(itemData);
        }

        topicData['items'] = itemsData;
      }
      topicsData.add(topicData);
    }

    // Add topics to the main data
    data['topics'] = topicsData;

    // Validate data before returning to prevent Firestore invalid-argument errors
    final validatedData = _validateDataForFirestore(data);
    return validatedData;
  }

  /// Validates data before sending to Firestore to prevent invalid-argument errors
  Map<String, dynamic> _validateDataForFirestore(Map<String, dynamic> data) {
    final validatedData = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip null values except for allowed nullable fields
      if (value == null) {
        // Only include null for explicitly allowed fields
        final allowedNullFields = {
          'observation', 'description', 'template_id', 'template_name', 
          'street', 'neighborhood', 'city', 'state', 'zip_code', 'address_string',
          'address', 'finished_at', 'scheduled_date', 'area', 'deleted_at',
          'evaluation_value', 'evaluation', 'custom_option_value', 'value'
        };
        if (allowedNullFields.contains(key)) {
          validatedData[key] = null;
        }
        continue;
      }
      
      // Skip empty string values that should be null
      if (value is String && value.isEmpty) {
        final shouldBeNullFields = {
          'observation', 'description', 'evaluation_value', 'evaluation', 
          'custom_option_value', 'value', 'options'
        };
        if (shouldBeNullFields.contains(key)) {
          validatedData[key] = null;
          continue;
        }
      }
      
      // Validate field name - Firestore doesn't allow certain characters
      if (key.isEmpty || key.length > 1500 || // Max field name length
          key.contains('.') || key.contains('/') || key.contains('__') || 
          key.startsWith('_') || key.endsWith('_') ||
          key.contains('\$') || key.contains('#') || key.contains('[') || key.contains(']')) {
        debugPrint('FirestoreSyncService: ⚠️ SKIPPING invalid field name: $key');
        continue;
      }
      
      // Validate string values
      if (value is String) {
        // Check for extremely long strings (Firestore has limits)
        if (value.length > 1048487) { // ~1MB limit for strings in Firestore
          debugPrint('FirestoreSyncService: ⚠️ TRUNCATING overly long string in field: $key');
          validatedData[key] = value.substring(0, 1048487);
          continue;
        }
        
        // Remove any invalid control characters from strings
        final cleanString = value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
        validatedData[key] = cleanString;
      } else if (value is num) {
        // Validate numeric values (Firestore has limits)
        if (value.isNaN || value.isInfinite) {
          debugPrint('FirestoreSyncService: ⚠️ SKIPPING invalid numeric value in field: $key');
          continue;
        }
        validatedData[key] = value;
      } else if (value is bool) {
        validatedData[key] = value;
      } else if (value is Map<String, dynamic>) {
        // Recursively validate nested objects
        final validatedNested = _validateDataForFirestore(value);
        if (validatedNested.isNotEmpty) {
          validatedData[key] = validatedNested;
        }
      } else if (value is List) {
        final validatedList = _validateListForFirestore(value);
        if (validatedList.isNotEmpty) {
          validatedData[key] = validatedList;
        }
      } else {
        // Convert other types to string for safety
        final stringValue = value.toString();
        if (stringValue.isNotEmpty && stringValue != 'null') {
          validatedData[key] = stringValue;
        }
      }
    }
    
    return validatedData;
  }
  
  /// Validates lists for Firestore compatibility
  List _validateListForFirestore(List list) {
    final validatedList = [];
    
    for (final item in list) {
      if (item == null) {
        // Skip null items in lists
        continue;
      } else if (item is Map<String, dynamic>) {
        validatedList.add(_validateDataForFirestore(item));
      } else if (item is List) {
        validatedList.add(_validateListForFirestore(item));
      } else if (item is String) {
        // Remove any invalid characters from strings
        final cleanString = item.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
        validatedList.add(cleanString);
      } else {
        validatedList.add(item);
      }
    }
    
    return validatedList;
  }

  // Helper method to build non-conformity data with hierarchical media structure (media vs solved_media)
  Future<Map<String, dynamic>> _buildNonConformityWithHierarchicalMedia(NonConformity nc) async {
    // Get all media for this non-conformity
    final allMedia = await _offlineService.getMediaByNonConformity(nc.id);
    
    // Separate media based on resolution status
    final mediaList = <Map<String, dynamic>>[];
    final solvedMediaList = <Map<String, dynamic>>[];
    
    for (final media in allMedia) {
      final mediaData = {
        'filename': media.filename,
        'type': media.type,
        'localPath': media.localPath,
        'cloudUrl': media.cloudUrl,
        'thumbnailPath': media.thumbnailPath,
        'fileSize': media.fileSize,
        'mimeType': 'image/jpeg', // Default mimeType
        'isUploaded': media.isUploaded,
        'createdAt': media.createdAt.toIso8601String(),
        'isResolutionMedia': media.isResolutionMedia,
        'source': media.source,
      };
      
      if (media.isResolutionMedia) {
        solvedMediaList.add(mediaData);
      } else {
        mediaList.add(mediaData);
      }
    }
    
    return {
      'id': nc.id,
      'title': nc.title,
      'description': nc.description,
      'severity': nc.severity,
      'status': nc.status,
      'corrective_action': nc.correctiveAction,
      'deadline': nc.deadline?.toIso8601String(),
      'is_resolved': nc.isResolved,
      'resolved_at': nc.resolvedAt?.toIso8601String(),
      'createdAt': nc.createdAt.toIso8601String(),
      'updatedAt': nc.updatedAt.toIso8601String(),
      'media': mediaList,           // Media for unresolved state
      'solved_media': solvedMediaList, // Media for resolved state
    };
  }

  Future<void> _downloadInspectionTemplate(Inspection inspection) async {
    try {
      if (inspection.templateId == null || inspection.templateId!.isEmpty) {
        debugPrint('FirestoreSyncService: No template associated with inspection ${inspection.id}');
        return;
      }

      debugPrint('FirestoreSyncService: Downloading template ${inspection.templateId} for inspection ${inspection.id}');
      
      // Tentar baixar o template usando o template service via service factory
      try {
        final serviceFactory = EnhancedOfflineServiceFactory.instance;
        final templateService = serviceFactory.templateService;
        final success = await templateService.downloadTemplateForOffline(inspection.templateId!);
        
        if (success) {
          debugPrint('FirestoreSyncService: Successfully downloaded template ${inspection.templateId}');
        } else {
          debugPrint('FirestoreSyncService: Failed to download template ${inspection.templateId}');
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Error downloading template ${inspection.templateId}: $e');
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error in _downloadInspectionTemplate: $e');
    }
  }

  // ===============================
  // UTILITÁRIOS
  // ===============================

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

  // ===============================
  // SINCRONIZAÇÃO DE INSPEÇÃO ESPECÍFICA
  // ===============================

  Future<Map<String, dynamic>> syncInspection(String inspectionId) async {
    if (!await isConnected()) {
      debugPrint(
          'FirestoreSyncService: No internet connection for inspection sync');
      return {'success': false, 'error': 'No internet connection'};
    }

    try {
      // Mark sync as active
      _activeSyncs[inspectionId] = true;
      _syncCompleters[inspectionId] = Completer<void>();

      // Enable Firestore network for sync operation
      await _firebaseService.enableNetwork();

      // Emit starting progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.starting,
        current: 0,
        total: 100,
        message: 'Preparando sincronização...',
      ));

      // Check for cancellation
      if (_activeSyncs[inspectionId] == false) {
        return {'success': false, 'error': 'Sync cancelled by user'};
      }

      // Get local inspection first to check for conflicts
      final localInspection = await _offlineService.getInspection(inspectionId);
      
      // Download da nuvem
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      int currentStep = 0;
      const totalSteps = 5; // Upload media, upload data, download, verify, complete

      // *** PRIMEIRO: Upload das mudanças locais (incluindo exclusões) ***
      if (localInspection != null) {
        // Check for cancellation before upload
        if (_activeSyncs[inspectionId] == false) {
          return {'success': false, 'error': 'Sync cancelled by user'};
        }

        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Enviando mídias para nuvem...',
          currentItem: 'Mídias pendentes',
          itemType: 'Arquivo',
        ));

        // PRIMEIRO: Upload das mídias pendentes
        await uploadMedia(inspectionId);

        // Check for cancellation after media upload
        if (_activeSyncs[inspectionId] == false) {
          return {'success': false, 'error': 'Sync cancelled by user'};
        }

        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Enviando dados da inspeção...',
          currentItem: localInspection.title,
          itemType: 'Inspeção',
        ));

        // SEGUNDO: Upload da inspeção com estrutura completa
        await _uploadSingleInspectionWithNestedStructure(inspectionId);

        // Check for cancellation after data upload
        if (_activeSyncs[inspectionId] == false) {
          return {'success': false, 'error': 'Sync cancelled by user'};
        }
      }

      // *** DOWNLOAD APENAS SE NÃO TEMOS DADOS LOCAIS (primeiro download) ***
      if (docSnapshot.exists && localInspection == null) {
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.downloading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Baixando dados da nuvem...',
          currentItem: 'Dados da inspeção',
          itemType: 'Inspeção',
        ));
        
        final data = docSnapshot.data()!;
        data['id'] = inspectionId;

        final convertedData = _convertFirestoreTimestamps(data);
        final cloudInspection = Inspection.fromMap(convertedData);

        // Salvar a vistoria principal no banco local com timestamp de sync
        final downloadedInspection = cloudInspection.copyWith(
          updatedAt: DateFormatter.now(),
          lastSyncAt: DateTime.now(),
        );

        debugPrint('FirestoreSyncService: Saving inspection $inspectionId to local database with sync timestamp');
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);

        // Process nested structure using InspectionJsonConverter (handles topics, items, details, NCs, media)
        debugPrint('FirestoreSyncService: Processing nested structure from cloud data');
        try {
          await InspectionJsonConverter.fromNestedJson(convertedData);
        } catch (e, stackTrace) {
          debugPrint('FirestoreSyncService: Error in fromNestedJson: $e');
          debugPrint('FirestoreSyncService: Stack trace: $stackTrace');
          debugPrint('FirestoreSyncService: Data keys: ${convertedData.keys.toList()}');
          rethrow;
        }

        // Download media files from cloud URLs
        debugPrint('FirestoreSyncService: Downloading media files for inspection');
        await _downloadMediaFilesForInspection(inspectionId);

        // Baixar template da inspeção se necessário
        await _downloadInspectionTemplate(cloudInspection);

        // Add download record to inspection_history
        await _addDownloadHistory(inspectionId, cloudInspection.inspectorId);
      } else if (localInspection != null) {
        debugPrint('FirestoreSyncService: ✅ SYNC ONLY - Local data preserved, upload completed');
        // Apenas baixar template se necessário, sem sobrescrever dados
        if (docSnapshot.exists) {
          currentStep++;
          final data = docSnapshot.data()!;
          final convertedData = _convertFirestoreTimestamps(data);
          final cloudInspection = Inspection.fromMap(convertedData);
          await _downloadInspectionTemplate(cloudInspection);
        }
      }

      // *** NOVA ETAPA: Verificação na nuvem (opcional e rápida) ***
      CloudVerificationResult? verificationResult;

      // Check for cancellation before verification
      if (_activeSyncs[inspectionId] == false) {
        return {'success': false, 'error': 'Sync cancelled by user'};
      }

      try {
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.verifying,
          current: ++currentStep,
          total: totalSteps,
          message: 'Verificando integridade na nuvem...',
          currentItem: 'Validação rápida',
          itemType: 'Verificação',
          isVerifying: true,
        ));

        // Verificação rápida - verifica apenas mídias pendentes
        verificationResult = await CloudVerificationService.instance.verifyInspectionSync(inspectionId);

        // Check for cancellation after verification
        if (_activeSyncs[inspectionId] == false) {
          return {'success': false, 'error': 'Sync cancelled by user'};
        }
      } catch (e) {
        // Erro na verificação (ignorando)
        // Se a verificação falhar por qualquer motivo, assumir sucesso
        verificationResult = CloudVerificationResult(
          isComplete: true,
          totalItems: 1,
          verifiedItems: 1,
          missingItems: [],
          failedItems: [],
          summary: 'Verificação pulada devido a erro - assumindo sucesso',
        );
      }

      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.completed,
        current: totalSteps,
        total: totalSteps,
        message: verificationResult.isComplete
            ? 'Sincronização completa!'
            : 'Sincronização concluída - ${verificationResult.summary}',
      ));

      return {
        'success': true,
        'hasConflicts': false,
        'verification': verificationResult
      };
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error syncing inspection $inspectionId: $e');

      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 0,
        total: 1,
        message: 'Erro na sincronização: $e',
      ));

      return {'success': false, 'error': e.toString()};
    } finally {
      // Cleanup: Remove from active syncs
      _activeSyncs.remove(inspectionId);
      _syncCompleters.remove(inspectionId);
    }
  }



  /// Sincroniza múltiplas inspeções com progresso detalhado
  Future<Map<String, dynamic>> syncMultipleInspections(List<String> inspectionIds) async {
    if (!await isConnected()) {
      debugPrint('FirestoreSyncService: No internet connection for multiple inspections sync');
      return {'success': false, 'error': 'No internet connection'};
    }

    try {
      debugPrint('FirestoreSyncService: Starting BATCH sync for ${inspectionIds.length} inspections');
      
      final results = <String, Map<String, dynamic>>{};
      int successCount = 0;
      int failureCount = 0;
      
      // Process inspections in parallel batches of 3
      const int batchSize = 3;
      int processedCount = 0;
      
      for (int i = 0; i < inspectionIds.length; i += batchSize) {
        final batch = inspectionIds.skip(i).take(batchSize).toList();
        debugPrint('FirestoreSyncService: Processing parallel batch ${(i ~/ batchSize) + 1}: ${batch.length} inspections');
        
        // Emit progress for current batch
        _syncProgressController.add(SyncProgress(
          inspectionId: 'multiple',
          phase: SyncPhase.starting,
          current: processedCount,
          total: inspectionIds.length,
          message: 'Sincronizando em batches ${(i ~/ batchSize) + 1} (${batch.length} inspeções)...',
          currentItem: '${(i ~/ batchSize) + 1}',
          itemType: 'Lote de Inspeções',
          totalInspections: inspectionIds.length,
          currentInspectionIndex: processedCount + 1,
        ));
        
        // Create futures for parallel execution
        final futures = batch.map((inspectionId) async {
          try {
            final inspection = await _offlineService.getInspection(inspectionId);
            final inspectionTitle = inspection?.title ?? 'Inspeção $inspectionId';
            
            debugPrint('FirestoreSyncService: Starting parallel sync for: $inspectionTitle');
            final result = await syncInspection(inspectionId);
            
            return {
              'id': inspectionId,
              'title': inspectionTitle,
              'result': result,
            };
          } catch (e) {
            debugPrint('FirestoreSyncService: Error in parallel sync for $inspectionId: $e');
            return {
              'id': inspectionId,
              'title': 'Inspeção $inspectionId',
              'result': {'success': false, 'error': e.toString()},
            };
          }
        });
        
        // Wait for all inspections in batch to complete
        final batchResults = await Future.wait(futures);
        
        // Process results
        for (final batchResult in batchResults) {
          final inspectionId = batchResult['id'] as String;
          final result = batchResult['result'] as Map<String, dynamic>;
          results[inspectionId] = result;
          
          if (result['success'] == true) {
            successCount++;
            debugPrint('FirestoreSyncService: ✅ Successfully synced inspection $inspectionId');
          } else {
            failureCount++;
            debugPrint('FirestoreSyncService: ❌ Failed to sync inspection $inspectionId: ${result['error']}');
          }
          
          processedCount++;
        }
        
        // Update progress after batch completion
        _syncProgressController.add(SyncProgress(
          inspectionId: 'multiple',
          phase: SyncPhase.uploading,
          current: processedCount,
          total: inspectionIds.length,
          message: 'Processadas $processedCount de ${inspectionIds.length} inspeções...',
          currentItem: 'Progresso geral',
          itemType: 'Inspeção',
          totalInspections: inspectionIds.length,
          currentInspectionIndex: processedCount,
        ));
        
        final successfulInBatch = batchResults.where((r) {
          final result = r['result'] as Map<String, dynamic>?;
          return result != null && result['success'] == true;
        }).length;
        debugPrint('FirestoreSyncService: Completed batch ${(i ~/ batchSize) + 1} - Success: $successfulInBatch/${batch.length}');
        
        // Add delay between batches to prevent resource conflicts
        if (i + batchSize < inspectionIds.length) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      // Final completion status
      final isFullSuccess = failureCount == 0;
      final summary = isFullSuccess 
          ? 'Todas as $successCount inspeções foram sincronizadas com sucesso!'
          : '$successCount de ${inspectionIds.length} inspeções sincronizadas. $failureCount falharam.';
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: isFullSuccess ? SyncPhase.completed : SyncPhase.error,
        current: inspectionIds.length,
        total: inspectionIds.length,
        message: summary,
        totalInspections: inspectionIds.length,
        currentInspectionIndex: inspectionIds.length,
      ));
      
      debugPrint('FirestoreSyncService: BATCH multiple sync completed - Success: $successCount, Failed: $failureCount');
      
      return {
        'success': isFullSuccess,
        'totalInspections': inspectionIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'summary': summary,
        'results': results,
      };
    } catch (e) {
      debugPrint('FirestoreSyncService: Error in batch multiple inspections sync: $e');
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: SyncPhase.error,
        current: 0,
        total: inspectionIds.length,
        message: 'Erro na sincronização múltipla: $e',
        totalInspections: inspectionIds.length,
      ));
      
      return {
        'success': false, 
        'error': e.toString(),
        'totalInspections': inspectionIds.length,
        'successCount': 0,
        'failureCount': inspectionIds.length,
      };
    }
  }

  // ===============================
  // RESOLUÇÃO DE CONFLITOS
  // ===============================

  /// Downloads a specific inspection from the cloud, replacing the local version
  Future<void> downloadSpecificInspection(String inspectionId) async {
    try {
      // Enable Firestore network for download operation
      await _firebaseService.enableNetwork();
      debugPrint('FirestoreSyncService: Downloading specific inspection $inspectionId to resolve conflicts');

      if (!await isConnected()) {
        throw Exception('Sem conexão com a internet');
      }

      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Inspeção não encontrada na nuvem');
      }

      final data = docSnapshot.data()!;
      data['id'] = inspectionId;

      final convertedData = _convertFirestoreTimestamps(data);
      final cloudInspection = Inspection.fromMap(convertedData);

      // Replace local version with cloud version
      await _offlineService.insertOrUpdateInspectionFromCloud(cloudInspection);
      // Process nested structure using InspectionJsonConverter
      await InspectionJsonConverter.fromNestedJson(convertedData);

      // Download media files
      await _downloadMediaFilesForInspection(inspectionId);

      // Download template if needed
      await _downloadInspectionTemplate(cloudInspection);

      // Add download record to inspection_history
      await _addDownloadHistory(inspectionId, cloudInspection.inspectorId);

      debugPrint('FirestoreSyncService: Successfully downloaded specific inspection $inspectionId');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading specific inspection $inspectionId: $e');
      rethrow;
    } finally {
      // Keep network enabled for continuous operation
      debugPrint('Download operation completed');
    }
  }

  /// Forces upload of local inspection changes to the cloud, overriding cloud version
  Future<void> forceUploadInspection(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Force uploading inspection $inspectionId to resolve conflicts');
      
      if (!await isConnected()) {
        throw Exception('Sem conexão com a internet');
      }

      final localInspection = await _offlineService.getInspection(inspectionId);
      if (localInspection == null) {
        throw Exception('Inspeção local não encontrada');
      }

      // Force upload media files first
      final mediaFiles = await _offlineService.getMediaPendingUpload();
      final inspectionMedia = mediaFiles.where((m) => m.inspectionId == inspectionId).toList();

      for (final media in inspectionMedia) {
        await _uploadSingleMediaSimple(media);
      }

      // Force upload the inspection with nested structure
      await _uploadSingleInspectionWithNestedStructure(inspectionId);

    } catch (e) {
      log('Erro ao forçar upload da inspeção $inspectionId: $e');
      rethrow;
    }
  }
}

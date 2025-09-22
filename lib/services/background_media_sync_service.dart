import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
// import 'package:lince_inspecoes/services/firebase_token_manager.dart'; // Temporariamente removido

/// Serviço para upload automático periódico de imagens em background
/// Mantém os status da inspeção inalterados - apenas acelera o upload futuro
class BackgroundMediaSyncService {
  static final BackgroundMediaSyncService _instance = BackgroundMediaSyncService._internal();
  factory BackgroundMediaSyncService() => _instance;
  BackgroundMediaSyncService._internal();

  static BackgroundMediaSyncService get instance => _instance;

  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  
  Timer? _periodicTimer;
  bool _isRunning = false;
  bool _isSyncing = false;
  
  // Configurações melhoradas
  static const Duration _syncInterval = Duration(minutes: 1); // Upload a cada 1 minuto
  static const int _maxImagesPerBatch = 7; // Máximo 7 imagens por minuto
  
  /// Inicia o serviço de background
  void startBackgroundSync() {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Inicia timer periódico
    _periodicTimer = Timer.periodic(_syncInterval, (_) async {
      await _performBackgroundImageSync();
    });
    
    // Executa primeira tentativa após 10 segundos para início mais rápido
    Timer(const Duration(seconds: 10), () async {
      await _performBackgroundImageSync();
    });
  }
  
  /// Para o serviço de background
  void stopBackgroundSync() {
    _isRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
  
  /// Executa o upload de imagens em background
  Future<void> _performBackgroundImageSync() async {
    if (_isSyncing || !_isRunning) return;
    
    try {
      _isSyncing = true;
      
      // Verifica conectividade
      if (!await _hasInternetConnection()) {
        return;
      }
      
      // Busca todas as inspeções (filtraremos as que têm mudanças locais)
      final allInspections = await _serviceFactory.dataService.getAllInspections();
      final inspections = allInspections.where((i) => i.hasLocalChanges == true).toList();
      
      if (inspections.isEmpty) {
          return;
      }
      
      
      // Processa cada inspeção
      for (final inspection in inspections) {
        await _syncInspectionMedia(inspection.id);
      }
      
    } catch (e) {
      log('BackgroundMediaSyncService: Erro durante sync automático: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Sincroniza apenas as imagens de uma inspeção específica
  Future<void> _syncInspectionMedia(String inspectionId) async {
    try {
      
      // Busca imagens que precisam de upload (sem cloudUrl)
      final allMedia = await _serviceFactory.mediaService.getMediaByInspection(inspectionId);
      final pendingMedia = allMedia.where((m) => m.cloudUrl == null || m.cloudUrl!.isEmpty).toList();
      
      if (pendingMedia.isEmpty) {
        return;
      }
      
      
      // Processa em lotes otimizados para performance
      final batch = pendingMedia.take(_maxImagesPerBatch).toList();
      
      // Upload paralelo para melhor performance (máx 5 simultâneos)
      const int maxConcurrent = 5;
      int successCount = 0;
      
      // Processa em chunks paralelos
      for (int i = 0; i < batch.length; i += maxConcurrent) {
        final chunk = batch.skip(i).take(maxConcurrent).toList();
        
        // Upload paralelo do chunk
        final futures = chunk.map((media) async {
          try {
            return await _uploadMediaOnly(media, inspectionId);
          } catch (e) {
            return false;
          }
        });
        
        final results = await Future.wait(futures);
        successCount += results.where((success) => success).length;
        
        // Pequena pausa entre chunks para não sobrecarregar
        if (i + maxConcurrent < batch.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      if (successCount > 0) {
      }
      
    } catch (e) {
      log('BackgroundMediaSyncService: Erro ao sincronizar imagens da inspeção $inspectionId: $e');
    }
  }
  
  /// Faz upload apenas da imagem SEM alterar status da inspeção
  Future<bool> _uploadMediaOnly(OfflineMedia media, String inspectionId) async {
    try {
      // Verifica se já tem URL na nuvem
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        return true; // Já foi feito upload
      }
      
      // Verifica se arquivo existe localmente
      if (media.localPath.isEmpty) {
        return false;
      }
      
      final file = File(media.localPath);
      if (!file.existsSync()) {
        return false;
      }
      
      
      // Upload direto para Firebase Storage
      final cloudUrl = await _uploadToFirebaseStorage(file, media, inspectionId);
      
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        // Atualiza apenas a cloudUrl da imagem NO BANCO LOCAL
        // SEM tocar nos status da inspeção
        await _updateMediaCloudUrlDirectly(media.id, cloudUrl);
        
        return true;
      }
      
      return false;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Atualiza apenas a cloudUrl da imagem SEM alterar status da inspeção
  Future<void> _updateMediaCloudUrlDirectly(String mediaId, String cloudUrl) async {
    try {
      await _serviceFactory.mediaService.updateMediaCloudUrlSilently(mediaId, cloudUrl);
    } catch (e) {
      // Erro silencioso para cloudUrl
    }
  }
  
  /// Upload direto para Firebase Storage com verificação de arquivos existentes
  Future<String?> _uploadToFirebaseStorage(File file, OfflineMedia media, String inspectionId) async {
    try {
      final firebaseService = FirebaseService();
      if (firebaseService.currentUser == null) {
        return null;
      }

      // Se já tem cloudUrl, assume que está válida (evita verificações desnecessárias)
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        return media.cloudUrl!;
      }

      // Comentado: Verificação que estava causando erros 404 desnecessários
      // final existingUrl = await FirebaseTokenManager.generateDownloadUrl(
      //   media.inspectionId,
      //   media.filename,
      //   media.type
      // );
      // if (existingUrl != null) {
      //   return existingUrl;
      // }

      // Se não existe, fazer upload
      final storagePath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // Default content type
        customMetadata: {
          'inspection_id': media.inspectionId,
          'topic_id': media.topicId ?? '',
          'item_id': media.itemId ?? '',
          'detail_id': media.detailId ?? '',
          'non_conformity_id': media.nonConformityId ?? '',
          'type': media.type,
          'original_filename': media.filename,
          'created_at': media.createdAt.toIso8601String(),
        },
      );

      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;

    } catch (e) {
      return null;
    }
  }
  
  /// Verifica se tem conexão com internet
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      
      return result.contains(ConnectivityResult.mobile) || 
             result.contains(ConnectivityResult.wifi) ||
             result.contains(ConnectivityResult.ethernet);
             
    } catch (e) {
      return false;
    }
  }
  
  /// Obtém status atual do serviço
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'isSyncing': _isSyncing,
      'syncInterval': _syncInterval.inMinutes,
      'maxImagesPerBatch': _maxImagesPerBatch,
    };
  }
  
  /// Força uma execução imediata (para testes)
  Future<void> forceSyncNow() async {
    if (!_isRunning) {
    }
    await _performBackgroundImageSync();
  }
}
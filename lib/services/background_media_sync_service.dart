import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/models/offline_media.dart';

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
  
  // Configurações
  static const Duration _syncInterval = Duration(minutes: 5); // Upload a cada 5 minutos
  static const int _maxImagesPerBatch = 3; // Máximo 3 imagens por vez para não sobrecarregar
  
  /// Inicia o serviço de background
  void startBackgroundSync() {
    if (_isRunning) return;
    
    _isRunning = true;
    log('BackgroundMediaSyncService: Iniciando serviço de upload automático de imagens');
    
    // Inicia timer periódico
    _periodicTimer = Timer.periodic(_syncInterval, (_) async {
      await _performBackgroundImageSync();
    });
    
    // Executa primeira tentativa após 30 segundos
    Timer(const Duration(seconds: 30), () async {
      await _performBackgroundImageSync();
    });
  }
  
  /// Para o serviço de background
  void stopBackgroundSync() {
    _isRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    log('BackgroundMediaSyncService: Serviço de upload automático parado');
  }
  
  /// Executa o upload de imagens em background
  Future<void> _performBackgroundImageSync() async {
    if (_isSyncing || !_isRunning) return;
    
    try {
      _isSyncing = true;
      
      // Verifica conectividade
      if (!await _hasInternetConnection()) {
        log('BackgroundMediaSyncService: Sem conexão com internet - pulando sync');
        return;
      }
      
      // Busca todas as inspeções (filtraremos as que têm mudanças locais)
      final allInspections = await _serviceFactory.dataService.getAllInspections();
      final inspections = allInspections.where((i) => i.hasLocalChanges == true).toList();
      
      if (inspections.isEmpty) {
        log('BackgroundMediaSyncService: Nenhuma inspeção com mudanças locais');
        return;
      }
      
      log('BackgroundMediaSyncService: Encontradas ${inspections.length} inspeções com mudanças locais');
      
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
      log('BackgroundMediaSyncService: Iniciando sync de imagens para inspeção $inspectionId');
      
      // Busca imagens que precisam de upload (sem cloudUrl)
      final allMedia = await _serviceFactory.mediaService.getMediaByInspection(inspectionId);
      final pendingMedia = allMedia.where((m) => m.cloudUrl == null || m.cloudUrl!.isEmpty).toList();
      
      if (pendingMedia.isEmpty) {
        log('BackgroundMediaSyncService: Nenhuma imagem pendente para inspeção $inspectionId');
        return;
      }
      
      log('BackgroundMediaSyncService: Encontradas ${pendingMedia.length} imagens pendentes para upload');
      
      // Processa em lotes pequenos para não sobrecarregar
      final batch = pendingMedia.take(_maxImagesPerBatch).toList();
      
      int successCount = 0;
      for (final media in batch) {
        try {
          // IMPORTANTE: Usa método específico que NÃO altera status da inspeção
          final success = await _uploadMediaOnly(media, inspectionId);
          if (success) {
            successCount++;
          }
        } catch (e) {
          log('BackgroundMediaSyncService: Erro ao fazer upload da imagem ${media.id}: $e');
        }
      }
      
      if (successCount > 0) {
        log('BackgroundMediaSyncService: Upload bem-sucedido de $successCount/${batch.length} imagens para inspeção $inspectionId');
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
        log('BackgroundMediaSyncService: Imagem ${media.id} sem caminho local');
        return false;
      }
      
      final file = File(media.localPath);
      if (!file.existsSync()) {
        log('BackgroundMediaSyncService: Arquivo não encontrado: ${media.localPath}');
        return false;
      }
      
      log('BackgroundMediaSyncService: Fazendo upload da imagem ${media.id}');
      
      // Upload direto para Firebase Storage
      final cloudUrl = await _uploadToFirebaseStorage(file, media, inspectionId);
      
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        // Atualiza apenas a cloudUrl da imagem NO BANCO LOCAL
        // SEM tocar nos status da inspeção
        await _updateMediaCloudUrlDirectly(media.id, cloudUrl);
        
        log('BackgroundMediaSyncService: Upload bem-sucedido - URL: $cloudUrl');
        return true;
      }
      
      return false;
      
    } catch (e) {
      log('BackgroundMediaSyncService: Erro no upload da imagem ${media.id}: $e');
      return false;
    }
  }
  
  /// Atualiza apenas a cloudUrl da imagem SEM alterar status da inspeção
  Future<void> _updateMediaCloudUrlDirectly(String mediaId, String cloudUrl) async {
    try {
      await _serviceFactory.mediaService.updateMediaCloudUrlSilently(mediaId, cloudUrl);
      log('BackgroundMediaSyncService: CloudUrl atualizada para $mediaId: $cloudUrl');
    } catch (e) {
      log('BackgroundMediaSyncService: Erro ao atualizar cloudUrl: $e');
    }
  }
  
  /// Upload direto para Firebase Storage
  Future<String?> _uploadToFirebaseStorage(File file, OfflineMedia media, String inspectionId) async {
    try {
      final firebaseService = FirebaseService();
      if (firebaseService.currentUser == null) {
        log('BackgroundMediaSyncService: Usuário não logado');
        return null;
      }
      
      // Gera caminho do arquivo no Storage
      final fileExtension = file.path.split('.').last;
      final fileName = '${media.id}.$fileExtension';
      final storagePath = 'inspections/$inspectionId/media/$fileName';
      
      // Upload para Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = storageRef.putFile(file);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      log('BackgroundMediaSyncService: Arquivo enviado para Storage: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      log('BackgroundMediaSyncService: Erro no upload para Storage: $e');
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
      log('BackgroundMediaSyncService: Erro ao verificar conectividade: $e');
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
      log('BackgroundMediaSyncService: Serviço não está rodando - iniciando sync forçado');
    }
    await _performBackgroundImageSync();
  }
}
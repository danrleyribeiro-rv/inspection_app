import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/features/enhanced_offline_media_service.dart';
import 'package:lince_inspecoes/services/features/template_service.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/services/core/auth_service.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/utils/settings_service.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';

class EnhancedOfflineServiceFactory {
  static EnhancedOfflineServiceFactory? _instance;
  static EnhancedOfflineServiceFactory get instance =>
      _instance ??= EnhancedOfflineServiceFactory._();

  EnhancedOfflineServiceFactory._();

  // Core services
  OfflineDataService? _dataService;
  EnhancedOfflineMediaService? _mediaService;
  TemplateService? _templateService;
  FirestoreSyncService? _syncService;
  AuthService? _authService;
  FirebaseService? _firebaseService;
  SettingsService? _settingsService;
  // SQLiteStorageService removed - now using Hive via DatabaseHelper

  bool _isInitialized = false;

  // Getters para os serviços
  OfflineDataService get dataService {
    _checkInitialization();
    return _dataService!;
  }

  EnhancedOfflineMediaService get mediaService {
    _checkInitialization();
    return _mediaService!;
  }

  FirestoreSyncService get syncService {
    _checkInitialization();
    return _syncService!;
  }

  AuthService get authService {
    _checkInitialization();
    return _authService!;
  }

  FirebaseService get firebaseService {
    _checkInitialization();
    return _firebaseService!;
  }

  SettingsService get settingsService {
    _checkInitialization();
    return _settingsService!;
  }

  // StorageService removed - using DatabaseHelper directly

  TemplateService get templateService {
    _checkInitialization();
    return _templateService!;
  }

  // Verificar se os serviços foram inicializados
  bool get isInitialized => _isInitialized;

  void _checkInitialization() {
    if (!_isInitialized) {
      throw StateError(
          'EnhancedOfflineServiceFactory not initialized. Call initialize() first.');
    }
  }

  // Inicializar todos os serviços
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint(
          'EnhancedOfflineServiceFactory: Initializing enhanced offline services...');

      // 1. Inicializar o banco de dados Hive
      await DatabaseHelper.init();
      debugPrint('EnhancedOfflineServiceFactory: Database initialized');

      // 2. Inicializar Firebase Service
      _firebaseService = FirebaseService();
      debugPrint('EnhancedOfflineServiceFactory: Firebase service initialized');

      // 3. Inicializar Auth Service
      _authService = AuthService();
      debugPrint('EnhancedOfflineServiceFactory: Auth service initialized');

      // 4. Inicializar Enhanced Data Service
      _dataService = OfflineDataService.instance;
      await _dataService!.initialize();
      debugPrint(
          'EnhancedOfflineServiceFactory: Enhanced data service initialized');

      // 5. Inicializar Sync Service
      FirestoreSyncService.initialize(
        firebaseService: _firebaseService!,
        offlineService: _dataService!,
      );
      _syncService = FirestoreSyncService.instance;
      debugPrint('EnhancedOfflineServiceFactory: Sync service initialized');

      // 6. Inicializar Enhanced Media Service
      _mediaService = EnhancedOfflineMediaService.instance;
      await _mediaService!.initialize();
      debugPrint(
          'EnhancedOfflineServiceFactory: Enhanced media service initialized');

      // 7. Inicializar Settings Service
      _settingsService = SettingsService();
      debugPrint('EnhancedOfflineServiceFactory: Settings service initialized');

      // 8. Storage Service removed - using Hive via DatabaseHelper directly
      debugPrint(
          'EnhancedOfflineServiceFactory: Using Hive storage via DatabaseHelper');

      // 9. Inicializar Template Service
      _templateService = TemplateService();
      debugPrint('EnhancedOfflineServiceFactory: Template service initialized');

      _isInitialized = true;
      debugPrint(
          'EnhancedOfflineServiceFactory: All enhanced offline services initialized successfully');
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error initializing services: $e');
      rethrow;
    }
  }

  // Reinicializar todos os serviços
  Future<void> reinitialize() async {
    _isInitialized = false;
    _dataService = null;
    _mediaService = null;
    _templateService = null;
    _syncService = null;
    _authService = null;
    _firebaseService = null;
    _settingsService = null;
    // _storageService removed

    await initialize();
  }

  // Limpar todos os dados
  Future<void> clearAllData() async {
    try {
      _checkInitialization();

      debugPrint('EnhancedOfflineServiceFactory: Clearing all data...');

      // Limpar arquivos de mídia físicos primeiro
      await _clearAllMediaFiles();

      // Limpar dados do banco
      await _dataService!.clearAllData();

      // Limpar Hive storage via DatabaseHelper
      await DatabaseHelper.clearAllData();

      debugPrint('EnhancedOfflineServiceFactory: All data cleared');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error clearing data: $e');
      rethrow;
    }
  }

  /// Limpar todos os arquivos de mídia físicos
  Future<void> _clearAllMediaFiles() async {
    try {
      final allMedia = DatabaseHelper.offlineMedia.values.toList();
      int deletedFiles = 0;
      int deletedThumbs = 0;

      for (final media in allMedia) {
        // Delete physical file
        if (media.localPath.isNotEmpty) {
          try {
            final file = File(media.localPath);
            if (await file.exists()) {
              await file.delete();
              deletedFiles++;
            }
          } catch (e) {
            debugPrint('EnhancedOfflineServiceFactory: Error deleting file ${media.filename}: $e');
          }
        }

        // Delete thumbnail
        if (media.thumbnailPath != null && media.thumbnailPath!.isNotEmpty) {
          try {
            final thumbFile = File(media.thumbnailPath!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
              deletedThumbs++;
            }
          } catch (e) {
            debugPrint('EnhancedOfflineServiceFactory: Error deleting thumbnail ${media.filename}: $e');
          }
        }
      }

      debugPrint('EnhancedOfflineServiceFactory: Deleted $deletedFiles media files and $deletedThumbs thumbnails');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error clearing media files: $e');
    }
  }

  // Obter estatísticas gerais
  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      _checkInitialization();

      final dataStats = await _dataService!.getGlobalStats();
      final mediaStats = await _mediaService!.getGlobalMediaStats();
      final storageStats = await DatabaseHelper.getStatistics();

      return {
        'data': dataStats,
        'media': mediaStats,
        'storage': storageStats,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error getting global stats: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Obter estatísticas de uma inspeção específica
  Future<Map<String, dynamic>> getInspectionStats(String inspectionId) async {
    try {
      _checkInitialization();

      final dataStats =
          await _dataService!.getInspectionCompleteStats(inspectionId);
      final mediaStats = await _mediaService!.getMediaStats(inspectionId);
      final totalMediaSize =
          await _mediaService!.getTotalMediaSize(inspectionId);

      return {
        'inspection_id': inspectionId,
        'data': dataStats,
        'media': mediaStats,
        'total_media_size': totalMediaSize,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error getting inspection stats: $e');
      return {
        'error': e.toString(),
        'inspection_id': inspectionId,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Verificar conectividade e status de sincronização
  Future<Map<String, dynamic>> getConnectivityStatus() async {
    try {
      _checkInitialization();

      final isConnected = await _syncService!.isConnected();

      return {
        'is_connected': isConnected,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error getting connectivity status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Sincronizar todos os dados
  Future<void> syncAllData() async {
    try {
      _checkInitialization();

      debugPrint('EnhancedOfflineServiceFactory: Starting full sync...');

      await _syncService!.performFullSync();

      debugPrint('EnhancedOfflineServiceFactory: Full sync completed');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error during full sync: $e');
      rethrow;
    }
  }

  // Sincronizar uma inspeção específica
  Future<void> syncInspection(String inspectionId) async {
    try {
      _checkInitialization();

      debugPrint(
          'EnhancedOfflineServiceFactory: Starting sync for inspection $inspectionId...');

      await _syncService!.syncInspection(inspectionId);

      debugPrint(
          'EnhancedOfflineServiceFactory: Sync completed for inspection $inspectionId');
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error syncing inspection $inspectionId: $e');
      rethrow;
    }
  }

  // Sincronizar apenas mídia
  Future<void> syncMedia() async {
    try {
      _checkInitialization();

      debugPrint('EnhancedOfflineServiceFactory: Starting media sync...');

      await _mediaService!.syncMedia();

      debugPrint('EnhancedOfflineServiceFactory: Media sync completed');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error during media sync: $e');
      rethrow;
    }
  }

  // Otimizar banco de dados
  Future<void> optimizeDatabase() async {
    try {
      _checkInitialization();

      debugPrint('EnhancedOfflineServiceFactory: Optimizing database...');

      await _dataService!.optimizeDatabase();

      debugPrint(
          'EnhancedOfflineServiceFactory: Database optimization completed');
    } catch (e) {
      debugPrint(
          'EnhancedOfflineServiceFactory: Error optimizing database: $e');
      rethrow;
    }
  }

  // Limpeza e manutenção
  Future<void> performMaintenance() async {
    try {
      _checkInitialization();

      debugPrint('EnhancedOfflineServiceFactory: Performing maintenance...');

      // Otimizar banco de dados
      await optimizeDatabase();

      // Limpar arquivos órfãos de mídia - método não existe ainda, comentado
      // await _mediaService!.cleanupOrphanedFiles();

      // Limpar arquivos temporários - método não existe ainda, comentado
      // await _mediaService!.cleanupTempFiles();

      debugPrint('EnhancedOfflineServiceFactory: Maintenance completed');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error during maintenance: $e');
      rethrow;
    }
  }

  // Status do serviço
  Map<String, dynamic> getServiceStatus() {
    return {
      'is_initialized': _isInitialized,
      'services': {
        'data_service': _dataService != null,
        'media_service': _mediaService != null,
        'sync_service': _syncService != null,
        'auth_service': _authService != null,
        'firebase_service': _firebaseService != null,
        'settings_service': _settingsService != null,
        'storage_service': true, // Using Hive via DatabaseHelper
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Dispose resources
  Future<void> dispose() async {
    try {
      debugPrint('EnhancedOfflineServiceFactory: Disposing services...');

      // Fechar conexões do banco de dados
      await DatabaseHelper.closeDatabase();

      // Limpar referências
      _dataService = null;
      _mediaService = null;
      _syncService = null;
      _authService = null;
      _firebaseService = null;
      _settingsService = null;
      // _storageService removed - using Hive via DatabaseHelper

      _isInitialized = false;

      debugPrint('EnhancedOfflineServiceFactory: Services disposed');
    } catch (e) {
      debugPrint('EnhancedOfflineServiceFactory: Error disposing services: $e');
    }
  }
}

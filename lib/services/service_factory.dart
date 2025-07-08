// service_factory.dart

import 'package:flutter/foundation.dart';
import 'package:inspection_app/services/inspection_coordinator.dart';
import 'package:inspection_app/services/core/auth_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/features/template_service.dart';
import 'package:inspection_app/services/download_service.dart';
import 'package:inspection_app/services/manual_sync_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/utils/settings_service.dart';
import 'package:inspection_app/services/utils/sync_service.dart';
import 'package:inspection_app/services/utils/notification_service.dart';
import 'package:inspection_app/services/utils/import_export_service.dart';
import 'package:inspection_app/services/utils/map_cache_service.dart';
import 'package:inspection_app/services/utils/cloud_media_downloader.dart';

class ServiceFactory {
  static final ServiceFactory _instance = ServiceFactory._internal();
  factory ServiceFactory() => _instance;
  ServiceFactory._internal();

  // Serviços offline-first
  late final DownloadService downloadService;
  late final ManualSyncService manualSyncService;
  
  // Serviços principais
  late final InspectionCoordinator coordinator;
  late final AuthService authService;
  late final MediaService mediaService;
  late final TemplateService templateService;
  
  // Serviços utilitários
  late final CacheService cacheService;
  late final SettingsService settingsService;
  late final SyncService syncService;
  late final NotificationService notificationService;
  late final ImportExportService importExportService;
  late final MapCacheService mapCacheService;
  late final CloudMediaDownloader cloudMediaDownloader;

  /// Inicializa todos os serviços na ordem correta de dependência.
  Future<void> initialize() async {
    // 1. Serviços principais
    authService = AuthService();
    mediaService = MediaService();
    templateService = TemplateService();
    coordinator = InspectionCoordinator();

    // 2. Serviços offline-first
    downloadService = DownloadService();
    manualSyncService = ManualSyncService();

    // 3. Serviços utilitários
    cacheService = CacheService();
    settingsService = SettingsService();
    notificationService = NotificationService();
    cloudMediaDownloader = CloudMediaDownloader();
    importExportService = ImportExportService();
    mapCacheService = MapCacheService();
    syncService = SyncService(cacheService: cacheService);

    // 4. Inicializar MediaService
    await mediaService.initialize();
    
    debugPrint('ServiceFactory: Initialized offline-first services');
  }


  /// Libera os recursos dos serviços, como streams.
  void dispose() {
    // Apenas dispose de serviços que realmente precisam
    mediaService.dispose();
    // syncService.dispose(); // <-- NÃO dispose pois não foi inicializado com listeners
    debugPrint('ServiceFactory: Disposed services');
  }
}

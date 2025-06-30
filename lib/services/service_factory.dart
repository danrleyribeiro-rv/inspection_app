// service_factory.dart

import 'package:inspection_app/services/inspection_coordinator.dart';
import 'package:inspection_app/services/core/auth_service.dart';
import 'package:inspection_app/services/features/chat_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/features/template_service.dart';
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

  // Mude para 'late final' para garantir que sejam inicializados uma vez e não sejam nulos.
  // Isso substitui o padrão de inicialização preguiçosa (lazy) que estava causando o problema.
  late final InspectionCoordinator coordinator;
  late final AuthService authService;
  late final ChatService chatService;
  late final MediaService mediaService;
  late final TemplateService templateService;
  late final CacheService cacheService;
  late final SettingsService settingsService;
  late final SyncService syncService;
  late final NotificationService notificationService;
  late final ImportExportService importExportService;
  late final MapCacheService mapCacheService;
  late final CloudMediaDownloader cloudMediaDownloader;

  /// Inicializa todos os serviços na ordem correta de dependência.
  /// Isso deve ser chamado no `main.dart` após os serviços de base (Firebase, Hive) serem inicializados.
  Future<void> initialize() async {
    // 1. Primeiro, inicialize serviços básicos que não dependem de outros
    cacheService = CacheService(); // <-- CacheService deve ser criado PRIMEIRO
    authService = AuthService();
    settingsService = SettingsService();
    notificationService = NotificationService();
    mapCacheService = MapCacheService();
    cloudMediaDownloader = CloudMediaDownloader();

    // 2. Depois, inicialize serviços que dependem dos básicos
    chatService = ChatService();
    mediaService = MediaService();
    templateService = TemplateService();
    importExportService = ImportExportService();

    // 3. Por último, inicialize o coordinator que depende de todos os data services
    coordinator = InspectionCoordinator();

    // 4. Instancie serviços que dependem de outros, injetando as instâncias já criadas.
    syncService = SyncService(
        cacheService:
            cacheService); // <-- A instância de cacheService é injetada no SyncService.

    // 5. Inicialize serviços que precisam de inicialização assíncrona
    await mediaService.initialize();

    // 6. Chame métodos de inicialização que iniciam listeners ou outras tarefas em segundo plano.
    syncService.initialize();
  }


  /// Libera os recursos dos serviços, como streams.
  void dispose() {
    syncService.dispose();
    mediaService.dispose();
  }
}

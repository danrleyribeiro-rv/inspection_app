// service_factory.dart

import 'package:flutter/material.dart';
import 'package:inspection_app/services/inspection_coordinator.dart';
import 'package:inspection_app/services/core/auth_service.dart';
import 'package:inspection_app/services/features/chat_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/features/checkpoint_service.dart';
import 'package:inspection_app/services/features/template_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/utils/settings_service.dart';
import 'package:inspection_app/services/utils/sync_service.dart';
import 'package:inspection_app/services/utils/notification_service.dart';
import 'package:inspection_app/services/utils/import_export_service.dart';
import 'package:inspection_app/services/utils/checkpoint_dialog_service.dart';

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
  late final CheckpointService checkpointService;
  late final TemplateService templateService;
  late final CacheService cacheService;
  late final SettingsService settingsService;
  late final SyncService syncService;
  late final NotificationService notificationService;
  late final ImportExportService importExportService;

  /// Inicializa todos os serviços na ordem correta de dependência.
  /// Isso deve ser chamado no `main.dart` após os serviços de base (Firebase, Hive) serem inicializados.
  void initialize() {
    // 1. Instancie serviços que não têm outras dependências de serviço.
    coordinator = InspectionCoordinator();
    authService = AuthService();
    chatService = ChatService();
    mediaService = MediaService();
    checkpointService = CheckpointService();
    templateService = TemplateService();
    cacheService = CacheService(); // <-- CacheService é criado aqui.
    settingsService = SettingsService();
    notificationService = NotificationService();
    importExportService = ImportExportService();

    // 2. Instancie serviços que dependem de outros, injetando as instâncias já criadas.
    syncService = SyncService(cacheService: cacheService); // <-- A instância de cacheService é injetada no SyncService.

    // 3. Chame métodos de inicialização que iniciam listeners ou outras tarefas em segundo plano.
    syncService.initialize();
  }

  CheckpointDialogService createCheckpointDialogService(
    BuildContext context,
    Function() onReloadData,
  ) {
    return CheckpointDialogService(
      context,
      checkpointService, // Usa a instância já criada
      onReloadData,
    );
  }

  /// Libera os recursos dos serviços, como streams.
  void dispose() {
    syncService.dispose();
  }
}
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:inspection_app/services/features/offline_service.dart';



class ServiceFactory {
  static final ServiceFactory _instance = ServiceFactory._internal();
  factory ServiceFactory() => _instance;
  ServiceFactory._internal();

  // Singletons
  InspectionCoordinator? _coordinator;
  AuthService? _authService;
  ChatService? _chatService;
  MediaService? _mediaService;
  CheckpointService? _checkpointService;
  TemplateService? _templateService;
  CacheService? _cacheService;
  SettingsService? _settingsService;
  SyncService? _syncService;
  NotificationService? _notificationService;
  ImportExportService? _importExportService;
  OfflineService? _offlineService;


  // Get services (singleton pattern)
  InspectionCoordinator get coordinator {
    _coordinator ??= InspectionCoordinator();
    return _coordinator!;
  }

  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  ChatService get chatService {
    _chatService ??= ChatService();
    return _chatService!;
  }

  MediaService get mediaService {
    _mediaService ??= MediaService();
    return _mediaService!;
  }

  CheckpointService get checkpointService {
    _checkpointService ??= CheckpointService();
    return _checkpointService!;
  }

  TemplateService get templateService {
    _templateService ??= TemplateService();
    return _templateService!;
  }

  CacheService get cacheService {
    _cacheService ??= CacheService();
    return _cacheService!;
  }

  SettingsService get settingsService {
    _settingsService ??= SettingsService();
    return _settingsService!;
  }

  SyncService get syncService {
    _syncService ??= SyncService();
    return _syncService!;
  }

  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  ImportExportService get importExportService {
    _importExportService ??= ImportExportService();
    return _importExportService!;
  }

  OfflineService get offlineService {
  _offlineService ??= OfflineService();
  return _offlineService!;
  }

  CheckpointDialogService createCheckpointDialogService(
    BuildContext context,
    Function() onReloadData,
  ) {
    return CheckpointDialogService(
      context,
      checkpointService,
      onReloadData,
    );
  }

  // Initialize all services
  void initialize() {
    offlineService.initialize();
    syncService.initialize();
  }

  // Dispose all services
  void dispose() {
    _offlineService?.dispose();
    _syncService?.dispose();
  }

  // Check if online
  Future<bool> isOnline() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
           result.contains(ConnectivityResult.mobile);
  }
}
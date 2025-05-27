// lib/services/service_locator.dart
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/auth_service.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/chat_service.dart';
import 'package:inspection_app/services/cache_service.dart';
import 'package:inspection_app/services/settings_service.dart';
import 'package:inspection_app/services/checkpoint_service.dart';
import 'package:inspection_app/services/notification_service.dart';
import 'package:inspection_app/services/import_export_service.dart';

class ServiceLocator {
  static final _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core services
  FirebaseService get firebase => FirebaseService();
  AuthService get auth => AuthService();
  InspectionService get inspection => InspectionService();
  ChatService get chat => ChatService();
  CacheService get cache => CacheService();
  SettingsService get settings => SettingsService();
  CheckpointService get checkpoint => CheckpointService();
  NotificationService get notification => NotificationService();
  ImportExportService get importExport => ImportExportService();

  // Initialize all services
  static Future<void> initialize() async {
    await ServiceLocator().cache.clearCache();
  }
}
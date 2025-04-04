// lib/utils/app_config.dart
import 'package:flutter/material.dart';

class AppConfig {
  // App Information
  static const String appName = 'Inspection App';
  static const String appVersion = '1.0.0';
  
  // API and Server Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Theme Configuration
  static const Color primaryColor = Color(0xFF1a237e);
  static const Color accentColor = Color(0xFF1a237e);
  
  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableSyncNotifications = true;
  
  // Sync Configuration
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxMediaPerDetail = 10;
  static const int maxDetailMediaSize = 5 * 1024 * 1024; // 5 MB
  
  // Cache Configuration
  static const Duration cacheExpirationDuration = Duration(days: 7);
  
  // Performance Tuning
  static const int maxConcurrentUploads = 3;
  static const Duration uploadRetryDelay = Duration(seconds: 30);
  static const int maxUploadRetries = 3;
}
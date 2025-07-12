import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class SimpleNotificationService {
  static SimpleNotificationService? _instance;
  static SimpleNotificationService get instance {
    _instance ??= SimpleNotificationService._internal();
    return _instance!;
  }
  
  SimpleNotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  static const String _channelId = 'lince_sync_channel';
  static const String _channelName = 'Lince Sincronização';
  static const String _channelDescription = 'Notificações de sincronização de inspeções';
  
  // Notification IDs
  static const int _syncProgressId = 1001;
  static const int _downloadProgressId = 1002;
  static const int _completionId = 1003;
  static const int _errorId = 1004;
  
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      debugPrint('SimpleNotificationService: Initializing...');
      
      // Request permissions first
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('SimpleNotificationService: Permissions not granted');
        return false;
      }
      
      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false,
      );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );
      
      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }
      
      _isInitialized = true;
      debugPrint('SimpleNotificationService: Initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('SimpleNotificationService: Error initializing: $e');
      return false;
    }
  }
  
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        debugPrint('SimpleNotificationService: Android notification permission status: $status');
        return status.isGranted;
      } else if (Platform.isIOS) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        debugPrint('SimpleNotificationService: iOS notification permission result: $result');
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('SimpleNotificationService: Error requesting permissions: $e');
      return false;
    }
  }
  
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      );
      
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      debugPrint('SimpleNotificationService: Notification channel created');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error creating notification channel: $e');
    }
  }
  
  Future<void> showSyncProgress({
    required String title,
    required String message,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) async {
    await _showProgressNotification(
      id: _syncProgressId,
      title: title,
      message: message,
      progress: progress,
      maxProgress: maxProgress,
      indeterminate: indeterminate,
    );
  }
  
  Future<void> showDownloadProgress({
    required String title,
    required String message,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) async {
    await _showProgressNotification(
      id: _downloadProgressId,
      title: title,
      message: message,
      progress: progress,
      maxProgress: maxProgress,
      indeterminate: indeterminate,
    );
  }
  
  Future<void> _showProgressNotification({
    required int id,
    required String title,
    required String message,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) async {
    if (!_isInitialized) {
      debugPrint('SimpleNotificationService: Not initialized, cannot show progress notification');
      return;
    }
    
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showProgress: true,
        progress: progress ?? 0,
        maxProgress: maxProgress ?? 100,
        indeterminate: indeterminate,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        message,
        platformChannelSpecifics,
      );
      
      debugPrint('SimpleNotificationService: Progress notification shown: $title - $message');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error showing progress notification: $e');
    }
  }
  
  Future<void> showCompletionNotification({
    required String title,
    required String message,
    bool isSuccess = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('SimpleNotificationService: Not initialized, cannot show completion notification');
      return;
    }
    
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showProgress: false,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );
      
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        _completionId,
        title,
        message,
        platformChannelSpecifics,
      );
      
      debugPrint('SimpleNotificationService: Completion notification shown: $title - $message');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error showing completion notification: $e');
    }
  }
  
  Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    if (!_isInitialized) {
      debugPrint('SimpleNotificationService: Not initialized, cannot show error notification');
      return;
    }
    
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showProgress: false,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );
      
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        _errorId,
        title,
        message,
        platformChannelSpecifics,
      );
      
      debugPrint('SimpleNotificationService: Error notification shown: $title - $message');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error showing error notification: $e');
    }
  }
  
  Future<void> hideAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('SimpleNotificationService: All notifications hidden');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error hiding notifications: $e');
    }
  }
  
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      } else if (Platform.isIOS) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return result?.isEnabled ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('SimpleNotificationService: Error checking notification permissions: $e');
      return false;
    }
  }
  
  /// Show a simple test notification
  Future<void> showTestNotification() async {
    try {
      await showCompletionNotification(
        title: 'Teste de Notificação',
        message: 'Sistema de notificações funcionando!',
        isSuccess: true,
      );
      debugPrint('SimpleNotificationService: Test notification sent');
    } catch (e) {
      debugPrint('SimpleNotificationService: Error showing test notification: $e');
    }
  }
}
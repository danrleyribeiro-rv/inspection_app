import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static LocalNotificationService? _instance;
  static LocalNotificationService get instance {
    _instance ??= LocalNotificationService._internal();
    return _instance!;
  }
  
  LocalNotificationService._internal();
  
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
      debugPrint('LocalNotificationService: Initializing...');
      
      // Request permissions first
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('LocalNotificationService: Permissions not granted');
        return false;
      }
      
      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      
      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }
      
      _isInitialized = true;
      debugPrint('LocalNotificationService: Initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('LocalNotificationService: Error initializing: $e');
      return false;
    }
  }
  
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires explicit notification permission
        if (await _isAndroid13OrHigher()) {
          final status = await Permission.notification.request();
          debugPrint('LocalNotificationService: Android notification permission status: $status');
          return status.isGranted;
        } else {
          // For Android 12 and below, notifications are allowed by default
          return true;
        }
      } else if (Platform.isIOS) {
        // iOS permission request
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        debugPrint('LocalNotificationService: iOS notification permission result: $result');
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('LocalNotificationService: Error requesting permissions: $e');
      return false;
    }
  }
  
  Future<bool> _isAndroid13OrHigher() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        return androidInfo >= 33; // Android 13 is API level 33
      }
      return false;
    } catch (e) {
      debugPrint('LocalNotificationService: Error checking Android version: $e');
      return false;
    }
  }
  
  Future<int> _getAndroidVersion() async {
    // This is a simplified version. In a real app, you'd use device_info_plus
    // For now, we'll assume it's a recent version
    return 33; // Assume Android 13+
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
      
      debugPrint('LocalNotificationService: Notification channel created');
    } catch (e) {
      debugPrint('LocalNotificationService: Error creating notification channel: $e');
    }
  }
  
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('LocalNotificationService: Notification tapped: ${response.payload}');
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
      debugPrint('LocalNotificationService: Not initialized, cannot show progress notification');
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
      
      debugPrint('LocalNotificationService: Progress notification shown: $title - $message');
    } catch (e) {
      debugPrint('LocalNotificationService: Error showing progress notification: $e');
    }
  }
  
  Future<void> showCompletionNotification({
    required String title,
    required String message,
    bool isSuccess = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('LocalNotificationService: Not initialized, cannot show completion notification');
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
      
      debugPrint('LocalNotificationService: Completion notification shown: $title - $message');
    } catch (e) {
      debugPrint('LocalNotificationService: Error showing completion notification: $e');
    }
  }
  
  Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    if (!_isInitialized) {
      debugPrint('LocalNotificationService: Not initialized, cannot show error notification');
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
      
      debugPrint('LocalNotificationService: Error notification shown: $title - $message');
    } catch (e) {
      debugPrint('LocalNotificationService: Error showing error notification: $e');
    }
  }
  
  Future<void> hideAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('LocalNotificationService: All notifications hidden');
    } catch (e) {
      debugPrint('LocalNotificationService: Error hiding notifications: $e');
    }
  }
  
  Future<void> updateProgress({
    required int progress,
    required int maxProgress,
    String? message,
  }) async {
    // This will be handled by showing a new notification with updated progress
    // The framework will replace the existing one with the same ID
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
      debugPrint('LocalNotificationService: Error checking notification permissions: $e');
      return false;
    }
  }
}
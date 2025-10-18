import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lince_inspecoes/services/app_toast_service.dart';

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
  static const String _channelName = 'Lince - Sincronização';
  static const String _channelDescription = 'Notificações de sincronização de inspeções';

  // Notification IDs
  static const int _syncProgressId = 1001;
  static const int _downloadProgressId = 1002;
  static const int _completionId = 1003;
  static const int _errorId = 1004;

  // Callback for sync cancellation
  Function(String)? _onCancelSync;
  String? _currentSyncInspectionId;
  
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Use in-app toasts for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _isInitialized = true;
        return true;
      }

      // Request permissions first
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
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
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      _isInitialized = true;
      return true;

    } catch (e) {
      debugPrint('SimpleNotificationService: Error initializing: $e');
      return false;
    }
  }
  
  /// Set callback for sync cancellation
  void setSyncCancelCallback(Function(String) callback, String inspectionId) {
    _onCancelSync = callback;
    _currentSyncInspectionId = inspectionId;
  }

  /// Clear sync cancel callback
  void clearSyncCancelCallback() {
    _onCancelSync = null;
    _currentSyncInspectionId = null;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('SimpleNotificationService: Notification tapped with action: ${response.actionId}');

    if (response.actionId == 'cancel_sync' && _currentSyncInspectionId != null && _onCancelSync != null) {
      debugPrint('SimpleNotificationService: Cancelling sync for inspection $_currentSyncInspectionId');
      _onCancelSync!(_currentSyncInspectionId!);
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
    int? currentItem,
    int? totalItems,
    String? estimatedTime,
    String? speed,
  }) async {
    // Formatar mensagem com progresso e tempo estimado
    String formattedMessage = message;
    
    if (currentItem != null && totalItems != null) {
      formattedMessage = 'Enviando $currentItem/$totalItems';
      
      if (estimatedTime != null) {
        formattedMessage += ' • $estimatedTime';
      }
      
      if (speed != null) {
        formattedMessage += ' • $speed';
      }
    }
    
    await _showProgressNotification(
      id: _syncProgressId,
      title: title,
      message: formattedMessage,
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

    // Use in-app toasts for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      AppToastService.instance.showProgress(
        title: title,
        message: message,
        progress: progress,
        maxProgress: maxProgress,
        indeterminate: indeterminate,
      );
      return;
    }

    try{
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
        actions: id == _syncProgressId
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'cancel_sync',
                  'Cancelar',
                  cancelNotification: true,
                  showsUserInterface: false,
                ),
              ]
            : null,
      );

      // Para iOS, incluir o progresso no texto da mensagem
      String iOSMessage = message;
      if (Platform.isIOS && !indeterminate && progress != null && maxProgress != null) {
        final percentage = ((progress / maxProgress) * 100).round();
        iOSMessage = '$message ($percentage%)';
      }

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
        id,
        title,
        Platform.isIOS ? iOSMessage : message,
        platformChannelSpecifics,
      );

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

    // Use in-app toasts for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      AppToastService.instance.showCompletion(
        title: title,
        message: message,
        isSuccess: isSuccess,
      );
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

    // Use in-app toasts for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      AppToastService.instance.showError(
        title: title,
        message: message,
      );
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

    } catch (e) {
      debugPrint('SimpleNotificationService: Error showing error notification: $e');
    }
  }
  
  Future<void> hideAllNotifications() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        AppToastService.instance.hideAll();
      } else {
        await _flutterLocalNotificationsPlugin.cancelAll();
      }
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
  
}
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lince_inspecoes/services/app_toast_service.dart';
import 'package:live_activities/live_activities.dart';

class SimpleNotificationService {
  static SimpleNotificationService? _instance;
  static SimpleNotificationService get instance {
    _instance ??= SimpleNotificationService._internal();
    return _instance!;
  }

  SimpleNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _liveActivitiesPlugin = LiveActivities();
  bool _isInitialized = false;
  String? _currentActivityId;

  static const String _channelId = 'lince_sync_channel';
  static const String _channelName = 'Lince - Sincronização';
  static const String _channelDescription =
      'Notificações de sincronização de inspeções';

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
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
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
    debugPrint(
        'SimpleNotificationService: Notification tapped with action: ${response.actionId}');

    if (response.actionId == 'cancel_sync' &&
        _currentSyncInspectionId != null &&
        _onCancelSync != null) {
      debugPrint(
          'SimpleNotificationService: Cancelling sync for inspection $_currentSyncInspectionId');
      _onCancelSync!(_currentSyncInspectionId!);
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      }
      return true;
    } catch (e) {
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
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      // Error creating notification channel
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
    String? inspectionId,
    String? currentItemName,
    String? topicName,
    String phase = 'uploading',
    int? mediaCount,
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

    // Atualizar Live Activity para iOS (Dynamic Island)
    if (Platform.isIOS && inspectionId != null) {
      await _updateLiveActivity(
        inspectionId: inspectionId,
        title: title,
        message: formattedMessage,
        current: currentItem ?? 0,
        total: totalItems ?? 100,
        progress: maxProgress != null && progress != null
            ? (progress / maxProgress)
            : 0.0,
        currentItem: currentItemName,
        topicName: topicName,
        phase: phase,
        mediaCount: mediaCount,
        estimatedTime: estimatedTime,
        speed: speed,
      );
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
      debugPrint(
          'SimpleNotificationService: Not initialized, cannot show progress notification');
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

    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
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
      if (Platform.isIOS &&
          !indeterminate &&
          progress != null &&
          maxProgress != null) {
        final percentage = ((progress / maxProgress) * 100).round();
        iOSMessage = '$message ($percentage%)';
      }

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
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
      debugPrint(
          'SimpleNotificationService: Error showing progress notification: $e');
    }
  }

  Future<void> showCompletionNotification({
    required String title,
    required String message,
    bool isSuccess = true,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'SimpleNotificationService: Not initialized, cannot show completion notification');
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
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
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

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
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
      debugPrint(
          'SimpleNotificationService: Error showing completion notification: $e');
    }
  }

  Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'SimpleNotificationService: Not initialized, cannot show error notification');
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
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
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

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
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
      debugPrint(
          'SimpleNotificationService: Error showing error notification: $e');
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
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return result?.isEnabled ?? false;
      }
      return true;
    } catch (e) {
      debugPrint(
          'SimpleNotificationService: Error checking notification permissions: $e');
      return false;
    }
  }

  // Live Activities (Dynamic Island)

  /// Cria ou atualiza uma Live Activity para iOS
  Future<void> _updateLiveActivity({
    required String inspectionId,
    required String title,
    required String message,
    required int current,
    required int total,
    required double progress,
    String? currentItem,
    String? topicName,
    required String phase,
    int? mediaCount,
    String? estimatedTime,
    String? speed,
  }) async {
    if (!Platform.isIOS) return;

    try {
      // Dados da Live Activity
      final activityData = {
        'inspectionId': inspectionId,
        'title': title,
        'message': message,
        'current': current,
        'total': total,
        'progress': progress,
        'currentItem': currentItem,
        'topicName': topicName,
        'phase': phase,
        'mediaCount': mediaCount,
        'estimatedTime': estimatedTime,
        'speed': speed,
      };

      // Se não existe uma atividade, cria uma nova
      if (_currentActivityId == null) {
        _currentActivityId = await _liveActivitiesPlugin.createActivity(
          activityData.toString(), // Convert Map to JSON string
          <String,
              dynamic>{}, // Provide an empty map or populate with required data
        );
        debugPrint(
            'SimpleNotificationService: Live Activity created: $_currentActivityId');
      } else {
        // Atualiza a atividade existente
        await _liveActivitiesPlugin.updateActivity(
            _currentActivityId!, activityData);
        debugPrint(
            'SimpleNotificationService: Live Activity updated: $_currentActivityId');
      }
    } catch (e) {
      debugPrint('SimpleNotificationService: Error updating Live Activity: $e');
    }
  }

  /// Finaliza a Live Activity atual
  Future<void> endLiveActivity() async {
    if (!Platform.isIOS || _currentActivityId == null) return;

    try {
      await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      debugPrint(
          'SimpleNotificationService: Live Activity ended: $_currentActivityId');
      _currentActivityId = null;
    } catch (e) {
      debugPrint('SimpleNotificationService: Error ending Live Activity: $e');
    }
  }

  /// Verifica se Live Activities estão habilitadas
  Future<bool> areLiveActivitiesEnabled() async {
    if (!Platform.isIOS) return false;

    try {
      return await _liveActivitiesPlugin.areActivitiesEnabled();
    } catch (e) {
      debugPrint(
          'SimpleNotificationService: Error checking Live Activities: $e');
      return false;
    }
  }

  /// Limpa todas as notificações e Live Activities
  Future<void> clearAll() async {
    await hideAllNotifications();
    await endLiveActivity();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Serviço de notificações toast internas da aplicação
/// Funciona em todas as plataformas (Windows, Linux, macOS, Android, iOS)
class AppToastService {
  static AppToastService? _instance;
  static AppToastService get instance {
    _instance ??= AppToastService._internal();
    return _instance!;
  }

  AppToastService._internal();

  final List<ToastNotification> _activeToasts = [];
  final ValueNotifier<List<ToastNotification>> toastsNotifier = ValueNotifier([]);

  /// Mostra uma notificação de progresso
  void showProgress({
    required String title,
    required String message,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) {
    debugPrint('AppToastService: Showing progress - $title: $message');

    String displayMessage = message;
    if (!indeterminate && progress != null && maxProgress != null && maxProgress > 0) {
      int percentage = ((progress / maxProgress) * 100).round();
      displayMessage = '$message ($percentage%)';
    }

    _showToast(
      title: title,
      message: displayMessage,
      type: ToastType.info,
      progress: !indeterminate && progress != null && maxProgress != null ? progress / maxProgress : null,
    );
  }

  /// Mostra uma notificação de conclusão
  void showCompletion({
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    debugPrint('AppToastService: Showing completion - $title: $message');
    _showToast(
      title: title,
      message: message,
      type: isSuccess ? ToastType.success : ToastType.warning,
      duration: const Duration(seconds: 4),
    );
  }

  /// Mostra uma notificação de erro
  void showError({
    required String title,
    required String message,
  }) {
    debugPrint('AppToastService: Showing error - $title: $message');
    _showToast(
      title: title,
      message: message,
      type: ToastType.error,
      duration: const Duration(seconds: 5),
    );
  }

  /// Remove todas as notificações
  void hideAll() {
    debugPrint('AppToastService: Hiding all toasts');
    _activeToasts.clear();
    toastsNotifier.value = List.from(_activeToasts);
  }

  void _showToast({
    required String title,
    required String message,
    required ToastType type,
    double? progress,
    Duration duration = const Duration(seconds: 3),
  }) {
    final toast = ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      progress: progress,
      timestamp: DateTime.now(),
    );

    _activeToasts.add(toast);
    toastsNotifier.value = List.from(_activeToasts);

    // Auto-remover após duração
    Future.delayed(duration, () {
      _activeToasts.removeWhere((t) => t.id == toast.id);
      toastsNotifier.value = List.from(_activeToasts);
    });
  }
}

enum ToastType {
  info,
  success,
  warning,
  error,
}

class ToastNotification {
  final String id;
  final String title;
  final String message;
  final ToastType type;
  final double? progress;
  final DateTime timestamp;

  ToastNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.progress,
    required this.timestamp,
  });
}

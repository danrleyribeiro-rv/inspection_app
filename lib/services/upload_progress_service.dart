import 'dart:async';
import 'dart:developer';

class UploadProgressService {
  static final UploadProgressService _instance = UploadProgressService._internal();
  factory UploadProgressService() => _instance;
  UploadProgressService._internal();

  static UploadProgressService get instance => _instance;

  // Controle de uploads ativos
  final Map<String, UploadProgress> _activeUploads = {};
  
  // Timer para atualização periódica
  Timer? _updateTimer;

  /// Inicia o tracking de um conjunto de uploads
  void startUploadTracking(String sessionId, List<UploadItem> items) {
    _activeUploads[sessionId] = UploadProgress(
      sessionId: sessionId,
      items: items,
      startTime: DateTime.now(),
    );
    
    // Inicia timer para atualizar a cada 2 segundos
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateProgress();
    });
  }

  /// Atualiza o progresso de um item específico
  void updateItemProgress(String sessionId, String itemId, int bytesUploaded) {
    final progress = _activeUploads[sessionId];
    if (progress == null) return;

    final item = progress.items.firstWhere((item) => item.id == itemId);
    item.bytesUploaded = bytesUploaded;
    item.isCompleted = bytesUploaded >= item.totalBytes;
    
    if (item.isCompleted && item.completedAt == null) {
      item.completedAt = DateTime.now();
    }
  }

  /// Marca um item como concluído
  void markItemCompleted(String sessionId, String itemId) {
    final progress = _activeUploads[sessionId];
    if (progress == null) return;

    final item = progress.items.firstWhere((item) => item.id == itemId);
    item.isCompleted = true;
    item.completedAt = DateTime.now();
    item.bytesUploaded = item.totalBytes;
  }

  /// Obtém estatísticas atuais do upload
  UploadStats? getUploadStats(String sessionId) {
    final progress = _activeUploads[sessionId];
    if (progress == null) return null;

    final now = DateTime.now();
    final elapsedTime = now.difference(progress.startTime);
    
    // Calcular progresso geral
    int totalBytes = 0;
    int uploadedBytes = 0;
    int completedItems = 0;
    
    for (final item in progress.items) {
      totalBytes += item.totalBytes;
      uploadedBytes += item.bytesUploaded;
      if (item.isCompleted) completedItems++;
    }

    // Calcular velocidade (últimos 10 segundos)
    final double speedBytesPerSecond = _calculateCurrentSpeed(progress, now);
    
    // Estimar tempo restante
    final int remainingBytes = totalBytes - uploadedBytes;
    Duration? estimatedTimeRemaining;
    if (speedBytesPerSecond > 0 && remainingBytes > 0) {
      final secondsRemaining = remainingBytes / speedBytesPerSecond;
      estimatedTimeRemaining = Duration(seconds: secondsRemaining.ceil());
    }

    return UploadStats(
      currentItem: completedItems + 1,
      totalItems: progress.items.length,
      completedItems: completedItems,
      totalBytes: totalBytes,
      uploadedBytes: uploadedBytes,
      speedBytesPerSecond: speedBytesPerSecond,
      estimatedTimeRemaining: estimatedTimeRemaining,
      elapsedTime: elapsedTime,
    );
  }

  /// Calcula a velocidade atual baseada nos últimos dados
  double _calculateCurrentSpeed(UploadProgress progress, DateTime now) {
    // Filtrar medições dos últimos 10 segundos para velocidade mais precisa
    final cutoffTime = now.subtract(const Duration(seconds: 10));
    
    int totalBytesInWindow = 0;
    int measurements = 0;
    
    for (final item in progress.items) {
      if (item.completedAt != null && item.completedAt!.isAfter(cutoffTime)) {
        final itemDuration = item.completedAt!.difference(progress.startTime);
        if (itemDuration.inSeconds > 0) {
          totalBytesInWindow += item.totalBytes;
          measurements++;
        }
      }
    }

    if (measurements == 0 || totalBytesInWindow == 0) {
      // Fallback: calcular velocidade média geral
      final totalElapsed = now.difference(progress.startTime);
      if (totalElapsed.inSeconds > 0) {
        int totalCompleted = progress.items
            .where((item) => item.isCompleted)
            .fold(0, (sum, item) => sum + item.totalBytes);
        return totalCompleted / totalElapsed.inSeconds;
      }
      return 0;
    }

    return totalBytesInWindow / 10; // últimos 10 segundos
  }

  /// Atualização periódica do progresso
  void _updateProgress() {
    for (final sessionId in _activeUploads.keys.toList()) {
      final stats = getUploadStats(sessionId);
      if (stats != null) {
        // Callback para atualizar UI se necessário
        _notifyProgressUpdate(sessionId, stats);
      }
    }
  }

  /// Notifica atualização de progresso (pode ser usado para callbacks)
  void _notifyProgressUpdate(String sessionId, UploadStats stats) {
    // Log apenas para debug - pode ser expandido para callbacks
    log('Upload $sessionId: ${stats.currentItem}/${stats.totalItems} - ${_formatSpeed(stats.speedBytesPerSecond)} - ${_formatTime(stats.estimatedTimeRemaining)}');
  }

  /// Para o tracking de uma sessão
  void stopUploadTracking(String sessionId) {
    _activeUploads.remove(sessionId);
    
    if (_activeUploads.isEmpty) {
      _updateTimer?.cancel();
      _updateTimer = null;
    }
  }

  /// Formatar velocidade para exibição
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Formatar tempo para exibição
  String _formatTime(Duration? duration) {
    if (duration == null) return 'calculando...';
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Formata estatísticas para notificação
  String formatStatsForNotification(UploadStats stats) {
    final speed = _formatSpeed(stats.speedBytesPerSecond);
    final timeRemaining = _formatTime(stats.estimatedTimeRemaining);
    
    return '${stats.currentItem}/${stats.totalItems} • $timeRemaining restantes • $speed';
  }
}

/// Classe para representar um item de upload
class UploadItem {
  final String id;
  final String filename;
  final int totalBytes;
  int bytesUploaded;
  bool isCompleted;
  DateTime? completedAt;

  UploadItem({
    required this.id,
    required this.filename,
    required this.totalBytes,
    this.bytesUploaded = 0,
    this.isCompleted = false,
    this.completedAt,
  });
}

/// Classe para representar o progresso de uma sessão
class UploadProgress {
  final String sessionId;
  final List<UploadItem> items;
  final DateTime startTime;

  UploadProgress({
    required this.sessionId,
    required this.items,
    required this.startTime,
  });
}

/// Estatísticas de upload
class UploadStats {
  final int currentItem;
  final int totalItems;
  final int completedItems;
  final int totalBytes;
  final int uploadedBytes;
  final double speedBytesPerSecond;
  final Duration? estimatedTimeRemaining;
  final Duration elapsedTime;

  UploadStats({
    required this.currentItem,
    required this.totalItems,
    required this.completedItems,
    required this.totalBytes,
    required this.uploadedBytes,
    required this.speedBytesPerSecond,
    required this.estimatedTimeRemaining,
    required this.elapsedTime,
  });

  double get progressPercentage => totalBytes > 0 ? (uploadedBytes / totalBytes) * 100 : 0;
}
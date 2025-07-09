// lib/presentation/widgets/sync/sync_progress_notification.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/sync_progress.dart'; // Import SyncProgress and SyncPhase

class SyncProgressNotification extends StatelessWidget {
  final SyncProgress progress;
  final VoidCallback? onDismiss;

  const SyncProgressNotification({
    super.key,
    required this.progress,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3B6B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPhaseIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPhaseTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress.phase == SyncPhase.completed || progress.phase == SyncPhase.error)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (progress.phase != SyncPhase.completed && progress.phase != SyncPhase.error) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progress.current} de ${progress.total}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(progress.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.progress,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseIcon() {
    switch (progress.phase) {
      case SyncPhase.starting:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6F4B99).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.sync,
            color: Color(0xFF6F4B99),
            size: 24,
          ),
        );
      case SyncPhase.downloading:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.cloud_download,
            color: Colors.blue,
            size: 24,
          ),
        );
      case SyncPhase.uploading:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.cloud_upload,
            color: Colors.orange,
            size: 24,
          ),
        );
      case SyncPhase.completed:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
        );
      case SyncPhase.error:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 24,
          ),
        );
    }
  }

  String _getPhaseTitle() {
    switch (progress.phase) {
      case SyncPhase.starting:
        return 'Preparando sincronização';
      case SyncPhase.downloading:
        return 'Baixando dados';
      case SyncPhase.uploading:
        return 'Enviando dados';
      case SyncPhase.completed:
        return 'Sincronização concluída';
      case SyncPhase.error:
        return 'Erro na sincronização';
    }
  }

  Color _getProgressColor() {
    switch (progress.phase) {
      case SyncPhase.starting:
        return const Color(0xFF6F4B99);
      case SyncPhase.downloading:
        return Colors.blue;
      case SyncPhase.uploading:
        return Colors.orange;
      case SyncPhase.completed:
        return Colors.green;
      case SyncPhase.error:
        return Colors.red;
    }
  }
}
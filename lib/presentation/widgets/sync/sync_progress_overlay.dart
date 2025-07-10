// lib/presentation/widgets/sync/sync_progress_overlay.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/manual_sync_service.dart'; // Use ManualSyncService
import 'package:lince_inspecoes/presentation/widgets/sync/sync_progress_notification.dart';
import 'package:lince_inspecoes/models/sync_progress.dart'; // Import SyncProgress and SyncPhase
import 'dart:async';

class SyncProgressOverlay {
  static OverlayEntry? _overlayEntry;
  static StreamSubscription<Map<String, bool>>?
      _subscription; // ManualSyncService returns Map<String, bool>

  static void show(BuildContext context) {
    hide(); // Remove any existing overlay

    final ManualSyncService syncService =
        ManualSyncService(); // Get ManualSyncService instance
    final overlay = Overlay.of(context);

    _subscription =
        syncService.syncAllPendingInspections().asStream().listen((results) {
      // Listen to the results of syncAllPendingInspections
      // For simplicity, we'll create a dummy SyncProgress from the results
      SyncProgress progress;
      if (results.containsValue(false)) {
        progress = SyncProgress(
          inspectionId: 'multi',
          phase: SyncPhase.error,
          current: 1,
          total: 1,
          message: 'Sincronização concluída com erros.',
        );
      } else {
        progress = SyncProgress(
          inspectionId: 'multi',
          phase: SyncPhase.completed,
          current: 1,
          total: 1,
          message: 'Sincronização concluída com sucesso!',
        );
      }

      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }

      _overlayEntry = OverlayEntry(
        builder: (overlayContext) => Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 16,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: SyncProgressNotification(
              progress: progress,
              onDismiss: () {
                if (progress.phase == SyncPhase.completed ||
                    progress.phase == SyncPhase.error) {
                  hide();
                }
              },
            ),
          ),
        ),
      );

      overlay.insert(_overlayEntry!);

      // Auto-hide after completion/error
      if (progress.phase == SyncPhase.completed ||
          progress.phase == SyncPhase.error) {
        Timer(const Duration(seconds: 3), () {
          hide();
        });
      }
    });
  }

  static void hide() {
    _subscription?.cancel();
    _subscription = null;

    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
}

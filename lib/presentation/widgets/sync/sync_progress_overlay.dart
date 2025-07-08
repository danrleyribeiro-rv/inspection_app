// lib/presentation/widgets/sync/sync_progress_overlay.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/utils/sync_service.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/sync/sync_progress_notification.dart';
import 'dart:async';

class SyncProgressOverlay {
  static OverlayEntry? _overlayEntry;
  static StreamSubscription<SyncProgress>? _subscription;

  static void show(BuildContext context) {
    hide(); // Remove any existing overlay

    final syncService = ServiceFactory().syncService;
    final overlay = Overlay.of(context);
    
    _subscription = syncService.syncProgressStream.listen((progress) {
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
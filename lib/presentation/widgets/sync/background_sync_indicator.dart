import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/native_sync_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';
import 'dart:async';

class BackgroundSyncIndicator extends StatefulWidget {
  const BackgroundSyncIndicator({super.key});

  @override
  State<BackgroundSyncIndicator> createState() => _BackgroundSyncIndicatorState();
}

class _BackgroundSyncIndicatorState extends State<BackgroundSyncIndicator>
    with SingleTickerProviderStateMixin {
  StreamSubscription<SyncProgress>? _syncSubscription;
  SyncProgress? _currentProgress;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _listenToSyncProgress();
  }

  void _listenToSyncProgress() {
    _syncSubscription = NativeSyncService.instance.syncProgressStream.listen((progress) {
      setState(() {
        _currentProgress = progress;
      });

      if (progress.phase == SyncPhase.starting ||
          progress.phase == SyncPhase.downloading ||
          progress.phase == SyncPhase.uploading) {
        _animationController.forward();
      } else if (progress.phase == SyncPhase.completed ||
          progress.phase == SyncPhase.error) {
        // Show completion/error briefly then hide
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _animationController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _currentProgress = null;
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProgress == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 4.0,
        decoration: BoxDecoration(
          color: _getProgressColor().withValues(alpha: 0.3),
        ),
        child: LinearProgressIndicator(
          value: _currentProgress!.phase == SyncPhase.starting ||
                  _currentProgress!.phase == SyncPhase.downloading ||
                  _currentProgress!.phase == SyncPhase.uploading
              ? null // Indeterminate progress
              : 1.0, // Complete for success/error
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
        ),
      ),
    );
  }

  Color _getProgressColor() {
    if (_currentProgress == null) return Colors.grey;
    
    switch (_currentProgress!.phase) {
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
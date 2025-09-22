import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';

class MediaDownloadVerificationService {
  static MediaDownloadVerificationService? _instance;
  static MediaDownloadVerificationService get instance {
    _instance ??= MediaDownloadVerificationService._internal();
    return _instance!;
  }
  
  MediaDownloadVerificationService._internal();
  
  late final OfflineDataService _offlineService;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final serviceFactory = EnhancedOfflineServiceFactory.instance;
    _offlineService = serviceFactory.dataService;
    _isInitialized = true;
  }
  
  /// Verifica se todas as mídias de uma inspeção foram baixadas
  Future<MediaDownloadStatus> checkInspectionMediaDownloadStatus(String inspectionId) async {
    await initialize();
    
    try {
      debugPrint('MediaDownloadVerificationService: Checking media download status for inspection $inspectionId');
      
      // Buscar todas as mídias da inspeção
      final allMedia = await _offlineService.getMediaByInspection(inspectionId);
      
      if (allMedia.isEmpty) {
        debugPrint('MediaDownloadVerificationService: No media found for inspection $inspectionId');
        return MediaDownloadStatus(
          inspectionId: inspectionId,
          totalMedia: 0,
          downloadedMedia: 0,
          pendingMedia: 0,
          missingMedia: [],
          isComplete: true,
        );
      }
      
      int downloadedCount = 0;
      int pendingCount = 0;
      List<String> missingMedia = [];
      
      for (final media in allMedia) {
        if (media.isUploaded && media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
          // Verificar se o arquivo existe localmente
          if (media.localPath.isNotEmpty) {
            try {
              final file = File(media.localPath);
              if (await file.exists()) {
                downloadedCount++;
                debugPrint('MediaDownloadVerificationService: Media ${media.filename} exists locally');
              } else {
                pendingCount++;
                missingMedia.add(media.filename);
                debugPrint('MediaDownloadVerificationService: Media ${media.filename} missing locally');
              }
            } catch (e) {
              pendingCount++;
              missingMedia.add(media.filename);
              debugPrint('MediaDownloadVerificationService: Error checking media ${media.filename}: $e');
            }
          } else {
            pendingCount++;
            missingMedia.add(media.filename);
            debugPrint('MediaDownloadVerificationService: Media ${media.filename} has no local path');
          }
        } else {
          // Mídia não foi enviada ainda ou não tem URL da nuvem
          debugPrint('MediaDownloadVerificationService: Media ${media.filename} not uploaded or no cloud URL');
        }
      }
      
      final status = MediaDownloadStatus(
        inspectionId: inspectionId,
        totalMedia: allMedia.length,
        downloadedMedia: downloadedCount,
        pendingMedia: pendingCount,
        missingMedia: missingMedia,
        isComplete: pendingCount == 0,
      );
      
      debugPrint('MediaDownloadVerificationService: Media status for inspection $inspectionId: ${status.downloadedMedia}/${status.totalMedia} downloaded, ${status.pendingMedia} pending');
      
      return status;
    } catch (e) {
      debugPrint('MediaDownloadVerificationService: Error checking media download status: $e');
      return MediaDownloadStatus(
        inspectionId: inspectionId,
        totalMedia: 0,
        downloadedMedia: 0,
        pendingMedia: 0,
        missingMedia: [],
        isComplete: false,
        error: e.toString(),
      );
    }
  }
  
  /// Lista todas as mídias que faltam baixar
  Future<List<String>> getMissingMediaFilenames(String inspectionId) async {
    final status = await checkInspectionMediaDownloadStatus(inspectionId);
    return status.missingMedia;
  }
  
  /// Verifica se todas as mídias foram baixadas
  Future<bool> areAllMediaDownloaded(String inspectionId) async {
    final status = await checkInspectionMediaDownloadStatus(inspectionId);
    return status.isComplete;
  }
}

class MediaDownloadStatus {
  final String inspectionId;
  final int totalMedia;
  final int downloadedMedia;
  final int pendingMedia;
  final List<String> missingMedia;
  final bool isComplete;
  final String? error;
  
  MediaDownloadStatus({
    required this.inspectionId,
    required this.totalMedia,
    required this.downloadedMedia,
    required this.pendingMedia,
    required this.missingMedia,
    required this.isComplete,
    this.error,
  });
  
  double get downloadProgress {
    if (totalMedia == 0) return 1.0;
    return downloadedMedia / totalMedia;
  }
  
  @override
  String toString() {
    return 'MediaDownloadStatus(inspectionId: $inspectionId, totalMedia: $totalMedia, downloadedMedia: $downloadedMedia, pendingMedia: $pendingMedia, isComplete: $isComplete, error: $error)';
  }
}
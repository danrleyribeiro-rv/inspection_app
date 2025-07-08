import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/services/service_factory.dart';

class CloudMediaDownloader {
  static const String _mediaDir = 'downloaded_media';
  
  // Stream controllers for progress tracking
  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;
  
  // Get media directory
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_mediaDir');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }
  
  // Download inspection with all media
  Future<void> downloadInspectionWithMedia(String inspectionId) async {
    try {
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.downloadingInspection,
        current: 0,
        total: 1,
        message: 'Baixando dados da inspeção...',
      ));
      
      // First download/refresh inspection data
      final inspectionService = ServiceFactory().cacheService;
      await inspectionService.getInspection(inspectionId);
      
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.downloadingInspection,
        current: 1,
        total: 1,
        message: 'Dados da inspeção baixados. Iniciando download das imagens...',
      ));
      
      // Then download all media
      await downloadAllInspectionMedia(inspectionId);
      
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.completed,
        current: 1,
        total: 1,
        message: 'Download completo!',
      ));
      
    } catch (e) {
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.error,
        current: 0,
        total: 1,
        message: 'Erro no download: $e',
      ));
      rethrow;
    }
  }
  
  // Download all media for an inspection from Firestore
  Future<void> downloadAllInspectionMedia(String inspectionId) async {
    try {
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Starting download for inspection $inspectionId');
      
      final firestore = FirebaseFirestore.instance;
      
      // Get the inspection document to extract media from its hierarchical structure
      final inspectionDoc = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!inspectionDoc.exists) {
        debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Inspection $inspectionId not found');
        return;
      }
      
      final inspectionData = inspectionDoc.data() as Map<String, dynamic>;
      final topics = inspectionData['topics'] as List<dynamic>? ?? [];
      
      // First pass: count total media
      int totalMediaCount = _countMediaInTopics(topics);
      
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.downloadingMedia,
        current: 0,
        total: totalMediaCount,
        message: 'Encontradas $totalMediaCount imagens para baixar...',
      ));
      
      int downloadedCount = 0;
      
      // Download media from hierarchical structure
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = topics[topicIndex] as Map<String, dynamic>;
        final topicId = topic['id'] ?? 'topic_$topicIndex';
        
        // Download topic-level media
        final topicDownloaded = await _downloadMediaFromList(
          topic['media'] as List<dynamic>? ?? [],
          inspectionId,
          topicId,
          null,
          null,
          false,
        );
        downloadedCount += topicDownloaded;
        
        final items = topic['items'] as List<dynamic>? ?? [];
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = items[itemIndex] as Map<String, dynamic>;
          final itemId = item['id'] ?? 'item_${topicIndex}_$itemIndex';
          
          // Download item-level media
          final itemDownloaded = await _downloadMediaFromList(
            item['media'] as List<dynamic>? ?? [],
            inspectionId,
            topicId,
            itemId,
            null,
            false,
          );
          downloadedCount += itemDownloaded;
          
          final details = item['details'] as List<dynamic>? ?? [];
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detail = details[detailIndex] as Map<String, dynamic>;
            final detailId = detail['id'] ?? 'detail_${topicIndex}_${itemIndex}_$detailIndex';
            
            // Download detail-level media
            final detailDownloaded = await _downloadMediaFromList(
              detail['media'] as List<dynamic>? ?? [],
              inspectionId,
              topicId,
              itemId,
              detailId,
              false,
            );
            downloadedCount += detailDownloaded;
            
            // Download non-conformity media
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            for (final nc in nonConformities) {
              final ncData = nc as Map<String, dynamic>;
              final ncDownloaded = await _downloadMediaFromList(
                ncData['media'] as List<dynamic>? ?? [],
                inspectionId,
                topicId,
                itemId,
                detailId,
                true,
              );
              downloadedCount += ncDownloaded;
            }
            
            // Report progress
            _progressController.add(DownloadProgress(
              inspectionId: inspectionId,
              phase: DownloadPhase.downloadingMedia,
              current: downloadedCount,
              total: totalMediaCount,
              message: 'Baixando imagens: $downloadedCount/$totalMediaCount...',
            ));
          }
        }
      }
      
      // Also check for media in separate collection (for backward compatibility)
      try {
        final mediaQuery = await firestore
            .collection('media')
            .where('inspection_id', isEqualTo: inspectionId)
            .get();
        
        debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Found ${mediaQuery.docs.length} media items in separate collection');
        
        for (final doc in mediaQuery.docs) {
          try {
            final mediaData = doc.data();
            final result = await _downloadSingleMedia(
              doc.id,
              mediaData,
              inspectionId,
              mediaData['topic_id'] as String?,
              mediaData['item_id'] as String?,
              mediaData['detail_id'] as String?,
              mediaData['is_non_conformity'] as bool? ?? false,
            );
            if (result) downloadedCount++;
            totalMediaCount++;
          } catch (e) {
            debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Error downloading media ${doc.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Error querying media collection: $e');
      }
      
      _progressController.add(DownloadProgress(
        inspectionId: inspectionId,
        phase: DownloadPhase.completed,
        current: downloadedCount,
        total: totalMediaCount,
        message: 'Download concluído! $downloadedCount/$totalMediaCount imagens baixadas.',
      ));
      
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Completed download for inspection $inspectionId. Downloaded $downloadedCount/$totalMediaCount media items');
    } catch (e) {
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Error downloading media for inspection $inspectionId: $e');
      rethrow;
    }
  }
  
  // Download media from a list of media items
  Future<int> _downloadMediaFromList(
    List<dynamic> mediaList,
    String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    bool isNonConformity,
  ) async {
    int downloadedCount = 0;
    for (int i = 0; i < mediaList.length; i++) {
      try {
        final mediaItem = mediaList[i] as Map<String, dynamic>;
        final mediaId = mediaItem['id'] ?? '${topicId}_${itemId}_${detailId}_media_$i';
        
        final result = await _downloadSingleMedia(
          mediaId,
          mediaItem,
          inspectionId,
          topicId,
          itemId,
          detailId,
          isNonConformity,
        );
        if (result) downloadedCount++;
      } catch (e) {
        debugPrint('CloudMediaDownloader._downloadMediaFromList: Error downloading media at index $i: $e');
      }
    }
    return downloadedCount;
  }
  
  // Download a single media item
  Future<bool> _downloadSingleMedia(
    String mediaId,
    Map<String, dynamic> mediaData,
    String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    bool isNonConformity,
  ) async {
    try {
      final mediaUrl = mediaData['url'] as String?;
      
      if (mediaUrl == null || mediaUrl.isEmpty) {
        debugPrint('CloudMediaDownloader._downloadSingleMedia: Skipping media $mediaId - no URL');
        return false;
      }
      
      final cacheService = ServiceFactory().cacheService;
      
      // Check if already downloaded
      final existingMedia = cacheService.getOfflineMedia(mediaId);
      if (existingMedia != null && existingMedia.isDownloadedFromCloud && await File(existingMedia.localPath).exists()) {
        debugPrint('CloudMediaDownloader._downloadSingleMedia: Media $mediaId already downloaded');
        return false;
      }
      
      // Download the media
      final localFile = await _downloadMediaFile(mediaUrl, mediaId);
      if (localFile != null) {
        // Create OfflineMedia entry
        final offlineMedia = OfflineMedia(
          id: mediaId,
          localPath: localFile.path,
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
          type: _getMediaType(mediaUrl),
          fileName: _getFileName(mediaUrl, mediaId),
          createdAt: _parseDateTime(mediaData['created_at']) ?? DateTime.now(),
          cloudUrl: mediaUrl,
          isDownloadedFromCloud: true,
          isProcessed: true,
          isUploaded: true, // Mark as already uploaded since it came from cloud
          uploadUrl: mediaUrl, // Set the cloud URL as upload URL
          metadata: {
            ...Map<String, dynamic>.from(mediaData['metadata'] ?? {}),
            'is_non_conformity': isNonConformity,
            'source': 'cloud_download',
          },
        );
        
        // Save to cache
        await cacheService.addOfflineMedia(offlineMedia);
        debugPrint('CloudMediaDownloader._downloadSingleMedia: Downloaded and cached media $mediaId');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('CloudMediaDownloader._downloadSingleMedia: Error downloading media $mediaId: $e');
      return false;
    }
  }
  
  // Download a single media file
  Future<File?> _downloadMediaFile(String url, String mediaId) async {
    try {
      debugPrint('CloudMediaDownloader._downloadMediaFile: Downloading $url');
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final mediaDir = await _getMediaDirectory();
        final extension = _getFileExtension(url);
        final fileName = '$mediaId$extension';
        final file = File('${mediaDir.path}/$fileName');
        
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('CloudMediaDownloader._downloadMediaFile: Successfully downloaded to ${file.path}');
        return file;
      } else {
        debugPrint('CloudMediaDownloader._downloadMediaFile: HTTP error ${response.statusCode} for $url');
        return null;
      }
    } catch (e) {
      debugPrint('CloudMediaDownloader._downloadMediaFile: Error downloading $url: $e');
      return null;
    }
  }
  
  // Helper methods
  String _getMediaType(String url) {
    final extension = _getFileExtension(url).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      return 'image';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
      return 'video';
    }
    return 'unknown';
  }
  
  String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1) {
      return path.substring(lastDot);
    }
    return '.jpg'; // Default extension
  }
  
  String _getFileName(String url, String mediaId) {
    final extension = _getFileExtension(url);
    return '$mediaId$extension';
  }
  
  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    
    try {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is Map) {
        // Handle Firestore Timestamp map format
        if (dateValue.containsKey('seconds')) {
          final seconds = dateValue['seconds'] as int;
          final nanoseconds = dateValue['nanoseconds'] as int? ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          );
        }
      }
    } catch (e) {
      debugPrint('CloudMediaDownloader._parseDateTime: Error parsing date $dateValue: $e');
    }
    
    return null;
  }
  
  // Clean downloaded media for inspection
  Future<void> cleanInspectionMedia(String inspectionId) async {
    try {
      final cacheService = ServiceFactory().cacheService;
      final allMedia = cacheService.getAllOfflineMediaForInspection(inspectionId);
      
      for (final media in allMedia) {
        if (media.isDownloadedFromCloud) {
          // Delete local file
          final file = File(media.localPath);
          if (await file.exists()) {
            await file.delete();
          }
          
          // Remove from cache
          await cacheService.removeOfflineMedia(media.id);
        }
      }
      
      debugPrint('CloudMediaDownloader.cleanInspectionMedia: Cleaned media for inspection $inspectionId');
    } catch (e) {
      debugPrint('CloudMediaDownloader.cleanInspectionMedia: Error cleaning media: $e');
    }
  }
  
  // Count total media in topics structure
  int _countMediaInTopics(List<dynamic> topics) {
    int count = 0;
    
    for (final topic in topics) {
      final topicData = topic as Map<String, dynamic>;
      
      // Count topic-level media
      final topicMedia = topicData['media'] as List<dynamic>? ?? [];
      count += topicMedia.length;
      
      final items = topicData['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemData = item as Map<String, dynamic>;
        
        // Count item-level media
        final itemMedia = itemData['media'] as List<dynamic>? ?? [];
        count += itemMedia.length;
        
        final details = itemData['details'] as List<dynamic>? ?? [];
        for (final detail in details) {
          final detailData = detail as Map<String, dynamic>;
          
          // Count detail-level media
          final detailMedia = detailData['media'] as List<dynamic>? ?? [];
          count += detailMedia.length;
          
          // Count non-conformity media
          final nonConformities = detailData['non_conformities'] as List<dynamic>? ?? [];
          for (final nc in nonConformities) {
            final ncData = nc as Map<String, dynamic>;
            final ncMedia = ncData['media'] as List<dynamic>? ?? [];
            count += ncMedia.length;
          }
        }
      }
    }
    
    return count;
  }
  
  void dispose() {
    _progressController.close();
  }
}

// Progress tracking classes
class DownloadProgress {
  final String inspectionId;
  final DownloadPhase phase;
  final int current;
  final int total;
  final String message;
  
  DownloadProgress({
    required this.inspectionId,
    required this.phase,
    required this.current,
    required this.total,
    required this.message,
  });
  
  double get progress => total > 0 ? current / total : 0.0;
}

enum DownloadPhase {
  downloadingInspection,
  downloadingMedia,
  completed,
  error,
}
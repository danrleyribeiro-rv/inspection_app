import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/services/service_factory.dart';

class CloudMediaDownloader {
  static const String _mediaDir = 'downloaded_media';
  
  // Get media directory
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_mediaDir');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }
  
  // Download all media for an inspection from Firestore
  Future<void> downloadAllInspectionMedia(String inspectionId) async {
    try {
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Starting download for inspection $inspectionId');
      
      final firestore = FirebaseFirestore.instance;
      final cacheService = ServiceFactory().cacheService;
      
      // Query all media for this inspection
      final mediaQuery = await firestore
          .collection('media')
          .where('inspection_id', isEqualTo: inspectionId)
          .get();
      
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Found ${mediaQuery.docs.length} media items');
      
      for (final doc in mediaQuery.docs) {
        try {
          final mediaData = doc.data();
          final mediaUrl = mediaData['url'] as String?;
          
          if (mediaUrl == null || mediaUrl.isEmpty) {
            debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Skipping media ${doc.id} - no URL');
            continue;
          }
          
          // Check if already downloaded
          final existingMedia = cacheService.getOfflineMedia(doc.id);
          if (existingMedia != null && existingMedia.isDownloadedFromCloud && await File(existingMedia.localPath).exists()) {
            debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Media ${doc.id} already downloaded');
            continue;
          }
          
          // Download the media
          final localFile = await _downloadMediaFile(mediaUrl, doc.id);
          if (localFile != null) {
            // Create OfflineMedia entry
            final offlineMedia = OfflineMedia(
              id: doc.id,
              localPath: localFile.path,
              inspectionId: inspectionId,
              topicId: mediaData['topic_id'] as String?,
              itemId: mediaData['item_id'] as String?,
              detailId: mediaData['detail_id'] as String?,
              type: _getMediaType(mediaUrl),
              fileName: _getFileName(mediaUrl, doc.id),
              createdAt: _parseDateTime(mediaData['created_at']) ?? DateTime.now(),
              cloudUrl: mediaUrl,
              isDownloadedFromCloud: true,
              isProcessed: true,
              metadata: Map<String, dynamic>.from(mediaData['metadata'] ?? {}),
            );
            
            // Save to cache
            await cacheService.addOfflineMedia(offlineMedia);
            debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Downloaded and cached media ${doc.id}');
          }
        } catch (e) {
          debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Error downloading media ${doc.id}: $e');
        }
      }
      
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Completed download for inspection $inspectionId');
    } catch (e) {
      debugPrint('CloudMediaDownloader.downloadAllInspectionMedia: Error downloading media for inspection $inspectionId: $e');
      rethrow;
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
}
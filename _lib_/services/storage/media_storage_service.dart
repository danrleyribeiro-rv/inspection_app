// lib/services/storage/media_storage_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/services/connectivity/connectivity_service.dart';

class MediaStorageService {
  final _supabase = Supabase.instance.client;
  final _connectivityService = ConnectivityService();
  
  // Get media directory
  Future<Directory> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }
  
  // Get media for a detail
  Future<List<Map<String, dynamic>>> getMediaByDetail(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
  ) async {
    final List<Map<String, dynamic>> mediaItems = [];
    
    try {
      // First try to get local media
      final Directory mediaDir = await getMediaDirectory();
      final String prefix = '${inspectionId}_${roomId}_${itemId}_${detailId}_';
      
      try {
        // Check if directory exists
        if (await mediaDir.exists()) {
          final List<FileSystemEntity> files = await mediaDir.list().toList();
          
          for (final file in files) {
            if (file is File && path.basename(file.path).startsWith(prefix)) {
              final filePath = file.path;
              final fileExt = path.extension(filePath).toLowerCase();
              final isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(fileExt);
              
              mediaItems.add({
                'path': filePath,
                'type': isImage ? 'image' : 'video',
                'timestamp': await file.lastModified().then((date) => date.toIso8601String()),
                'isLocal': true,
              });
            }
          }
        }
      } catch (e) {
        print('Error loading local media: $e');
      }
      
      // Then try to get remote media if online
      if (!_connectivityService.isOffline) {
        try {
          final remoteMedia = await _supabase
              .from('media')
              .select('id, url, type, created_at')
              .eq('inspection_id', inspectionId)
              .eq('room_id', roomId)
              .eq('room_item_id', itemId)
              .eq('detail_id', detailId)
              .order('created_at', ascending: false);
          
          for (final media in remoteMedia) {
            // Check if this remote media is already in our local list
            final String url = media['url'];
            final bool alreadyExists = mediaItems.any((local) => 
              local.containsKey('path') && local['path'].contains(path.basename(url))
            );
            
            if (!alreadyExists) {
              mediaItems.add({
                'id': media['id'],
                'url': url,
                'type': media['type'],
                'timestamp': media['created_at'],
                'isRemote': true,
              });
            }
          }
        } catch (e) {
          print('Error loading remote media: $e');
        }
      }
      
      // Sort by timestamp, newest first
      mediaItems.sort((a, b) {
        final aTime = a['timestamp'] ?? '';
        final bTime = b['timestamp'] ?? '';
        return bTime.compareTo(aTime);
      });
      
      return mediaItems;
    } catch (e) {
      print('Error in getMediaByDetail: $e');
      return [];
    }
  }
  
  // Save media file
  Future<String?> saveMedia(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    File mediaFile,
    String section,
    String mediaType,
  ) async {
    try {
      final mediaDir = await getMediaDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${inspectionId}_${roomId}_${itemId}_${detailId}_${timestamp}${path.extension(mediaFile.path)}';
      final localPath = '${mediaDir.path}/$filename';
      
      // Copy file to media directory
      await mediaFile.copy(localPath);
      
      // Try to upload to Supabase if online
      if (!_connectivityService.isOffline) {
        try {
          // Create storage path
          final storagePath = 'inspections/$inspectionId/$roomId/$itemId/$detailId/$filename';
          
          // Upload to storage
          final storageResponse = await _supabase.storage
              .from('inspection_media')
              .upload(storagePath, mediaFile);
          
          if (storageResponse.isNotEmpty) {
            final publicUrl = _supabase.storage
                .from('inspection_media')
                .getPublicUrl(storagePath);
            
            // Insert reference in database
            await _supabase.from('media').insert({
              'inspection_id': inspectionId,
              'room_id': roomId,
              'room_item_id': itemId,
              'detail_id': detailId,
              'type': mediaType,
              'section': section,
              'url': publicUrl,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          print('Error uploading to Supabase: $e');
          // Continue anyway since we have a local copy
        }
      }
      
      return localPath;
    } catch (e) {
      print('Error saving media: $e');
      return null;
    }
  }
  
  // Delete media
  Future<bool> deleteMedia(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    String mediaPath,
  ) async {
    try {
      // Delete local file
      final file = File(mediaPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Try to delete from Supabase if online
      if (!_connectivityService.isOffline) {
        try {
          final filename = path.basename(mediaPath);
          final storagePath = 'inspections/$inspectionId/$roomId/$itemId/$detailId/$filename';
          
          // Delete from storage
          await _supabase.storage
              .from('inspection_media')
              .remove([storagePath]);
          
          // Delete from database
          await _supabase.from('media')
              .delete()
              .eq('inspection_id', inspectionId)
              .eq('room_id', roomId)
              .eq('room_item_id', itemId)
              .eq('detail_id', detailId)
              .like('url', '%$filename%');
        } catch (e) {
          print('Error deleting from Supabase: $e');
          // Continue anyway since we deleted the local copy
        }
      }
      
      return true;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }
  
  // Delete remote media
  Future<bool> deleteRemoteMedia(String url) async {
    if (_connectivityService.isOffline) {
      return false;
    }
    
    try {
      // Extract path from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Remove the bucket name from path
      final storagePath = pathSegments.join('/');
      
      // Delete from storage
      await _supabase.storage
          .from('inspection_media')
          .remove([storagePath]);
      
      // Delete from database
      await _supabase.from('media')
          .delete()
          .eq('url', url);
      
      return true;
    } catch (e) {
      print('Error deleting remote media: $e');
      return false;
    }
  }
  
  // Download remote media to local storage
  Future<String?> downloadMedia(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    String url,
  ) async {
    if (_connectivityService.isOffline) {
      return null;
    }
    
    try {
      final mediaDir = await getMediaDirectory();
      final filename = path.basename(url);
      final localPath = '${mediaDir.path}/$filename';
      
      // Check if file already exists
      final file = File(localPath);
      if (await file.exists()) {
        return localPath;
      }
      
      // Download from URL
      final http = await _supabase.storage
          .from('inspection_media')
          .download(url);
      
      // Save to file
      await file.writeAsBytes(http);
      
      return localPath;
    } catch (e) {
      print('Error downloading media: $e');
      return null;
    }
  }
}
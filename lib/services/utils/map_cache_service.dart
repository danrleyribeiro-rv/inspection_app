import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapCacheService {
  static const String _cacheDir = 'map_cache';
  
  // Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }
  
  // Generate cache file name from URL
  String _getCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return '${digest.toString()}.png';
  }
  
  // Check if image is cached
  Future<bool> isCached(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      debugPrint('MapCacheService.isCached: Error checking cache: $e');
      return false;
    }
  }
  
  // Get cached image file
  Future<File?> getCachedImage(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('MapCacheService.getCachedImage: Found cached image for URL: $url');
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('MapCacheService.getCachedImage: Error getting cached image: $e');
      return null;
    }
  }
  
  // Download and cache image
  Future<File?> downloadAndCacheImage(String url) async {
    try {
      debugPrint('MapCacheService.downloadAndCacheImage: Downloading image from URL: $url');
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final cacheDir = await _getCacheDirectory();
        final fileName = _getCacheFileName(url);
        final file = File('${cacheDir.path}/$fileName');
        
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('MapCacheService.downloadAndCacheImage: Successfully cached image: $fileName');
        return file;
      } else {
        debugPrint('MapCacheService.downloadAndCacheImage: HTTP error ${response.statusCode} for URL: $url');
        return null;
      }
    } catch (e) {
      debugPrint('MapCacheService.downloadAndCacheImage: Error downloading image: $e');
      return null;
    }
  }
  
  // Clear all cached images
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('MapCacheService.clearCache: Cache cleared successfully');
      }
    } catch (e) {
      debugPrint('MapCacheService.clearCache: Error clearing cache: $e');
    }
  }
  
  // Get cache size
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('MapCacheService.getCacheSize: Error calculating cache size: $e');
      return 0;
    }
  }
  
  // Clean old cache files (older than 7 days)
  Future<void> cleanOldCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            debugPrint('MapCacheService.cleanOldCache: Deleted old cache file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('MapCacheService.cleanOldCache: Error cleaning old cache: $e');
    }
  }
}
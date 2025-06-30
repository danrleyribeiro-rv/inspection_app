// lib/utils/media_debug.dart
import 'dart:io';
import 'package:flutter/material.dart';

class MediaDebug {
  static void logMediaItem(Map<String, dynamic> mediaItem) {
    debugPrint('=== Media Debug ===');
    debugPrint('ID: ${mediaItem['id']}');
    debugPrint('Type: ${mediaItem['type']}');
    debugPrint('URL: ${mediaItem['url']}');
    debugPrint('Local Path: ${mediaItem['localPath']}');
    
    if (mediaItem['localPath'] != null) {
      final file = File(mediaItem['localPath']);
      debugPrint('Local file exists: ${file.existsSync()}');
      if (file.existsSync()) {
        debugPrint('File size: ${file.lengthSync()} bytes');
      }
    }
    debugPrint('==================');
  }
}
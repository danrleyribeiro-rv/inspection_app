// lib/data/repositories/settings_repository_impl.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inspection_app/data/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'darkMode': prefs.getBool('darkMode') ?? false,
        'notificationsEnabled': prefs.getBool('notificationsEnabled') ?? true,
        'locationPermission': prefs.getBool('locationPermission') ?? true,
        'cameraPermission': prefs.getBool('cameraPermission') ?? true,
      };
    } catch (e) {
      print('Error getting settings: $e');
      return {
        'darkMode': false,
        'notificationsEnabled': true,
        'locationPermission': true,
        'cameraPermission': true,
      };
    }
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save each setting individually
      if (settings.containsKey('darkMode')) {
        await prefs.setBool('darkMode', settings['darkMode']);
      }
      
      if (settings.containsKey('notificationsEnabled')) {
        await prefs.setBool('notificationsEnabled', settings['notificationsEnabled']);
      }
      
      if (settings.containsKey('locationPermission')) {
        await prefs.setBool('locationPermission', settings['locationPermission']);
      }
      
      if (settings.containsKey('cameraPermission')) {
        await prefs.setBool('cameraPermission', settings['cameraPermission']);
      }
    } catch (e) {
      print('Error saving settings: $e');
      throw Exception('Failed to save settings: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      // Clear temporary directories
      final cacheDir = await getTemporaryDirectory();
      
      // Don't delete the entire cache directory as it might cause issues
      // Instead, scan directory and delete files older than a certain threshold
      final files = cacheDir.listSync();
      
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          final fileAge = DateTime.now().difference(stat.modified);
          
          // Delete files older than 7 days
          if (fileAge.inDays > 7) {
            // lib/data/repositories/settings_repository_impl.dart (continued)
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
      throw Exception('Failed to clear cache: $e');
    }
  }
}
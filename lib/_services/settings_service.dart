// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_service.dart';

class SettingsService {
  static final _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _firebase = FirebaseService();

  Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _firebase.currentUser?.uid;
    
    Map<String, bool> defaultSettings = {
      'notificationsEnabled': true,
      'locationPermission': true,
      'cameraPermission': true,
    };

    if (userId != null) {
      try {
        final userDoc = await _firebase.firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          return {
            'notificationsEnabled': data['notificationsEnabled'] ?? defaultSettings['notificationsEnabled']!,
            'locationPermission': data['locationPermission'] ?? defaultSettings['locationPermission']!,
            'cameraPermission': data['cameraPermission'] ?? defaultSettings['cameraPermission']!,
          };
        }
      } catch (e) {
        print('Error loading settings from Firebase: $e');
      }
    }

    return {
      'notificationsEnabled': prefs.getBool('notificationsEnabled') ?? defaultSettings['notificationsEnabled']!,
      'locationPermission': prefs.getBool('locationPermission') ?? defaultSettings['locationPermission']!,
      'cameraPermission': prefs.getBool('cameraPermission') ?? defaultSettings['cameraPermission']!,
    };
  }

  Future<void> saveSettings({
    required bool notificationsEnabled,
    required bool locationPermission,
    required bool cameraPermission,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
    await prefs.setBool('locationPermission', locationPermission);
    await prefs.setBool('cameraPermission', cameraPermission);
    
    final userId = _firebase.currentUser?.uid;
    if (userId != null) {
      try {
        await _firebase.firestore.collection('users').doc(userId).set({
          'notificationsEnabled': notificationsEnabled,
          'locationPermission': locationPermission,
          'cameraPermission': cameraPermission,
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error saving settings to Firebase: $e');
      }
    }
  }
}
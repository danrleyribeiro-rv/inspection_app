import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';

class SettingsService {
  final FirebaseService _firebase = FirebaseService();

  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _firebase.currentUser?.uid;

    Map<String, dynamic> defaultSettings = {
      'notificationsEnabled': true,
      'locationPermission': true,
      'cameraPermission': true,
      'themeMode': 'system', // 'light', 'dark', ou 'system'
    };

    if (userId != null) {
      try {
        final userDoc =
            await _firebase.firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          return {
            'notificationsEnabled': data['notificationsEnabled'] ??
                defaultSettings['notificationsEnabled']!,
            'locationPermission': data['locationPermission'] ??
                defaultSettings['locationPermission']!,
            'cameraPermission': data['cameraPermission'] ??
                defaultSettings['cameraPermission']!,
            'themeMode': data['themeMode'] ??
                defaultSettings['themeMode']!,
          };
        }
      } catch (e) {
        debugPrint('Error loading settings from Firebase: $e');
      }
    }

    return {
      'notificationsEnabled': prefs.getBool('notificationsEnabled') ??
          defaultSettings['notificationsEnabled']!,
      'locationPermission': prefs.getBool('locationPermission') ??
          defaultSettings['locationPermission']!,
      'cameraPermission': prefs.getBool('cameraPermission') ??
          defaultSettings['cameraPermission']!,
      'themeMode': prefs.getString('themeMode') ??
          defaultSettings['themeMode']!,
    };
  }

  Future<void> saveSettings({
    required bool notificationsEnabled,
    required bool locationPermission,
    required bool cameraPermission,
    required String themeMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('notificationsEnabled', notificationsEnabled);
    await prefs.setBool('locationPermission', locationPermission);
    await prefs.setBool('cameraPermission', cameraPermission);
    await prefs.setString('themeMode', themeMode);

    final userId = _firebase.currentUser?.uid;
    if (userId != null) {
      try {
        await _firebase.firestore.collection('users').doc(userId).set({
          'notificationsEnabled': notificationsEnabled,
          'locationPermission': locationPermission,
          'cameraPermission': cameraPermission,
          'themeMode': themeMode,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving settings to Firebase: $e');
      }
    }
  }

  Future<String> getThemeMode() async {
    final settings = await loadSettings();
    return settings['themeMode'] as String;
  }

  Future<void> setThemeMode(String themeMode) async {
    final currentSettings = await loadSettings();
    await saveSettings(
      notificationsEnabled: currentSettings['notificationsEnabled'] as bool,
      locationPermission: currentSettings['locationPermission'] as bool,
      cameraPermission: currentSettings['cameraPermission'] as bool,
      themeMode: themeMode,
    );
  }
}

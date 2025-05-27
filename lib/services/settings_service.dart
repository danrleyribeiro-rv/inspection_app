import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _auth.currentUser?.uid;
    bool? notif, loc, cam;
    if (userId != null) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        notif = data['notificationsEnabled'] as bool?;
        loc = data['locationPermission'] as bool?;
        cam = data['cameraPermission'] as bool?;
      }
    }
    return {
      'notificationsEnabled':
          notif ?? prefs.getBool('notificationsEnabled') ?? true,
      'locationPermission': loc ?? prefs.getBool('locationPermission') ?? true,
      'cameraPermission': cam ?? prefs.getBool('cameraPermission') ?? true,
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
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).set({
        'notificationsEnabled': notificationsEnabled,
        'locationPermission': locationPermission,
        'cameraPermission': cameraPermission,
      }, SetOptions(merge: true));
    }
  }
}

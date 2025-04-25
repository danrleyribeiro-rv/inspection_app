// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inspection_app/firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() {
    return _instance;
  }
  
  FirebaseService._internal();
  
  // Firebase instances
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  
  // Initialize Firebase with offline persistence
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable offline persistence for Firestore
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(
        synchronizeTabs: true,
      ),
    );
    
    // Set cache size to 100MB
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600,
    );
    
    print('Firebase initialized with offline persistence');
  }
  
  // Check if device is online (for UI indicators)
  static Future<bool> isOnline() async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('online_check')
          .doc('ping')
          .get(GetOptions(source: Source.server));
      return true;
    } catch (e) {
      return false;
    }
  }
}
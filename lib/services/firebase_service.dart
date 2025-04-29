// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inspection_app/firebase_options.dart';
import 'package:flutter/foundation.dart';

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
  
  // Initialize Firebase with proper offline persistence
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      if (!kIsWeb) {
        // Para plataformas móveis (Android/iOS)
        // A persistência já está habilitada por padrão, mas configuramos o tamanho do cache
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
          print('Firebase initialized for mobile with unlimited cache size');
        } catch (e) {
          print('Error configuring Firestore settings: $e');
        }
      } else {
        // Para plataforma web
        try {
          // Web requer chamada explícita ao enablePersistence
          await FirebaseFirestore.instance.enablePersistence(
            const PersistenceSettings(
              synchronizeTabs: true,
            ),
          );
          print('Firebase web persistence enabled successfully');
        } catch (e) {
          print('Error enabling web persistence: $e');
          // Isso é esperado se já estiver habilitado ou não for suportado neste navegador
        }
      }
      
      print('Firebase initialized with appropriate offline persistence settings');
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }
  
  // Check if device is online (for UI indicators)
  static Future<bool> isOnline() async {
    try {
      // Tenta buscar um documento pequeno do servidor para testar a conexão
      final result = await FirebaseFirestore.instance
          .collection('online_check')
          .doc('ping')
          .get(const GetOptions(source: Source.server));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Force synchronization attempt
  static Future<void> forceSynchronize() async {
    try {
      // Desabilita temporariamente a rede
      await FirebaseFirestore.instance.disableNetwork();
      
      // Pequena pausa para garantir desconexão
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reabilita para forçar sincronização
      await FirebaseFirestore.instance.enableNetwork();
      
      print('Forced synchronization attempt initiated');
    } catch (e) {
      print('Error forcing synchronization: $e');
    }
  }
  
  // Check if there's pending writes that need to be synced to the server
  static Future<bool> hasPendingWrites() async {
    try {
      // Obter qualquer documento com metadados para verificar
      final snapshot = await FirebaseFirestore.instance
          .collection('inspections')
          .limit(1)
          .get();
          
      // Verificar se há writes pendentes
      return snapshot.metadata.hasPendingWrites;
    } catch (e) {
      print('Error checking pending writes: $e');
      return false;
    }
  }
}
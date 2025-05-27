// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_service.dart';

class AuthService {
  static final _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _firebase = FirebaseService();

  User? get currentUser => _firebase.currentUser;
  Stream<User?> get authStateChanges => _firebase.auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    final userCredential = await _firebase.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final isInspector = await _checkUserRole(userCredential.user!.uid, 'inspector');
    if (!isInspector) {
      await _firebase.auth.signOut();
      throw FirebaseAuthException(
        code: 'unauthorized-role',
        message: 'Only inspectors can access this application.',
      );
    }
    
    return userCredential;
  }

  Future<UserCredential> registerInspector({
    required String email,
    required String password,
    required String name,
    required String lastName,
    String? profession,
    String? document,
    String? phoneNumber,
    String? cep,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
  }) async {
    final userCredential = await _firebase.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final userId = userCredential.user!.uid;
    
    await _firebase.firestore.collection('users').doc(userId).set({
      'email': email,
      'role': 'inspector',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    await _firebase.firestore.collection('inspectors').doc(userId).set({
      'user_id': userId,
      'name': name,
      'last_name': lastName,
      'email': email,
      'profession': profession,
      'document': document,
      'phonenumber': phoneNumber,
      'cep': cep,
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'deleted_at': null,
    });
    
    return userCredential;
  }

  Future<bool> _checkUserRole(String userId, String role) async {
    final docSnapshot = await _firebase.firestore.collection('users').doc(userId).get();
    
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      return data != null && data['role'] == role;
    }
    
    return false;
  }

  Future<void> signOut() async => await _firebase.auth.signOut();

  Future<void> resetPassword(String email) async => 
      await _firebase.auth.sendPasswordResetEmail(email: email);

  Future<Map<String, dynamic>?> getInspectorProfile(String userId) async {
    final doc = await _firebase.firestore.collection('inspectors').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateInspectorProfile(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firebase.firestore.collection('inspectors').doc(userId).update(data);
  }
}
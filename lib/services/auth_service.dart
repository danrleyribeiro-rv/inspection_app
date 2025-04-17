// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      } else {
        throw Exception('User not signed in');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Create or update inspector profile
  Future<void> createInspectorProfile({
    required String userId,
    required String name,
    required String lastName,
    required String email,
    String? document,
    String? profession,
    String? phonenumber,
    String? cep,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
  }) async {
    try {
      await _firestore.collection('inspectors').doc(userId).set({
        'user_id': userId,
        'name': name,
        'last_name': lastName,
        'email': email,
        'document': document,
        'profession': profession,
        'phonenumber': phonenumber,
        'cep': cep,
        'street': street,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // Check if user is an inspector
  Future<bool> isUserInspector(String userId) async {
    try {
      final doc = await _firestore.collection('inspectors').doc(userId).get();
      return doc.exists;
    } catch (e) {
      rethrow;
    }
  }

  // Get inspector profile
  Future<Map<String, dynamic>?> getInspectorProfile(String userId) async {
    try {
      final doc = await _firestore.collection('inspectors').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Assign role to user
  Future<void> assignRoleToUser(String userId, String role) async {
    try {
      await _firestore.collection('user_roles').doc(userId).set({
        'user_id': userId,
        'roles': FieldValue.arrayUnion([role]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';

class AuthService {
  final FirebaseService _firebase = FirebaseService();

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? get currentUser => _firebase.currentUser;
  Stream<User?> get authStateChanges => _firebase.auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    final userCredential = await _firebase.auth
        .signInWithEmailAndPassword(email: email, password: password);

    final isInspector =
        await checkUserRole(userCredential.user!.uid, 'inspector');
    if (!isInspector) {
      await _firebase.auth.signOut();
      throw FirebaseAuthException(
        code: 'unauthorized-role',
        message: 'Only inspectors can access this application.',
      );
    }

    // Check if user has accepted terms
    final hasTermsAccepted = await hasAcceptedTerms(userCredential.user!.uid);
    if (!hasTermsAccepted) {
      await _firebase.auth.signOut();
      throw FirebaseAuthException(
        code: 'terms-not-accepted',
        message: 'Terms of service must be accepted to access the application.',
      );
    }

    return userCredential;
  }

  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, Map<String, dynamic> userData) async {
    final userCredential = await _firebase.auth
        .createUserWithEmailAndPassword(email: email, password: password);

    final userId = userCredential.user!.uid;

    await _firebase.firestore.collection('users').doc(userId).set({
      'email': email,
      'role': 'inspector',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firebase.firestore.collection('inspectors').doc(userId).set({
      'user_id': userId,
      ...userData,
      'email': email,
      'terms_accepted': false,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'deleted_at': null,
    });

    return userCredential;
  }

  Future<bool> checkUserRole(String userId, String role) async {
    try {
      final doc =
          await _firebase.firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null && data['role'] == role;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking user role: $e');
      return false;
    }
  }

  Future<bool> isUserInspector(String userId) async {
    return await checkUserRole(userId, 'inspector');
  }

  Future<void> signOut() async {
    await _firebase.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _firebase.auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _firebase.auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw Exception('User not signed in');
    }
  }

  Future<Map<String, dynamic>?> getInspectorProfile(String userId) async {
    final doc =
        await _firebase.firestore.collection('inspectors').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateInspectorProfile(
      String userId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firebase.firestore.collection('inspectors').doc(userId).update(data);
  }

  Future<void> acceptTerms(String userId) async {
    await _firebase.firestore.collection('inspectors').doc(userId).update({
      'terms_accepted': true,
      'terms_accepted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasAcceptedTerms(String userId) async {
    try {
      final doc = await _firebase.firestore.collection('inspectors').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null && (data['terms_accepted'] == true);
      }
      return false;
    } catch (e) {
      debugPrint('Error checking terms acceptance: $e');
      return false;
    }
  }
}

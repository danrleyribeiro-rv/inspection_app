// lib/services/firebase_auth_service.dart (simplified)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseService().auth;
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  static final FirebaseAuthService _instance = FirebaseAuthService._internal();

  factory FirebaseAuthService() {
    return _instance;
  }

  FirebaseAuthService._internal();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Verify if user is an inspector
      final isInspector = await checkUserRole(userCredential.user!.uid, 'inspector');
      if (!isInspector) {
        // If not an inspector, sign out and throw an exception
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'unauthorized-role',
          message: 'Only inspectors can access this application.',
        );
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Register a new user with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email, 
    String password, 
    Map<String, dynamic> userData
  ) async {
    try {
      // Create user in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final userId = userCredential.user!.uid;
      
      // Create user in Firestore with 'inspector' role
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'role': 'inspector',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Create inspector profile in Firestore
      await _firestore.collection('inspectors').doc(userId).set({
        'user_id': userId,
        'name': userData['name'],
        'last_name': userData['last_name'],
        'email': email,
        'document': userData['document'],
        'profession': userData['profession'],
        'phonenumber': userData['phonenumber'],
        'cep': userData['cep'],
        'street': userData['street'],
        'neighborhood': userData['neighborhood'],
        'city': userData['city'],
        'state': userData['state'],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
      });
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Check if a user has a specific role
  Future<bool> checkUserRole(String userId, String role) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        return data != null && data['role'] == role;
      }
      
      return false;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  // Check if a user is an inspector
  Future<bool> isUserInspector(String userId) async {
    return await checkUserRole(userId, 'inspector');
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

  // Update inspector profile
  Future<void> updateInspectorProfile(String userId, Map<String, dynamic> data) async {
    try {
      // Add timestamp
      data['updated_at'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('inspectors').doc(userId).update(data);
    } catch (e) {
      rethrow;
    }
  }
}
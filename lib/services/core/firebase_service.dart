import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  User? get currentUser => auth.currentUser;

  static Future<void> initialize() async {
    // Enable offline persistence for better offline-first experience
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('FirebaseService: Configured for offline-first operation');
    } catch (e) {
      debugPrint('FirebaseService: Settings already configured: $e');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<Map<String, dynamic>?> getInspectorData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      // Try to find by document ID first
      final inspectorDoc =
          await firestore.collection('inspectors').doc(user.uid).get();

      if (inspectorDoc.exists) {
        return {
          'id': inspectorDoc.id,
          ...inspectorDoc.data() ?? {},
        };
      }

      // Fallback to query by user_id
      final inspectorQuery = await firestore
          .collection('inspectors')
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (inspectorQuery.docs.isNotEmpty) {
        final inspectorDoc = inspectorQuery.docs.first;
        return {
          'id': inspectorDoc.id,
          ...inspectorDoc.data(),
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting inspector data: $e');
      return null;
    }
  }

  Future<void> updateInspectorProfile(
      String inspectorId, Map<String, dynamic> data) async {
    await firestore.collection('inspectors').doc(inspectorId).update(data);
  }

  Future<List<Map<String, dynamic>>> getUserInspections() async {
    final inspector = await getInspectorData();
    if (inspector == null) return [];

    final inspectionQuery = await firestore
        .collection('inspections')
        .where('inspector_id', isEqualTo: inspector['id'])
        .where('deleted_at', isNull: true)
        .orderBy('scheduled_date', descending: true)
        .get();

    return inspectionQuery.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // Helper methods
  Future<DocumentReference> addDocument(
      String collection, Map<String, dynamic> data) async {
    return await firestore.collection(collection).add(data);
  }

  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) async {
    await firestore.collection(collection).doc(docId).delete();
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await firestore.collection(collection).doc(docId).get();
  }

  Future<QuerySnapshot> queryDocuments(
    String collection, {
    List<QueryPredicate> predicates = const [],
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query query = firestore.collection(collection);

    for (final predicate in predicates) {
      query = query.where(
        predicate.field,
        isEqualTo: predicate.isEqualTo,
        isNotEqualTo: predicate.isNotEqualTo,
        isGreaterThan: predicate.isGreaterThan,
        isGreaterThanOrEqualTo: predicate.isGreaterThanOrEqualTo,
        isLessThan: predicate.isLessThan,
        isLessThanOrEqualTo: predicate.isLessThanOrEqualTo,
        arrayContains: predicate.arrayContains,
        arrayContainsAny: predicate.arrayContainsAny,
        whereIn: predicate.whereIn,
        whereNotIn: predicate.whereNotIn,
        isNull: predicate.isNull,
      );
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return await query.get();
  }
}

class QueryPredicate {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic>? arrayContainsAny;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;
  final bool? isNull;

  QueryPredicate({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  });
}

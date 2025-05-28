import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // Inicialização do FirebaseService
  static Future<void> initialize() async {
    // Placeholder para inicialização futura
  }

  // Firebase services
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => auth.currentUser;

  // Sign in
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    return await auth.signOut();
  }

  // Get inspector data
Future<Map<String, dynamic>?> getInspectorData() async {
  final user = currentUser;
  if (user == null) {
    return null;
  }

  try {
    // Primeiro tenta buscar por documento com ID igual ao user_id
    final inspectorDoc = await firestore
        .collection('inspectors')
        .doc(user.uid)
        .get();

    if (inspectorDoc.exists) {
      return {
        'id': inspectorDoc.id,
        ...inspectorDoc.data() ?? {},
      };
    }

    // Se não encontrar, busca por consulta
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
    print('Error getting inspector data: $e');
    return null;
  }
}

  // Update inspector profile
  Future<void> updateInspectorProfile(
      String inspectorId, Map<String, dynamic> data) async {
    await firestore.collection('inspectors').doc(inspectorId).update(data);
  }

  // Get inspections for the current user
  Future<List<Map<String, dynamic>>> getUserInspections() async {
    final inspector = await getInspectorData();
    if (inspector == null) {
      return [];
    }

    final inspectionQuery = await firestore
        .collection('inspections')
        .where('inspector_id', isEqualTo: inspector['id'])
        .where('deleted_at', isNull: true)
        .orderBy('scheduled_date', descending: true)
        .get();

    return inspectionQuery.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  // Helper to create a new document with auto-ID
  Future<DocumentReference> addDocument(
      String collection, Map<String, dynamic> data) async {
    return await firestore.collection(collection).add(data);
  }

  // Helper to update a document
  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(docId).update(data);
  }

  // Helper to delete a document
  Future<void> deleteDocument(String collection, String docId) async {
    await firestore.collection(collection).doc(docId).delete();
  }

  // Helper to get a document by ID
  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await firestore.collection(collection).doc(docId).get();
  }

  // Helper to query documents
  Future<QuerySnapshot> queryDocuments(
    String collection, {
    List<QueryPredicate> predicates = const [],
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query query = firestore.collection(collection);

    // Apply predicates
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

    // Apply order
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return await query.get();
  }
}

// Helper class for query predicates
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
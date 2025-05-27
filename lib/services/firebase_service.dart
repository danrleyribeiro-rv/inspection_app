// lib/services/firebase_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class FirebaseService {
  static final _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  final _uuid = Uuid();

  User? get currentUser => auth.currentUser;

  Future<Map<String, dynamic>?> getInspectorData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final inspectorDoc = await firestore
          .collection('inspectors')
          .doc(user.uid)
          .get();

      if (inspectorDoc.exists) {
        return {'id': inspectorDoc.id, ...inspectorDoc.data() ?? {}};
      }

      final inspectorQuery = await firestore
          .collection('inspectors')
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (inspectorQuery.docs.isNotEmpty) {
        final doc = inspectorQuery.docs.first;
        return {'id': doc.id, ...doc.data()};
      }

      return null;
    } catch (e) {
      print('Error getting inspector data: $e');
      return null;
    }
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

    return inspectionQuery.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // Storage methods
  Future<String> uploadFile({
    required File file,
    required String storagePath,
    String? contentType,
  }) async {
    final ref = storage.ref().child(storagePath);

    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<String> uploadInspectionMedia({
    required File file,
    required String inspectionId,
    required String topicId,
    required String itemId,
    required String detailId,
    required String type,
  }) async {
    final fileExt = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${type}_${timestamp}_${_uuid.v4()}$fileExt';

    final storagePath = 'inspections/$inspectionId/$topicId/$itemId/$detailId/$filename';

    String? contentType;
    if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
      contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
    } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
      contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
    }

    return await uploadFile(
      file: file,
      storagePath: storagePath,
      contentType: contentType,
    );
  }

  Future<void> deleteFile(String url) async {
    final ref = storage.refFromURL(url);
    await ref.delete();
  }
}
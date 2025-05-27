// lib/services/checkpoint_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_service.dart';

class InspectionCheckpoint {
  final String id;
  final String inspectionId;
  final String createdBy;
  final DateTime createdAt;
  final String? message;
  final Map<String, dynamic>? data;

  InspectionCheckpoint({
    required this.id,
    required this.inspectionId,
    required this.createdBy,
    required this.createdAt,
    this.message,
    this.data,
  });

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }
}

class CheckpointService {
  static final _instance = CheckpointService._internal();
  factory CheckpointService() => _instance;
  CheckpointService._internal();

  final _firebase = FirebaseService();

  Future<InspectionCheckpoint> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    final inspectionDoc = await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .get();
    
    if (!inspectionDoc.exists) throw Exception('Inspection not found');
    
    final inspectionData = Map<String, dynamic>.from(inspectionDoc.data() ?? {});
    
    final checkpointRef = _firebase.firestore.collection('inspection_checkpoints').doc();
    final timestamp = FieldValue.serverTimestamp();
    
    final checkpointData = {
      'inspection_id': inspectionId,
      'created_by': user.uid,
      'created_at': timestamp,
      'message': message,
      'data': inspectionData,
    };
    
    await checkpointRef.set(checkpointData);
    
    await _firebase.firestore.collection('inspections').doc(inspectionId).update({
      'last_checkpoint_at': timestamp,
      'last_checkpoint_by': user.uid,
      'last_checkpoint_message': message,
      'updated_at': timestamp,
    });
    
    return InspectionCheckpoint(
      id: checkpointRef.id,
      inspectionId: inspectionId,
      createdBy: user.uid,
      createdAt: DateTime.now(),
      message: message,
      data: inspectionData,
    );
  }

  Future<List<InspectionCheckpoint>> getCheckpoints(String inspectionId) async {
    final snapshot = await _firebase.firestore
        .collection('inspection_checkpoints')
        .where('inspection_id', isEqualTo: inspectionId)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      DateTime createdAt;
      
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }
      
      return InspectionCheckpoint(
        id: doc.id,
        inspectionId: data['inspection_id'],
        createdBy: data['created_by'],
        createdAt: createdAt,
        message: data['message'],
        data: data['data'],
      );
    }).toList();
  }

  Future<bool> restoreCheckpoint(String inspectionId, String checkpointId) async {
    try {
      final checkpointDoc = await _firebase.firestore
          .collection('inspection_checkpoints')
          .doc(checkpointId)
          .get();
      
      if (!checkpointDoc.exists) throw Exception('Checkpoint not found');
      
      final checkpointData = checkpointDoc.data();
      if (checkpointData == null || checkpointData['data'] == null) {
        throw Exception('Checkpoint data is missing');
      }
      
      if (checkpointData['inspection_id'] != inspectionId) {
        throw Exception('Checkpoint belongs to a different inspection');
      }
      
      final savedData = Map<String, dynamic>.from(checkpointData['data']);
      
      savedData['restored_from_checkpoint'] = checkpointId;
      savedData['restored_at'] = FieldValue.serverTimestamp();
      savedData['updated_at'] = FieldValue.serverTimestamp();
      
      await _firebase.firestore.collection('inspections').doc(inspectionId).set(savedData);
      
      return true;
    } catch (e) {
      print('Error restoring checkpoint: $e');
      return false;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  // Format date for display
  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }
}

class InspectionCheckpointService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new checkpoint
  Future<InspectionCheckpoint> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    try {
      // Get user ID
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get the current inspection document
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }
      
      // Make a deep copy of the inspection data
      final inspectionData = Map<String, dynamic>.from(inspectionDoc.data() ?? {});
      
      // Create the checkpoint document
      final checkpointRef = _firestore.collection('inspection_checkpoints').doc();
      final timestamp = FieldValue.serverTimestamp();
      
      final checkpointData = {
        'inspection_id': inspectionId,
        'created_by': user.uid,
        'created_at': timestamp,
        'message': message,
        'data': inspectionData,
      };
      
      await checkpointRef.set(checkpointData);
      
      // Return the checkpoint object
      return InspectionCheckpoint(
        id: checkpointRef.id,
        inspectionId: inspectionId,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        message: message,
        data: inspectionData,
      );
    } catch (e) {
      debugPrint('Error creating checkpoint: $e');
      rethrow;
    }
  }

  // Get all checkpoints for an inspection
  Future<List<InspectionCheckpoint>> getCheckpoints(String inspectionId) async {
    try {
      final snapshot = await _firestore
          .collection('inspection_checkpoints')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime createdAt;
        
        // Handle Timestamp or DateTime
        if (data['created_at'] is Timestamp) {
          createdAt = (data['created_at'] as Timestamp).toDate();
        } else {
          // Default to now if timestamp is missing or invalid
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
    } catch (e) {
      debugPrint('Error getting checkpoints: $e');
      rethrow;
    }
  }

  // Restore inspection to a checkpoint
  Future<bool> restoreCheckpoint(String inspectionId, String checkpointId) async {
    try {
      // Get the checkpoint document
      final checkpointDoc = await _firestore.collection('inspection_checkpoints').doc(checkpointId).get();
      if (!checkpointDoc.exists) {
        throw Exception('Checkpoint not found');
      }
      
      final checkpointData = checkpointDoc.data();
      if (checkpointData == null || checkpointData['data'] == null) {
        throw Exception('Checkpoint data is missing');
      }
      
      // Check that the checkpoint belongs to the correct inspection
      if (checkpointData['inspection_id'] != inspectionId) {
        throw Exception('Checkpoint belongs to a different inspection');
      }
      
      // Get the saved data
      final savedData = Map<String, dynamic>.from(checkpointData['data']);
      
      // Add metadata about the restoration
      savedData['restored_from_checkpoint'] = checkpointId;
      savedData['restored_at'] = FieldValue.serverTimestamp();
      
      // Update the inspection with the saved data
      await _firestore.collection('inspections').doc(inspectionId).set(savedData);
      
      return true;
    } catch (e) {
      debugPrint('Error restoring checkpoint: $e');
      return false;
    }
  }

  // Compare current inspection state with a checkpoint
  Future<Map<String, dynamic>> compareWithCheckpoint(String inspectionId, String checkpointId) async {
    try {
      // Get the current inspection
      final currentDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!currentDoc.exists) {
        throw Exception('Inspection not found');
      }
      
      // Get the checkpoint
      final checkpointDoc = await _firestore.collection('inspection_checkpoints').doc(checkpointId).get();
      if (!checkpointDoc.exists) {
        throw Exception('Checkpoint not found');
      }
      
      final checkpointData = checkpointDoc.data();
      if (checkpointData == null || checkpointData['data'] == null) {
        throw Exception('Checkpoint data is missing');
      }
      
      final currentData = currentDoc.data() ?? {};
      final savedData = checkpointData['data'] as Map<String, dynamic>;
      
      // Compare counts
      final currentRooms = currentData['rooms'] as List<dynamic>? ?? [];
      final savedRooms = savedData['rooms'] as List<dynamic>? ?? [];
      
      final currentItems = currentData['items'] as List<dynamic>? ?? [];
      final savedItems = savedData['items'] as List<dynamic>? ?? [];
      
      final currentDetails = currentData['details'] as List<dynamic>? ?? [];
      final savedDetails = savedData['details'] as List<dynamic>? ?? [];
      
      final currentMedia = currentData['media'] as List<dynamic>? ?? [];
      final savedMedia = savedData['media'] as List<dynamic>? ?? [];
      
      final currentNCs = currentData['non_conformities'] as List<dynamic>? ?? [];
      final savedNCs = savedData['non_conformities'] as List<dynamic>? ?? [];
      
      return {
        'rooms': {
          'current': currentRooms.length,
          'checkpoint': savedRooms.length,
          'diff': currentRooms.length - savedRooms.length,
        },
        'items': {
          'current': currentItems.length,
          'checkpoint': savedItems.length,
          'diff': currentItems.length - savedItems.length,
        },
        'details': {
          'current': currentDetails.length,
          'checkpoint': savedDetails.length,
          'diff': currentDetails.length - savedDetails.length,
        },
        'media': {
          'current': currentMedia.length,
          'checkpoint': savedMedia.length,
          'diff': currentMedia.length - savedMedia.length,
        },
        'non_conformities': {
          'current': currentNCs.length,
          'checkpoint': savedNCs.length,
          'diff': currentNCs.length - savedNCs.length,
        },
      };
    } catch (e) {
      debugPrint('Error comparing checkpoint: $e');
      return {};
    }
  }
}
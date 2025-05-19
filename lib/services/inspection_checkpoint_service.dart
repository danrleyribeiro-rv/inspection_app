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

  Future<InspectionCheckpoint> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get the complete inspection document with all nested data
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }
      
      // Create a deep copy of the entire inspection data
      final inspectionData = Map<String, dynamic>.from(inspectionDoc.data() ?? {});
      
      // Create the checkpoint document with the complete inspection state
      final checkpointRef = _firestore.collection('inspection_checkpoints').doc();
      final timestamp = FieldValue.serverTimestamp();
      
      final checkpointData = {
        'inspection_id': inspectionId,
        'created_by': user.uid,
        'created_at': timestamp,
        'message': message,
        'data': inspectionData, // Store the complete inspection state
      };
      
      await checkpointRef.set(checkpointData);
      
      // Update the inspection document with last checkpoint info
      await _firestore.collection('inspections').doc(inspectionId).update({
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
    } catch (e) {
      debugPrint('Error creating checkpoint: $e');
      rethrow;
    }
  }

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
    } catch (e) {
      debugPrint('Error getting checkpoints: $e');
      rethrow;
    }
  }

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
      
      // Get the saved inspection data
      final savedData = Map<String, dynamic>.from(checkpointData['data']);
      
      // Add metadata about the restoration
      savedData['restored_from_checkpoint'] = checkpointId;
      savedData['restored_at'] = FieldValue.serverTimestamp();
      savedData['updated_at'] = FieldValue.serverTimestamp();
      
      // Replace the entire inspection document with the checkpoint data
      await _firestore.collection('inspections').doc(inspectionId).set(savedData);
      
      return true;
    } catch (e) {
      debugPrint('Error restoring checkpoint: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> compareWithCheckpoint(String inspectionId, String checkpointId) async {
    try {
      // Get the checkpoint
      final checkpointDoc = await _firestore.collection('inspection_checkpoints').doc(checkpointId).get();
      if (!checkpointDoc.exists) {
        throw Exception('Checkpoint not found');
      }
      
      final checkpointData = checkpointDoc.data();
      if (checkpointData == null || checkpointData['data'] == null) {
        throw Exception('Checkpoint data is missing');
      }
      
      // Get current inspection
      final currentInspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!currentInspectionDoc.exists) {
        throw Exception('Current inspection not found');
      }
      
      final savedInspectionData = checkpointData['data'] as Map<String, dynamic>;
      final currentInspectionData = currentInspectionDoc.data() as Map<String, dynamic>;
      
      // Count elements in saved state
      final savedTopics = List<Map<String, dynamic>>.from(savedInspectionData['topics'] ?? []);
      int savedTopicsCount = savedTopics.length;
      int savedItemsCount = 0;
      int savedDetailsCount = 0;
      int savedMediaCount = 0;
      int savedNcCount = 0;
      
      for (final topic in savedTopics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        savedItemsCount += items.length;
        
        for (final item in items) {
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          savedDetailsCount += details.length;
          
          for (final detail in details) {
            final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
            savedMediaCount += media.length;
            
            final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
            savedNcCount += nonConformities.length;
            
            // Count media in non-conformities
            for (final nc in nonConformities) {
              final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
              savedMediaCount += ncMedia.length;
            }
          }
        }
      }
      
      // Count elements in current state
      final currentTopics = List<Map<String, dynamic>>.from(currentInspectionData['topics'] ?? []);
      int currentTopicsCount = currentTopics.length;
      int currentItemsCount = 0;
      int currentDetailsCount = 0;
      int currentMediaCount = 0;
      int currentNcCount = 0;
      
      for (final topic in currentTopics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        currentItemsCount += items.length;
        
        for (final item in items) {
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          currentDetailsCount += details.length;
          
          for (final detail in details) {
            final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
            currentMediaCount += media.length;
            
            final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
            currentNcCount += nonConformities.length;
            
            // Count media in non-conformities
            for (final nc in nonConformities) {
              final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
              currentMediaCount += ncMedia.length;
            }
          }
        }
      }
      
      return {
        'topics': {
          'current': currentTopicsCount,
          'checkpoint': savedTopicsCount,
          'diff': currentTopicsCount - savedTopicsCount,
        },
        'items': {
          'current': currentItemsCount,
          'checkpoint': savedItemsCount,
          'diff': currentItemsCount - savedItemsCount,
        },
        'details': {
          'current': currentDetailsCount,
          'checkpoint': savedDetailsCount,
          'diff': currentDetailsCount - savedDetailsCount,
        },
        'media': {
          'current': currentMediaCount,
          'checkpoint': savedMediaCount,
          'diff': currentMediaCount - savedMediaCount,
        },
        'non_conformities': {
          'current': currentNcCount,
          'checkpoint': savedNcCount,
          'diff': currentNcCount - savedNcCount,
        },
      };
    } catch (e) {
      debugPrint('Error comparing checkpoint: $e');
      return {};
    }
  }
  
  Future<double> getCompletionPercentage(String inspectionId) async {
    try {
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!inspectionDoc.exists) return 0.0;
      
      final inspectionData = inspectionDoc.data() as Map<String, dynamic>;
      final topics = List<Map<String, dynamic>>.from(inspectionData['topics'] ?? []);
      
      int totalDetails = 0;
      int completedDetails = 0;
      
      for (final topic in topics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        
        for (final item in items) {
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          
          for (final detail in details) {
            totalDetails++;
            
            // Consider a detail completed if it has a value
            if (detail['value'] != null && detail['value'].toString().isNotEmpty) {
              completedDetails++;
            }
          }
        }
      }
      
      if (totalDetails == 0) return 0.0;
      return (completedDetails / totalDetails) * 100.0;
    } catch (e) {
      debugPrint('Error calculating completion percentage: $e');
      return 0.0;
    }
  }
  
  Future<void> updateLastCheckpoint(String inspectionId, double completion) async {
      try {
        await _firestore.collection('inspections').doc(inspectionId).update({
          'last_checkpoint_completion': completion,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating last checkpoint: $e');
      }
    }
  }
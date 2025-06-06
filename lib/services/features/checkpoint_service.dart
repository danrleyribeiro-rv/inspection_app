// lib/services/features/checkpoint_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/models/inspection_checkpoint.dart'; // Import adicionado

class CheckpointService {
  final FirebaseService _firebase = FirebaseService();

  Future<InspectionCheckpoint> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final inspectionDoc = await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .get();

    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final inspectionData =
        Map<String, dynamic>.from(inspectionDoc.data() ?? {});

    final checkpointRef =
        _firebase.firestore.collection('inspection_checkpoints').doc();
    final timestamp = FieldValue.serverTimestamp();

    final checkpointData = {
      'inspection_id': inspectionId,
      'created_by': user.uid,
      'created_at': timestamp,
      'message': message,
      'data': inspectionData,
    };

    await checkpointRef.set(checkpointData);

    await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .update({
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

    return snapshot.docs
        .map((doc) => InspectionCheckpoint.fromFirestore(doc))
        .toList();
  }

  Future<bool> restoreCheckpoint(
      String inspectionId, String checkpointId) async {
    try {
      final checkpointDoc = await _firebase.firestore
          .collection('inspection_checkpoints')
          .doc(checkpointId)
          .get();

      if (!checkpointDoc.exists) {
        throw Exception('Checkpoint not found');
      }

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

      await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .set(savedData);

      return true;
    } catch (e) {
      debugPrint('Error restoring checkpoint: $e');
      return false;
    }
  }

  Future<double> getCompletionPercentage(String inspectionId) async {
    try {
      final inspectionDoc = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!inspectionDoc.exists) return 0.0;

      final inspectionData = inspectionDoc.data() as Map<String, dynamic>;
      final topics =
          List<Map<String, dynamic>>.from(inspectionData['topics'] ?? []);

      int totalDetails = 0;
      int completedDetails = 0;

      for (final topic in topics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

        for (final item in items) {
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);

          for (final detail in details) {
            totalDetails++;

            if (detail['value'] != null &&
                detail['value'].toString().isNotEmpty) {
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

  Future<Map<String, dynamic>> compareWithCheckpoint(
      String inspectionId, String checkpointId) async {
    try {
      final checkpointDoc = await _firebase.firestore
          .collection('inspection_checkpoints')
          .doc(checkpointId)
          .get();

      if (!checkpointDoc.exists) {
        throw Exception('Checkpoint not found');
      }

      final checkpointData = checkpointDoc.data();
      if (checkpointData == null || checkpointData['data'] == null) {
        throw Exception('Checkpoint data is missing');
      }

      final currentInspectionDoc = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!currentInspectionDoc.exists) {
        throw Exception('Current inspection not found');
      }

      final savedInspectionData =
          checkpointData['data'] as Map<String, dynamic>;
      final currentInspectionData =
          currentInspectionDoc.data() as Map<String, dynamic>;

      // Count elements in saved state
      final savedTopics =
          List<Map<String, dynamic>>.from(savedInspectionData['topics'] ?? []);
      int savedTopicsCount = savedTopics.length;
      int savedItemsCount = 0;
      int savedDetailsCount = 0;
      int savedMediaCount = 0;
      int savedNcCount = 0;

      for (final topic in savedTopics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        savedItemsCount += items.length;

        for (final item in items) {
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          savedDetailsCount += details.length;

          for (final detail in details) {
            final media =
                List<Map<String, dynamic>>.from(detail['media'] ?? []);
            savedMediaCount += media.length;

            final nonConformities = List<Map<String, dynamic>>.from(
                detail['non_conformities'] ?? []);
            savedNcCount += nonConformities.length;

            for (final nc in nonConformities) {
              final ncMedia =
                  List<Map<String, dynamic>>.from(nc['media'] ?? []);
              savedMediaCount += ncMedia.length;
            }
          }
        }
      }

      // Count elements in current state
      final currentTopics = List<Map<String, dynamic>>.from(
          currentInspectionData['topics'] ?? []);
      int currentTopicsCount = currentTopics.length;
      int currentItemsCount = 0;
      int currentDetailsCount = 0;
      int currentMediaCount = 0;
      int currentNcCount = 0;

      for (final topic in currentTopics) {
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        currentItemsCount += items.length;

        for (final item in items) {
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          currentDetailsCount += details.length;

          for (final detail in details) {
            final media =
                List<Map<String, dynamic>>.from(detail['media'] ?? []);
            currentMediaCount += media.length;

            final nonConformities = List<Map<String, dynamic>>.from(
                detail['non_conformities'] ?? []);
            currentNcCount += nonConformities.length;

            for (final nc in nonConformities) {
              final ncMedia =
                  List<Map<String, dynamic>>.from(nc['media'] ?? []);
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
}

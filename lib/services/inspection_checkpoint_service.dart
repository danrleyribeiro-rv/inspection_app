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
      
      // Get the inspection document
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }
      
      // Create a deep copy of the inspection data
      final inspectionData = Map<String, dynamic>.from(inspectionDoc.data() ?? {});
      
      // Get topics, items, details, etc.
      final topics = await _getAllTopics(inspectionId);
      
      // Add topics to the data
      inspectionData['topics'] = topics;
      
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
      
      // Update the inspection document with last checkpoint info
      await _firestore.collection('inspections').doc(inspectionId).update({
        'last_checkpoint_at': timestamp,
        'last_checkpoint_by': user.uid,
        'last_checkpoint_message': message,
        'updated_at': timestamp,
      });
      
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
      
      // Get the saved inspection data
      final savedData = Map<String, dynamic>.from(checkpointData['data']);
      
      // Get the topics data
      final topicsData = savedData['topics'] as List<dynamic>? ?? [];
      
      // Remove topics from savedData
      savedData.remove('topics');
      
      // Add metadata about the restoration
      savedData['restored_from_checkpoint'] = checkpointId;
      savedData['restored_at'] = FieldValue.serverTimestamp();
      
      // Start a batch operation
      WriteBatch batch = _firestore.batch();
      
      // Update the inspection document
      batch.set(_firestore.collection('inspections').doc(inspectionId), savedData);
      
      // Delete existing topics and their children
      await _deleteAllTopics(inspectionId);
      
      // Restore topics from checkpoint
      for (var topicData in topicsData) {
        final topicId = topicData['id'];
        final topicRef = _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId);
        
        // Remove nested data and id
        final cleanTopicData = Map<String, dynamic>.from(topicData);
        cleanTopicData.remove('id');
        cleanTopicData.remove('items');
        
        // Set topic data
        batch.set(topicRef, cleanTopicData);
        
        // Process items
        final itemsData = topicData['items'] as List<dynamic>? ?? [];
        
        for (var itemData in itemsData) {
          final itemId = itemData['id'];
          final itemRef = topicRef.collection('topic_items').doc(itemId);
          
          // Remove nested data and id
          final cleanItemData = Map<String, dynamic>.from(itemData);
          cleanItemData.remove('id');
          cleanItemData.remove('details');
          
          // Set item data
          batch.set(itemRef, cleanItemData);
          
          // Process details
          final detailsData = itemData['details'] as List<dynamic>? ?? [];
          
          for (var detailData in detailsData) {
            final detailId = detailData['id'];
            final detailRef = itemRef.collection('item_details').doc(detailId);
            
            // Remove nested data and id
            final cleanDetailData = Map<String, dynamic>.from(detailData);
            cleanDetailData.remove('id');
            cleanDetailData.remove('media');
            cleanDetailData.remove('non_conformities');
            
            // Set detail data
            batch.set(detailRef, cleanDetailData);
            
            // Process media
            final mediaData = detailData['media'] as List<dynamic>? ?? [];
            
            for (var media in mediaData) {
              final mediaId = media['id'];
              final mediaRef = detailRef.collection('media').doc(mediaId);
              
              // Remove id
              final cleanMediaData = Map<String, dynamic>.from(media);
              cleanMediaData.remove('id');
              
              // Set media data
              batch.set(mediaRef, cleanMediaData);
            }
            
            // Process non-conformities
            final ncData = detailData['non_conformities'] as List<dynamic>? ?? [];
            
            for (var nc in ncData) {
              final ncId = nc['id'];
              final ncRef = detailRef.collection('non_conformities').doc(ncId);
              
              // Remove nested data and id
              final cleanNcData = Map<String, dynamic>.from(nc);
              cleanNcData.remove('id');
              cleanNcData.remove('media');
              
              // Set non-conformity data
              batch.set(ncRef, cleanNcData);
              
              // Process non-conformity media
              final ncMediaData = nc['media'] as List<dynamic>? ?? [];
              
              for (var ncMedia in ncMediaData) {
                final ncMediaId = ncMedia['id'];
                final ncMediaRef = ncRef.collection('nc_media').doc(ncMediaId);
                
                // Remove id
                final cleanNcMediaData = Map<String, dynamic>.from(ncMedia);
                cleanNcMediaData.remove('id');
                
                // Set non-conformity media data
                batch.set(ncMediaRef, cleanNcMediaData);
              }
            }
          }
        }
      }
      
      // Commit the batch
      await batch.commit();
      
      return true;
    } catch (e) {
      debugPrint('Error restoring checkpoint: $e');
      return false;
    }
  }

  // Compare current inspection state with a checkpoint
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
      
      final savedData = checkpointData['data'] as Map<String, dynamic>;
      final savedTopics = savedData['topics'] as List<dynamic>? ?? [];
      
      // Get current topics, items, details, etc.
      final currentTopics = await _getAllTopics(inspectionId);
      
      // Compare counts
      int currentTopicsCount = currentTopics.length;
      int savedTopicsCount = savedTopics.length;
      
      int currentItemsCount = 0;
      int savedItemsCount = 0;
      
      int currentDetailsCount = 0;
      int savedDetailsCount = 0;
      
      int currentMediaCount = 0;
      int savedMediaCount = 0;
      
      int currentNcCount = 0;
      int savedNcCount = 0;
      
      // Count current items, details, media, and non-conformities
      for (var topic in currentTopics) {
        final items = topic['items'] as List<dynamic>? ?? [];
        currentItemsCount += items.length;
        
        for (var item in items) {
          final details = item['details'] as List<dynamic>? ?? [];
          currentDetailsCount += details.length;
          
          for (var detail in details) {
            final media = detail['media'] as List<dynamic>? ?? [];
            currentMediaCount += media.length;
            
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            currentNcCount += nonConformities.length;
            
            for (var nc in nonConformities) {
              final ncMedia = nc['media'] as List<dynamic>? ?? [];
              currentMediaCount += ncMedia.length;
            }
          }
        }
      }
      
      // Count saved items, details, media, and non-conformities
      for (var topic in savedTopics) {
        final items = topic['items'] as List<dynamic>? ?? [];
        savedItemsCount += items.length;
        
        for (var item in items) {
          final details = item['details'] as List<dynamic>? ?? [];
          savedDetailsCount += details.length;
          
          for (var detail in details) {
            final media = detail['media'] as List<dynamic>? ?? [];
            savedMediaCount += media.length;
            
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            savedNcCount += nonConformities.length;
            
            for (var nc in nonConformities) {
              final ncMedia = nc['media'] as List<dynamic>? ?? [];
              savedMediaCount += ncMedia.length;
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
  
  // Helper to get all topics and their children
  Future<List<Map<String, dynamic>>> _getAllTopics(String inspectionId) async {
    final topicsSnapshot = await _firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .get();
    
    List<Map<String, dynamic>> topics = [];
    
    for (var topicDoc in topicsSnapshot.docs) {
      final topicId = topicDoc.id;
      final topicData = topicDoc.data();
      
      // Get items for this topic
      final itemsSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .get();
      
      List<Map<String, dynamic>> items = [];
      
      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        final itemData = itemDoc.data();
        
        // Get details for this item
        final detailsSnapshot = await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .get();
        
        List<Map<String, dynamic>> details = [];
        
        for (var detailDoc in detailsSnapshot.docs) {
          final detailId = detailDoc.id;
          final detailData = detailDoc.data();
          
          // Get media for this detail
          final mediaSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('media')
              .get();
          
          List<Map<String, dynamic>> media = [];
          
          for (var mediaDoc in mediaSnapshot.docs) {
            media.add({
              'id': mediaDoc.id,
              ...mediaDoc.data(),
            });
          }
          
          // Get non-conformities for this detail
          final ncSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('non_conformities')
              .get();
          
          List<Map<String, dynamic>> nonConformities = [];
          
          for (var ncDoc in ncSnapshot.docs) {
            final ncId = ncDoc.id;
            final ncData = ncDoc.data();
            
            // Get media for this non-conformity
            final ncMediaSnapshot = await _firestore
                .collection('inspections')
                .doc(inspectionId)
.collection('topics')
                .doc(topicId)
                .collection('topic_items')
                .doc(itemId)
                .collection('item_details')
                .doc(detailId)
                .collection('non_conformities')
                .doc(ncId)
                .collection('nc_media')
                .get();
            
            List<Map<String, dynamic>> ncMedia = [];
            
            for (var ncMediaDoc in ncMediaSnapshot.docs) {
              ncMedia.add({
                'id': ncMediaDoc.id,
                ...ncMediaDoc.data(),
              });
            }
            
            // Add media to non-conformity
            nonConformities.add({
              'id': ncId,
              ...ncData,
              'media': ncMedia,
            });
          }
          
          // Add media and non-conformities to detail
          details.add({
            'id': detailId,
            ...detailData,
            'media': media,
            'non_conformities': nonConformities,
          });
        }
        
        // Add details to item
        items.add({
          'id': itemId,
          ...itemData,
          'details': details,
        });
      }
      
      // Add items to topic
      topics.add({
        'id': topicId,
        ...topicData,
        'items': items,
      });
    }
    
    return topics;
  }
  
  // Helper to delete all topics and their children
  Future<void> _deleteAllTopics(String inspectionId) async {
    // Get all topics
    final topicsSnapshot = await _firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .get();
    
    // For each topic
    for (var topicDoc in topicsSnapshot.docs) {
      final topicId = topicDoc.id;
      
      // Get all items
      final itemsSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .get();
      
      // For each item
      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        
        // Get all details
        final detailsSnapshot = await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .get();
        
        // For each detail
        for (var detailDoc in detailsSnapshot.docs) {
          final detailId = detailDoc.id;
          
          // Delete all media
          final mediaSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('media')
              .get();
          
          for (var mediaDoc in mediaSnapshot.docs) {
            await mediaDoc.reference.delete();
          }
          
          // Get all non-conformities
          final ncSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('non_conformities')
              .get();
          
          // For each non-conformity
          for (var ncDoc in ncSnapshot.docs) {
            final ncId = ncDoc.id;
            
            // Delete all non-conformity media
            final ncMediaSnapshot = await _firestore
                .collection('inspections')
                .doc(inspectionId)
                .collection('topics')
                .doc(topicId)
                .collection('topic_items')
                .doc(itemId)
                .collection('item_details')
                .doc(detailId)
                .collection('non_conformities')
                .doc(ncId)
                .collection('nc_media')
                .get();
            
            for (var ncMediaDoc in ncMediaSnapshot.docs) {
              await ncMediaDoc.reference.delete();
            }
            
            // Delete non-conformity
            await ncDoc.reference.delete();
          }
          
          // Delete detail
          await detailDoc.reference.delete();
        }
        
        // Delete item
        await itemDoc.reference.delete();
      }
      
      // Delete topic
      await topicDoc.reference.delete();
    }
  }
  
  // Get completion percentage
  Future<double> getCompletionPercentage(String inspectionId) async {
    try {
      // Get all topics
      final topics = await _getAllTopics(inspectionId);
      
      int totalDetails = 0;
      int completedDetails = 0;
      
      // Count details with values
      for (var topic in topics) {
        final items = topic['items'] as List<dynamic>? ?? [];
        
        for (var item in items) {
          final details = item['details'] as List<dynamic>? ?? [];
          
          for (var detail in details) {
            totalDetails++;
            
            // Consider a detail completed if it has a value
            if (detail['detail_value'] != null && detail['detail_value'] != '') {
              completedDetails++;
            }
          }
        }
      }
      
      // Calculate percentage
      if (totalDetails == 0) {
        return 0.0;
      }
      
      return (completedDetails / totalDetails) * 100.0;
    } catch (e) {
      debugPrint('Error calculating completion percentage: $e');
      return 0.0;
    }
  }
  
  // Update last checkpoint info
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
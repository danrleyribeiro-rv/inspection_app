import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class MediaDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  // Get all media for an inspection with filtering support
  Future<List<Map<String, dynamic>>> getAllMedia(
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) async {
    List<Map<String, dynamic>> allMedia = [];

    try {
      // Get topics
      final topicsQuery = _firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics');

      final topicsSnapshot = topicId != null
          ? await topicsQuery
              .where(FieldPath.documentId, isEqualTo: topicId)
              .get()
          : await topicsQuery.get();

      // Process each topic
      for (var topicDoc in topicsSnapshot.docs) {
        final topicData = topicDoc.data();
        final currentTopicId = topicDoc.id;

        // Get items
        final itemsQuery = topicDoc.reference.collection('topic_items');
        final itemsSnapshot = itemId != null
            ? await itemsQuery
                .where(FieldPath.documentId, isEqualTo: itemId)
                .get()
            : await itemsQuery.get();

        // Process each item
        for (var itemDoc in itemsSnapshot.docs) {
          final itemData = itemDoc.data();
          final currentItemId = itemDoc.id;

          // Get details
          final detailsQuery = itemDoc.reference.collection('item_details');
          final detailsSnapshot = detailId != null
              ? await detailsQuery
                  .where(FieldPath.documentId, isEqualTo: detailId)
                  .get()
              : await detailsQuery.get();

          // Process each detail
          for (var detailDoc in detailsSnapshot.docs) {
            final detailData = detailDoc.data();
            final currentDetailId = detailDoc.id;

            // Only get regular media if not specifically looking for non-conformities
            if (isNonConformityOnly != true) {
              // Get regular media
              final mediaSnapshot =
                  await detailDoc.reference.collection('media').get();

              // Process regular media
              for (var mediaDoc in mediaSnapshot.docs) {
                final mediaData = mediaDoc.data();

                // Apply media type filter if specified
                if (mediaType != null && mediaData['type'] != mediaType)
                  continue;

                allMedia.add({
                  ...mediaData,
                  'id': mediaDoc.id,
                  'inspection_id': inspectionId,
                  'topic_id': currentTopicId,
                  'topic_item_id': currentItemId,
                  'detail_id': currentDetailId,
                  'topic_name': topicData['topic_name'],
                  'item_name': itemData['item_name'],
                  'detail_name': detailData['detail_name'],
                  'is_non_conformity': false,
                });
              }
            }

            // Get non-conformity media
            final ncSnapshot =
                await detailDoc.reference.collection('non_conformities').get();

            // Process each non-conformity
            for (var ncDoc in ncSnapshot.docs) {
              final ncId = ncDoc.id;

              // Get non-conformity media
              final ncMediaSnapshot =
                  await ncDoc.reference.collection('nc_media').get();

              // Process non-conformity media
              for (var ncMediaDoc in ncMediaSnapshot.docs) {
                final mediaData = ncMediaDoc.data();

                // Apply media type filter if specified
                if (mediaType != null && mediaData['type'] != mediaType)
                  continue;

                allMedia.add({
                  ...mediaData,
                  'id': ncMediaDoc.id,
                  'inspection_id': inspectionId,
                  'topic_id': currentTopicId,
                  'topic_item_id': currentItemId,
                  'detail_id': currentDetailId,
                  'non_conformity_id':
                      "${inspectionId}-${currentTopicId}-${currentItemId}-${currentDetailId}-${ncId}",
                  'topic_name': topicData['topic_name'],
                  'item_name': itemData['item_name'],
                  'detail_name': detailData['detail_name'],
                  'is_non_conformity': true,
                });
              }
            }
          }
        }
      }

      return allMedia;
    } catch (e) {
      print('Error getting media: $e');
      rethrow;
    }
  }

  // Filter media list
  List<Map<String, dynamic>> filterMedia({
    required List<Map<String, dynamic>> allMedia,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    return allMedia.where((media) {
      // Apply topic filter
      if (topicId != null && media['topic_id'] != topicId) return false;

      // Apply item filter
      if (itemId != null && media['topic_item_id'] != itemId) return false;

      // Apply detail filter
      if (detailId != null && media['detail_id'] != detailId) return false;

      // Apply non-conformity filter
      if (isNonConformityOnly == true && media['is_non_conformity'] != true)
        return false;

      // Apply media type filter
      if (mediaType != null && media['type'] != mediaType) return false;

      return true;
    }).toList();
  }

  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    try {
      final String inspectionId = mediaData['inspection_id'];
      final String topicId = mediaData['topic_id'];
      final String itemId = mediaData['topic_item_id'];
      final String detailId = mediaData['detail_id'];
      final bool isNonConformity = mediaData['is_non_conformity'] == true;
      final String? nonConformityId = mediaData['non_conformity_id'];
      final String mediaId = _uuid.v4();

      // If it's a non-conformity media
      if (isNonConformity && nonConformityId != null) {
        final parts = nonConformityId.split('-');
        if (parts.length < 5) {
          throw Exception('Invalid non-conformity ID format');
        }

        final ncId = parts[4];

        // Save to non-conformity media collection
        await _firestore
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
            .doc(mediaId)
            .set({
              ...mediaData,
              'id': mediaId,
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            }..removeWhere((key, _) => [
                  'inspection_id',
                  'topic_id',
                  'topic_item_id',
                  'detail_id',
                  'non_conformity_id'
                ].contains(key)));

        // Update detail damage status
        await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .update({'is_damaged': true});
      } else {
        // Save to regular media collection
        await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('media')
            .doc(mediaId)
            .set({
              ...mediaData,
              'id': mediaId,
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            }..removeWhere((key, _) => [
                  'inspection_id',
                  'topic_id',
                  'topic_item_id',
                  'detail_id',
                  'non_conformity_id'
                ].contains(key)));
      }
    } catch (e) {
      print('Error saving media: $e');
      rethrow;
    }
  }

  Future<void> updateMedia(
    String mediaId,
    Map<String, dynamic> originalData,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final String inspectionId = originalData['inspection_id'];
      final String topicId = originalData['topic_id'];
      final String itemId = originalData['topic_item_id'];
      final String detailId = originalData['detail_id'];
      final bool isNonConformity = originalData['is_non_conformity'] == true;
      final String? nonConformityId = originalData['non_conformity_id'];

      final updatedFields = {
        ...updateData,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Remove fields that shouldn't be updated
      updatedFields.removeWhere((key, _) => [
            'id',
            'inspection_id',
            'topic_id',
            'topic_item_id',
            'detail_id',
            'non_conformity_id',
            'created_at'
          ].contains(key));

      // If it's a non-conformity media
      if (isNonConformity && nonConformityId != null) {
        final parts = nonConformityId.split('-');
        if (parts.length < 5) {
          throw Exception('Invalid non-conformity ID format');
        }

        final ncId = parts[4];

        await _firestore
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
            .doc(mediaId)
            .update(updatedFields);

        // Update is_non_conformity status
        if (updateData.containsKey('is_non_conformity')) {
          await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .update({'is_damaged': updateData['is_non_conformity']});
        }
      } else {
        await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('media')
            .doc(mediaId)
            .update(updatedFields);
      }
    } catch (e) {
      print('Error updating media: $e');
      rethrow;
    }
  }

  Future<void> deleteMedia(Map<String, dynamic> mediaData) async {
    try {
      final String inspectionId = mediaData['inspection_id'];
      final String topicId = mediaData['topic_id'];
      final String itemId = mediaData['topic_item_id'];
      final String detailId = mediaData['detail_id'];
      final String mediaId = mediaData['id'];
      final bool isNonConformity = mediaData['is_non_conformity'] == true;
      final String? nonConformityId = mediaData['non_conformity_id'];
      final String? url = mediaData['url'];
      final String? localPath = mediaData['localPath'];

      // Delete file from storage if URL exists
      if (url != null) {
        try {
          final storageRef = _storage.refFromURL(url);
          await storageRef.delete();
        } catch (e) {
          print('Error deleting from storage: $e');
        }
      }

      // Delete local file if exists
      if (localPath != null) {
        try {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting local file: $e');
        }
      }

      // If it's a non-conformity media
      if (isNonConformity && nonConformityId != null) {
        final parts = nonConformityId.split('-');
        if (parts.length < 5) {
          throw Exception('Invalid non-conformity ID format');
        }

        final ncId = parts[4];

        await _firestore
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
            .doc(mediaId)
            .delete();

        // Check if there are any other non-conformities for this detail
        final otherNcSnapshot = await _firestore
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

        // If no other non-conformities, update detail
        if (otherNcSnapshot.docs.isEmpty) {
          await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .update({'is_damaged': false});
        }
      } else {
        // Delete regular media
        await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('media')
            .doc(mediaId)
            .delete();
      }
    } catch (e) {
      print('Error deleting media: $e');
      rethrow;
    }
  }

  // Upload media file to Firebase Storage
  Future<String> uploadMediaFile(File file, String path,
      {String? contentType}) async {
    try {
      // Generate content type if not provided
      if (contentType == null) {
        final fileExt = p.extension(file.path).toLowerCase();
        if (fileExt.contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
          contentType = 'image/${fileExt.replaceAll(".", "")}';
        } else if (fileExt.contains(RegExp(r'mp4|mov|avi'))) {
          contentType = 'video/${fileExt.replaceAll(".", "")}';
        }
      }

      // Create storage reference
      final ref = _storage.ref().child(path);

      // Set upload metadata
      SettableMetadata? metadata;
      if (contentType != null) {
        metadata = SettableMetadata(contentType: contentType);
      }

      // Upload file
      await ref.putFile(file, metadata);

      // Return download URL
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  // Generate a storage path for media
  String generateStoragePath({
    required String inspectionId,
    required String topicId,
    required String itemId,
    required String detailId,
    String? nonConformityId,
    required String filename,
  }) {
    if (nonConformityId != null) {
      return 'inspections/$inspectionId/$topicId/$itemId/$detailId/non_conformities/$nonConformityId/$filename';
    } else {
      return 'inspections/$inspectionId/$topicId/$itemId/$detailId/$filename';
    }
  }
}

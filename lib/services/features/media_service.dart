import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';

class MediaService {
  final FirebaseService _firebase = FirebaseService();
  final InspectionService _inspectionService = InspectionService();
  final Uuid _uuid = Uuid();

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

    final ref = _firebase.storage.ref().child(storagePath);
    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<String?> uploadNonConformityMedia(
      String localPath, String inspectionId, String topicId, String itemId, 
      String detailId, String nonConformityId) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found: $localPath');
    }

    final fileExt = path.extension(localPath);
    String type = 'other';

    if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
      type = 'image';
    } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
      type = 'video';
    }

    final filename = '${type}_${_uuid.v4()}$fileExt';
    final storagePath = 'inspections/$inspectionId/$topicId/$itemId/$detailId/non_conformities/$nonConformityId/$filename';

    String? contentType;
    if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
      contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
    } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
      contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
    }

    final ref = _firebase.storage.ref().child(storagePath);
    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> allMedia = [];

    for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];

          // Regular media
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          for (int mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
            allMedia.add({
              ...media[mediaIndex],
              'id': 'media_${topicIndex}_${itemIndex}_${detailIndex}_$mediaIndex',
              'inspection_id': inspectionId,
              'topic_index': topicIndex,
              'item_index': itemIndex,
              'detail_index': detailIndex,
              'media_index': mediaIndex,
              'is_non_conformity': false,
            });
          }

          // Non-conformity media
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
            final nc = nonConformities[ncIndex];
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            for (int ncMediaIndex = 0; ncMediaIndex < ncMedia.length; ncMediaIndex++) {
              allMedia.add({
                ...ncMedia[ncMediaIndex],
                'id': 'nc_media_${topicIndex}_${itemIndex}_${detailIndex}_${ncIndex}_$ncMediaIndex',
                'inspection_id': inspectionId,
                'topic_index': topicIndex,
                'item_index': itemIndex,
                'detail_index': detailIndex,
                'nc_index': ncIndex,
                'nc_media_index': ncMediaIndex,
                'is_non_conformity': true,
              });
            }
          }
        }
      }
    }

    return allMedia;
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _firebase.storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> filterMedia({
    required List<Map<String, dynamic>> allMedia,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    return allMedia.where((media) {
      if (topicId != null && media['topic_id'] != topicId) return false;
      if (itemId != null && media['topic_item_id'] != itemId) return false;
      if (detailId != null && media['detail_id'] != detailId) return false;
      if (isNonConformityOnly == true && media['is_non_conformity'] != true) return false;
      if (mediaType != null && media['type'] != mediaType) return false;
      return true;
    }).toList();
  }
}
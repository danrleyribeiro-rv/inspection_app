import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class MediaDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final InspectionDataService _inspectionService = InspectionDataService();

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> allMedia = [];

    for (int topicIndex = 0;
        topicIndex < inspection!.topics!.length;
        topicIndex++) {
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
              'id':
                  'media_${topicIndex}_${itemIndex}_${detailIndex}_$mediaIndex',
              'inspection_id': inspectionId,
              'topic_index': topicIndex,
              'item_index': itemIndex,
              'detail_index': detailIndex,
              'media_index': mediaIndex,
              'is_non_conformity': false,
            });
          }

          // Non-conformity media
          final nonConformities =
              List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
            final nc = nonConformities[ncIndex];
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            for (int ncMediaIndex = 0;
                ncMediaIndex < ncMedia.length;
                ncMediaIndex++) {
              allMedia.add({
                ...ncMedia[ncMediaIndex],
                'id':
                    'nc_media_${topicIndex}_${itemIndex}_${detailIndex}_${ncIndex}_$ncMediaIndex',
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

  Future<void> deleteMedia(Map<String, dynamic> mediaData) async {
    final String inspectionId = mediaData['inspection_id'];
    final int topicIndex = mediaData['topic_index'];
    final int itemIndex = mediaData['item_index'];
    final int detailIndex = mediaData['detail_index'];
    final bool isNonConformity = mediaData['is_non_conformity'] == true;

    // Delete from storage if URL exists
    if (mediaData['url'] != null) {
      try {
        final storageRef = _storage.refFromURL(mediaData['url']);
        await storageRef.delete();
      } catch (e) {
        print('Error deleting from storage: $e');
      }
    }

    // Delete local file if exists
    if (mediaData['localPath'] != null) {
      try {
        final file = File(mediaData['localPath']);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting local file: $e');
      }
    }

    // Remove from inspection document
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      final item = items[itemIndex];
      final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
      final detail = Map<String, dynamic>.from(details[detailIndex]);

      if (isNonConformity) {
        final ncIndex = mediaData['nc_index'];
        final ncMediaIndex = mediaData['nc_media_index'];
        final nonConformities =
            List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
        final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
        final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);

        ncMedia.removeAt(ncMediaIndex);
        nc['media'] = ncMedia;
        nonConformities[ncIndex] = nc;
        detail['non_conformities'] = nonConformities;
      } else {
        final mediaIndex = mediaData['media_index'];
        final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
        media.removeAt(mediaIndex);
        detail['media'] = media;
      }

      details[detailIndex] = detail;
      item['details'] = details;
      items[itemIndex] = item;
      topic['items'] = items;
      topics[topicIndex] = topic;

      await _firestore.collection('inspections').doc(inspectionId).update({
        'topics': topics,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    final inspectionId = mediaData['inspection_id'];
    final topicIndex = mediaData['topic_index'];
    final itemIndex = mediaData['item_index'];
    final detailIndex = mediaData['detail_index'];

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      final item = items[itemIndex];
      final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
      final detail = Map<String, dynamic>.from(details[detailIndex]);
      final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);

      media.add(mediaData);
      detail['media'] = media;
      details[detailIndex] = detail;
      item['details'] = details;
      items[itemIndex] = item;
      topic['items'] = items;
      topics[topicIndex] = topic;

      await _firestore.collection('inspections').doc(inspectionId).update({
        'topics': topics,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateMedia(String mediaId, Map<String, dynamic> originalData,
      Map<String, dynamic> updateData) async {
    // Implementar lógica de atualização de mídia similar
    // Usar os índices de originalData para localizar e atualizar a mídia
    final inspectionId = originalData['inspection_id'];
    final topicIndex = originalData['topic_index'];
    final itemIndex = originalData['item_index'];
    final detailIndex = originalData['detail_index'];
    final mediaIndex = originalData['media_index'];

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      final item = items[itemIndex];
      final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
      final detail = Map<String, dynamic>.from(details[detailIndex]);
      final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);

      if (mediaIndex >= 0 && mediaIndex < media.length) {
        media[mediaIndex] = {...media[mediaIndex], ...updateData};
        detail['media'] = media;
        details[detailIndex] = detail;
        item['details'] = details;
        items[itemIndex] = item;
        topic['items'] = items;
        topics[topicIndex] = topic;

        await _firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class NonConformityDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    final topicsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .get();

    List<Map<String, dynamic>> nonConformities = [];

    for (var topicDoc in topicsSnapshot.docs) {
      final topicId = topicDoc.id;
      final topicData = topicDoc.data();

      final itemsSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .get();

      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        final itemData = itemDoc.data();

        final detailsSnapshot = await firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .get();

        for (var detailDoc in detailsSnapshot.docs) {
          final detailId = detailDoc.id;
          final detailData = detailDoc.data();

          final ncSnapshot = await firestore
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

          for (var ncDoc in ncSnapshot.docs) {
            final ncData = ncDoc.data();

            nonConformities.add({
              ...ncData,
              'id': ncDoc.id,
              'inspection_id': inspectionId,
              'topic_id': topicId,
              'item_id': itemId,
              'detail_id': detailId,
              'topics': {
                'topic_name': topicData['topic_name'],
                'id': topicId,
              },
              'topic_items': {
                'item_name': itemData['item_name'],
                'id': itemId,
              },
              'item_details': {
                'detail_name': detailData['detail_name'],
                'id': detailId,
              },
            });
          }
        }
      }
    }

    return nonConformities;
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    final inspectionId = nonConformityData['inspection_id'];
    final topicId = nonConformityData['topic_id'];
    final itemId = nonConformityData['item_id'];
    final detailId = nonConformityData['detail_id'];

    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .collection('non_conformities')
        .add({
          ...nonConformityData,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }
          ..remove('inspection_id')
          ..remove('topic_id')
          ..remove('item_id')
          ..remove('detail_id')
          ..remove('id'));

    // Also update the detail to mark as damaged
    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .update({'is_damaged': true});
  }

  Future<void> updateNonConformityStatus(
      String nonConformityId, String newStatus) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicId = parts[1];
    final itemId = parts[2];
    final detailId = parts[3];
    final ncId = parts[4];

    await firestore
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
        .update({
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNonConformity(
      String nonConformityId, Map<String, dynamic> updatedData) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicId = parts[1];
    final itemId = parts[2];
    final detailId = parts[3];
    final ncId = parts[4];

    await firestore
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
        .update({
          ...updatedData,
          'updated_at': FieldValue.serverTimestamp(),
        }
          ..remove('inspection_id')
          ..remove('topic_id')
          ..remove('item_id')
          ..remove('detail_id')
          ..remove('id'));
  }

  Future<void> deleteNonConformity(
      String nonConformityId, String inspectionId) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final topicId = parts[1];
    final itemId = parts[2];
    final detailId = parts[3];
    final ncId = parts[4];

    // Delete non-conformity media and then the non-conformity itself
    await firestore
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
        .delete();

    // Check for remaining non-conformities
    final otherNcSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .collection('non_conformities')
        .limit(1)
        .get();

    if (otherNcSnapshot.docs.isEmpty) {
      await firestore
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
  }
}

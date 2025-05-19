import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/detail.dart';

class DetailDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .orderBy('position')
        .get();

    List<Detail> details = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      details.add(Detail.fromMap({
        ...data,
        'id': doc.id,
        'topic_id': topicId,
        'item_id': itemId,
        'inspection_id': inspectionId,
      }));
    }

    return details;
  }

  Future<Detail> addDetail(
    String inspectionId,
    String topicId,
    String itemId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
  }) async {
    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition =
        existingDetails.isEmpty ? 0 : (existingDetails.last.position ?? 0) + 1;

    final detail = Detail(
      id: null,
      topicId: topicId,
      itemId: itemId,
      inspectionId: inspectionId,
      detailName: detailName,
      type: type ?? 'text',
      options: options,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? false,
      position: newPosition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .add(detail.toMap()
          ..remove('inspection_id')
          ..remove('id')
          ..remove('topic_id')
          ..remove('item_id'));

    return detail.copyWith(id: docRef.id);
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    final inspectionId = updatedDetail.inspectionId;
    final topicId = updatedDetail.topicId;
    final itemId = updatedDetail.itemId;
    final detailId = updatedDetail.id;

    if (topicId == null || itemId == null || detailId == null) {
      throw Exception(
          'Topic ID, Item ID, and Detail ID are required for updates');
    }

    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .update(updatedDetail.toMap()
          ..remove('inspection_id')
          ..remove('id')
          ..remove('topic_id')
          ..remove('item_id'));
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId,
      String detailId) async {
    // Delete media
    final mediaSnapshot = await firestore
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

    // Delete non-conformities and their media
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
      // Delete non-conformity media
      final ncMediaSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .doc(itemId)
          .collection('item_details')
          .doc(detailId)
          .collection('non_conformities')
          .doc(ncDoc.id)
          .collection('nc_media')
          .get();

      for (var ncMediaDoc in ncMediaSnapshot.docs) {
        await ncMediaDoc.reference.delete();
      }

      // Delete non-conformity
      await ncDoc.reference.delete();
    }

    // Delete detail
    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .delete();
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId,
      String itemId, String detailName) async {
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .where('detail_name', isEqualTo: detailName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Source detail not found');
    }

    final sourceDetailDoc = querySnapshot.docs.first;
    final sourceDetailData = sourceDetailDoc.data();

    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition =
        existingDetails.isEmpty ? 0 : (existingDetails.last.position ?? 0) + 1;
    final newDetailName = '$detailName (copy)';

    // Create options array if needed
    List<String>? options;
    if (sourceDetailData['options'] != null) {
      if (sourceDetailData['options'] is List) {
        options = List<String>.from(sourceDetailData['options']);
      } else if (sourceDetailData['options'] is Map &&
          sourceDetailData['options']['arrayValue'] != null &&
          sourceDetailData['options']['arrayValue']['values'] != null) {
        options = [];
        for (var option in sourceDetailData['options']['arrayValue']
            ['values']) {
          if (option['stringValue'] != null) {
            options.add(option['stringValue']);
          }
        }
      }
    }

    return await addDetail(
      inspectionId,
      topicId,
      itemId,
      newDetailName,
      type: sourceDetailData['type'],
      options: options,
      detailValue: sourceDetailData['detail_value'],
      observation: sourceDetailData['observation'],
      isDamaged: sourceDetailData['is_damaged'],
    );
  }
}
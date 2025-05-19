import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/item.dart';

class ItemDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .orderBy('position')
        .get();

    List<Item> items = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      items.add(Item.fromMap({
        ...data,
        'id': doc.id,
        'topic_id': topicId,
        'inspection_id': inspectionId,
      }));
    }

    return items;
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    final existingItems = await getItems(inspectionId, topicId);
    final newPosition =
        existingItems.isEmpty ? 0 : existingItems.last.position + 1;

    final item = Item(
      id: null,
      topicId: topicId,
      inspectionId: inspectionId,
      itemName: itemName,
      itemLabel: label,
      observation: observation,
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
        .add(item.toMap()
          ..remove('inspection_id')
          ..remove('id')
          ..remove('topic_id'));

    return item.copyWith(id: docRef.id);
  }

  Future<void> updateItem(Item updatedItem) async {
    final inspectionId = updatedItem.inspectionId;
    final topicId = updatedItem.topicId;
    final itemId = updatedItem.id;

    if (topicId == null || itemId == null) {
      throw Exception('Topic ID and Item ID are required for updates');
    }

    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .update(updatedItem.toMap()
          ..remove('inspection_id')
          ..remove('id')
          ..remove('topic_id'));
  }

  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    // Get all details for this item
    final detailsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .get();

    // Delete all details, media, and non-conformities
    for (var detailDoc in detailsSnapshot.docs) {
      await _deleteDetailComplete(inspectionId, topicId, itemId, detailDoc.id);
    }

    // Delete item
    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .delete();
  }

  Future<void> _deleteDetailComplete(String inspectionId, String topicId, String itemId, String detailId) async {
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

  Future<Item> isItemDuplicate(String inspectionId, String topicId, String itemName) async {
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .where('item_name', isEqualTo: itemName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Source item not found');
    }

    final sourceItemDoc = querySnapshot.docs.first;
    final sourceItemData = sourceItemDoc.data();

    final existingItems = await getItems(inspectionId, topicId);
    final newPosition =
        existingItems.isEmpty ? 0 : existingItems.last.position + 1;
    final newItemName = '$itemName (copy)';

    return await addItem(
      inspectionId,
      topicId,
      newItemName,
      label: sourceItemData['item_label'],
      observation: sourceItemData['observation'],
    );
  }
}
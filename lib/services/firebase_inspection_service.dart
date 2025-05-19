import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:uuid/uuid.dart';

class FirebaseInspectionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // INSPECTION METHODS
  Future<Inspection?> getInspection(String inspectionId) async {
    final docSnapshot =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!docSnapshot.exists) {
      return null;
    }

    return Inspection.fromMap({
      'id': docSnapshot.id,
      ...docSnapshot.data() ?? {},
    });
  }

  Future<void> saveInspection(Inspection inspection) async {
    await firestore.collection('inspections').doc(inspection.id).set(
          inspection.toMap()..remove('id'),
          SetOptions(merge: true),
        );
  }

  // TOPICS METHODS (Previously ROOMS)
  Future<List<Topic>> getTopics(String inspectionId) async {
    final topicsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .orderBy('position')
        .get();

    if (topicsSnapshot.docs.isEmpty) {
      return [];
    }

    List<Topic> topics = [];
    for (var doc in topicsSnapshot.docs) {
      final data = doc.data();
      topics.add(Topic.fromMap({
        ...data,
        'id': doc.id,
        'inspection_id': inspectionId,
      }));
    }

    return topics;
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final existingTopics = await getTopics(inspectionId);
    final newPosition = position ??
        (existingTopics.isEmpty ? 0 : existingTopics.last.position + 1);

    final topic = Topic(
      id: null, // Will be set by Firestore
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create a new topic document
    final docRef = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .add(topic.toMap()
          ..remove('inspection_id')
          ..remove('id'));

    // Return the topic with the generated ID
    return topic.copyWith(id: docRef.id);
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    final inspectionId = updatedTopic.inspectionId;
    final topicId = updatedTopic.id;

    if (topicId == null) {
      throw Exception('Topic ID is required for updates');
    }

    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .update(updatedTopic.toMap()
          ..remove('inspection_id')
          ..remove('id'));
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    // Get all items for this topic
    final itemsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .get();

    // Delete all items and their details recursively
    for (var itemDoc in itemsSnapshot.docs) {
      // Get all details for this item
      final detailsSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .doc(itemDoc.id)
          .collection('item_details')
          .get();

      // Delete all details, media, and non-conformities
      for (var detailDoc in detailsSnapshot.docs) {
        // Delete media
        final mediaSnapshot = await firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemDoc.id)
            .collection('item_details')
            .doc(detailDoc.id)
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
            .doc(itemDoc.id)
            .collection('item_details')
            .doc(detailDoc.id)
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
              .doc(itemDoc.id)
              .collection('item_details')
              .doc(detailDoc.id)
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
        await detailDoc.reference.delete();
      }

      // Delete item
      await itemDoc.reference.delete();
    }

    // Delete topic
    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .delete();
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    WriteBatch batch = firestore.batch();

    for (int i = 0; i < topicIds.length; i++) {
      final topicRef = firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicIds[i]);

      batch.update(topicRef, {'position': i});
    }

    await batch.commit();
  }

  Future<Topic> isTopicDuplicate(String inspectionId, String topicName) async {
    // Find the source topic
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .where('topic_name', isEqualTo: topicName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Source topic not found');
    }

    final sourceTopicDoc = querySnapshot.docs.first;
    final sourceTopicData = sourceTopicDoc.data();

    // Create new topic with duplicated name
    final existingTopics = await getTopics(inspectionId);
    final newPosition =
        existingTopics.isEmpty ? 0 : existingTopics.last.position + 1;
    final newTopicName = '$topicName (copy)';

    // Create the new topic
    final newTopic = await addTopic(
      inspectionId,
      newTopicName,
      label: sourceTopicData['topic_label'],
      position: newPosition,
      observation: sourceTopicData['observation'],
    );

    // Get all items for the source topic
    final itemsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(sourceTopicDoc.id)
        .collection('topic_items')
        .orderBy('position')
        .get();

    // Duplicate all items and their details
    for (var itemDoc in itemsSnapshot.docs) {
      final itemData = itemDoc.data();

      // Create new item
      final newItemRef = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(newTopic.id)
          .collection('topic_items')
          .add({
        ...itemData,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Get all details for the source item
      final detailsSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(sourceTopicDoc.id)
          .collection('topic_items')
          .doc(itemDoc.id)
          .collection('item_details')
          .orderBy('position')
          .get();

      // Duplicate all details
      for (var detailDoc in detailsSnapshot.docs) {
        final detailData = detailDoc.data();

        await firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(newTopic.id)
            .collection('topic_items')
            .doc(newItemRef.id)
            .collection('item_details')
            .add({
          ...detailData,
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }

    return newTopic;
  }

  // ITEMS METHODS
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
      id: null, // Will be set by Firestore
      topicId: topicId,
      inspectionId: inspectionId,
      itemName: itemName,
      itemLabel: label,
      observation: observation,
      position: newPosition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create a new item document
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

    // Return the item with the generated ID
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

  Future<void> deleteItem(
      String inspectionId, String topicId, String itemId) async {
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
      // Delete media
      final mediaSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .doc(itemId)
          .collection('item_details')
          .doc(detailDoc.id)
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
          .doc(detailDoc.id)
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
            .doc(detailDoc.id)
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
      await detailDoc.reference.delete();
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

  Future<Item> isItemDuplicate(
      String inspectionId, String topicId, String itemName) async {
    // Find the source item
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

    // Create new item with duplicated name
    final existingItems = await getItems(inspectionId, topicId);
    final newPosition =
        existingItems.isEmpty ? 0 : existingItems.last.position + 1;
    final newItemName = '$itemName (copy)';

    // Create the new item
    final newItem = await addItem(
      inspectionId,
      topicId,
      newItemName,
      label: sourceItemData['item_label'],
      observation: sourceItemData['observation'],
    );

    // Get all details for the source item
    final detailsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(sourceItemDoc.id)
        .collection('item_details')
        .orderBy('position')
        .get();

    // Duplicate all details
    for (var detailDoc in detailsSnapshot.docs) {
      final detailData = detailDoc.data();

      await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .doc(newItem.id)
          .collection('item_details')
          .add({
        ...detailData,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    return newItem;
  }

  // DETAILS METHODS
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
      id: null, // Will be set by Firestore
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

    // Create a new detail document
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

    // Return the detail with the generated ID
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
    // Find the source detail
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

    // Get existing details to determine position
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

    // Create the new detail
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

  // NON-CONFORMITY METHODS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    // First get all topics (topics)
    final topicsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .get();

    List<Map<String, dynamic>> nonConformities = [];

    // For each topic
    for (var topicDoc in topicsSnapshot.docs) {
      final topicId = topicDoc.id;
      final topicData = topicDoc.data();

      // Get all items
      final itemsSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .get();

      // For each item
      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        final itemData = itemDoc.data();

        // Get all details
        final detailsSnapshot = await firestore
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
          final detailData = detailDoc.data();

          // Get all non-conformities
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

          // For each non-conformity
          for (var ncDoc in ncSnapshot.docs) {
            final ncData = ncDoc.data();

            // Add to the list with hierarchy data
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

    // Create a new non-conformity document
    final docRef = await firestore
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
    // Parse the composite ID to extract the hierarchy IDs
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
    // Parse the composite ID to extract the hierarchy IDs
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
    // Parse the composite ID to extract the hierarchy IDs
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final topicId = parts[1];
    final itemId = parts[2];
    final detailId = parts[3];
    final ncId = parts[4];

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
        .doc(ncId)
        .collection('nc_media')
        .get();

    for (var ncMediaDoc in ncMediaSnapshot.docs) {
      await ncMediaDoc.reference.delete();
    }

    // Delete the non-conformity
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

    // Check if there are any other non-conformities for this detail
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

    // If no other non-conformities, update detail to not damaged
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

  // MEDIA METHODS
  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    final inspectionId = mediaData['inspection_id'];
    final topicId = mediaData['topic_id'];
    final itemId = mediaData['topic_item_id'];
    final detailId = mediaData['detail_id'];
    final isNonConformity = mediaData['is_non_conformity'] == true;
    final nonConformityId = mediaData['non_conformity_id'];

    // Generate a unique ID for the media
    final mediaId = _uuid.v4();

    // Determine where to save the media
    if (isNonConformity && nonConformityId != null) {
      // Parse the non-conformity ID to extract the NC doc ID
      final parts = nonConformityId.split('-');
      if (parts.length < 5) {
        throw Exception('Invalid non-conformity ID format');
      }

      final ncId = parts[4];

      // Save to non-conformity media
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
          .collection('nc_media')
          .doc(mediaId)
          .set({
            ...mediaData,
            'id': mediaId,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }
            ..remove('inspection_id')
            ..remove('topic_id')
            ..remove('topic_item_id')
            ..remove('detail_id')
            ..remove('non_conformity_id'));
    } else {
      // Save to regular media
      await firestore
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
          }
            ..remove('inspection_id')
            ..remove('topic_id')
            ..remove('topic_item_id')
            ..remove('detail_id')
            ..remove('non_conformity_id'));
    }

    // If marked as non-conformity, update the detail
    if (isNonConformity) {
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
  }

  Future<void> deleteMedia(
      String mediaId, Map<String, dynamic> mediaData) async {
    final inspectionId = mediaData['inspection_id'];
    final topicId = mediaData['topic_id'];
    final itemId = mediaData['topic_item_id'];
    final detailId = mediaData['detail_id'];
    final isNonConformity = mediaData['is_non_conformity'] == true;
    final nonConformityId = mediaData['non_conformity_id'];

    if (isNonConformity && nonConformityId != null) {
      // Parse the non-conformity ID to extract the NC doc ID
      final parts = nonConformityId.split('-');
      if (parts.length < 5) {
        throw Exception('Invalid non-conformity ID format');
      }

      final ncId = parts[4];

      // Delete from non-conformity media
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
          .collection('nc_media')
          .doc(mediaId)
          .delete();
    } else {
      // Delete from regular media
      await firestore
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
  }

  Future<void> updateMedia(String mediaId, Map<String, dynamic> mediaData,
      Map<String, dynamic> updatedData) async {
    final inspectionId = mediaData['inspection_id'];
    final topicId = mediaData['topic_id'];
    final itemId = mediaData['topic_item_id'];
    final detailId = mediaData['detail_id'];
    final isNonConformity = mediaData['is_non_conformity'] == true;
    final nonConformityId = mediaData['non_conformity_id'];

    if (isNonConformity && nonConformityId != null) {
      // Parse the non-conformity ID to extract the NC doc ID
      final parts = nonConformityId.split('-');
      if (parts.length < 5) {
        throw Exception('Invalid non-conformity ID format');
      }

      final ncId = parts[4];

      // Update in non-conformity media
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
          .collection('nc_media')
          .doc(mediaId)
          .update({
            ...updatedData,
            'updated_at': FieldValue.serverTimestamp(),
          }
            ..remove('inspection_id')
            ..remove('topic_id')
            ..remove('topic_item_id')
            ..remove('detail_id')
            ..remove('non_conformity_id')
            ..remove('id'));
    } else {
      // Update in regular media
      await firestore
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
          .update({
            ...updatedData,
            'updated_at': FieldValue.serverTimestamp(),
          }
            ..remove('inspection_id')
            ..remove('topic_id')
            ..remove('topic_item_id')
            ..remove('detail_id')
            ..remove('non_conformity_id')
            ..remove('id'));
    }

    // If is_non_conformity status changed, update the detail
    if (updatedData.containsKey('is_non_conformity')) {
      bool isNowNonConformity = updatedData['is_non_conformity'] == true;

      if (isNowNonConformity) {
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
      } else {
        // Check if there are any other media or non-conformities marking this as damaged
        bool stillDamaged = false;

        // Check other media
        final otherMediaSnapshot = await firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('media')
            .where('is_non_conformity', isEqualTo: true)
            .limit(1)
            .get();

        if (otherMediaSnapshot.docs.isNotEmpty) {
          stillDamaged = true;
        }

        // Check non-conformities
        if (!stillDamaged) {
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
              .limit(1)
              .get();

          if (ncSnapshot.docs.isNotEmpty) {
            stillDamaged = true;
          }
        }

        // Update the detail if no longer damaged
        if (!stillDamaged) {
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
  }

  // Get all media for an inspection
  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    List<Map<String, dynamic>> allMedia = [];

    // First get all topics (topics)
    final topicsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .get();

    // For each topic
    for (var topicDoc in topicsSnapshot.docs) {
      final topicId = topicDoc.id;
      final topicData = topicDoc.data();

      // Get all items
      final itemsSnapshot = await firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicId)
          .collection('topic_items')
          .get();

      // For each item
      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        final itemData = itemDoc.data();

        // Get all details
        final detailsSnapshot = await firestore
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
          final detailData = detailDoc.data();

          // Get regular media
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

          // Add regular media to list
          for (var mediaDoc in mediaSnapshot.docs) {
            final mediaData = mediaDoc.data();

            allMedia.add({
              ...mediaData,
              'id': mediaDoc.id,
              'inspection_id': inspectionId,
              'topic_id': topicId,
              'topic_item_id': itemId,
              'detail_id': detailId,
              'topic_name': topicData['topic_name'],
              'item_name': itemData['item_name'],
              'detail_name': detailData['detail_name'],
            });
          }

          // Get non-conformities
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

          // For each non-conformity
          for (var ncDoc in ncSnapshot.docs) {
            final ncId = ncDoc.id;
            final ncData = ncDoc.data();

            // Build a non-conformity ID
            final nonConformityId =
                '$inspectionId-$topicId-$itemId-$detailId-$ncId';

            // Get non-conformity media
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
                .doc(ncId)
                .collection('nc_media')
                .get();

            // Add non-conformity media to list
            for (var mediaDoc in ncMediaSnapshot.docs) {
              final mediaData = mediaDoc.data();

              allMedia.add({
                ...mediaData,
                'id': mediaDoc.id,
                'inspection_id': inspectionId,
                'topic_id': topicId,
                'topic_item_id': itemId,
                'detail_id': detailId,
                'non_conformity_id': nonConformityId,
                'is_non_conformity': true,
                'topic_name': topicData['topic_name'],
                'item_name': itemData['item_name'],
                'detail_name': detailData['detail_name'],
              });
            }
          }
        }
      }
    }

    return allMedia;
  }

  // TEMPLATE APPLICATION
  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    try {
      // Get the template
      final templateDoc =
          await firestore.collection('templates').doc(templateId).get();
      if (!templateDoc.exists) {
        return false;
      }

      final templateData = templateDoc.data() ?? {};
      final topicsData = templateData['topics'] as List<dynamic>? ?? [];

      // Process topics (topics)
      for (var i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];

        // Extract topic name
        String topicName = '';
        if (topicTemplate is Map &&
            topicTemplate['name'] is Map &&
            topicTemplate['name']['stringValue'] != null) {
          topicName = topicTemplate['name']['stringValue'];
        } else if (topicTemplate is Map && topicTemplate['name'] is String) {
          topicName = topicTemplate['name'];
        }

        if (topicName.isEmpty) continue;

        // Create topic
        final topic = await addTopic(
          inspectionId,
          topicName,
          position: i,
        );

        // Extract items
        final itemsData = _extractArrayFromTemplate(topicTemplate, 'items');

        // Process items
        for (var j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          String itemName = _extractStringValueFromTemplate(itemFields, 'name',
              defaultValue: 'Item sem nome');

          // Create item
          final item = await addItem(
            inspectionId,
            topic.id!,
            itemName,
            observation:
                _extractStringValueFromTemplate(itemFields, 'description'),
          );

          // Extract details
          final detailsData = _extractArrayFromTemplate(itemFields, 'details');

          // Process details
          for (var k = 0; k < detailsData.length; k++) {
            final detailTemplate = detailsData[k];
            final detailFields = _extractFieldsFromTemplate(detailTemplate);

            if (detailFields == null) continue;

            String detailName = _extractStringValueFromTemplate(
                detailFields, 'name',
                defaultValue: 'Detalhe sem nome');

            String detailType = _extractStringValueFromTemplate(
                detailFields, 'type',
                defaultValue: 'text');

            // Extract options for select type
            List<String>? options;
            if (detailType == 'select') {
              final optionsArray =
                  _extractArrayFromTemplate(detailFields, 'options');
              options = [];

              for (var option in optionsArray) {
                if (option is Map && option.containsKey('stringValue')) {
                  options.add(option['stringValue']);
                } else if (option is String) {
                  options.add(option);
                }
              }

              // Check for optionsText field as alternative
              if (options.isEmpty && detailFields.containsKey('optionsText')) {
                final optionsText = _extractStringValueFromTemplate(
                    detailFields, 'optionsText',
                    defaultValue: '');

                if (optionsText.isNotEmpty) {
                  options =
                      optionsText.split(',').map((e) => e.trim()).toList();
                }
              }
            }

            // Create detail
            await addDetail(
              inspectionId,
              topic.id!,
              item.id!,
              detailName,
              type: detailType,
              options: options,
            );
          }
        }
      }

      // Update inspection to mark as templated
      await firestore.collection('inspections').doc(inspectionId).update({
        'is_templated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error applying template: $e');
      return false;
    }
  }

  // Check if template is already applied to prevent duplicates
  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (inspectionDoc.exists) {
      final data = inspectionDoc.data() as Map<String, dynamic>;
      return data['is_templated'] == true;
    }
    return false;
  }

  // Apply template with duplicate prevention
  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    // First check if template is already applied
    if (await isTemplateAlreadyApplied(inspectionId)) {
      print('Template already applied to inspection $inspectionId');
      return true; // Consider as success since template is already applied
    }

    // Check if there are already topics in the inspection
    final existingTopics = await getTopics(inspectionId);
    if (existingTopics.isNotEmpty) {
      print(
          'Inspection $inspectionId already has topics, skipping template application');
      return true; // Consider as success to prevent blocking
    }

    // Apply template normally
    return await applyTemplateToInspection(inspectionId, templateId);
  }

  // Helper methods for template handling
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];

    // Case 1: Already a list
    if (data[key] is List) {
      return data[key];
    }

    // Case 2: Firestore format (arrayValue)
    if (data[key] is Map &&
        data[key].containsKey('arrayValue') &&
        data[key]['arrayValue'] is Map &&
        data[key]['arrayValue'].containsKey('values')) {
      return data[key]['arrayValue']['values'] ?? [];
    }

    return [];
  }

  Map<String, dynamic>? _extractFieldsFromTemplate(dynamic data) {
    if (data == null) return null;

    // Case 1: Already a map of fields
    if (data is Map && data.containsKey('fields')) {
      return Map<String, dynamic>.from(data['fields']);
    }

    // Case 2: Complex Firestore format
    if (data is Map &&
        data.containsKey('mapValue') &&
        data['mapValue'] is Map &&
        data['mapValue'].containsKey('fields')) {
      return Map<String, dynamic>.from(data['mapValue']['fields']);
    }

    // Case 3: Simple map
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  String _extractStringValueFromTemplate(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    // Case 1: Direct string
    if (data[key] is String) {
      return data[key];
    }

    // Case 2: Firestore format (stringValue)
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }

    return defaultValue;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class InspectionDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

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
    final data = inspection.toMap();
    data.remove('id');
    await firestore
        .collection('inspections')
        .doc(inspection.id)
        .set(data, SetOptions(merge: true));
  }

  // Extract topics from inspection structure
  List<Topic> extractTopics(String inspectionId, List<dynamic>? topicsData) {
    if (topicsData == null) return [];

    List<Topic> topics = [];
    for (int i = 0; i < topicsData.length; i++) {
      final topicData = topicsData[i];
      if (topicData is Map<String, dynamic>) {
        topics.add(Topic(
          id: 'topic_$i',
          inspectionId: inspectionId,
          topicName: topicData['name'] ?? 'Tópico ${i + 1}',
          topicLabel: topicData['description'],
          position: i,
          observation: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return topics;
  }

  // Extract items from topic structure
  List<Item> extractItems(
      String inspectionId, String topicId, Map<String, dynamic> topicData) {
    final itemsData = topicData['items'] as List<dynamic>? ?? [];
    List<Item> items = [];

    for (int i = 0; i < itemsData.length; i++) {
      final itemData = itemsData[i];
      if (itemData is Map<String, dynamic>) {
        items.add(Item(
          id: 'item_$i',
          inspectionId: inspectionId,
          topicId: topicId,
          itemName: itemData['name'] ?? 'Item ${i + 1}',
          itemLabel: itemData['description'],
          position: i,
          observation: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return items;
  }

  // Extract details from item structure
  List<Detail> extractDetails(String inspectionId, String topicId,
      String itemId, Map<String, dynamic> itemData) {
    final detailsData = itemData['details'] as List<dynamic>? ?? [];
    List<Detail> details = [];

    for (int i = 0; i < detailsData.length; i++) {
      final detailData = detailsData[i];
      if (detailData is Map<String, dynamic>) {
        List<String>? options;
        if (detailData['options'] is List) {
          options = List<String>.from(detailData['options']);
        }

        details.add(Detail(
          id: 'detail_$i',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: detailData['name'] ?? 'Detalhe ${i + 1}',
          type: detailData['type'] ?? 'text',
          options: options,
          position: i,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return details;
  }

  // Update specific topic in inspection
  Future<void> updateTopic(String inspectionId, int topicIndex,
      Map<String, dynamic> updatedTopic) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics[topicIndex] = updatedTopic;
        await firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Add topic to inspection
  Future<void> addTopic(
      String inspectionId, Map<String, dynamic> newTopic) async {
    final inspection = await getInspection(inspectionId);
    final topics = inspection?.topics != null
        ? List<Map<String, dynamic>>.from(inspection!.topics!)
        : <Map<String, dynamic>>[];

    topics.add(newTopic);

    await firestore.collection('inspections').doc(inspectionId).update({
      'topics': topics,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete topic from inspection
  Future<void> deleteTopic(String inspectionId, int topicIndex) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics.removeAt(topicIndex);
        await firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Update specific item in topic
  Future<void> updateItem(String inspectionId, int topicIndex, int itemIndex,
      Map<String, dynamic> updatedItem) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          items[itemIndex] = updatedItem;
          topic['items'] = items;
          topics[topicIndex] = topic;

          await firestore.collection('inspections').doc(inspectionId).update({
            'topics': topics,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // Add item to topic
  Future<void> addItem(
      String inspectionId, int topicIndex, Map<String, dynamic> newItem) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        items.add(newItem);
        topic['items'] = items;
        topics[topicIndex] = topic;

        await firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Delete item from topic
  Future<void> deleteItem(
      String inspectionId, int topicIndex, int itemIndex) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          items.removeAt(itemIndex);
          topic['items'] = items;
          topics[topicIndex] = topic;

          await firestore.collection('inspections').doc(inspectionId).update({
            'topics': topics,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // Update detail in item
  Future<void> updateDetail(String inspectionId, int topicIndex, int itemIndex,
      int detailIndex, Map<String, dynamic> updatedDetail) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            details[detailIndex] = updatedDetail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  // Add detail to item
  Future<void> addDetail(String inspectionId, int topicIndex, int itemIndex,
      Map<String, dynamic> newDetail) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          details.add(newDetail);
          item['details'] = details;
          items[itemIndex] = item;
          topic['items'] = items;
          topics[topicIndex] = topic;

          await firestore.collection('inspections').doc(inspectionId).update({
            'topics': topics,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // Delete detail from item
  Future<void> deleteDetail(String inspectionId, int topicIndex, int itemIndex,
      int detailIndex) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            details.removeAt(detailIndex);
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  // Add media to detail
  Future<void> addMedia(String inspectionId, int topicIndex, int itemIndex,
      int detailIndex, Map<String, dynamic> media) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            final mediaList =
                List<Map<String, dynamic>>.from(detail['media'] ?? []);
            mediaList.add(media);
            detail['media'] = mediaList;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  // Add non-conformity to detail
  Future<void> addNonConformity(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      Map<String, dynamic> nonConformity) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            final ncList = List<Map<String, dynamic>>.from(
                detail['non_conformities'] ?? []);
            ncList.add(nonConformity);
            detail['non_conformities'] = ncList;
            detail['is_damaged'] = true; // Mark detail as damaged
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }
}

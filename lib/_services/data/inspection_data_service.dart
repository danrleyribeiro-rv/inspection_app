import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class InspectionDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

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
    final data = inspection.toMap();
    data.remove('id');
    await firestore
        .collection('inspections')
        .doc(inspection.id)
        .set(data, SetOptions(merge: true));
  }

  // TOPIC METHODS
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
          observation: topicData['observation'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return topics;
  }

  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await getInspection(inspectionId);
    return extractTopics(inspectionId, inspection?.topics);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final inspection = await getInspection(inspectionId);
    final existingTopics = inspection?.topics ?? [];
    final newPosition = position ?? existingTopics.length;

    final newTopicData = {
      'name': topicName,
      'description': label,
      'observation': observation,
      'items': <Map<String, dynamic>>[],
    };

    await _addTopicToInspection(inspectionId, newTopicData);

    return Topic(
      id: 'topic_$newPosition',
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

Future<void> updateTopic(Topic updatedTopic) async {
  final inspection = await getInspection(updatedTopic.inspectionId);
  if (inspection?.topics != null) {
    final topicIndex = int.tryParse(updatedTopic.id?.replaceFirst('topic_', '') ?? '');
    if (topicIndex != null && topicIndex < inspection!.topics!.length) {
      final currentTopicData = Map<String, dynamic>.from(inspection.topics![topicIndex]);
      currentTopicData['name'] = updatedTopic.topicName; // Certifique-se que está salvando o nome
      currentTopicData['description'] = updatedTopic.topicLabel;
      currentTopicData['observation'] = updatedTopic.observation;

      await _updateTopicAtIndex(updatedTopic.inspectionId, topicIndex, currentTopicData);
    }
  }
}

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex != null) {
      await _deleteTopicAtIndex(inspectionId, topicIndex);
    }
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    final inspection = await getInspection(inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final reorderedTopics = <Map<String, dynamic>>[];

      for (final topicId in topicIds) {
        final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
        if (topicIndex != null && topicIndex < topics.length) {
          reorderedTopics.add(topics[topicIndex]);
        }
      }

      await firestore.collection('inspections').doc(inspectionId).update({
        'topics': reorderedTopics,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Topic> duplicateTopic(String inspectionId, String topicName) async {
    final inspection = await getInspection(inspectionId);
    final topics = inspection?.topics ?? [];

    Map<String, dynamic>? sourceTopicData;
    for (final topic in topics) {
      if (topic['name'] == topicName) {
        sourceTopicData = Map<String, dynamic>.from(topic);
        break;
      }
    }

    if (sourceTopicData == null) {
      throw Exception('Source topic not found');
    }

    final duplicateTopicData = Map<String, dynamic>.from(sourceTopicData);
    duplicateTopicData['name'] = '$topicName (copy)';

    await _addTopicToInspection(inspectionId, duplicateTopicData);

    return Topic(
      id: 'topic_${topics.length}',
      inspectionId: inspectionId,
      topicName: '$topicName (copy)',
      topicLabel: duplicateTopicData['description'],
      position: topics.length,
      observation: duplicateTopicData['observation'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ITEM METHODS
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
          observation: itemData['observation'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return items;
  }

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final inspection = await getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));

    if (inspection?.topics != null &&
        topicIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topicData = inspection.topics![topicIndex];
      return extractItems(inspectionId, topicId, topicData);
    }

    return [];
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');

    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;

    final newItemData = {
      'name': itemName,
      'description': label,
      'observation': observation,
      'details': <Map<String, dynamic>>[],
    };

    await _addItemToTopic(inspectionId, topicIndex, newItemData);

    return Item(
      id: 'item_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemName: itemName,
      itemLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateItem(Item updatedItem) async {
    final topicIndex =
        int.tryParse(updatedItem.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex =
        int.tryParse(updatedItem.id?.replaceFirst('item_', '') ?? '');

    if (topicIndex != null && itemIndex != null) {
      final inspection = await getInspection(updatedItem.inspectionId);
      if (inspection?.topics != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final currentItemData = Map<String, dynamic>.from(items[itemIndex]);
          currentItemData['name'] = updatedItem.itemName;
          currentItemData['description'] = updatedItem.itemLabel;
          currentItemData['observation'] = updatedItem.observation;

          await _updateItemAtIndex(
              updatedItem.inspectionId, topicIndex, itemIndex, currentItemData);
        }
      }
    }
  }

  Future<void> deleteItem(
      String inspectionId, String topicId, String itemId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (topicIndex != null && itemIndex != null) {
      await _deleteItemAtIndex(inspectionId, topicIndex, itemIndex);
    }
  }

  Future<Item> duplicateItem(
      String inspectionId, String topicId, String itemName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');

    final inspection = await getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      Map<String, dynamic>? sourceItemData;
      for (final item in items) {
        if (item['name'] == itemName) {
          sourceItemData = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (sourceItemData == null) {
        throw Exception('Source item not found');
      }

      final duplicateItemData = Map<String, dynamic>.from(sourceItemData);
      duplicateItemData['name'] = '$itemName (copy)';

      await _addItemToTopic(inspectionId, topicIndex, duplicateItemData);

      return Item(
        id: 'item_${items.length}',
        inspectionId: inspectionId,
        topicId: topicId,
        itemName: '$itemName (copy)',
        itemLabel: duplicateItemData['description'],
        position: items.length,
        observation: duplicateItemData['observation'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    throw Exception('Topic not found');
  }

  // DETAIL METHODS
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
          detailValue: detailData['value'],
          observation: detailData['observation'],
          isDamaged: detailData['is_damaged'] ?? false,
          position: i,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return details;
  }

  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    final inspection = await getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (inspection?.topics != null &&
        topicIndex != null &&
        itemIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final itemData = items[itemIndex];
        return extractDetails(inspectionId, topicId, itemId, itemData);
      }
    }

    return [];
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
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }

    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition = existingDetails.length;

    final newDetailData = {
      'name': detailName,
      'type': type ?? 'text',
      'options': options,
      'value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged ?? false,
      'required': false,
      'media': <Map<String, dynamic>>[],
      'non_conformities': <Map<String, dynamic>>[],
    };

    await _addDetailToItem(inspectionId, topicIndex, itemIndex, newDetailData);

    return Detail(
      id: 'detail_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
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
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    final topicIndex =
        int.tryParse(updatedDetail.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex =
        int.tryParse(updatedDetail.itemId?.replaceFirst('item_', '') ?? '');
    final detailIndex =
        int.tryParse(updatedDetail.id?.replaceFirst('detail_', '') ?? '');

    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      final inspection = await getInspection(updatedDetail.inspectionId);
      if (inspection?.topics != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = items[itemIndex];
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            final currentDetailData =
                Map<String, dynamic>.from(details[detailIndex]);
            currentDetailData['name'] = updatedDetail.detailName;
            currentDetailData['value'] = updatedDetail.detailValue;
            currentDetailData['observation'] = updatedDetail.observation;
            currentDetailData['is_damaged'] = updatedDetail.isDamaged ?? false;

            await _updateDetailAtIndex(updatedDetail.inspectionId, topicIndex,
                itemIndex, detailIndex, currentDetailData);
          }
        }
      }
    }
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId,
      String detailId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));

    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      await _deleteDetailAtIndex(
          inspectionId, topicIndex, itemIndex, detailIndex);
    }
  }

  Future<Detail?> duplicateDetail(String inspectionId, String topicId,
      String itemId, String detailName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }

    final inspection = await getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        Map<String, dynamic>? sourceDetailData;
        for (final detail in details) {
          if (detail['name'] == detailName) {
            sourceDetailData = Map<String, dynamic>.from(detail);
            break;
          }
        }

        if (sourceDetailData == null) {
          throw Exception('Source detail not found');
        }

        final duplicateDetailData = Map<String, dynamic>.from(sourceDetailData);
        duplicateDetailData['name'] = '$detailName (copy)';
        duplicateDetailData['media'] = <Map<String, dynamic>>[];
        duplicateDetailData['non_conformities'] = <Map<String, dynamic>>[];

        await _addDetailToItem(
            inspectionId, topicIndex, itemIndex, duplicateDetailData);

        List<String>? options;
        if (duplicateDetailData['options'] is List) {
          options = List<String>.from(duplicateDetailData['options']);
        }

        return Detail(
          id: 'detail_${details.length}',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: '$detailName (copy)',
          type: duplicateDetailData['type'] ?? 'text',
          options: options,
          detailValue: duplicateDetailData['value'],
          observation: duplicateDetailData['observation'],
          isDamaged: duplicateDetailData['is_damaged'] ?? false,
          position: details.length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    throw Exception('Item not found');
  }

  // PRIVATE HELPER METHODS

  Future<void> _addTopicToInspection(
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

  Future<void> _updateTopicAtIndex(String inspectionId, int topicIndex,
      Map<String, dynamic> updatedTopic) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics[topicIndex] = updatedTopic;
        await firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': DateTime.now()
              .toIso8601String(), // Use DateTime.now() for arrays/aninhados
        });
      }
    }
  }

  Future<void> _deleteTopicAtIndex(String inspectionId, int topicIndex) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics.removeAt(topicIndex);
        await firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': DateTime.now()
              .toIso8601String(), // Use DateTime.now() for arrays/aninhados
        });
      }
    }
  }

  Future<void> _addItemToTopic(
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
          'updated_at': DateTime.now()
              .toIso8601String(), // Use DateTime.now() for arrays/aninhados
        });
      }
    }
  }

  Future<void> _updateItemAtIndex(String inspectionId, int topicIndex,
      int itemIndex, Map<String, dynamic> updatedItem) async {
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
            'updated_at': DateTime.now()
                .toIso8601String(), // Use DateTime.now() for arrays/aninhados
          });
        }
      }
    }
  }

  Future<void> _deleteItemAtIndex(
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
            'updated_at': DateTime.now()
                .toIso8601String(), // Use DateTime.now() for arrays/aninhados
          });
        }
      }
    }
  }

  Future<void> _addDetailToItem(String inspectionId, int topicIndex,
      int itemIndex, Map<String, dynamic> newDetail) async {
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
            'updated_at': DateTime.now()
                .toIso8601String(), // Use DateTime.now() for arrays/aninhados
          });
        }
      }
    }
  }

  Future<void> _updateDetailAtIndex(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      Map<String, dynamic> updatedDetail) async {
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
              'updated_at': DateTime.now()
                  .toIso8601String(), // Use DateTime.now() for arrays/aninhados
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
              'updated_at': DateTime.now()
                  .toIso8601String(), // Use DateTime.now() for arrays/aninhados
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
              'updated_at': DateTime.now()
                  .toIso8601String(), // Use DateTime.now() for arrays/aninhados
            });
          }
        }
      }
    }
  }

  // Remove media from detail
  Future<void> removeMedia(String inspectionId, int topicIndex, int itemIndex,
      int detailIndex, int mediaIndex) async {
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
            if (mediaIndex < mediaList.length) {
              mediaList.removeAt(mediaIndex);
              detail['media'] = mediaList;
              details[detailIndex] = detail;
              item['details'] = details;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;

              await firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .update({
                'topics': topics,
                'updated_at': DateTime.now()
                    .toIso8601String(), // Use DateTime.now() for arrays/aninhados
              });
            }
          }
        }
      }
    }
  }

  // Update media in detail
  Future<void> updateMedia(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      int mediaIndex,
      Map<String, dynamic> updatedMedia) async {
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
            if (mediaIndex < mediaList.length) {
              mediaList[mediaIndex] = updatedMedia;
              detail['media'] = mediaList;
              details[detailIndex] = detail;
              item['details'] = details;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;

              await firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .update({
                'topics': topics,
                'updated_at': DateTime.now()
                    .toIso8601String(), // Use DateTime.now() for arrays/aninhados
              });
            }
          }
        }
      }
    }
  }

  // Remove non-conformity from detail
  Future<void> removeNonConformity(String inspectionId, int topicIndex,
      int itemIndex, int detailIndex, int ncIndex) async {
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
            if (ncIndex < ncList.length) {
              ncList.removeAt(ncIndex);
              detail['non_conformities'] = ncList;

              // Update is_damaged status based on remaining non-conformities
              detail['is_damaged'] = ncList.isNotEmpty;

              details[detailIndex] = detail;
              item['details'] = details;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;

              await firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .update({
                'topics': topics,
                'updated_at': DateTime.now()
                    .toIso8601String(), // Use DateTime.now() for arrays/aninhados
              });
            }
          }
        }
      }
    }
  }

  // Update non-conformity in detail
  Future<void> updateNonConformity(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      int ncIndex,
      Map<String, dynamic> updatedNc) async {
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
            if (ncIndex < ncList.length) {
              ncList[ncIndex] = updatedNc;
              detail['non_conformities'] = ncList;
              details[detailIndex] = detail;
              item['details'] = details;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;

              await firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .update({
                'topics': topics,
                'updated_at': DateTime.now()
                    .toIso8601String(), // Use DateTime.now() for arrays/aninhados
              });
            }
          }
        }
      }
    }
  }

  // Add media to non-conformity
  Future<void> addMediaToNonConformity(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      int ncIndex,
      Map<String, dynamic> media) async {
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
            if (ncIndex < ncList.length) {
              final nc = Map<String, dynamic>.from(ncList[ncIndex]);
              final ncMedia =
                  List<Map<String, dynamic>>.from(nc['media'] ?? []);
              ncMedia.add(media);
              nc['media'] = ncMedia;
              ncList[ncIndex] = nc;
              detail['non_conformities'] = ncList;
              details[detailIndex] = detail;
              item['details'] = details;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;

              await firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .update({
                'topics': topics,
                'updated_at': DateTime.now()
                    .toIso8601String(), // Use DateTime.now() for arrays/aninhados
              });
            }
          }
        }
      }
    }
  }

  // Remove media from non-conformity
  Future<void> removeMediaFromNonConformity(String inspectionId, int topicIndex,
      int itemIndex, int detailIndex, int ncIndex, int mediaIndex) async {
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
            if (ncIndex < ncList.length) {
              final nc = Map<String, dynamic>.from(ncList[ncIndex]);
              final ncMedia =
                  List<Map<String, dynamic>>.from(nc['media'] ?? []);
              if (mediaIndex < ncMedia.length) {
                ncMedia.removeAt(mediaIndex);
                nc['media'] = ncMedia;
                ncList[ncIndex] = nc;
                detail['non_conformities'] = ncList;
                details[detailIndex] = detail;
                item['details'] = details;
                items[itemIndex] = item;
                topic['items'] = items;
                topics[topicIndex] = topic;

                await firestore
                    .collection('inspections')
                    .doc(inspectionId)
                    .update({
                  'topics': topics,
                  'updated_at': DateTime.now()
                      .toIso8601String(), // Use DateTime.now() for arrays/aninhados
                });
              }
            }
          }
        }
      }
    }
  }
}

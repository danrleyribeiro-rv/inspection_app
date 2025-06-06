import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/services/data/inspection_service.dart';

class ItemService {
  final InspectionService _inspectionService = InspectionService();

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));

    if (inspection?.topics != null &&
        topicIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topicData = inspection.topics![topicIndex];
      return _extractItems(inspectionId, topicId, topicData);
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
      final inspection =
          await _inspectionService.getInspection(updatedItem.inspectionId);
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

  List<Item> _extractItems(
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

  Future<void> _addItemToTopic(
      String inspectionId, int topicIndex, Map<String, dynamic> newItem) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        items.add(newItem);
        topic['items'] = items;
        topics[topicIndex] = topic;

        await _inspectionService
            .saveInspection(inspection.copyWith(topics: topics));
      }
    }
  }

  Future<void> _updateItemAtIndex(String inspectionId, int topicIndex,
      int itemIndex, Map<String, dynamic> updatedItem) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          items[itemIndex] = updatedItem;
          topic['items'] = items;
          topics[topicIndex] = topic;

          await _inspectionService
              .saveInspection(inspection.copyWith(topics: topics));
        }
      }
    }
  }

  Future<void> _deleteItemAtIndex(
      String inspectionId, int topicIndex, int itemIndex) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          items.removeAt(itemIndex);
          topic['items'] = items;
          topics[topicIndex] = topic;

          await _inspectionService
              .saveInspection(inspection.copyWith(topics: topics));
        }
      }
    }
  }

  Future<Item?> isItemDuplicate(
      String inspectionId, String topicId, String itemName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) return null;

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item['name'] == itemName) {
          return Item(
            id: 'item_$i',
            inspectionId: inspectionId,
            topicId: topicId,
            itemName: item['name'] ?? 'Item ${i + 1}',
            itemLabel: item['description'],
            position: i,
            observation: item['observation'],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    return null;
  }
}

// lib/services/data/item_service.dart
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/services/data/detail_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/service_factory.dart';

class ItemService {
  final InspectionService _inspectionService = InspectionService();
  DetailService get _detailService => DetailService();
  CacheService get _cacheService => ServiceFactory().cacheService;

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    try {
      final inspection = await _inspectionService.getInspection(inspectionId);
      final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
      if (inspection?.topics != null &&
          topicIndex != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        return _extractItems(inspectionId, topicId, topic);
      }
      
      // Fallback to cache
      final cachedInspection = _cacheService.getCachedInspection(inspectionId);
      if (cachedInspection != null && topicIndex != null) {
        final topics = cachedInspection.data['topics'] as List<dynamic>?;
        if (topics != null && topicIndex < topics.length) {
          final topic = topics[topicIndex];
          return _extractItems(inspectionId, topicId, topic);
        }
      }

      return [];
    } catch (e) {
      // Final fallback to cache
      final cachedInspection = _cacheService.getCachedInspection(inspectionId);
      final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
      if (cachedInspection != null && topicIndex != null) {
        final topics = cachedInspection.data['topics'] as List<dynamic>?;
        if (topics != null && topicIndex < topics.length) {
          final topic = topics[topicIndex];
          return _extractItems(inspectionId, topicId, topic);
        }
      }
      return [];
    }
  }

  // ADICIONADO: Novo método para calcular o progresso de um item.
  Future<double> getItemProgress(
      String inspectionId, String topicId, String itemId) async {
    final details =
        await _detailService.getDetails(inspectionId, topicId, itemId);

    if (details.isEmpty) {
      return 0.0;
    }

    int completedDetails = 0;
    for (final detail in details) {
      if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
        completedDetails++;
      }
    }

    return completedDetails / details.length;
  }

  Future<Item> addItem(
    String inspectionId,
    String topicId,
    String itemName, {
    String? description,
    String? observation,
  }) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) {
      throw Exception('Invalid topic ID');
    }

    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;

    final newItemData = {
      'name': itemName,
      'description': description,
      'observation': observation,
      'details': <Map<String, dynamic>>[],
    };

    await _addItemToTopic(inspectionId, topicIndex, newItemData);

    return Item(
      id: 'item_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      position: newPosition,
      itemName: itemName,
      itemLabel: description,
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

  Future<Item> duplicateItem(
    String inspectionId,
    String topicId,
    Item sourceItem,
  ) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) {
      throw Exception('Invalid topic ID');
    }

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = Map<String, dynamic>.from(inspection.topics![topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      final sourceItemIndex =
          int.tryParse(sourceItem.id?.replaceFirst('item_', '') ?? '');
      if (sourceItemIndex == null || sourceItemIndex >= items.length) {
        throw Exception('Source item not found');
      }

      final sourceItemData = Map<String, dynamic>.from(items[sourceItemIndex]);

      final duplicateItemData = Map<String, dynamic>.from(sourceItemData);
      duplicateItemData['name'] = '${sourceItem.itemName} (cópia)';

      if (duplicateItemData['details'] is List) {
        final details =
            List<Map<String, dynamic>>.from(duplicateItemData['details']);
        for (int i = 0; i < details.length; i++) {
          details[i] = Map<String, dynamic>.from(details[i]);
          details[i]['media'] = <Map<String, dynamic>>[];
          details[i]['non_conformities'] = <Map<String, dynamic>>[];
          details[i]['value'] = null;
          details[i]['observation'] = null;
          details[i]['is_damaged'] = false;
        }
        duplicateItemData['details'] = details;
      }

      items.add(duplicateItemData);
      topic['items'] = items;

      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      topics[topicIndex] = topic;

      await _cacheService
          .saveInspection(inspection.copyWith(topics: topics));

      return Item(
        id: 'item_${items.length - 1}',
        inspectionId: inspectionId,
        topicId: topicId,
        position: items.length - 1,
        itemName: '${sourceItem.itemName} (cópia)',
        itemLabel: sourceItem.itemLabel,
        observation: sourceItem.observation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    throw Exception('Failed to duplicate item');
  }

  Future<void> deleteItem(
      String inspectionId, String topicId, String itemId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (topicIndex != null && itemIndex != null) {
      await _deleteItemAtIndex(inspectionId, topicIndex, itemIndex);
    }
  }

  Future<void> reorderItems(
      String inspectionId, String topicId, int oldIndex, int newIndex) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) return;

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (oldIndex < 0 ||
          oldIndex >= items.length ||
          newIndex < 0 ||
          newIndex > items.length) {
        return;
      }

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final itemToMove = items.removeAt(oldIndex);
      items.insert(newIndex, itemToMove);

      topic['items'] = items;
      topics[topicIndex] = topic;

      await _cacheService
          .saveInspection(inspection.copyWith(topics: topics));
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
          position: i,
          itemName: itemData['name'] ?? 'Item ${i + 1}',
          itemLabel: itemData['description'],
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
        await _cacheService
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
          await _cacheService
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
          await _cacheService
              .saveInspection(inspection.copyWith(topics: topics));
        }
      }
    }
  }
}
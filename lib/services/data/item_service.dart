// lib/services/data/item_service.dart
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/services/data/detail_service.dart';
import 'package:inspection_app/services/storage/sqlite_storage_service.dart'; // Use SQLiteStorageService

class ItemService {
  final SQLiteStorageService _localStorage = SQLiteStorageService.instance; // Use SQLiteStorageService
  DetailService get _detailService => DetailService();

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
      final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
      if (inspection?.topics != null &&
          topicIndex != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        return _extractItems(inspectionId, topicId, topic);
      }
      return [];
    } catch (e) {
      debugPrint('ItemService.getItems: Error getting items: $e');
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

    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final existingTopics = inspection.topics ?? [];
    if (topicIndex < 0 || topicIndex >= existingTopics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }

    final topic = Map<String, dynamic>.from(existingTopics[topicIndex]);
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
    final newPosition = items.length;

    final newItemData = {
      'name': itemName,
      'description': description,
      'observation': observation,
      'details': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    items.add(newItemData);
    topic['items'] = items;

    final updatedTopics = List<Map<String, dynamic>>.from(existingTopics);
    updatedTopics[topicIndex] = topic;

    final updatedInspection = inspection.copyWith(
      topics: updatedTopics,
      updatedAt: DateTime.now(),
    );
    await _localStorage.saveInspection(updatedInspection); // Save to SQLite

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
          await _localStorage.getInspection(updatedItem.inspectionId); // Get from SQLite
      if (inspection?.topics != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = Map<String, dynamic>.from(inspection.topics![topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final currentItemData = Map<String, dynamic>.from(items[itemIndex]);
          currentItemData['name'] = updatedItem.itemName;
          currentItemData['description'] = updatedItem.itemLabel;
          currentItemData['observation'] = updatedItem.observation;
          currentItemData['updated_at'] = DateTime.now().toIso8601String();

          items[itemIndex] = currentItemData;
          topic['items'] = items;

          final updatedTopics = List<Map<String, dynamic>>.from(inspection.topics!);
          updatedTopics[topicIndex] = topic;

          final updatedInspection = inspection.copyWith(
            topics: updatedTopics,
            updatedAt: DateTime.now(),
          );
          await _localStorage.saveInspection(updatedInspection); // Save to SQLite
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

    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection == null) {
      throw Exception('Inspection not found');
    }

    final existingTopics = inspection.topics ?? [];
    if (topicIndex < 0 || topicIndex >= existingTopics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }

    final topic = Map<String, dynamic>.from(existingTopics[topicIndex]);
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
    duplicateItemData['created_at'] = DateTime.now().toIso8601String();
    duplicateItemData['updated_at'] = DateTime.now().toIso8601String();

    items.add(duplicateItemData);
    topic['items'] = items;

    final updatedTopics = List<Map<String, dynamic>>.from(existingTopics);
    updatedTopics[topicIndex] = topic;

    final updatedInspection = inspection.copyWith(topics: updatedTopics);
    await _localStorage.saveInspection(updatedInspection); // Save to SQLite

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

    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
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

      final updatedInspection = inspection.copyWith(topics: topics);
      await _localStorage.saveInspection(updatedInspection); // Save to SQLite
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

  Future<void> _deleteItemAtIndex(
      String inspectionId, int topicIndex, int itemIndex) async {
    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          items.removeAt(itemIndex);
          topic['items'] = items;
          topics[topicIndex] = topic;
          final updatedInspection = inspection.copyWith(topics: topics);
          await _localStorage.saveInspection(updatedInspection); // Save to SQLite
        }
      }
    }
  }
}
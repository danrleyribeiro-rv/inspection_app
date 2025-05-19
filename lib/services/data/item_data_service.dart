import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';

class ItemDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final InspectionDataService _inspectionService = InspectionDataService();

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    
    if (inspection?.topics != null && topicIndex != null && topicIndex < inspection!.topics!.length) {
      final topicData = inspection.topics![topicIndex];
      return _inspectionService.extractItems(inspectionId, topicId, topicData);
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

    await _inspectionService.addItem(inspectionId, topicIndex, newItemData);

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
    final topicIndex = int.tryParse(updatedItem.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex = int.tryParse(updatedItem.id?.replaceFirst('item_', '') ?? '');
    
    if (topicIndex != null && itemIndex != null) {
      final inspection = await _inspectionService.getInspection(updatedItem.inspectionId);
      if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final currentItemData = Map<String, dynamic>.from(items[itemIndex]);
          currentItemData['name'] = updatedItem.itemName;
          currentItemData['description'] = updatedItem.itemLabel;
          currentItemData['observation'] = updatedItem.observation;
          
          await _inspectionService.updateItem(updatedItem.inspectionId, topicIndex, itemIndex, currentItemData);
        }
      }
    }
  }

  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    
    if (topicIndex != null && itemIndex != null) {
      await _inspectionService.deleteItem(inspectionId, topicIndex, itemIndex);
    }
  }

  Future<Item> isItemDuplicate(String inspectionId, String topicId, String itemName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');
    
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      // Find the source item
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
      
      // Create duplicate
      final duplicateItemData = Map<String, dynamic>.from(sourceItemData);
      duplicateItemData['name'] = '$itemName (copy)';
      
      await _inspectionService.addItem(inspectionId, topicIndex, duplicateItemData);
      
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
}
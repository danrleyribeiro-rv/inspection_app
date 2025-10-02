import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class ItemRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(Item item) async {
    await DatabaseHelper.insertItem(item);
    return item.id;
  }

  Future<void> update(Item item) async {
    await DatabaseHelper.updateItem(item);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteItem(id);
  }

  Future<Item?> findById(String id) async {
    return await DatabaseHelper.getItem(id);
  }

  Item fromMap(Map<String, dynamic> map) {
    return Item.fromMap(map);
  }

  Map<String, dynamic> toMap(Item entity) {
    return entity.toMap();
  }

  // Métodos específicos do Item
  Future<List<Item>> findByTopicId(String topicId) async {
    return await DatabaseHelper.getItemsByTopic(topicId);
  }

  Future<List<Item>> findByTopicIdOrdered(String topicId) async {
    final items = await DatabaseHelper.getItemsByTopic(topicId);
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  Future<List<Item>> findByInspectionId(String inspectionId) async {
    final allItems = DatabaseHelper.items.values.toList();
    return allItems.where((item) => item.inspectionId == inspectionId).toList();
  }

  Future<List<Item>> findByInspectionIdOrdered(String inspectionId) async {
    final items = await findByInspectionId(inspectionId);
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  Future<Item?> findByTopicIdAndIndex(String topicId, int orderIndex) async {
    final items = await findByTopicId(topicId);
    try {
      return items.firstWhere((item) => item.orderIndex == orderIndex);
    } catch (e) {
      return null;
    }
  }

  Future<int> getMaxOrderIndex(String topicId) async {
    final items = await findByTopicId(topicId);
    if (items.isEmpty) return 0;
    return items.map((i) => i.orderIndex).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateProgress(String itemId, double progressPercentage,
      int completedDetails, int totalDetails) async {
    final item = await findById(itemId);
    if (item != null) {
      final updatedItem = item.copyWith(
        updatedAt: DateFormatter.now(),
      );
      await update(updatedItem);
    }
  }

  Future<void> reorderItems(String topicId, List<String> itemIds) async {
    for (int i = 0; i < itemIds.length; i++) {
      final item = await findById(itemIds[i]);
      if (item != null && item.topicId == topicId) {
        final updatedItem = item.copyWith(
          orderIndex: i,
          updatedAt: DateFormatter.now(),
        );
        await update(updatedItem);
      }
    }
  }

  Future<void> deleteByTopicId(String topicId) async {
    final items = await findByTopicId(topicId);
    for (final item in items) {
      await delete(item.id);
    }
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final items = await findByInspectionId(inspectionId);
    for (final item in items) {
      await delete(item.id);
    }
  }

  Future<List<Item>> findByEvaluation(String evaluation) async {
    final allItems = DatabaseHelper.items.values.toList();
    return allItems.where((item) => item.evaluation == evaluation).toList();
  }

  Future<List<Item>> findByEvaluationValue(String evaluationValue) async {
    final allItems = DatabaseHelper.items.values.toList();
    return allItems.where((item) => item.evaluationValue == evaluationValue).toList();
  }

  Future<int> countByTopicId(String topicId) async {
    final items = await findByTopicId(topicId);
    return items.length;
  }

  Future<int> countEvaluatedByTopicId(String topicId) async {
    final items = await findByTopicId(topicId);
    return items.where((item) => item.evaluation != null && item.evaluation!.isNotEmpty).length;
  }

  Future<int> countCompletedByTopicId(String topicId) async {
    return await countEvaluatedByTopicId(topicId);
  }

  /// Inserir ou atualizar item vindo da nuvem
  Future<void> insertOrUpdateFromCloud(Item item) async {
    final existing = await findById(item.id);
    final itemToSave = item.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(itemToSave);
    } else {
      await insert(itemToSave);
    }
  }

  /// Inserir ou atualizar item local
  Future<void> insertOrUpdate(Item item) async {
    final existing = await findById(item.id);
    final itemToSave = item.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(itemToSave);
    } else {
      await insert(itemToSave);
    }
  }
}

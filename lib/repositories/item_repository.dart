import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';

class ItemRepository extends BaseRepository<Item> {
  @override
  String get tableName => 'items';

  @override
  Item fromMap(Map<String, dynamic> map) {
    return Item.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Item entity) {
    return entity.toMap();
  }

  // Métodos específicos do Item
  Future<List<Item>> findByTopicId(String topicId) async {
    return await findWhere('topic_id = ?', [topicId]);
  }

  Future<List<Item>> findByTopicIdOrdered(String topicId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'topic_id = ? AND is_deleted = 0',
      whereArgs: [topicId],
      orderBy: 'order_index ASC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<Item>> findByInspectionId(String inspectionId) async {
    return await findWhere('inspection_id = ?', [inspectionId]);
  }

  Future<List<Item>> findByInspectionIdOrdered(String inspectionId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND is_deleted = 0',
      whereArgs: [inspectionId],
      orderBy: 'order_index ASC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  Future<Item?> findByTopicIdAndIndex(String topicId, int orderIndex) async {
    final results = await findWhere(
        'topic_id = ? AND order_index = ?', [topicId, orderIndex]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> getMaxOrderIndex(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as max_index FROM $tableName WHERE topic_id = ? AND is_deleted = 0',
      [topicId],
    );
    return (result.first['max_index'] as int?) ?? 0;
  }

  Future<void> updateProgress(String itemId, double progressPercentage,
      int completedDetails, int totalDetails) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'progress_percentage': progressPercentage,
        'completed_details': completedDetails,
        'total_details': totalDetails,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> reorderItems(String topicId, List<String> itemIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < itemIds.length; i++) {
        await txn.update(
          tableName,
          {
            'order_index': i,
            'updated_at': DateTime.now().toIso8601String(),
            'needs_sync': 1,
          },
          where: 'id = ? AND topic_id = ?',
          whereArgs: [itemIds[i], topicId],
        );
      }
    });
  }

  Future<void> deleteByTopicId(String topicId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<List<Item>> findByStatus(String status) async {
    return await findWhere('status = ?', [status]);
  }

  Future<List<Item>> findByType(String type) async {
    return await findWhere('type = ?', [type]);
  }

  Future<int> countByTopicId(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE topic_id = ? AND is_deleted = 0',
      [topicId],
    );
    return result.first['count'] as int;
  }

  Future<int> countCompletedByTopicId(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE topic_id = ? AND is_deleted = 0 AND status = ?',
      [topicId, 'completed'],
    );
    return result.first['count'] as int;
  }
}

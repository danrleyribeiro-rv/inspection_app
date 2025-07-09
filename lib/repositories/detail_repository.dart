import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/repositories/base_repository.dart';

class DetailRepository extends BaseRepository<Detail> {
  @override
  String get tableName => 'details';

  @override
  Detail fromMap(Map<String, dynamic> map) {
    return Detail.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Detail entity) {
    return entity.toMap();
  }

  // Métodos específicos do Detail
  Future<List<Detail>> findByItemId(String itemId) async {
    return await findWhere('item_id = ?', [itemId]);
  }

  Future<List<Detail>> findByItemIdOrdered(String itemId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'item_id = ? AND is_deleted = 0',
      whereArgs: [itemId],
      orderBy: 'order_index ASC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<Detail>> findByTopicId(String topicId) async {
    return await findWhere('topic_id = ?', [topicId]);
  }

  Future<List<Detail>> findByInspectionId(String inspectionId) async {
    return await findWhere('inspection_id = ?', [inspectionId]);
  }

  Future<Detail?> findByItemIdAndIndex(String itemId, int orderIndex) async {
    final results = await findWhere('item_id = ? AND order_index = ?', [itemId, orderIndex]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> getMaxOrderIndex(String itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as max_index FROM $tableName WHERE item_id = ? AND is_deleted = 0',
      [itemId],
    );
    return (result.first['max_index'] as int?) ?? 0;
  }

  Future<void> updateValue(String detailId, String? value, String? observations) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'value': value,
        'observations': observations,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [detailId],
    );
  }

  Future<void> markAsCompleted(String detailId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [detailId],
    );
  }

  Future<void> markAsIncomplete(String detailId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [detailId],
    );
  }

  Future<void> setNonConformity(String detailId, bool hasNonConformity) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'has_non_conformity': hasNonConformity ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [detailId],
    );
  }

  Future<void> reorderDetails(String itemId, List<String> detailIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < detailIds.length; i++) {
        await txn.update(
          tableName,
          {
            'order_index': i,
            'updated_at': DateTime.now().toIso8601String(),
            'needs_sync': 1,
          },
          where: 'id = ? AND item_id = ?',
          whereArgs: [detailIds[i], itemId],
        );
      }
    });
  }

  Future<void> deleteByItemId(String itemId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
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

  Future<List<Detail>> findByStatus(String status) async {
    return await findWhere('status = ?', [status]);
  }

  Future<List<Detail>> findByType(String type) async {
    return await findWhere('type = ?', [type]);
  }

  Future<List<Detail>> findRequired() async {
    return await findWhere('is_required = 1', []);
  }

  Future<List<Detail>> findWithNonConformity() async {
    return await findWhere('has_non_conformity = 1', []);
  }

  Future<List<Detail>> findWithValue() async {
    return await findWhere('value IS NOT NULL AND value != ""', []);
  }

  Future<int> countByItemId(String itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE item_id = ? AND is_deleted = 0',
      [itemId],
    );
    return result.first['count'] as int;
  }

  Future<int> countCompletedByItemId(String itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE item_id = ? AND is_deleted = 0 AND status = ?',
      [itemId, 'completed'],
    );
    return result.first['count'] as int;
  }

  Future<int> countRequiredByItemId(String itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE item_id = ? AND is_deleted = 0 AND is_required = 1',
      [itemId],
    );
    return result.first['count'] as int;
  }

  Future<int> countRequiredCompletedByItemId(String itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE item_id = ? AND is_deleted = 0 AND is_required = 1 AND status = ?',
      [itemId, 'completed'],
    );
    return result.first['count'] as int;
  }
}
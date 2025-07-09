import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/repositories/base_repository.dart';

class TopicRepository extends BaseRepository<Topic> {
  @override
  String get tableName => 'topics';

  @override
  Topic fromMap(Map<String, dynamic> map) {
    return Topic.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Topic entity) {
    return entity.toMap();
  }

  // Métodos específicos do Topic
  Future<List<Topic>> findByInspectionId(String inspectionId) async {
    return await findWhere('inspection_id = ?', [inspectionId]);
  }

  Future<List<Topic>> findByInspectionIdOrdered(String inspectionId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND is_deleted = 0',
      whereArgs: [inspectionId],
      orderBy: 'order_index ASC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<Topic?> findByInspectionIdAndIndex(String inspectionId, int orderIndex) async {
    final results = await findWhere('inspection_id = ? AND order_index = ?', [inspectionId, orderIndex]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> getMaxOrderIndex(String inspectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as max_index FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
      [inspectionId],
    );
    return (result.first['max_index'] as int?) ?? 0;
  }

  Future<void> updateProgress(String topicId, double progressPercentage, int completedItems, int totalItems) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'progress_percentage': progressPercentage,
        'completed_items': completedItems,
        'total_items': totalItems,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < topicIds.length; i++) {
        await txn.update(
          tableName,
          {
            'order_index': i,
            'updated_at': DateTime.now().toIso8601String(),
            'needs_sync': 1,
          },
          where: 'id = ? AND inspection_id = ?',
          whereArgs: [topicIds[i], inspectionId],
        );
      }
    });
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
}
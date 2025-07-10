import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';

class NonConformityRepository extends BaseRepository<NonConformity> {
  @override
  String get tableName => 'non_conformities';

  @override
  NonConformity fromMap(Map<String, dynamic> map) {
    return NonConformity.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(NonConformity entity) {
    return entity.toMap();
  }

  // Métodos específicos do NonConformity
  Future<List<NonConformity>> findByInspectionId(String inspectionId) async {
    return await findWhere('inspection_id = ?', [inspectionId]);
  }

  Future<List<NonConformity>> findByTopicId(String topicId) async {
    return await findWhere('topic_id = ?', [topicId]);
  }

  Future<List<NonConformity>> findByItemId(String itemId) async {
    return await findWhere('item_id = ?', [itemId]);
  }

  Future<List<NonConformity>> findByDetailId(String detailId) async {
    return await findWhere('detail_id = ?', [detailId]);
  }

  Future<List<NonConformity>> findBySeverity(String severity) async {
    return await findWhere('severity = ?', [severity]);
  }

  Future<List<NonConformity>> findByStatus(String status) async {
    return await findWhere('status = ?', [status]);
  }

  Future<List<NonConformity>> findByInspectionIdAndStatus(
      String inspectionId, String status) async {
    return await findWhere(
        'inspection_id = ? AND status = ?', [inspectionId, status]);
  }

  Future<List<NonConformity>> findByInspectionIdAndSeverity(
      String inspectionId, String severity) async {
    return await findWhere(
        'inspection_id = ? AND severity = ?', [inspectionId, severity]);
  }

  Future<void> updateStatus(String nonConformityId, String status) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [nonConformityId],
    );
  }

  Future<void> updateSeverity(String nonConformityId, String severity) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'severity': severity,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [nonConformityId],
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

  Future<void> deleteByDetailId(String detailId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'detail_id = ?',
      whereArgs: [detailId],
    );
  }

  Future<int> countByInspectionId(String inspectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
      [inspectionId],
    );
    return result.first['count'] as int;
  }

  Future<int> countByInspectionIdAndStatus(
      String inspectionId, String status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND status = ? AND is_deleted = 0',
      [inspectionId, status],
    );
    return result.first['count'] as int;
  }

  Future<int> countByInspectionIdAndSeverity(
      String inspectionId, String severity) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND severity = ? AND is_deleted = 0',
      [inspectionId, severity],
    );
    return result.first['count'] as int;
  }

  Future<Map<String, int>> getStatsByInspectionId(String inspectionId) async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
          [inspectionId]),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND status = ? AND is_deleted = 0',
          [inspectionId, 'open']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND status = ? AND is_deleted = 0',
          [inspectionId, 'closed']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND severity = ? AND is_deleted = 0',
          [inspectionId, 'low']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND severity = ? AND is_deleted = 0',
          [inspectionId, 'medium']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND severity = ? AND is_deleted = 0',
          [inspectionId, 'high']),
      db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND severity = ? AND is_deleted = 0',
          [inspectionId, 'critical']),
    ]);

    return {
      'total': results[0].first['count'] as int,
      'open': results[1].first['count'] as int,
      'closed': results[2].first['count'] as int,
      'low': results[3].first['count'] as int,
      'medium': results[4].first['count'] as int,
      'high': results[5].first['count'] as int,
      'critical': results[6].first['count'] as int,
    };
  }

  Future<List<NonConformity>> findByInspectionIdGroupedBySeverity(
      String inspectionId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND is_deleted = 0',
      whereArgs: [inspectionId],
      orderBy:
          'CASE severity WHEN "critical" THEN 1 WHEN "high" THEN 2 WHEN "medium" THEN 3 WHEN "low" THEN 4 END, created_at DESC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }
}

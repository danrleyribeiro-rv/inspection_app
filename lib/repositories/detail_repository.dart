import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';

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
    final results = await findWhere(
        'item_id = ? AND order_index = ?', [itemId, orderIndex]);
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

  Future<void> updateValue(
      String detailId, String? value, String? observation) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'detail_value': value,
        'observation': observation,
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

  // =================================
  // MÉTODOS PARA HIERARQUIAS FLEXÍVEIS
  // =================================

  // Buscar detalhes diretos de tópico (sem item intermediário)
  Future<List<Detail>> findDirectDetailsByTopicId(String topicId) async {
    return await findWhere('topic_id = ? AND item_id IS NULL', [topicId]);
  }

  // Buscar detalhes diretos de tópico ordenados
  Future<List<Detail>> findDirectDetailsByTopicIdOrdered(String topicId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'topic_id = ? AND item_id IS NULL AND is_deleted = 0',
      whereArgs: [topicId],
      orderBy: 'order_index ASC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  // Contar detalhes diretos de tópico
  Future<int> countDirectDetailsByTopicId(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE topic_id = ? AND item_id IS NULL AND is_deleted = 0',
      [topicId],
    );
    return result.first['count'] as int;
  }

  // Contar detalhes diretos completados de tópico
  Future<int> countDirectDetailsCompletedByTopicId(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE topic_id = ? AND item_id IS NULL AND is_deleted = 0 AND status = ?',
      [topicId, 'completed'],
    );
    return result.first['count'] as int;
  }

  // Buscar detalhes por hierarquia flexível
  Future<List<Detail>> findByHierarchy({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? directOnly,
  }) async {
    final conditions = ['inspection_id = ?'];
    final args = [inspectionId];
    
    if (topicId != null) {
      conditions.add('topic_id = ?');
      args.add(topicId);
    }
    if (itemId != null) {
      conditions.add('item_id = ?');
      args.add(itemId);
    } else if (directOnly == true) {
      conditions.add('item_id IS NULL');
    }
    if (detailId != null) {
      conditions.add('detail_id = ?');
      args.add(detailId);
    }
    
    return await findWhere(conditions.join(' AND '), args);
  }

  // Buscar detalhes por contexto específico com ordenação
  Future<List<Detail>> findDetailsByContextOrdered({
    required String inspectionId,
    String? topicId,
    String? itemId,
    bool? directOnly,
  }) async {
    var whereClause = 'inspection_id = ? AND is_deleted = 0';
    var args = [inspectionId];
    
    if (topicId != null) {
      whereClause += ' AND topic_id = ?';
      args.add(topicId);
    }
    
    if (itemId != null) {
      whereClause += ' AND item_id = ?';
      args.add(itemId);
    } else if (directOnly == true) {
      whereClause += ' AND item_id IS NULL';
    }

    final db = await database;
    final maps = await db.query(
      tableName,
      where: whereClause,
      whereArgs: args,
      orderBy: 'order_index ASC',
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  // Reordenar detalhes diretos de tópico
  Future<void> reorderDirectDetails(String topicId, List<String> detailIds) async {
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
          where: 'id = ? AND topic_id = ? AND item_id IS NULL',
          whereArgs: [detailIds[i], topicId],
        );
      }
    });
  }

  // Validar hierarquia do detalhe
  Future<bool> validateDetailHierarchy(Detail detail) async {
    // Se é detalhe direto de tópico, verificar se o tópico permite
    if (detail.topicId != null && detail.itemId == null) {
      // Buscar o tópico para verificar se permite detalhes diretos
      final db = await database;
      final result = await db.query(
        'topics',
        columns: ['direct_details'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [detail.topicId],
      );
      
      if (result.isNotEmpty) {
        final directDetails = result.first['direct_details'] as int;
        return directDetails == 1;
      }
      return false;
    }
    
    // Se é detalhe de item, verificar se o item existe
    if (detail.itemId != null) {
      final db = await database;
      final result = await db.query(
        'items',
        columns: ['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [detail.itemId],
      );
      return result.isNotEmpty;
    }
    
    return true;
  }

  // Obter máximo order_index para detalhes diretos de tópico
  Future<int> getMaxOrderIndexForTopic(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as max_index FROM $tableName WHERE topic_id = ? AND item_id IS NULL AND is_deleted = 0',
      [topicId],
    );
    return (result.first['max_index'] as int?) ?? 0;
  }

  // Atualizar opção customizada
  Future<void> updateCustomOption(String detailId, bool allowCustom, String? customValue) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'allow_custom_option': allowCustom ? 1 : 0,
        'custom_option_value': customValue,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [detailId],
    );
  }
}

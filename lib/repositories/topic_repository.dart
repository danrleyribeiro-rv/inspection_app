import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';

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

  Future<Topic?> findByInspectionIdAndIndex(
      String inspectionId, int orderIndex) async {
    final results = await findWhere(
        'inspection_id = ? AND order_index = ?', [inspectionId, orderIndex]);
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

  Future<void> updateProgress(String topicId, double progressPercentage,
      int completedItems, int totalItems) async {
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

  // =================================
  // MÉTODOS PARA HIERARQUIAS FLEXÍVEIS
  // =================================

  // Buscar tópicos com detalhes diretos
  Future<List<Topic>> findTopicsWithDirectDetails(String inspectionId) async {
    return await findWhere('inspection_id = ? AND direct_details = 1', [inspectionId]);
  }

  // Buscar tópicos com itens (hierarquia tradicional)
  Future<List<Topic>> findTopicsWithItems(String inspectionId) async {
    return await findWhere('inspection_id = ? AND (direct_details = 0 OR direct_details IS NULL)', [inspectionId]);
  }

  // Atualizar configuração de detalhes diretos
  Future<void> updateDirectDetailsConfig(String topicId, bool directDetails) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'direct_details': directDetails ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  // Verificar se tópico permite detalhes diretos
  Future<bool> hasDirectDetails(String topicId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['direct_details'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [topicId],
    );
    
    if (result.isNotEmpty) {
      final directDetails = result.first['direct_details'] as int?;
      return directDetails == 1;
    }
    return false;
  }

  // Atualizar descrição do tópico
  Future<void> updateDescription(String topicId, String? description) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'description': description,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  // Contar tópicos por tipo de hierarquia
  Future<Map<String, int>> getHierarchyStats(String inspectionId) async {
    final db = await database;
    
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0',
      [inspectionId],
    );
    
    final directDetailsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0 AND direct_details = 1',
      [inspectionId],
    );
    
    final withItemsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND is_deleted = 0 AND (direct_details = 0 OR direct_details IS NULL)',
      [inspectionId],
    );
    
    final total = totalResult.first['count'] as int;
    final directDetails = directDetailsResult.first['count'] as int;
    final withItems = withItemsResult.first['count'] as int;
    
    return {
      'total': total,
      'direct_details': directDetails,
      'with_items': withItems,
    };
  }

  // Buscar tópicos com base na configuração de hierarquia
  Future<List<Topic>> findByHierarchyType(String inspectionId, {bool? directDetails}) async {
    if (directDetails == null) {
      return await findByInspectionIdOrdered(inspectionId);
    }
    
    final condition = directDetails ? 'direct_details = 1' : '(direct_details = 0 OR direct_details IS NULL)';
    return await findWhere('inspection_id = ? AND $condition', [inspectionId]);
  }

  // Converter tópico entre tipos de hierarquia
  Future<void> convertTopicHierarchy(String topicId, bool toDirectDetails) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Atualizar configuração do tópico
      await txn.update(
        tableName,
        {
          'direct_details': toDirectDetails ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
          'needs_sync': 1,
        },
        where: 'id = ?',
        whereArgs: [topicId],
      );
      
      if (toDirectDetails) {
        // Se convertendo para detalhes diretos, mover detalhes dos itens para o tópico
        // e marcar itens como removidos
        await txn.update(
          'details',
          {
            'item_id': null,
            'updated_at': DateTime.now().toIso8601String(),
            'needs_sync': 1,
          },
          where: 'topic_id = ? AND is_deleted = 0',
          whereArgs: [topicId],
        );
        
        await txn.update(
          'items',
          {
            'is_deleted': 1,
            'updated_at': DateTime.now().toIso8601String(),
            'needs_sync': 1,
          },
          where: 'topic_id = ? AND is_deleted = 0',
          whereArgs: [topicId],
        );
      }
    });
  }
}

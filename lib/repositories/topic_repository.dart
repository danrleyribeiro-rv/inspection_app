import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class TopicRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(Topic topic) async {
    await DatabaseHelper.insertTopic(topic);
    return topic.id!; // Use ! since we expect id to be non-null after insertion
  }

  Future<void> update(Topic topic) async {
    await DatabaseHelper.updateTopic(topic);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteTopic(id);
  }

  Future<Topic?> findById(String id) async {
    return await DatabaseHelper.getTopic(id);
  }

  Topic fromMap(Map<String, dynamic> map) {
    return Topic.fromMap(map);
  }

  Map<String, dynamic> toMap(Topic entity) {
    return entity.toMap();
  }

  // Métodos específicos do Topic
  Future<List<Topic>> findByInspectionId(String inspectionId) async {
    return await DatabaseHelper.getTopicsByInspection(inspectionId);
  }

  Future<List<Topic>> findByInspectionIdOrdered(String inspectionId) async {
    final topics = await DatabaseHelper.getTopicsByInspection(inspectionId);
    topics.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return topics;
  }

  Future<Topic?> findByInspectionIdAndIndex(
      String inspectionId, int orderIndex) async {
    final topics = await findByInspectionId(inspectionId);
    try {
      return topics.firstWhere((topic) => topic.orderIndex == orderIndex);
    } catch (e) {
      return null;
    }
  }

  Future<int> getMaxOrderIndex(String inspectionId) async {
    final topics = await findByInspectionId(inspectionId);
    if (topics.isEmpty) return 0;
    return topics.map((t) => t.orderIndex).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateProgress(String topicId, double progressPercentage,
      int completedItems, int totalItems) async {
    final topic = await findById(topicId);
    if (topic != null) {
      final updatedTopic = topic.copyWith(
        updatedAt: DateFormatter.now(),
      );
      await update(updatedTopic);
    }
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    for (int i = 0; i < topicIds.length; i++) {
      final topic = await findById(topicIds[i]);
      if (topic != null && topic.inspectionId == inspectionId) {
        final updatedTopic = topic.copyWith(
          orderIndex: i,
          updatedAt: DateFormatter.now(),
        );
        await update(updatedTopic);
      }
    }
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final topics = await findByInspectionId(inspectionId);
    for (final topic in topics) {
      if (topic.id != null) {
        await delete(topic.id!);
      }
    }
  }

  // =================================
  // MÉTODOS PARA HIERARQUIAS FLEXÍVEIS
  // =================================

  // Buscar tópicos com detalhes diretos
  Future<List<Topic>> findTopicsWithDirectDetails(String inspectionId) async {
    final allTopics = await findByInspectionId(inspectionId);
    return allTopics.where((topic) => topic.directDetails == true).toList();
  }

  // Buscar tópicos com itens (hierarquia tradicional)
  Future<List<Topic>> findTopicsWithItems(String inspectionId) async {
    final allTopics = await findByInspectionId(inspectionId);
    return allTopics.where((topic) => topic.directDetails != true).toList();
  }

  // Atualizar configuração de detalhes diretos
  Future<void> updateDirectDetailsConfig(String topicId, bool directDetails) async {
    final topic = await findById(topicId);
    if (topic != null) {
      final updatedTopic = topic.copyWith(
        directDetails: directDetails,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedTopic);
    }
  }

  // Verificar se tópico permite detalhes diretos
  Future<bool> hasDirectDetails(String topicId) async {
    final topic = await findById(topicId);
    return topic?.directDetails == true;
  }

  // Atualizar descrição do tópico
  Future<void> updateDescription(String topicId, String? description) async {
    final topic = await findById(topicId);
    if (topic != null) {
      final updatedTopic = topic.copyWith(
        description: description,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedTopic);
    }
  }

  // Contar tópicos por tipo de hierarquia
  Future<Map<String, int>> getHierarchyStats(String inspectionId) async {
    final allTopics = await findByInspectionId(inspectionId);

    final total = allTopics.length;
    final directDetails = allTopics.where((t) => t.directDetails == true).length;
    final withItems = allTopics.where((t) => t.directDetails != true).length;

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

    final allTopics = await findByInspectionId(inspectionId);
    if (directDetails) {
      return allTopics.where((topic) => topic.directDetails == true).toList();
    } else {
      return allTopics.where((topic) => topic.directDetails != true).toList();
    }
  }

  // Converter tópico entre tipos de hierarquia
  Future<void> convertTopicHierarchy(String topicId, bool toDirectDetails) async {
    // Atualizar configuração do tópico
    final topic = await findById(topicId);
    if (topic != null) {
      final updatedTopic = topic.copyWith(
        directDetails: toDirectDetails,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedTopic);

      if (toDirectDetails) {
        // Se convertendo para detalhes diretos, mover detalhes dos itens para o tópico
        // e marcar itens como removidos
        final allDetails = DatabaseHelper.details.values.toList();
        final topicDetails = allDetails.where((detail) => detail.topicId == topicId).toList();

        for (final detail in topicDetails) {
          final updatedDetail = detail.copyWith(
            itemId: null,
            updatedAt: DateFormatter.now(),
          );
          await DatabaseHelper.updateDetail(updatedDetail);
        }

        final allItems = DatabaseHelper.items.values.toList();
        final topicItems = allItems.where((item) => item.topicId == topicId).toList();

        for (final item in topicItems) {
          if (item.id != null) {
            await DatabaseHelper.deleteItem(item.id!);
          }
        }
      }
    }
  }

  // ===============================
  // MÉTODOS DE SINCRONIZAÇÃO
  // ===============================

  /// Buscar tópicos que precisam ser sincronizados
  Future<List<Topic>> findPendingSync() async {
    final List<Map<String, dynamic>> results = await DatabaseHelper.rawQuery(
      'SELECT * FROM topics WHERE needs_sync = 1'
    );
    return results.map((map) => Topic.fromMap(map)).toList();
  }

  /// Inserir ou atualizar tópico vindo da nuvem
  Future<void> insertOrUpdateFromCloud(Topic topic) async {
    final existing = await findById(topic.id!);
    final topicToSave = topic.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(topicToSave);
    } else {
      await insert(topicToSave);
    }
  }

  /// Inserir ou atualizar tópico local
  Future<void> insertOrUpdate(Topic topic) async {
    final existing = await findById(topic.id!);
    final topicToSave = topic.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(topicToSave);
    } else {
      await insert(topicToSave);
    }
  }
}

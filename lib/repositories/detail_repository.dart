import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class DetailRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(Detail detail) async {
    await DatabaseHelper.insertDetail(detail);
    return detail.id!;
  }

  Future<void> update(Detail detail) async {
    await DatabaseHelper.updateDetail(detail);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteDetail(id);
  }

  Future<Detail?> findById(String id) async {
    return await DatabaseHelper.getDetail(id);
  }

  Future<List<Detail>> findByItemId(String itemId) async {
    return await DatabaseHelper.getDetailsByItem(itemId);
  }

  Future<List<Detail>> findByItemIdOrdered(String itemId) async {
    final details = await DatabaseHelper.getDetailsByItem(itemId);
    details.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return details;
  }

  Future<List<Detail>> findByTopicId(String topicId) async {
    // Para Hive, filtraremos na aplicação já que não temos SQL WHERE
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.topicId == topicId).toList();
  }

  Future<List<Detail>> findByInspectionId(String inspectionId) async {
    // Para Hive, filtraremos na aplicação
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.inspectionId == inspectionId).toList();
  }

  Future<Detail?> findByItemIdAndIndex(String itemId, int orderIndex) async {
    final details = await findByItemId(itemId);
    try {
      return details.firstWhere((detail) => detail.orderIndex == orderIndex);
    } catch (e) {
      return null;
    }
  }

  Future<int> getMaxOrderIndex(String itemId) async {
    final details = await findByItemId(itemId);
    if (details.isEmpty) return 0;
    return details.map((d) => d.orderIndex).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateValue(String detailId, String? value, String? observation) async {
    final detail = await findById(detailId);
    if (detail != null) {
      final updatedDetail = detail.copyWith(
        detailValue: value,
        observation: observation,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedDetail);
    }
  }

  Future<void> markAsCompleted(String detailId) async {
    final detail = await findById(detailId);
    if (detail != null) {
      final updatedDetail = detail.copyWith(
        status: 'completed',
        updatedAt: DateFormatter.now(),
      );
      await update(updatedDetail);
    }
  }

  Future<void> markAsIncomplete(String detailId) async {
    final detail = await findById(detailId);
    if (detail != null) {
      final updatedDetail = detail.copyWith(
        status: 'pending',
        updatedAt: DateFormatter.now(),
      );
      await update(updatedDetail);
    }
  }

  Future<void> setNonConformity(String detailId, bool hasNonConformity) async {
    final detail = await findById(detailId);
    if (detail != null) {
      final updatedDetail = detail.copyWith(
        isDamaged: hasNonConformity,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedDetail);
    }
  }

  Future<void> reorderDetails(String itemId, List<String> detailIds) async {
    for (int i = 0; i < detailIds.length; i++) {
      final detail = await findById(detailIds[i]);
      if (detail != null && detail.itemId == itemId) {
        final updatedDetail = detail.copyWith(
          orderIndex: i,
          updatedAt: DateFormatter.now(),
        );
        await update(updatedDetail);
      }
    }
  }

  Future<void> deleteByItemId(String itemId) async {
    final details = await findByItemId(itemId);
    for (final detail in details) {
      await delete(detail.id!);
    }
  }

  Future<void> deleteByTopicId(String topicId) async {
    final details = await findByTopicId(topicId);
    for (final detail in details) {
      await delete(detail.id!);
    }
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final details = await findByInspectionId(inspectionId);
    for (final detail in details) {
      await delete(detail.id!);
    }
  }

  Future<List<Detail>> findByStatus(String status) async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.status == status).toList();
  }

  Future<List<Detail>> findByType(String type) async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.type == type).toList();
  }

  Future<List<Detail>> findRequired() async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.isRequired == true).toList();
  }

  Future<List<Detail>> findWithNonConformity() async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) => detail.isDamaged == true).toList();
  }

  Future<List<Detail>> findWithValue() async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) =>
      detail.detailValue != null && detail.detailValue!.isNotEmpty
    ).toList();
  }

  Future<int> countByItemId(String itemId) async {
    final details = await findByItemId(itemId);
    return details.length;
  }

  Future<int> countCompletedByItemId(String itemId) async {
    final details = await findByItemId(itemId);
    return details.where((d) => d.status == 'completed').length;
  }

  Future<int> countRequiredByItemId(String itemId) async {
    final details = await findByItemId(itemId);
    return details.where((d) => d.isRequired == true).length;
  }

  Future<int> countRequiredCompletedByItemId(String itemId) async {
    final details = await findByItemId(itemId);
    return details.where((d) => d.isRequired == true && d.status == 'completed').length;
  }

  // =================================
  // MÉTODOS PARA HIERARQUIAS FLEXÍVEIS
  // =================================

  Future<List<Detail>> findDirectDetailsByTopicId(String topicId) async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) =>
      detail.topicId == topicId && detail.itemId == null
    ).toList();
  }

  Future<List<Detail>> findDirectDetailsByTopicIdOrdered(String topicId) async {
    final details = await findDirectDetailsByTopicId(topicId);
    details.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return details;
  }

  Future<int> countDirectDetailsByTopicId(String topicId) async {
    final details = await findDirectDetailsByTopicId(topicId);
    return details.length;
  }

  Future<int> countDirectDetailsCompletedByTopicId(String topicId) async {
    final details = await findDirectDetailsByTopicId(topicId);
    return details.where((d) => d.status == 'completed').length;
  }

  Future<List<Detail>> findByHierarchy({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? directOnly,
  }) async {
    final allDetails = DatabaseHelper.details.values.toList();
    return allDetails.where((detail) {
      if (detail.inspectionId != inspectionId) return false;
      if (topicId != null && detail.topicId != topicId) return false;
      if (itemId != null && detail.itemId != itemId) return false;
      if (directOnly == true && detail.itemId != null) return false;
      if (detailId != null && detail.detailId != detailId) return false;
      return true;
    }).toList();
  }

  Future<List<Detail>> findDetailsByContextOrdered({
    required String inspectionId,
    String? topicId,
    String? itemId,
    bool? directOnly,
  }) async {
    final details = await findByHierarchy(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      directOnly: directOnly,
    );
    details.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return details;
  }

  Future<void> reorderDirectDetails(String topicId, List<String> detailIds) async {
    for (int i = 0; i < detailIds.length; i++) {
      final detail = await findById(detailIds[i]);
      if (detail != null && detail.topicId == topicId && detail.itemId == null) {
        final updatedDetail = detail.copyWith(
          orderIndex: i,
          updatedAt: DateFormatter.now(),
        );
        await update(updatedDetail);
      }
    }
  }

  Future<bool> validateDetailHierarchy(Detail detail) async {
    // Se é detalhe direto de tópico, verificar se o tópico permite
    if (detail.topicId != null && detail.itemId == null) {
      final topic = await DatabaseHelper.getTopic(detail.topicId!);
      return topic?.directDetails == true;
    }

    // Se é detalhe de item, verificar se o item existe
    if (detail.itemId != null) {
      final item = await DatabaseHelper.getItem(detail.itemId!);
      return item != null;
    }

    return true;
  }

  Future<int> getMaxOrderIndexForTopic(String topicId) async {
    final details = await findDirectDetailsByTopicId(topicId);
    if (details.isEmpty) return 0;
    return details.map((d) => d.orderIndex).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateCustomOption(String detailId, bool allowCustom, String? customValue) async {
    final detail = await findById(detailId);
    if (detail != null) {
      final updatedDetail = detail.copyWith(
        allowCustomOption: allowCustom,
        customOptionValue: customValue,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedDetail);
    }
  }

  // ===============================
  // MÉTODOS DE CLOUD SYNC
  // ===============================

  /// Inserir ou atualizar detalhe vindo da nuvem
  Future<void> insertOrUpdateFromCloud(Detail detail) async {
    final existing = await findById(detail.id!);
    final detailToSave = detail.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(detailToSave);
    } else {
      await insert(detailToSave);
    }
  }

  /// Inserir ou atualizar detalhe local
  Future<void> insertOrUpdate(Detail detail) async {
    final existing = await findById(detail.id!);
    final detailToSave = detail.copyWith(
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await update(detailToSave);
    } else {
      await insert(detailToSave);
    }
  }
}
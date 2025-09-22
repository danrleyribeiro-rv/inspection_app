import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class NonConformityRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(NonConformity nonConformity) async {
    await DatabaseHelper.insertNonConformity(nonConformity);
    return nonConformity.id;
  }

  Future<void> update(NonConformity nonConformity) async {
    await DatabaseHelper.updateNonConformity(nonConformity);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteNonConformity(id);
  }

  Future<NonConformity?> findById(String id) async {
    return await DatabaseHelper.getNonConformity(id);
  }

  NonConformity fromMap(Map<String, dynamic> map) {
    return NonConformity.fromMap(map);
  }

  Map<String, dynamic> toMap(NonConformity entity) {
    return entity.toMap();
  }

  // Métodos específicos do NonConformity
  Future<List<NonConformity>> findByInspectionId(String inspectionId) async {
    return await DatabaseHelper.getNonConformitiesByInspection(inspectionId);
  }

  Future<List<NonConformity>> findByTopicId(String topicId) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) => nc.topicId == topicId).toList();
  }

  Future<List<NonConformity>> findByItemId(String itemId) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) => nc.itemId == itemId).toList();
  }

  Future<List<NonConformity>> findByDetailId(String detailId) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) => nc.detailId == detailId).toList();
  }

  Future<List<NonConformity>> findBySeverity(String severity) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) => nc.severity == severity).toList();
  }

  Future<List<NonConformity>> findByStatus(String status) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) => nc.status == status).toList();
  }

  Future<List<NonConformity>> findByInspectionIdAndStatus(
      String inspectionId, String status) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) =>
        nc.inspectionId == inspectionId && nc.status == status).toList();
  }

  Future<List<NonConformity>> findByInspectionIdAndSeverity(
      String inspectionId, String severity) async {
    final allNonConformities = DatabaseHelper.nonConformities.values.toList();
    return allNonConformities.where((nc) =>
        nc.inspectionId == inspectionId && nc.severity == severity).toList();
  }

  Future<void> updateStatus(String nonConformityId, String status) async {
    final nonConformity = await findById(nonConformityId);
    if (nonConformity != null) {
      final updatedNonConformity = nonConformity.copyWith(
        status: status,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedNonConformity);
    }
  }

  Future<void> updateSeverity(String nonConformityId, String severity) async {
    final nonConformity = await findById(nonConformityId);
    if (nonConformity != null) {
      final updatedNonConformity = nonConformity.copyWith(
        severity: severity,
        updatedAt: DateFormatter.now(),
      );
      await update(updatedNonConformity);
    }
  }

  Future<void> deleteByInspectionId(String inspectionId) async {
    final nonConformities = await findByInspectionId(inspectionId);
    for (final nc in nonConformities) {
      await delete(nc.id);
    }
  }

  Future<void> deleteByTopicId(String topicId) async {
    final nonConformities = await findByTopicId(topicId);
    for (final nc in nonConformities) {
      await delete(nc.id);
    }
  }

  Future<void> deleteByItemId(String itemId) async {
    final nonConformities = await findByItemId(itemId);
    for (final nc in nonConformities) {
      await delete(nc.id);
    }
  }

  Future<void> deleteByDetailId(String detailId) async {
    final nonConformities = await findByDetailId(detailId);
    for (final nc in nonConformities) {
      await delete(nc.id);
    }
  }

  Future<int> countByInspectionId(String inspectionId) async {
    final nonConformities = await findByInspectionId(inspectionId);
    return nonConformities.length;
  }

  Future<int> countByInspectionIdAndStatus(
      String inspectionId, String status) async {
    final nonConformities = await findByInspectionIdAndStatus(inspectionId, status);
    return nonConformities.length;
  }

  Future<int> countByInspectionIdAndSeverity(
      String inspectionId, String severity) async {
    final nonConformities = await findByInspectionIdAndSeverity(inspectionId, severity);
    return nonConformities.length;
  }

  Future<Map<String, int>> getStatsByInspectionId(String inspectionId) async {
    final allNonConformities = await findByInspectionId(inspectionId);

    final total = allNonConformities.length;
    final open = allNonConformities.where((nc) => nc.status == 'open').length;
    final closed = allNonConformities.where((nc) => nc.status == 'closed').length;
    final low = allNonConformities.where((nc) => nc.severity == 'low').length;
    final medium = allNonConformities.where((nc) => nc.severity == 'medium').length;
    final high = allNonConformities.where((nc) => nc.severity == 'high').length;
    final critical = allNonConformities.where((nc) => nc.severity == 'critical').length;

    return {
      'total': total,
      'open': open,
      'closed': closed,
      'low': low,
      'medium': medium,
      'high': high,
      'critical': critical,
    };
  }

  Future<List<NonConformity>> findByInspectionIdGroupedBySeverity(
      String inspectionId) async {
    final nonConformities = await findByInspectionId(inspectionId);

    nonConformities.sort((a, b) {
      // Sort by severity: critical(1), high(2), medium(3), low(4)
      final severityOrder = {'critical': 1, 'high': 2, 'medium': 3, 'low': 4};
      final aOrder = severityOrder[a.severity] ?? 5;
      final bOrder = severityOrder[b.severity] ?? 5;

      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      // If same severity, sort by created date DESC
      return b.createdAt.compareTo(a.createdAt);
    });

    return nonConformities;
  }

  // ===============================
  // MÉTODOS DE SINCRONIZAÇÃO
  // ===============================

  /// Buscar não conformidades que precisam ser sincronizadas
  Future<List<NonConformity>> findPendingSync() async {
    final allNcs = DatabaseHelper.nonConformities.values.toList();
    return allNcs.where((nc) => nc.needsSync == true).toList();
  }

  // REMOVED: markSynced - Always sync all data on demand

  // REMOVED: markAllSynced - Always sync all data on demand
}
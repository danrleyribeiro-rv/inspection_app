// lib/services/data/non_conformity_service.dart - Refactored for Hive boxes
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class NonConformityService {
  final InspectionRepository _inspectionRepository = InspectionRepository();

  /// Get all non-conformities for an inspection from Hive box
  Future<List<NonConformity>> getNonConformitiesByInspection(
      String inspectionId) async {
    return await DatabaseHelper.getNonConformitiesByInspection(inspectionId);
  }

  /// Get non-conformities for a specific topic
  Future<List<NonConformity>> getNonConformitiesByTopic(
      String inspectionId, String topicId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);
    return allNCs.where((nc) => nc.topicId == topicId).toList();
  }

  /// Get non-conformities for a specific item
  Future<List<NonConformity>> getNonConformitiesByItem(
      String inspectionId, String topicId, String itemId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);
    return allNCs.where((nc) => nc.itemId == itemId).toList();
  }

  /// Get non-conformities for a specific detail
  Future<List<NonConformity>> getNonConformitiesByDetail(
      String inspectionId, String topicId, String itemId, String detailId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);
    return allNCs.where((nc) => nc.detailId == detailId).toList();
  }

  /// Save/create a new non-conformity
  Future<NonConformity> saveNonConformity({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    required String title,
    required String description,
    required String severity,
    String? correctiveAction,
    DateTime? deadline,
    String? status,
  }) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final newNC = NonConformity.create(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      title: title,
      description: description,
      severity: severity,
      status: status ?? 'open',
      correctiveAction: correctiveAction,
      deadline: deadline,
    );

    await DatabaseHelper.insertNonConformity(newNC);

    // Update inspection timestamp
    final updatedInspection = inspection.copyWith(
      updatedAt: DateFormatter.now(),
    );
    await _inspectionRepository.update(updatedInspection);

    return newNC;
  }

  /// Update an existing non-conformity
  Future<void> updateNonConformity(NonConformity updatedNC) async {
    await DatabaseHelper.updateNonConformity(updatedNC);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(updatedNC.inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Update non-conformity status
  Future<void> updateNonConformityStatus(
      String nonConformityId, String newStatus) async {
    final nc = await DatabaseHelper.getNonConformity(nonConformityId);
    if (nc == null) {
      throw Exception('Non-conformity not found: $nonConformityId');
    }

    final updatedNC = nc.copyWith(
      status: newStatus,
      updatedAt: DateFormatter.now(),
    );

    await updateNonConformity(updatedNC);
  }

  /// Resolve non-conformity
  Future<void> resolveNonConformity(String nonConformityId) async {
    final nc = await DatabaseHelper.getNonConformity(nonConformityId);
    if (nc == null) {
      throw Exception('Non-conformity not found: $nonConformityId');
    }

    final updatedNC = nc.copyWith(
      status: 'closed',
      isResolved: true,
      resolvedAt: DateFormatter.now(),
      updatedAt: DateFormatter.now(),
    );

    await updateNonConformity(updatedNC);
  }

  /// Delete non-conformity
  Future<void> deleteNonConformity(String inspectionId, String nonConformityId) async {
    await DatabaseHelper.deleteNonConformity(nonConformityId);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Get non-conformities count by severity
  Future<Map<String, int>> getNonConformitiesCountBySeverity(
      String inspectionId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);

    return {
      'low': allNCs.where((nc) => nc.severity == 'low').length,
      'medium': allNCs.where((nc) => nc.severity == 'medium').length,
      'high': allNCs.where((nc) => nc.severity == 'high').length,
      'critical': allNCs.where((nc) => nc.severity == 'critical').length,
    };
  }

  /// Get non-conformities count by status
  Future<Map<String, int>> getNonConformitiesCountByStatus(
      String inspectionId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);

    return {
      'open': allNCs.where((nc) => nc.status == 'open').length,
      'in_progress': allNCs.where((nc) => nc.status == 'in_progress').length,
      'closed': allNCs.where((nc) => nc.status == 'closed').length,
    };
  }

  /// Get open non-conformities
  Future<List<NonConformity>> getOpenNonConformities(String inspectionId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);
    return allNCs.where((nc) => nc.status == 'open').toList();
  }

  /// Get resolved non-conformities
  Future<List<NonConformity>> getResolvedNonConformities(String inspectionId) async {
    final allNCs = await getNonConformitiesByInspection(inspectionId);
    return allNCs.where((nc) => nc.isResolved).toList();
  }
}

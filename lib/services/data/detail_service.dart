// lib/services/data/detail_service.dart - Refactored for Hive boxes
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class DetailService {
  final InspectionRepository _inspectionRepository = InspectionRepository();

  /// Get all details for an item from Hive details box
  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    final details = DatabaseHelper.details.values
        .where((detail) => detail.itemId == itemId)
        .toList();
    // Sort by position
    details.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
    return details;
  }

  /// Get details directly under a topic (for direct_details mode)
  Future<List<Detail>> getTopicDetails(String inspectionId, String topicId) async {
    final details = DatabaseHelper.details.values
        .where((detail) => detail.topicId == topicId && detail.itemId == null)
        .toList();
    // Sort by position
    details.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
    return details;
  }

  /// Add a new detail directly to Hive details box
  Future<Detail> addDetail(
    String inspectionId,
    String topicId,
    String itemId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
    bool? isRequired,
  }) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    // Get existing details to determine position
    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition = existingDetails.length;

    final newDetail = Detail(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      position: newPosition,
      detailName: detailName,
      type: type ?? 'text',
      options: options,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? false,
      isRequired: isRequired ?? false,
      createdAt: DateFormatter.now(),
      updatedAt: DateFormatter.now(),
    );

    await DatabaseHelper.insertDetail(newDetail);

    // Update inspection timestamp
    final updatedInspection = inspection.copyWith(
      updatedAt: DateFormatter.now(),
    );
    await _inspectionRepository.update(updatedInspection);

    return newDetail;
  }

  /// Add a detail directly under a topic (for direct_details mode)
  Future<Detail> addTopicDetail(
    String inspectionId,
    String topicId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
    bool? isRequired,
  }) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    // Get existing topic details to determine position
    final existingDetails = await getTopicDetails(inspectionId, topicId);
    final newPosition = existingDetails.length;

    final newDetail = Detail(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: null, // No item - direct topic detail
      position: newPosition,
      detailName: detailName,
      type: type ?? 'text',
      options: options,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? false,
      isRequired: isRequired ?? false,
      createdAt: DateFormatter.now(),
      updatedAt: DateFormatter.now(),
    );

    await DatabaseHelper.insertDetail(newDetail);

    // Update inspection timestamp
    final updatedInspection = inspection.copyWith(
      updatedAt: DateFormatter.now(),
    );
    await _inspectionRepository.update(updatedInspection);

    return newDetail;
  }

  /// Update detail in Hive
  Future<void> updateDetail(Detail updatedDetail) async {
    await DatabaseHelper.updateDetail(updatedDetail);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(updatedDetail.inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Duplicate a detail
  Future<Detail> duplicateDetail(
    String inspectionId,
    String topicId,
    String itemId,
    Detail sourceDetail,
  ) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found');
    }

    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition = existingDetails.length;
    final now = DateFormatter.now();

    // Create duplicate detail
    final duplicateDetail = Detail(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      position: newPosition,
      detailName: '${sourceDetail.detailName} (cópia)',
      type: sourceDetail.type,
      options: sourceDetail.options,
      detailValue: sourceDetail.detailValue,
      observation: sourceDetail.observation,
      isDamaged: sourceDetail.isDamaged,
      tags: sourceDetail.tags,
      allowCustomOption: sourceDetail.allowCustomOption,
      customOptionValue: sourceDetail.customOptionValue,
      status: sourceDetail.status,
      isRequired: sourceDetail.isRequired,
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseHelper.insertDetail(duplicateDetail);

    // Update inspection timestamp
    final updated = inspection.copyWith(updatedAt: now);
    await _inspectionRepository.update(updated);

    return duplicateDetail;
  }

  /// Delete detail
  Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
    await DatabaseHelper.deleteDetail(detailId);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Reorder details by updating their position field
  Future<void> reorderDetails(String inspectionId, String topicId, String itemId, List<String> detailIds) async {
    for (int i = 0; i < detailIds.length; i++) {
      final detail = await DatabaseHelper.getDetail(detailIds[i]);
      if (detail != null) {
        final updated = detail.copyWith(position: i, updatedAt: DateFormatter.now());
        await DatabaseHelper.updateDetail(updated);
      }
    }

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }
}

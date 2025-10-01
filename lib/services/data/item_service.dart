// lib/services/data/item_service.dart - Refactored for Hive boxes
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class ItemService {
  final InspectionRepository _inspectionRepository = InspectionRepository();

  /// Get all items for a topic from Hive items box
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    try {
      final items = DatabaseHelper.items.values
          .where((item) => item.topicId == topicId)
          .toList();
      // Sort by position
      items.sort((a, b) => a.position.compareTo(b.position));
      return items;
    } catch (e) {
      debugPrint('ItemService.getItems: Error getting items: $e');
      return [];
    }
  }

  /// Calculate progress of an item based on its details
  Future<double> getItemProgress(
      String inspectionId, String topicId, String itemId) async {
    final details = DatabaseHelper.details.values
        .where((detail) => detail.itemId == itemId)
        .toList();

    if (details.isEmpty) return 0.0;

    int completedDetails = 0;
    for (final detail in details) {
      if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
        completedDetails++;
      }
    }

    return completedDetails / details.length;
  }

  /// Add a new item directly to Hive items box
  Future<Item> addItem(
    String inspectionId,
    String topicId,
    String itemName, {
    String? description,
    String? observation,
  }) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    // Get existing items to determine position
    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;

    final newItem = Item(
      inspectionId: inspectionId,
      topicId: topicId,
      position: newPosition,
      itemName: itemName,
      itemLabel: description,
      observation: observation,
      createdAt: DateFormatter.now(),
      updatedAt: DateFormatter.now(),
    );

    await DatabaseHelper.insertItem(newItem);

    // Update inspection timestamp
    final updatedInspection = inspection.copyWith(
      updatedAt: DateFormatter.now(),
    );
    await _inspectionRepository.update(updatedInspection);

    return newItem;
  }

  /// Update item in Hive
  Future<void> updateItem(Item updatedItem) async {
    await DatabaseHelper.updateItem(updatedItem);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(updatedItem.inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Duplicate an item with all its details
  Future<Item> duplicateItem(
    String inspectionId,
    String topicId,
    Item sourceItem,
  ) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found');
    }

    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;
    final now = DateFormatter.now();

    // Create duplicate item
    final duplicateItem = Item(
      inspectionId: inspectionId,
      topicId: topicId,
      position: newPosition,
      itemName: '${sourceItem.itemName} (cópia)',
      itemLabel: sourceItem.itemLabel,
      description: sourceItem.description,
      evaluable: sourceItem.evaluable,
      evaluationOptions: sourceItem.evaluationOptions,
      // Clear evaluation and observation for copy
      evaluationValue: null,
      evaluation: null,
      observation: null,
      isDamaged: false,
      tags: sourceItem.tags,
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseHelper.insertItem(duplicateItem);

    // Duplicate details
    final sourceDetails = DatabaseHelper.details.values
        .where((detail) => detail.itemId == sourceItem.id)
        .toList();
    sourceDetails.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

    for (final sourceDetail in sourceDetails) {
      final duplicateDetail = Detail(
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: duplicateItem.id,
        position: sourceDetail.position,
        detailName: sourceDetail.detailName,
        // Clear values for copy
        detailValue: null,
        observation: null,
        isDamaged: false,
        tags: sourceDetail.tags,
        type: sourceDetail.type,
        options: sourceDetail.options,
        allowCustomOption: sourceDetail.allowCustomOption,
        customOptionValue: null,
        status: sourceDetail.status,
        isRequired: sourceDetail.isRequired,
        createdAt: now,
        updatedAt: now,
      );

      await DatabaseHelper.insertDetail(duplicateDetail);
    }

    // Update inspection timestamp
    final updated = inspection.copyWith(updatedAt: now);
    await _inspectionRepository.update(updated);

    return duplicateItem;
  }

  /// Delete item and all related details
  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    // Delete all details
    final details = DatabaseHelper.details.values
        .where((detail) => detail.itemId == itemId)
        .toList();
    for (final detail in details) {
      await DatabaseHelper.deleteDetail(detail.id);
    }

    // Delete item
    await DatabaseHelper.deleteItem(itemId);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Reorder items by updating their position field
  Future<void> reorderItems(String inspectionId, String topicId, List<String> itemIds) async {
    for (int i = 0; i < itemIds.length; i++) {
      final item = await DatabaseHelper.getItem(itemIds[i]);
      if (item != null) {
        final updated = item.copyWith(position: i, updatedAt: DateFormatter.now());
        await DatabaseHelper.updateItem(updated);
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

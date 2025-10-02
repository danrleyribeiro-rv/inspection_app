// lib/services/data/topic_service.dart - Refactored for Hive boxes
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/services/features/template_service.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopicService {
  final InspectionRepository _inspectionRepository = InspectionRepository();
  final TemplateService _templateService = TemplateService();

  /// Get all topics for an inspection from Hive topics box
  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      final topics = await DatabaseHelper.getTopicsByInspection(inspectionId);
      // Sort by position
      topics.sort((a, b) => a.position.compareTo(b.position));
      return topics;
    } catch (e) {
      debugPrint('TopicService.getTopics: Error getting topics: $e');
      return [];
    }
  }

  /// Calculate progress of a topic based on its items/details
  Future<double> getTopicProgress(String inspectionId, String topicId) async {
    final items = DatabaseHelper.items.values
        .where((item) => item.topicId == topicId)
        .toList();

    if (items.isEmpty) {
      // Check if topic has direct details
      final details = DatabaseHelper.details.values
          .where((detail) => detail.topicId == topicId && detail.itemId == null)
          .toList();
      if (details.isEmpty) return 0.0;

      // Calculate progress based on filled details
      int filledDetails = details.where((d) => d.detailValue != null && d.detailValue!.isNotEmpty).length;
      return filledDetails / details.length;
    }

    // Calculate progress based on items
    double totalProgress = 0.0;
    for (final item in items) {
      final details = DatabaseHelper.details.values
          .where((detail) => detail.itemId == item.id)
          .toList();
      if (details.isNotEmpty) {
        int filledDetails = details.where((d) => d.detailValue != null && d.detailValue!.isNotEmpty).length;
        totalProgress += filledDetails / details.length;
      }
    }

    return items.isNotEmpty ? totalProgress / items.length : 0.0;
  }

  /// Add a new topic directly to Hive topics box
  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    // Get existing topics to determine position
    final existingTopics = await getTopics(inspectionId);
    final newPosition = position ?? existingTopics.length;

    final newTopic = Topic(
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateFormatter.now(),
      updatedAt: DateFormatter.now(),
    );

    await DatabaseHelper.insertTopic(newTopic);

    // Update inspection timestamp
    final updatedInspection = inspection.copyWith(
      updatedAt: DateFormatter.now(),
    );
    await _inspectionRepository.update(updatedInspection);

    return newTopic;
  }

  /// Add topic from template (online mode - fetch from Firestore)
  Future<Topic> addTopicFromTemplate(
    String inspectionId,
    Map<String, dynamic> templateData,
  ) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final existingTopics = await getTopics(inspectionId);
    final newPosition = existingTopics.length;
    String topicName = templateData['name'] as String;
    final isCustom = templateData['isCustom'] as bool? ?? false;

    // Check for duplicate names
    final existingNames = existingTopics.map((t) => t.topicName).toSet();
    String finalTopicName = topicName;

    if (existingNames.contains(topicName)) {
      finalTopicName = '$topicName (cópia)';
      int counter = 1;
      while (existingNames.contains(finalTopicName)) {
        finalTopicName = '$topicName (cópia $counter)';
        counter++;
      }
    }

    if (isCustom) {
      // Simple custom topic without template structure
      return await addTopic(
        inspectionId,
        finalTopicName,
        label: templateData['value'],
      );
    } else {
      // Build topic from full template
      final topicStructure = await _buildTopicFromTemplate(templateData);
      return await _createTopicWithStructure(
        inspectionId,
        finalTopicName,
        topicStructure,
        newPosition,
      );
    }
  }

  /// Add topic from template (offline mode - use cached template)
  Future<Topic> addTopicFromTemplateOffline(
      String inspectionId, Map<String, dynamic> topicTemplate) async {
    try {
      final inspection = await _inspectionRepository.findById(inspectionId);
      if (inspection == null) {
        throw Exception('Inspection not found in cache');
      }

      final existingTopics = await getTopics(inspectionId);
      final newPosition = existingTopics.length;

      final topicData = topicTemplate['topicData'] as Map<String, dynamic>;

      String topicName = topicData['name'] as String;

      // Check for duplicate names
      final existingNames = existingTopics.map((t) => t.topicName).toSet();
      String finalTopicName = topicName;

      if (existingNames.contains(topicName)) {
        finalTopicName = '$topicName (cópia)';
        int counter = 1;
        while (existingNames.contains(finalTopicName)) {
          finalTopicName = '$topicName (cópia $counter)';
          counter++;
        }
      }

      // Create topic with structure from offline template
      return await _createTopicWithStructure(
        inspectionId,
        finalTopicName,
        topicData,
        newPosition,
      );
    } catch (e) {
      debugPrint('TopicService.addTopicFromTemplateOffline: Error adding topic from template: $e');
      rethrow;
    }
  }

  /// Create topic with nested items and details structure
  Future<Topic> _createTopicWithStructure(
    String inspectionId,
    String topicName,
    Map<String, dynamic> topicData,
    int position,
  ) async {
    final now = DateFormatter.now();

    // Create the topic
    final newTopic = Topic(
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: topicData['description'],
      position: position,
      observation: topicData['observation'],
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseHelper.insertTopic(newTopic);

    // Process items from template
    final itemsData = topicData['items'] as List<dynamic>? ?? [];
    for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
      final itemData = itemsData[itemIndex] as Map<String, dynamic>;

      // Create item
      final newItem = Item(
        inspectionId: inspectionId,
        topicId: newTopic.id,
        position: itemIndex,
        itemName: itemData['name'] ?? 'Item sem nome',
        itemLabel: itemData['description'],
        observation: itemData['observation'],
        createdAt: now,
        updatedAt: now,
      );

      await DatabaseHelper.insertItem(newItem);

      // Process details from template
      final detailsData = itemData['details'] as List<dynamic>? ?? [];
      for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
        final detailData = detailsData[detailIndex] as Map<String, dynamic>;

        // Parse options if exists
        List<String>? options;
        if (detailData['options'] != null) {
          if (detailData['options'] is List) {
            options = List<String>.from(detailData['options']);
          } else if (detailData['options'] is String && (detailData['options'] as String).isNotEmpty) {
            options = (detailData['options'] as String).split(',').map((e) => e.trim()).toList();
          }
        }

        // Create detail
        final newDetail = Detail(
          inspectionId: inspectionId,
          topicId: newTopic.id,
          itemId: newItem.id,
          position: detailIndex,
          detailName: detailData['name'] ?? 'Detalhe sem nome',
          detailValue: detailData['value'],
          observation: detailData['observation'],
          type: detailData['type'],
          options: options,
          allowCustomOption: detailData['allow_custom_option'] == true || detailData['allow_custom_option'] == 1,
          customOptionValue: detailData['custom_option_value'],
          status: detailData['status'],
          createdAt: now,
          updatedAt: now,
        );

        await DatabaseHelper.insertDetail(newDetail);
      }
    }

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updatedInspection = inspection.copyWith(updatedAt: now);
      await _inspectionRepository.update(updatedInspection);
    }

    return newTopic;
  }

  /// Update topic in Hive
  Future<void> updateTopic(Topic updatedTopic) async {
    try {
      await DatabaseHelper.updateTopic(updatedTopic);

      // Update inspection timestamp
      final inspection = await _inspectionRepository.findById(updatedTopic.inspectionId);
      if (inspection != null) {
        final updated = inspection.copyWith(updatedAt: DateFormatter.now());
        await _inspectionRepository.update(updated);
      }

      debugPrint('TopicService.updateTopic: Topic ${updatedTopic.id} updated');
    } catch (e) {
      debugPrint('TopicService.updateTopic: Error updating topic ${updatedTopic.id}: $e');
      rethrow;
    }
  }

  /// Duplicate a topic with all its items and details
  Future<Topic> duplicateTopic(String inspectionId, Topic sourceTopic) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found');
    }

    final existingTopics = await getTopics(inspectionId);
    final newPosition = existingTopics.length;
    final now = DateFormatter.now();

    // Create duplicate topic
    final duplicateTopic = Topic(
      inspectionId: inspectionId,
      topicName: '${sourceTopic.topicName} (cópia)',
      topicLabel: sourceTopic.topicLabel,
      position: newPosition,
      observation: sourceTopic.observation,
      directDetails: sourceTopic.directDetails,
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseHelper.insertTopic(duplicateTopic);

    // Duplicate items
    final sourceItems = DatabaseHelper.items.values
        .where((item) => item.topicId == sourceTopic.id)
        .toList();
    sourceItems.sort((a, b) => a.position.compareTo(b.position));

    for (final sourceItem in sourceItems) {
      // Create duplicate item
      final duplicateItem = Item(
        inspectionId: inspectionId,
        topicId: duplicateTopic.id,
        position: sourceItem.position,
        itemName: sourceItem.itemName,
        itemLabel: sourceItem.itemLabel,
        description: sourceItem.description,
        evaluable: sourceItem.evaluable,
        evaluationOptions: sourceItem.evaluationOptions,
        // Clear evaluation and observation for copy
        evaluationValue: null,
        evaluation: null,
        observation: null,
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
          topicId: duplicateTopic.id,
          itemId: duplicateItem.id,
          position: sourceDetail.position,
          detailName: sourceDetail.detailName,
          // Clear values for copy
          detailValue: null,
          observation: null,
          type: sourceDetail.type,
          options: sourceDetail.options,
          allowCustomOption: sourceDetail.allowCustomOption,
          customOptionValue: null,
          status: sourceDetail.status,
          createdAt: now,
          updatedAt: now,
        );

        await DatabaseHelper.insertDetail(duplicateDetail);
      }
    }

    // Duplicate direct details (if topic has direct_details mode)
    final sourceDirectDetails = DatabaseHelper.details.values
        .where((detail) => detail.topicId == sourceTopic.id && detail.itemId == null)
        .toList();

    for (final sourceDetail in sourceDirectDetails) {
      final duplicateDetail = Detail(
        inspectionId: inspectionId,
        topicId: duplicateTopic.id,
        itemId: null,
        position: sourceDetail.position,
        detailName: sourceDetail.detailName,
        detailValue: null,
        observation: null,
        type: sourceDetail.type,
        options: sourceDetail.options,
        allowCustomOption: sourceDetail.allowCustomOption,
        customOptionValue: null,
        status: sourceDetail.status,
        createdAt: now,
        updatedAt: now,
      );

      await DatabaseHelper.insertDetail(duplicateDetail);
    }

    // Update inspection timestamp
    final updated = inspection.copyWith(updatedAt: now);
    await _inspectionRepository.update(updated);

    return duplicateTopic;
  }

  /// Delete topic and all related items/details
  Future<void> deleteTopic(String inspectionId, String topicId) async {
    // Delete all items and their details
    final items = DatabaseHelper.items.values
        .where((item) => item.topicId == topicId)
        .toList();

    for (final item in items) {
      // Delete details
      final details = DatabaseHelper.details.values
          .where((detail) => detail.itemId == item.id)
          .toList();
      for (final detail in details) {
        await DatabaseHelper.deleteDetail(detail.id);
      }
      await DatabaseHelper.deleteItem(item.id);
    }

    // Delete direct details
    final directDetails = DatabaseHelper.details.values
        .where((detail) => detail.topicId == topicId && detail.itemId == null)
        .toList();
    for (final detail in directDetails) {
      await DatabaseHelper.deleteDetail(detail.id);
    }

    // Delete topic
    await DatabaseHelper.deleteTopic(topicId);

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Reorder topics by updating their position field
  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    for (int i = 0; i < topicIds.length; i++) {
      final topic = await DatabaseHelper.getTopic(topicIds[i]);
      if (topic != null) {
        final updated = topic.copyWith(position: i, updatedAt: DateFormatter.now());
        await DatabaseHelper.updateTopic(updated);
      }
    }

    // Update inspection timestamp
    final inspection = await _inspectionRepository.findById(inspectionId);
    if (inspection != null) {
      final updated = inspection.copyWith(updatedAt: DateFormatter.now());
      await _inspectionRepository.update(updated);
    }
  }

  /// Build topic from Firestore template
  Future<Map<String, dynamic>> _buildTopicFromTemplate(
      Map<String, dynamic> templateData) async {
    try {
      final templateId = templateData['template_id'] as String;
      final topicName = templateData['name'] as String;
      final templateDoc = await FirebaseFirestore.instance
          .collection('templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        throw Exception('Template not found');
      }

      final fullTemplateData = templateDoc.data()!;
      final topicsData = _extractArrayFromTemplate(fullTemplateData, 'topics');

      for (final topicTemplate in topicsData) {
        final topicFields = _extractFieldsFromTemplate(topicTemplate);
        if (topicFields == null) continue;

        final templateTopicName = _extractStringValue(topicFields, 'name');
        if (templateTopicName == topicName) {
          return _processTopicTemplate(topicFields);
        }
      }

      throw Exception('Topic not found in template');
    } catch (e) {
      return {
        'name': templateData['name'],
        'description': templateData['description'],
        'observation': null,
        'items': <Map<String, dynamic>>[],
      };
    }
  }

  /// Process Firestore template topic structure
  Map<String, dynamic> _processTopicTemplate(Map<String, dynamic> topicFields) {
    final String topicName = _extractStringValue(topicFields, 'name');
    final String? topicDescription =
        _extractStringValue(topicFields, 'description').isNotEmpty
            ? _extractStringValue(topicFields, 'description')
            : null;
    final itemsData = _extractArrayFromTemplate(topicFields, 'items');
    List<Map<String, dynamic>> processedItems = [];

    for (final itemTemplate in itemsData) {
      final itemFields = _extractFieldsFromTemplate(itemTemplate);
      if (itemFields == null) continue;

      final String itemName = _extractStringValue(itemFields, 'name');
      final String? itemDescription =
          _extractStringValue(itemFields, 'description').isNotEmpty
              ? _extractStringValue(itemFields, 'description')
              : null;

      final detailsData = _extractArrayFromTemplate(itemFields, 'details');
      List<Map<String, dynamic>> processedDetails = [];

      for (final detailTemplate in detailsData) {
        final detailFields = _extractFieldsFromTemplate(detailTemplate);
        if (detailFields == null) continue;

        final String detailName = _extractStringValue(detailFields, 'name');
        final String detailType =
            _extractStringValue(detailFields, 'type', defaultValue: 'text');

        List<String>? options;
        if (detailType == 'select') {
          final optionsArray =
              _extractArrayFromTemplate(detailFields, 'options');
          options = <String>[];
          for (var option in optionsArray) {
            if (option is Map && option.containsKey('stringValue')) {
              options.add(option['stringValue']);
            } else if (option is String) {
              options.add(option);
            }
          }

          if (options.isEmpty && detailFields.containsKey('optionsText')) {
            final String optionsText =
                _extractStringValue(detailFields, 'optionsText');
            if (optionsText.isNotEmpty) {
              options = optionsText.split(',').map((e) => e.trim()).toList();
            }
          }
        }

        processedDetails.add({
          'name': detailName,
          'type': detailType,
          'options': options,
          'value': null,
          'observation': null,
          'is_damaged': false,
        });
      }

      processedItems.add({
        'name': itemName,
        'description': itemDescription,
        'observation': null,
        'details': processedDetails,
      });
    }

    return {
      'name': topicName,
      'description': topicDescription,
      'observation': null,
      'items': processedItems,
    };
  }


  // Template parsing helper methods
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];
    if (data[key] is List) return data[key];
    if (data[key] is Map &&
        data[key].containsKey('arrayValue') &&
        data[key]['arrayValue'] is Map &&
        data[key]['arrayValue'].containsKey('values')) {
      return data[key]['arrayValue']['values'] ?? [];
    }
    return [];
  }

  Map<String, dynamic>? _extractFieldsFromTemplate(dynamic data) {
    if (data == null) return null;
    if (data is Map && data.containsKey('fields')) {
      return Map<String, dynamic>.from(data['fields']);
    }
    if (data is Map &&
        data.containsKey('mapValue') &&
        data['mapValue'] is Map &&
        data['mapValue'].containsKey('fields')) {
      return Map<String, dynamic>.from(data['mapValue']['fields']);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  String _extractStringValue(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;
    if (data[key] is String) return data[key];
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }
    return defaultValue;
  }

  // Template methods - delegate to TemplateService
  Future<List<Map<String, dynamic>>> getAvailableTemplateTopics() async {
    try {
      return await _templateService.getAvailableTopicsFromTemplates();
    } catch (e) {
      debugPrint('TopicService.getAvailableTemplateTopics: Error getting template topics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopicsFromSpecificTemplate(
      String templateId) async {
    try {
      return await _templateService.getTopicsFromSpecificTemplate(templateId);
    } catch (e) {
      debugPrint('TopicService.getTopicsFromSpecificTemplate: Error getting topics from template $templateId: $e');
      return [];
    }
  }
}

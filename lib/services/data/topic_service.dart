import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/data/item_service.dart';
import 'package:inspection_app/services/storage/sqlite_storage_service.dart'; // Use SQLiteStorageService
import 'package:inspection_app/services/features/template_service.dart'; // Import TemplateService directly
import 'package:cloud_firestore/cloud_firestore.dart';


class TopicService {
  ItemService get _itemService => ItemService();
  final SQLiteStorageService _localStorage = SQLiteStorageService.instance; // Use SQLiteStorageService
  final TemplateService _templateService = TemplateService(); // Use TemplateService directly

  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
      if (inspection != null) {
        return _extractTopics(inspectionId, inspection.topics);
      }
      return [];
    } catch (e) {
      debugPrint('TopicService.getTopics: Error getting topics: $e');
      return [];
    }
  }

  // ADICIONADO: Novo método para calcular o progresso de um tópico.
  Future<double> getTopicProgress(String inspectionId, String topicId) async {
    final items = await _itemService.getItems(inspectionId, topicId);

    if (items.isEmpty) {
      return 0.0;
    }

    double totalProgress = 0.0;
    for (final item in items) {
      totalProgress +=
          await _itemService.getItemProgress(inspectionId, topicId, item.id!);
    }

    return totalProgress / items.length;
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final existingTopics = inspection.topics ?? [];
    final newPosition = position ?? existingTopics.length;
    final newTopicData = {
      'name': topicName,
      'description': label,
      'observation': observation,
      'items': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updatedTopics = List<Map<String, dynamic>>.from(existingTopics);
    updatedTopics.add(newTopicData);

    final updatedInspection = inspection.copyWith(
      topics: updatedTopics,
      updatedAt: DateTime.now(),
    );
    await _localStorage.saveInspection(updatedInspection); // Save to SQLite

    return Topic(
      id: 'topic_$newPosition',
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

Future<Topic> addTopicFromTemplate(
  String inspectionId,
  Map<String, dynamic> templateData,
) async {
  final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
  if (inspection == null) {
    throw Exception('Inspection not found: $inspectionId');
  }

  final existingTopics = inspection.topics ?? [];
  final newPosition = existingTopics.length;
  String topicName = templateData['name'] as String;
  final isCustom = templateData['isCustom'] as bool? ?? false;

  // Verificar se já existe um tópico com o mesmo nome
  final existingNames = existingTopics.map((t) => t['name'] as String? ?? '').toSet();
  String finalTopicName = topicName;
  
  if (existingNames.contains(topicName)) {
    finalTopicName = '$topicName (cópia)';
    int counter = 1;
    while (existingNames.contains(finalTopicName)) {
      finalTopicName = '$topicName (cópia $counter)';
      counter++;
    }
  }

  Map<String, dynamic> newTopicData;

  if (isCustom) {
    newTopicData = {
      'name': finalTopicName,
      'description': templateData['value'],
      'observation': null,
      'items': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  } else {
    // Usar dados completos do template
    if (templateData.containsKey('templateData')) {
      final extractedFields = _extractFieldsFromTemplate(templateData['templateData']) ?? <String, dynamic>{};
      newTopicData = _processTopicTemplate(extractedFields);
      newTopicData['name'] = finalTopicName;
    } else {
      newTopicData = await _buildTopicFromTemplate(templateData);
      newTopicData['name'] = finalTopicName;
    }
  }

  final updatedTopics = List<Map<String, dynamic>>.from(existingTopics);
  updatedTopics.add(newTopicData);

  final updatedInspection = inspection.copyWith(
    topics: updatedTopics,
    updatedAt: DateTime.now(),
  );
  await _localStorage.saveInspection(updatedInspection); // Save to SQLite

  return Topic(
    id: 'topic_$newPosition',
    inspectionId: inspectionId,
    topicName: finalTopicName,
    topicLabel: newTopicData['description'],
    position: newPosition,
    observation: newTopicData['observation'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

  Future<void> updateTopic(Topic updatedTopic) async {
    try {
      final inspection = await _localStorage.getInspection(updatedTopic.inspectionId); // Get from SQLite
      if (inspection?.topics != null) {
        final topicIndex = int.tryParse(updatedTopic.id?.replaceFirst('topic_', '') ?? '');
        if (topicIndex != null && topicIndex < inspection!.topics!.length) {
          final currentTopicData = Map<String, dynamic>.from(inspection.topics![topicIndex]);
          currentTopicData['name'] = updatedTopic.topicName;
          currentTopicData['description'] = updatedTopic.topicLabel;
          currentTopicData['observation'] = updatedTopic.observation;
          currentTopicData['updated_at'] = DateTime.now().toIso8601String();
          
          final updatedTopics = List<Map<String, dynamic>>.from(inspection.topics!);
          updatedTopics[topicIndex] = currentTopicData;
          
          final updatedInspection = inspection.copyWith(
            topics: updatedTopics,
            updatedAt: DateTime.now(),
          );
          
          await _localStorage.saveInspection(updatedInspection); // Save to SQLite
          
          debugPrint('TopicService.updateTopic: Topic ${updatedTopic.id} updated offline');
        }
      }
    } catch (e) {
      debugPrint('TopicService.updateTopic: Error updating topic ${updatedTopic.id}: $e');
      rethrow;
    }
  }

  Future<Topic> duplicateTopic(
      String inspectionId, Topic sourceTopic) async {
    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection == null) {
      throw Exception('Inspection not found');
    }
    final sourceTopicIndex =
        int.tryParse(sourceTopic.id?.replaceFirst('topic_', '') ?? '');
    if (sourceTopicIndex == null ||
        sourceTopicIndex >= inspection.topics!.length) {
      throw Exception('Source topic not found');
    }

    final sourceTopicData =
        Map<String, dynamic>.from(inspection.topics![sourceTopicIndex]);

    final duplicateTopicData = Map<String, dynamic>.from(sourceTopicData);
    duplicateTopicData['name'] = '${sourceTopic.topicName} (cópia)';

    if (duplicateTopicData['items'] is List) {
      final items =
          List<Map<String, dynamic>>.from(duplicateTopicData['items']);
      for (int i = 0; i < items.length; i++) {
        items[i] = Map<String, dynamic>.from(items[i]);

        if (items[i]['details'] is List) {
          final details =
              List<Map<String, dynamic>>.from(items[i]['details']);
          for (int j = 0; j < details.length; j++) {
            details[j] = Map<String, dynamic>.from(details[j]);
            details[j]['media'] = <Map<String, dynamic>>[];
            details[j]['non_conformities'] = <Map<String, dynamic>>[];
            details[j]['value'] = null;
            details[j]['observation'] = null;
            details[j]['is_damaged'] = false;
          }
          items[i]['details'] = details;
        }
      }
      duplicateTopicData['items'] = items;
    }
    duplicateTopicData['created_at'] = DateTime.now().toIso8601String();
    duplicateTopicData['updated_at'] = DateTime.now().toIso8601String();

    final updatedTopics = List<Map<String, dynamic>>.from(inspection.topics!);
    updatedTopics.add(duplicateTopicData);

    final updatedInspection = inspection.copyWith(
      topics: updatedTopics,
      updatedAt: DateTime.now(),
    );
    await _localStorage.saveInspection(updatedInspection); // Save to SQLite

    return Topic(
      id: 'topic_${inspection.topics!.length}',
      inspectionId: inspectionId,
      topicName: '${sourceTopic.topicName} (cópia)',
      topicLabel: sourceTopic.topicLabel,
      position: inspection.topics!.length,
      observation: sourceTopic.observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex != null) {
      await _deleteTopicAtIndex(inspectionId, topicIndex);
    }
  }

  Future<void> reorderTopics(
      String inspectionId, List<String> topicIds) async {
    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final reorderedTopics = <Map<String, dynamic>>[];
      for (final topicId in topicIds) {
        final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
        if (topicIndex != null && topicIndex < topics.length) {
          reorderedTopics.add(topics[topicIndex]);
        }
      }

      final updatedInspection = inspection.copyWith(
        topics: reorderedTopics,
        updatedAt: DateTime.now(),
      );
      await _localStorage.saveInspection(updatedInspection); // Save to SQLite
    }
  }

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

  Map<String, dynamic> _processTopicTemplate(
      Map<String, dynamic> topicFields) {
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
        final bool isRequired =
            _extractBooleanValue(detailFields, 'required', defaultValue: false);

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
          'required': isRequired,
          'options': options,
          'value': null,
          'observation': null,
          'is_damaged': false,
          'media': <Map<String, dynamic>>[],
          'non_conformities': <Map<String, dynamic>>[],
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

  List<Topic> _extractTopics(String inspectionId, List<dynamic>? topicsData) {
    if (topicsData == null) return [];
    List<Topic> topics = [];
    for (int i = 0; i < topicsData.length; i++) {
      final topicData = topicsData[i];
      if (topicData is Map<String, dynamic>) {
        topics.add(Topic(
          id: 'topic_$i',
          inspectionId: inspectionId,
          topicName: topicData['name'] ?? 'Tópico ${i + 1}',
          topicLabel: topicData['description'],
          position: i,
          observation: topicData['observation'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return topics;
  }

  // Method removed - not used anywhere


  Future<void> _deleteTopicAtIndex(String inspectionId, int topicIndex) async {
    final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics.removeAt(topicIndex);
        final updatedInspection = inspection.copyWith(
          topics: topics,
          updatedAt: DateTime.now(),
        );
        await _localStorage.saveInspection(updatedInspection); // Save to SQLite
      }
    }
  }

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

  bool _extractBooleanValue(dynamic data, String key,
      {bool defaultValue = false}) {
    if (data == null) return defaultValue;
    if (data[key] is bool) return data[key];
    if (data[key] is Map && data[key].containsKey('booleanValue')) {
      return data[key]['booleanValue'];
    }
    return defaultValue;
  }

  // OFFLINE TEMPLATE SUPPORT METHODS
  Future<List<Map<String, dynamic>>> getAvailableTemplateTopics() async {
    try {
      return await _templateService.getAvailableTopicsFromTemplates();
    } catch (e) {
      debugPrint('TopicService.getAvailableTemplateTopics: Error getting template topics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopicsFromSpecificTemplate(String templateId) async {
    try {
      return await _templateService.getTopicsFromSpecificTemplate(templateId);
    } catch (e) {
      debugPrint('TopicService.getTopicsFromSpecificTemplate: Error getting topics from template $templateId: $e');
      return [];
    }
  }

  Future<Topic> addTopicFromTemplateOffline(String inspectionId, Map<String, dynamic> topicTemplate) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId); // Get from SQLite
      if (inspection == null) {
        throw Exception('Inspection not found in cache');
      }

      final existingTopics = inspection.topics ?? [];
      final newPosition = existingTopics.length;
      
      final topicData = topicTemplate['topicData'] as Map<String, dynamic>;
      final templateId = topicTemplate['templateId'] as String;
      final templateName = topicTemplate['templateName'] as String;
      
      String topicName = topicData['name'] as String;
      
      // Check for duplicate names and modify if necessary
      final existingNames = existingTopics.map((t) => t['name'] as String? ?? '').toSet();
      String finalTopicName = topicName;
      
      if (existingNames.contains(topicName)) {
        finalTopicName = '$topicName (cópia)';
        int counter = 1;
        while (existingNames.contains(finalTopicName)) {
          finalTopicName = '$topicName (cópia $counter)';
          counter++;
        }
      }

      // Process the template topic data into inspection format
      final newTopicData = {
        'name': finalTopicName,
        'description': topicData['description'],
        'observation': null,
        'items': _processTemplateItems(topicData['items'] as List<dynamic>? ?? []),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'template_id': templateId,
        'template_name': templateName,
      };

      // Add topic to inspection
      final updatedTopics = List<Map<String, dynamic>>.from(existingTopics);
      updatedTopics.add(newTopicData);
      
      final updatedInspection = inspection.copyWith(
        topics: updatedTopics,
        updatedAt: DateTime.now(),
      );

      await _localStorage.saveInspection(updatedInspection); // Save to SQLite
      
      debugPrint('TopicService.addTopicFromTemplateOffline: Added topic "$finalTopicName" from template offline');

      return Topic(
        id: 'topic_$newPosition',
        inspectionId: inspectionId,
        topicName: finalTopicName,
        topicLabel: newTopicData['description'],
        position: newPosition,
        observation: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('TopicService.addTopicFromTemplateOffline: Error adding topic from template: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _processTemplateItems(List<dynamic> itemsData) {
    final processedItems = <Map<String, dynamic>>[];

    for (final itemTemplate in itemsData) {
      final itemFields = _extractFieldsFromTemplate(itemTemplate);
      if (itemFields == null) continue;

      final String itemName = _extractStringValue(itemFields, 'name', defaultValue: 'Item sem nome');
      final String? itemDescription = _extractStringValue(itemFields, 'description').isNotEmpty
          ? _extractStringValue(itemFields, 'description')
          : null;

      final detailsData = _extractArrayFromTemplate(itemFields, 'details');
      final processedDetails = <Map<String, dynamic>>[];

      for (final detailTemplate in detailsData) {
        final detailFields = _extractFieldsFromTemplate(detailTemplate);
        if (detailFields == null) continue;

        final String detailName = _extractStringValue(detailFields, 'name', defaultValue: 'Detalhe sem nome');
        final String detailType = _extractStringValue(detailFields, 'type', defaultValue: 'text');
        final bool isRequired = _extractBooleanValue(detailFields, 'required', defaultValue: false);

        List<String>? options;
        if (detailType == 'select') {
          final optionsArray = _extractArrayFromTemplate(detailFields, 'options');
          options = <String>[];
          for (var option in optionsArray) {
            if (option is Map && option.containsKey('stringValue')) {
              options.add(option['stringValue']);
            } else if (option is String) {
              options.add(option);
            }
          }

          if (options.isEmpty && detailFields.containsKey('optionsText')) {
            final String optionsText = _extractStringValue(detailFields, 'optionsText');
            if (optionsText.isNotEmpty) {
              options = optionsText.split(',').map((e) => e.trim()).toList();
            }
          }
        }

        processedDetails.add({
          'name': detailName,
          'type': detailType,
          'required': isRequired,
          'options': options,
          'value': null,
          'observation': null,
          'is_damaged': false,
          'media': <Map<String, dynamic>>[],
          'non_conformities': <Map<String, dynamic>>[],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      processedItems.add({
        'name': itemName,
        'description': itemDescription,
        'observation': null,
        'details': processedDetails,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return processedItems;
  }
}
// lib/services/inspection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class InspectionService {
  static final _instance = InspectionService._internal();
  factory InspectionService() => _instance;
  InspectionService._internal();

  final _firebase = FirebaseService();

  // INSPECTION OPERATIONS
  Future<Inspection?> getInspection(String inspectionId) async {
    final docSnapshot = await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .get();

    if (!docSnapshot.exists) return null;

    return Inspection.fromMap({
      'id': docSnapshot.id,
      ...docSnapshot.data() ?? {},
    });
  }

  Future<void> saveInspection(Inspection inspection) async {
    final data = inspection.toMap();
    data.remove('id');
    await _firebase.firestore
        .collection('inspections')
        .doc(inspection.id)
        .set(data, SetOptions(merge: true));
  }

  // TOPIC OPERATIONS
  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await getInspection(inspectionId);
    return _extractTopics(inspectionId, inspection?.topics);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final inspection = await getInspection(inspectionId);
    final existingTopics = inspection?.topics ?? [];
    final newPosition = position ?? existingTopics.length;

    final newTopicData = {
      'name': topicName,
      'description': label,
      'observation': observation,
      'items': <Map<String, dynamic>>[],
    };

    await _addTopicToInspection(inspectionId, newTopicData);

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

  Future<void> updateTopic(Topic updatedTopic) async {
    final inspection = await getInspection(updatedTopic.inspectionId);
    if (inspection?.topics != null) {
      final topicIndex = int.tryParse(updatedTopic.id?.replaceFirst('topic_', '') ?? '');
      if (topicIndex != null && topicIndex < inspection!.topics!.length) {
        final currentTopicData = Map<String, dynamic>.from(inspection.topics![topicIndex]);
        currentTopicData['name'] = updatedTopic.topicName;
        currentTopicData['description'] = updatedTopic.topicLabel;
        currentTopicData['observation'] = updatedTopic.observation;

        await _updateTopicAtIndex(updatedTopic.inspectionId, topicIndex, currentTopicData);
      }
    }
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex != null) {
      await _deleteTopicAtIndex(inspectionId, topicIndex);
    }
  }

  // ITEM OPERATIONS
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final inspection = await getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));

    if (inspection?.topics != null &&
        topicIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topicData = inspection.topics![topicIndex];
      return _extractItems(inspectionId, topicId, topicData);
    }

    return [];
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');

    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;

    final newItemData = {
      'name': itemName,
      'description': label,
      'observation': observation,
      'details': <Map<String, dynamic>>[],
    };

    await _addItemToTopic(inspectionId, topicIndex, newItemData);

    return Item(
      id: 'item_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemName: itemName,
      itemLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // DETAIL OPERATIONS
  Future<List<Detail>> getDetails(String inspectionId, String topicId, String itemId) async {
    final inspection = await getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (inspection?.topics != null &&
        topicIndex != null &&
        itemIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final itemData = items[itemIndex];
        return _extractDetails(inspectionId, topicId, itemId, itemData);
      }
    }

    return [];
  }

  // NON-CONFORMITY OPERATIONS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    final inspection = await getInspection(inspectionId);
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> nonConformities = [];

    for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];
          final ncList = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          for (int ncIndex = 0; ncIndex < ncList.length; ncIndex++) {
            final nc = ncList[ncIndex];
            nonConformities.add({
              ...nc,
              'id': 'nc_$ncIndex',
              'inspection_id': inspectionId,
              'topic_id': 'topic_$topicIndex',
              'item_id': 'item_$itemIndex',
              'detail_id': 'detail_$detailIndex',
              'topics': {'topic_name': topic['name'], 'id': 'topic_$topicIndex'},
              'topic_items': {'item_name': item['name'], 'id': 'item_$itemIndex'},
              'item_details': {'detail_name': detail['name'], 'id': 'detail_$detailIndex'},
            });
          }
        }
      }
    }

    return nonConformities;
  }

  // TEMPLATE OPERATIONS
  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    final templateDoc = await _firebase.firestore.collection('templates').doc(templateId).get();

    if (!templateDoc.exists) return false;

    final templateData = templateDoc.data();
    if (templateData == null) return false;

    final topicsData = _extractArrayFromTemplate(templateData, 'topics');
    List<Map<String, dynamic>> processedTopics = [];

    for (int i = 0; i < topicsData.length; i++) {
      final topicTemplate = topicsData[i];
      final topicFields = _extractFieldsFromTemplate(topicTemplate);

      if (topicFields == null) continue;

      final String topicName = _extractStringValueFromTemplate(topicFields, 'name', defaultValue: 'Tópico sem nome');
      final String? topicDescription = _extractStringValueFromTemplate(topicFields, 'description');

      final itemsData = _extractArrayFromTemplate(topicFields, 'items');
      List<Map<String, dynamic>> processedItems = [];

      for (int j = 0; j < itemsData.length; j++) {
        final itemTemplate = itemsData[j];
        final itemFields = _extractFieldsFromTemplate(itemTemplate);

        if (itemFields == null) continue;

        final String itemName = _extractStringValueFromTemplate(itemFields, 'name', defaultValue: 'Item sem nome');
        final String? itemDescription = _extractStringValueFromTemplate(itemFields, 'description');

        final detailsData = _extractArrayFromTemplate(itemFields, 'details');
        List<Map<String, dynamic>> processedDetails = [];

        for (int k = 0; k < detailsData.length; k++) {
          final detailTemplate = detailsData[k];
          final detailFields = _extractFieldsFromTemplate(detailTemplate);

          if (detailFields == null) continue;

          final String detailName = _extractStringValueFromTemplate(detailFields, 'name', defaultValue: 'Detalhe sem nome');
          final String detailType = _extractStringValueFromTemplate(detailFields, 'type', defaultValue: 'text');
          final bool isRequired = _extractBooleanValueFromTemplate(detailFields, 'required', defaultValue: false);

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
              final String optionsText = _extractStringValueFromTemplate(detailFields, 'optionsText', defaultValue: '');
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

      processedTopics.add({
        'name': topicName,
        'description': topicDescription,
        'observation': null,
        'items': processedItems,
      });
    }

    await _firebase.firestore.collection('inspections').doc(inspectionId).update({
      'topics': processedTopics,
      'is_templated': true,
      'updated_at': FieldValue.serverTimestamp(),
    });

    return true;
  }

  // PRIVATE HELPER METHODS
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

  List<Item> _extractItems(String inspectionId, String topicId, Map<String, dynamic> topicData) {
    final itemsData = topicData['items'] as List<dynamic>? ?? [];
    List<Item> items = [];

    for (int i = 0; i < itemsData.length; i++) {
      final itemData = itemsData[i];
      if (itemData is Map<String, dynamic>) {
        items.add(Item(
          id: 'item_$i',
          inspectionId: inspectionId,
          topicId: topicId,
          itemName: itemData['name'] ?? 'Item ${i + 1}',
          itemLabel: itemData['description'],
          position: i,
          observation: itemData['observation'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return items;
  }

  List<Detail> _extractDetails(String inspectionId, String topicId, String itemId, Map<String, dynamic> itemData) {
    final detailsData = itemData['details'] as List<dynamic>? ?? [];
    List<Detail> details = [];

    for (int i = 0; i < detailsData.length; i++) {
      final detailData = detailsData[i];
      if (detailData is Map<String, dynamic>) {
        List<String>? options;
        if (detailData['options'] is List) {
          options = List<String>.from(detailData['options']);
        }

        details.add(Detail(
          id: 'detail_$i',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: detailData['name'] ?? 'Detalhe ${i + 1}',
          type: detailData['type'] ?? 'text',
          options: options,
          detailValue: detailData['value'],
          observation: detailData['observation'],
          isDamaged: detailData['is_damaged'] ?? false,
          position: i,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return details;
  }

  Future<void> _addTopicToInspection(String inspectionId, Map<String, dynamic> newTopic) async {
    final inspection = await getInspection(inspectionId);
    final topics = inspection?.topics != null
        ? List<Map<String, dynamic>>.from(inspection!.topics!)
        : <Map<String, dynamic>>[];

    topics.add(newTopic);

    await _firebase.firestore.collection('inspections').doc(inspectionId).update({
      'topics': topics,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateTopicAtIndex(String inspectionId, int topicIndex, Map<String, dynamic> updatedTopic) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics[topicIndex] = updatedTopic;
        await _firebase.firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _deleteTopicAtIndex(String inspectionId, int topicIndex) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics.removeAt(topicIndex);
        await _firebase.firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _addItemToTopic(String inspectionId, int topicIndex, Map<String, dynamic> newItem) async {
    final inspection = await getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        items.add(newItem);
        topic['items'] = items;
        topics[topicIndex] = topic;

        await _firebase.firestore.collection('inspections').doc(inspectionId).update({
          'topics': topics,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  // Template helper methods
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];

    if (data[key] is List) {
      return data[key];
    }

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

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  String _extractStringValueFromTemplate(dynamic data, String key, {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    if (data[key] is String) {
      return data[key];
    }

    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }

    return defaultValue;
  }

  bool _extractBooleanValueFromTemplate(dynamic data, String key, {bool defaultValue = false}) {
    if (data == null) return defaultValue;

    if (data[key] is bool) {
      return data[key];
    }

    if (data[key] is Map && data[key].containsKey('booleanValue')) {
      return data[key]['booleanValue'];
    }

    return defaultValue;
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/core/firebase_service.dart';

class TemplateService {
  final FirebaseService _firebase = FirebaseService();

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspectionDoc = await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .get();

    if (inspectionDoc.exists) {
      final data = inspectionDoc.data() as Map<String, dynamic>;
      return data['is_templated'] == true;
    }
    return false;
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    if (await isTemplateAlreadyApplied(inspectionId)) {
      debugPrint('Template already applied to inspection $inspectionId');
      return true;
    }

    return await applyTemplateToInspection(inspectionId, templateId);
  }

  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    try {
      final templateDoc = await _firebase.firestore
          .collection('templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        debugPrint('Template $templateId not found');
        return false;
      }

      final templateData = templateDoc.data();
      if (templateData == null) {
        debugPrint('Template data is null');
        return false;
      }

      final topicsData = _extractArrayFromTemplate(templateData, 'topics');
      List<Map<String, dynamic>> processedTopics = [];

      for (int i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];
        final topicFields = _extractFieldsFromTemplate(topicTemplate);

        if (topicFields == null) continue;

        final String topicName = _extractStringValue(topicFields, 'name',
            defaultValue: 'Tópico sem nome');
        final String topicDescriptionValue = _extractStringValue(topicFields, 'description');
        final String? topicDescription = topicDescriptionValue.isNotEmpty ? topicDescriptionValue : null;

        final itemsData = _extractArrayFromTemplate(topicFields, 'items');
        List<Map<String, dynamic>> processedItems = [];

        for (int j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          final String itemName = _extractStringValue(itemFields, 'name',
              defaultValue: 'Item sem nome');
          final String itemDescriptionValue = _extractStringValue(itemFields, 'description');
          final String? itemDescription = itemDescriptionValue.isNotEmpty ? itemDescriptionValue : null;

          final detailsData = _extractArrayFromTemplate(itemFields, 'details');
          List<Map<String, dynamic>> processedDetails = [];

          for (int k = 0; k < detailsData.length; k++) {
            final detailTemplate = detailsData[k];
            final detailFields = _extractFieldsFromTemplate(detailTemplate);

            if (detailFields == null) continue;

            final String detailName = _extractStringValue(detailFields, 'name',
                defaultValue: 'Detalhe sem nome');
            final String detailType =
                _extractStringValue(detailFields, 'type', defaultValue: 'text');
            final bool isRequired = _extractBooleanValue(
                detailFields, 'required',
                defaultValue: false);

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
                final String optionsText = _extractStringValue(
                    detailFields, 'optionsText',
                    defaultValue: '');
                if (optionsText.isNotEmpty) {
                  options =
                      optionsText.split(',').map((e) => e.trim()).toList();
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

      await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .update({
        'topics': processedTopics,
        'is_templated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error applying template: $e');
      return false;
    }
  }

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

  String _extractStringValue(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    if (data[key] is String) {
      return data[key];
    }

    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }

    return defaultValue;
  }

  bool _extractBooleanValue(dynamic data, String key,
      {bool defaultValue = false}) {
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

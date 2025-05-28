import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspectionDoc = await firestore.collection('inspections').doc(inspectionId).get();
    if (inspectionDoc.exists) {
      final data = inspectionDoc.data() as Map<String, dynamic>;
      return data['is_templated'] == true;
    }
    return false;
  }

  Future<bool> applyTemplateToInspectionSafe(String inspectionId, String templateId) async {
    // First check if template is already applied
    if (await isTemplateAlreadyApplied(inspectionId)) {
      print('Template already applied to inspection $inspectionId');
      return true; // Consider as success since template is already applied
    }

    // Apply template normally
    return await applyTemplateToInspection(inspectionId, templateId);
  }

  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    try {
      // Get the template document
      final templateDoc = await firestore.collection('templates').doc(templateId).get();

      if (!templateDoc.exists) {
        print('Template $templateId not found');
        return false;
      }

      final templateData = templateDoc.data();
      if (templateData == null) {
        print('Template data is null');
        return false;
      }

      // Extract topics from template
      final topicsData = _extractArrayFromTemplate(templateData, 'topics');
      List<Map<String, dynamic>> processedTopics = [];

      // Process each topic from the template
      for (int i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];
        final topicFields = _extractFieldsFromTemplate(topicTemplate);

        if (topicFields == null) continue;

        final String topicName = _extractStringValueFromTemplate(topicFields, 'name', defaultValue: 'Tópico sem nome');
        final String? topicDescription = _extractStringValueFromTemplate(topicFields, 'description');

        // Process items for this topic
        final itemsData = _extractArrayFromTemplate(topicFields, 'items');
        List<Map<String, dynamic>> processedItems = [];

        for (int j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          final String itemName = _extractStringValueFromTemplate(itemFields, 'name', defaultValue: 'Item sem nome');
          final String? itemDescription = _extractStringValueFromTemplate(itemFields, 'description');

          // Process details for this item
          final detailsData = _extractArrayFromTemplate(itemFields, 'details');
          List<Map<String, dynamic>> processedDetails = [];

          for (int k = 0; k < detailsData.length; k++) {
            final detailTemplate = detailsData[k];
            final detailFields = _extractFieldsFromTemplate(detailTemplate);

            if (detailFields == null) continue;

            final String detailName = _extractStringValueFromTemplate(detailFields, 'name', defaultValue: 'Detalhe sem nome');
            final String detailType = _extractStringValueFromTemplate(detailFields, 'type', defaultValue: 'text');
            final bool isRequired = _extractBooleanValueFromTemplate(detailFields, 'required', defaultValue: false);

            // Extract options for select type
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

              // Check for optionsText as alternative
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

      // Update the inspection with the processed template structure
      await firestore.collection('inspections').doc(inspectionId).update({
        'topics': processedTopics,
        'is_templated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error applying template: $e');
      return false;
    }
  }

  // Helper methods for template handling
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
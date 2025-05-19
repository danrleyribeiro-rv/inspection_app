import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (inspectionDoc.exists) {
      final data = inspectionDoc.data() as Map<String, dynamic>;
      return data['is_templated'] == true;
    }
    return false;
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    // First check if template is already applied
    if (await isTemplateAlreadyApplied(inspectionId)) {
      print('Template already applied to inspection $inspectionId');
      return true; // Consider as success since template is already applied
    }

    // Apply template normally
    return await applyTemplateToInspection(inspectionId, templateId);
  }

  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    try {
      // Get the template document
      final templateDoc =
          await firestore.collection('templates').doc(templateId).get();

      if (!templateDoc.exists) {
        print('Template $templateId not found');
        return false;
      }

      final templateData = templateDoc.data();
      final topicsData = _extractArrayFromTemplate(templateData, 'topics');

      // Process topics
      for (var i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];
        final topicFields = _extractFieldsFromTemplate(topicTemplate);

        if (topicFields == null) continue;

        String topicName = _extractStringValueFromTemplate(topicFields, 'name',
            defaultValue: 'Tópico sem nome');

        // Update inspection to mark as templated
        await firestore.collection('inspections').doc(inspectionId).update({
          'is_templated': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        return true;
      }
      return false;
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

  String _extractStringValueFromTemplate(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    if (data[key] is String) {
      return data[key];
    }

    if (data[key] is Map &&
        data[key].containsKey('stringValue') &&
        data[key]['stringValue'] is String) {
      return data[key]['stringValue'];
    }

    return defaultValue;
  }
}

import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/storage/sqlite_storage_service.dart'; // Use SQLiteStorageService

class TemplateService {
  final FirebaseService _firebaseService = FirebaseService();
  final SQLiteStorageService _localStorage =
      SQLiteStorageService.instance; // Use SQLiteStorageService

  // Existing methods...

  Future<List<Map<String, dynamic>>> getAvailableTemplates() async {
    try {
      // First, try to get from local storage
      final localTemplates = await _localStorage.getTemplates();
      if (localTemplates.isNotEmpty) {
        return localTemplates;
      }

      // If not in local storage, fetch from Firestore
      final querySnapshot = await _firebaseService.firestore
          .collection('templates')
          .where('is_active', isEqualTo: true)
          .orderBy('name')
          .get();

      final templates = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final templateData = doc.data();
        templates.add({
          'id': doc.id,
          'name': templateData['name'],
          'data': templateData,
        });
        // Save to local storage for future offline access
        await _localStorage.saveTemplate(
            doc.id, templateData['name'], templateData);
      }
      return templates;
    } catch (e) {
      debugPrint('TemplateService: Error getting available templates: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTemplate(String templateId) async {
    try {
      // First, try to get from local storage
      final localTemplate = await _localStorage.getTemplate(templateId);
      if (localTemplate != null) {
        return localTemplate;
      }

      // If not in local storage, fetch from Firestore
      final docSnapshot = await _firebaseService.firestore
          .collection('templates')
          .doc(templateId)
          .get();

      if (docSnapshot.exists) {
        final templateData = docSnapshot.data()!;
        // Save to local storage for future offline access
        await _localStorage.saveTemplate(
            templateId, templateData['name'], templateData);
        return templateData;
      }
      return null;
    } catch (e) {
      debugPrint('TemplateService: Error getting template $templateId: $e');
      return null;
    }
  }

  Future<void> saveTemplate(
      String id, String name, Map<String, dynamic> data) async {
    await _localStorage.saveTemplate(id, name, data);
  }

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspection = await _localStorage.getInspection(inspectionId);
    return inspection?.templateId != null && inspection!.templateId!.isNotEmpty;
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      if (inspection.topics != null && inspection.topics!.isNotEmpty) {
        debugPrint(
            'TemplateService: Inspection $inspectionId already has topics. Cannot apply template safely.');
        return false;
      }

      return await applyTemplateToInspection(inspectionId, templateId);
    } catch (e) {
      debugPrint('TemplateService: Error applying template safely: $e');
      return false;
    }
  }

  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      final template = await getTemplate(templateId);
      if (template == null) {
        debugPrint('TemplateService: Template $templateId not found.');
        return false;
      }

      final templateTopics = template['topics'] as List? ?? [];
      final topics = templateTopics
          .map((topic) => Map<String, dynamic>.from(topic))
          .toList();

      final updatedInspection = inspection.copyWith(
        topics: topics,
        templateId: templateId,
        updatedAt: DateTime.now(),
      );
      await _localStorage.saveInspection(updatedInspection);
      debugPrint(
          'TemplateService: Applied template $templateId to inspection $inspectionId');
      return true;
    } catch (e) {
      debugPrint('TemplateService: Error applying template: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableTopicsFromTemplates() async {
    try {
      final templates = await getAvailableTemplates();
      final List<Map<String, dynamic>> allTopics = [];

      for (final template in templates) {
        final templateId = template['id'] as String;
        final templateName = template['name'] as String;
        final topicsData = template['data']['topics'] as List<dynamic>? ?? [];

        for (final topicData in topicsData) {
          if (topicData is Map<String, dynamic>) {
            allTopics.add({
              'templateId': templateId,
              'templateName': templateName,
              'topicData': topicData,
            });
          }
        }
      }
      return allTopics;
    } catch (e) {
      debugPrint(
          'TemplateService: Error getting available topics from templates: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopicsFromSpecificTemplate(
      String templateId) async {
    try {
      final template = await getTemplate(templateId);
      if (template == null) {
        debugPrint('TemplateService: Template $templateId not found.');
        return [];
      }
      final topicsData = template['topics'] as List<dynamic>? ?? [];
      return topicsData
          .map((topic) => Map<String, dynamic>.from(topic))
          .toList();
    } catch (e) {
      debugPrint(
          'TemplateService: Error getting topics from specific template $templateId: $e');
      return [];
    }
  }

  Future<bool> applyTemplateToInspectionOfflineSafe(
      String inspectionId, String templateId) async {
    try {
      final inspection = await _localStorage.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      if (inspection.topics != null && inspection.topics!.isNotEmpty) {
        debugPrint(
            'TemplateService: Inspection $inspectionId already has topics. Cannot apply template safely offline.');
        return false;
      }

      final template = await _localStorage.getTemplate(templateId);
      if (template == null) {
        debugPrint(
            'TemplateService: Template $templateId not found in local storage.');
        return false;
      }

      final templateTopics = template['topics'] as List? ?? [];
      final topics = templateTopics
          .map((topic) => Map<String, dynamic>.from(topic))
          .toList();

      final updatedInspection = inspection.copyWith(
        topics: topics,
        templateId: templateId,
        updatedAt: DateTime.now(),
      );
      await _localStorage.saveInspection(updatedInspection);
      debugPrint(
          'TemplateService: Applied template $templateId to inspection $inspectionId offline safely');
      return true;
    } catch (e) {
      debugPrint('TemplateService: Error applying template offline safely: $e');
      return false;
    }
  }
}

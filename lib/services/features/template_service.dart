import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/storage/sqlite_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateService {
  final FirebaseService _firebaseService = FirebaseService();
  final SQLiteStorageService _localStorage = SQLiteStorageService.instance;

  // =========================================================================
  // MÉTODOS PARA CACHE E DOWNLOAD DE TEMPLATES OFFLINE
  // =========================================================================
  
  /// Baixa e salva um template para uso offline
  Future<bool> downloadTemplateForOffline(String templateId) async {
    try {
      debugPrint('TemplateService: Downloading template $templateId for offline use');
      
      // Verificar se já existe localmente
      final existingTemplate = await _localStorage.getTemplate(templateId);
      if (existingTemplate != null) {
        debugPrint('TemplateService: Template $templateId already exists locally');
        return true;
      }

      // Buscar template no Firestore
      final templateDoc = await _firebaseService.firestore
          .collection('templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        debugPrint('TemplateService: Template $templateId not found in Firestore');
        return false;
      }

      final templateData = templateDoc.data()!;
      
      // Convert Firestore data to JSON-safe format
      final jsonSafeData = _convertFirestoreData(templateData);
      
      // Salvar template localmente
      await _localStorage.saveTemplate(templateId, jsonSafeData['name'] ?? 'Template', jsonSafeData);
      
      debugPrint('TemplateService: Successfully downloaded template $templateId');
      return true;
    } catch (e) {
      debugPrint('TemplateService: Error downloading template $templateId: $e');
      return false;
    }
  }

  /// Baixa templates associados a uma inspeção específica
  Future<bool> downloadTemplatesForInspection(String inspectionId) async {
    try {
      debugPrint('TemplateService: Downloading templates for inspection $inspectionId');
      
      // Buscar a inspeção no Firestore para obter o templateId
      final inspectionDoc = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!inspectionDoc.exists) {
        debugPrint('TemplateService: Inspection $inspectionId not found in Firestore');
        return false;
      }

      final inspectionData = inspectionDoc.data()!;
      final templateId = inspectionData['template_id'] as String?;

      if (templateId == null || templateId.isEmpty) {
        debugPrint('TemplateService: No template associated with inspection $inspectionId');
        return true; // No template to download, but it's not an error
      }

      // Baixar o template
      return await downloadTemplateForOffline(templateId);
    } catch (e) {
      debugPrint('TemplateService: Error downloading templates for inspection $inspectionId: $e');
      return false;
    }
  }

  /// Verifica se todos os templates necessários estão disponíveis offline
  Future<bool> areTemplatesAvailableOffline(List<String> templateIds) async {
    try {
      for (final templateId in templateIds) {
        final template = await _localStorage.getTemplate(templateId);
        if (template == null) {
          debugPrint('TemplateService: Template $templateId not available offline');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('TemplateService: Error checking offline template availability: $e');
      return false;
    }
  }

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
        final jsonSafeData = _convertFirestoreData(templateData);
        templates.add({
          'id': doc.id,
          'name': jsonSafeData['name'],
          'data': jsonSafeData,
        });
        // Save to local storage for future offline access
        await _localStorage.saveTemplate(
            doc.id, jsonSafeData['name'], jsonSafeData);
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
        final jsonSafeData = _convertFirestoreData(templateData);
        // Save to local storage for future offline access
        await _localStorage.saveTemplate(
            templateId, jsonSafeData['name'], jsonSafeData);
        return jsonSafeData;
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
      debugPrint('TemplateService: Getting topics from template $templateId');
      
      final template = await getTemplate(templateId);
      if (template == null) {
        debugPrint('TemplateService: Template $templateId not found.');
        return [];
      }
      
      // Extract topics from template data
      final topicsData = template['topics'] as List<dynamic>? ?? [];
      final result = <Map<String, dynamic>>[];
      
      for (final topicData in topicsData) {
        if (topicData is Map<String, dynamic>) {
          // Create a properly formatted topic for the dialog
          result.add({
            'name': topicData['name'] ?? 'Tópico sem nome',
            'description': topicData['description'] ?? '',
            'template_id': templateId,
            'templateData': topicData, // Keep original data for creation
          });
        }
      }
      
      debugPrint('TemplateService: Found ${result.length} topics in template $templateId');
      return result;
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

  /// Convert Firestore data to JSON-safe format by handling Timestamps
  Map<String, dynamic> _convertFirestoreData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      result[entry.key] = _convertValue(entry.value);
    }
    
    return result;
  }
  
  /// Recursively convert Firestore values to JSON-safe equivalents
  dynamic _convertValue(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Timestamp) {
      // Convert Firestore Timestamp to ISO string
      return value.toDate().toIso8601String();
    } else if (value is Map<String, dynamic>) {
      // Recursively convert maps
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key] = _convertValue(entry.value);
      }
      return result;
    } else if (value is List) {
      // Recursively convert lists
      return value.map((item) => _convertValue(item)).toList();
    } else {
      // Return primitive values as-is
      return value;
    }
  }
}

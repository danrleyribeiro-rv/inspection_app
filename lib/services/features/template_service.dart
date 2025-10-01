import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/models/template.dart';
import 'package:lince_inspecoes/utils/inspection_json_converter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateService {
  final FirebaseService _firebaseService = FirebaseService();
  final InspectionRepository _inspectionRepository = InspectionRepository();

  // =========================================================================
  // MÉTODOS PARA CACHE E DOWNLOAD DE TEMPLATES OFFLINE
  // =========================================================================
  
  /// Baixa e salva um template para uso offline
  Future<bool> downloadTemplateForOffline(String templateId) async {
    try {
      debugPrint('TemplateService: Downloading template $templateId for offline use');
      
      // Verificar se já existe localmente
      final existingTemplate = await DatabaseHelper.getTemplate(templateId);
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
      final template = Template(
        id: templateId,
        name: jsonSafeData['name'] ?? 'Template',
        version: jsonSafeData['version'] ?? '1.0',
        description: jsonSafeData['description'],
        category: jsonSafeData['category'],
        structure: jsonSafeData.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: jsonSafeData['is_active'] ?? true,
      );
      await DatabaseHelper.insertTemplate(template);
      
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
        final template = await DatabaseHelper.getTemplate(templateId);
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
      final localTemplates = await DatabaseHelper.getAllTemplates();
      if (localTemplates.isNotEmpty) {
        return localTemplates.map((template) => {
          'id': template.id,
          'name': template.name,
          'data': {'name': template.name, 'version': template.version, 'description': template.description}
        }).toList();
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
        final template = Template(
          id: doc.id,
          name: jsonSafeData['name'] ?? 'Template',
          version: jsonSafeData['version'] ?? '1.0',
          description: jsonSafeData['description'],
          category: jsonSafeData['category'],
          structure: jsonSafeData.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: jsonSafeData['is_active'] ?? true,
        );
        await DatabaseHelper.insertTemplate(template);
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
      final localTemplate = await DatabaseHelper.getTemplate(templateId);
      if (localTemplate != null) {
        // Try to parse structure back to original format
        Map<String, dynamic> templateData;
        try {
          // If structure contains topics data, try to extract it
          if (localTemplate.structure.contains('topics')) {
            // This is a simplified approach - in practice, you might want to store JSON
            templateData = {
              'name': localTemplate.name,
              'description': localTemplate.description,
              'version': localTemplate.version,
              'category': localTemplate.category,
              'is_active': localTemplate.isActive,
              'topics': [], // Will be populated from Firestore as fallback
            };
          } else {
            templateData = {
              'name': localTemplate.name,
              'description': localTemplate.description,
              'version': localTemplate.version,
              'category': localTemplate.category,
              'is_active': localTemplate.isActive,
            };
          }
        } catch (e) {
          debugPrint('TemplateService: Error parsing local template structure: $e');
          templateData = {
            'name': localTemplate.name,
            'description': localTemplate.description,
            'version': localTemplate.version,
            'category': localTemplate.category,
            'is_active': localTemplate.isActive,
          };
        }

        // If no topics in local data, fetch from Firestore to get complete structure
        if (templateData['topics'] == null || (templateData['topics'] as List).isEmpty) {
          try {
            final docSnapshot = await _firebaseService.firestore
                .collection('templates')
                .doc(templateId)
                .get();

            if (docSnapshot.exists) {
              final firestoreData = docSnapshot.data()!;
              final jsonSafeData = _convertFirestoreData(firestoreData);
              templateData['topics'] = jsonSafeData['topics'] ?? [];
            }
          } catch (e) {
            debugPrint('TemplateService: Could not fetch topics from Firestore: $e');
            templateData['topics'] = [];
          }
        }

        return templateData;
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
        final template = Template(
          id: templateId,
          name: jsonSafeData['name'] ?? 'Template',
          version: jsonSafeData['version'] ?? '1.0',
          description: jsonSafeData['description'],
          category: jsonSafeData['category'],
          structure: jsonSafeData.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: jsonSafeData['is_active'] ?? true,
        );
        await DatabaseHelper.insertTemplate(template);
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
    final template = Template(
      id: id,
      name: name,
      version: data['version'] ?? '1.0',
      description: data['description'],
      category: data['category'],
      structure: data.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: data['is_active'] ?? true,
    );
    await DatabaseHelper.insertTemplate(template);
  }

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    return inspection?.templateId != null && inspection!.templateId!.isNotEmpty;
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    try {
      final inspection = await _inspectionRepository.findById(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      // Check if inspection already has topics in Hive
      final existingTopics = await DatabaseHelper.getTopicsByInspection(inspectionId);
      if (existingTopics.isNotEmpty) {
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
      final inspection = await _inspectionRepository.findById(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      final template = await getTemplate(templateId);
      if (template == null) {
        debugPrint('TemplateService: Template $templateId not found.');
        return false;
      }

      // Build nested JSON structure with inspection data and template topics
      final inspectionData = inspection.toJson();
      inspectionData['topics'] = template['topics'] ?? [];

      // Use InspectionJsonConverter to populate Hive boxes from template structure
      await InspectionJsonConverter.fromNestedJson(inspectionData);

      // Update inspection with template ID
      final updatedInspection = inspection.copyWith(
        templateId: templateId,
        updatedAt: DateTime.now(),
      );
      await _inspectionRepository.update(updatedInspection);
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
      final inspection = await _inspectionRepository.findById(inspectionId);
      if (inspection == null) {
        debugPrint('TemplateService: Inspection $inspectionId not found.');
        return false;
      }

      // Check if inspection already has topics in Hive
      final existingTopics = await DatabaseHelper.getTopicsByInspection(inspectionId);
      if (existingTopics.isNotEmpty) {
        debugPrint(
            'TemplateService: Inspection $inspectionId already has topics. Cannot apply template safely offline.');
        return false;
      }

      final templateModel = await DatabaseHelper.getTemplate(templateId);
      if (templateModel == null) {
        debugPrint(
            'TemplateService: Template $templateId not found in local storage.');
        return false;
      }

      // Convert back to Map format for compatibility
      final template = {
        'name': templateModel.name,
        'description': templateModel.description,
        'version': templateModel.version,
        'topics': [], // Will need to be populated from structure if needed
      };

      // Build nested JSON structure with inspection data and template topics
      final inspectionData = inspection.toJson();
      inspectionData['topics'] = template['topics'] ?? [];

      // Use InspectionJsonConverter to populate Hive boxes from template structure
      await InspectionJsonConverter.fromNestedJson(inspectionData);

      // Update inspection with template ID
      final updatedInspection = inspection.copyWith(
        templateId: templateId,
        updatedAt: DateTime.now(),
      );
      await _inspectionRepository.update(updatedInspection);
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

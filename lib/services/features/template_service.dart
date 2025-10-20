import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/models/template.dart';
import 'package:lince_inspecoes/models/template_topic.dart';
import 'package:lince_inspecoes/models/template_item.dart';
import 'package:lince_inspecoes/models/template_detail.dart';
import 'package:lince_inspecoes/utils/inspection_json_converter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateService {
  final FirebaseService _firebaseService = FirebaseService();
  final InspectionRepository _inspectionRepository = InspectionRepository();

  // =========================================================================
  // MÉTODOS PARA CACHE E DOWNLOAD DE TEMPLATES OFFLINE
  // =========================================================================
  
  /// Reconstrói a estrutura completa do template a partir dos dados persistidos
  Future<Map<String, dynamic>> _buildTemplateStructure(String templateId) async {
    debugPrint('TemplateService: Building template structure for $templateId');

    final templateTopics = await DatabaseHelper.getTemplateTopicsByTemplate(templateId);
    final topics = <Map<String, dynamic>>[];

    for (final templateTopic in templateTopics) {
      final topicData = <String, dynamic>{
        'name': templateTopic.name,
        'description': templateTopic.description,
        'observation': templateTopic.observation,
        'direct_details': templateTopic.directDetails,
      };

      if (templateTopic.directDetails) {
        // Load direct details
        final templateDetails = await DatabaseHelper.getTemplateDetailsByTopic(templateTopic.id);
        topicData['details'] = templateDetails.map((detail) => {
          'name': detail.name,
          'type': detail.type,
          'options': detail.options,
          'required': detail.required,
        }).toList();
      } else {
        // Load items and their details
        final templateItems = await DatabaseHelper.getTemplateItemsByTopic(templateTopic.id);
        final items = <Map<String, dynamic>>[];

        for (final templateItem in templateItems) {
          final itemData = <String, dynamic>{
            'name': templateItem.name,
            'description': templateItem.description,
            'evaluable': templateItem.evaluable,
            'evaluation_options': templateItem.evaluationOptions,
          };

          // Load item details
          final templateDetails = await DatabaseHelper.getTemplateDetailsByItem(templateItem.id);
          if (templateDetails.isNotEmpty) {
            itemData['details'] = templateDetails.map((detail) => {
              'name': detail.name,
              'type': detail.type,
              'options': detail.options,
              'required': detail.required,
            }).toList();
          }

          items.add(itemData);
        }

        topicData['items'] = items;
      }

      topics.add(topicData);
    }

    debugPrint('TemplateService: Built structure with ${topics.length} topics for template $templateId');
    return {'topics': topics};
  }

  /// Salva a estrutura completa do template (topics, items, details)
  Future<void> _saveTemplateStructure(String templateId, Map<String, dynamic> templateData) async {
    debugPrint('TemplateService: Saving template structure for $templateId');
    debugPrint('TemplateService: templateData keys: ${templateData.keys}');

    final topics = templateData['topics'] as List<dynamic>? ?? [];
    debugPrint('TemplateService: Found ${topics.length} topics to save');

    for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
      final topicData = topics[topicIndex] as Map<String, dynamic>;
      debugPrint('TemplateService: Processing topic $topicIndex: ${topicData['name']}');

      // Create TemplateTopic
      final templateTopic = TemplateTopic.fromJson(topicData, templateId, topicIndex);
      await DatabaseHelper.insertTemplateTopic(templateTopic);

      debugPrint('TemplateService: Saved template topic ${templateTopic.id} (${templateTopic.name})');

      // Check if topic has direct details or items
      if (topicData['direct_details'] == true || topicData['items'] == null) {
        // Save direct details
        final details = topicData['details'] as List<dynamic>? ?? [];
        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detailData = details[detailIndex] as Map<String, dynamic>;
          final templateDetail = TemplateDetail.fromJson(
            detailData,
            templateTopic.id,
            detailIndex,
          );
          await DatabaseHelper.insertTemplateDetail(templateDetail);
          debugPrint('TemplateService: Saved direct template detail ${templateDetail.id}');
        }
      } else {
        // Save items and their details
        final items = topicData['items'] as List<dynamic>? ?? [];
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final itemData = items[itemIndex] as Map<String, dynamic>;

          // Create TemplateItem
          final templateItem = TemplateItem.fromJson(itemData, templateTopic.id, itemIndex);
          await DatabaseHelper.insertTemplateItem(templateItem);
          debugPrint('TemplateService: Saved template item ${templateItem.id}');

          // Save item details
          final details = itemData['details'] as List<dynamic>? ?? [];
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detailData = details[detailIndex] as Map<String, dynamic>;
            final templateDetail = TemplateDetail.fromJson(
              detailData,
              templateTopic.id,
              detailIndex,
              itemId: templateItem.id,
            );
            await DatabaseHelper.insertTemplateDetail(templateDetail);
            debugPrint('TemplateService: Saved template detail ${templateDetail.id}');
          }
        }
      }
    }

    debugPrint('TemplateService: Successfully saved complete structure for template $templateId');
  }

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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: jsonSafeData['is_active'] ?? true,
      );
      await DatabaseHelper.insertTemplate(template);

      // Save complete template structure
      await _saveTemplateStructure(templateId, jsonSafeData);

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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: jsonSafeData['is_active'] ?? true,
        );
        await DatabaseHelper.insertTemplate(template);

        // Save complete template structure
        await _saveTemplateStructure(doc.id, jsonSafeData);
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
        debugPrint('TemplateService: Found template $templateId in local storage');

        // Build template structure from persisted data
        final structure = await _buildTemplateStructure(templateId);
        final topicsCount = (structure['topics'] as List).length;

        debugPrint('TemplateService: Built template with $topicsCount topics');

        // If no topics found, try to re-fetch from Firestore and save structure
        if (topicsCount == 0) {
          debugPrint('TemplateService: No topics found in local storage, checking Firestore...');
          try {
            final docSnapshot = await _firebaseService.firestore
                .collection('templates')
                .doc(templateId)
                .get();

            if (docSnapshot.exists) {
              final firestoreData = docSnapshot.data()!;
              final jsonSafeData = _convertFirestoreData(firestoreData);

              final firestoreTopics = jsonSafeData['topics'] as List<dynamic>? ?? [];
              debugPrint('TemplateService: Found ${firestoreTopics.length} topics in Firestore, saving structure...');

              if (firestoreTopics.isNotEmpty) {
                // Save the complete structure
                await _saveTemplateStructure(templateId, jsonSafeData);

                // Rebuild structure
                final newStructure = await _buildTemplateStructure(templateId);
                return {
                  'name': localTemplate.name,
                  'description': localTemplate.description,
                  'version': localTemplate.version,
                  'category': localTemplate.category,
                  'is_active': localTemplate.isActive,
                  'topics': newStructure['topics'],
                };
              }
            }
          } catch (e) {
            debugPrint('TemplateService: Could not fetch from Firestore: $e');
          }
        }

        final templateData = {
          'name': localTemplate.name,
          'description': localTemplate.description,
          'version': localTemplate.version,
          'category': localTemplate.category,
          'is_active': localTemplate.isActive,
          'topics': structure['topics'],
        };

        return templateData;
      }

      // If not in local storage, fetch from Firestore
      debugPrint('TemplateService: Template $templateId not found locally, fetching from Firestore');
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: jsonSafeData['is_active'] ?? true,
        );
        await DatabaseHelper.insertTemplate(template);

        // Save complete template structure
        await _saveTemplateStructure(templateId, jsonSafeData);

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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: data['is_active'] ?? true,
    );
    await DatabaseHelper.insertTemplate(template);

    // Save complete template structure
    await _saveTemplateStructure(id, data);
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

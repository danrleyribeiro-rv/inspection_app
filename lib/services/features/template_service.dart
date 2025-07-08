import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/service_factory.dart';

class TemplateService {
  final FirebaseService _firebase = FirebaseService();
  CacheService get _cacheService => ServiceFactory().cacheService;
  final Connectivity _connectivity = Connectivity();

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
        final String topicDescriptionValue =
            _extractStringValue(topicFields, 'description');
        final String? topicDescription =
            topicDescriptionValue.isNotEmpty ? topicDescriptionValue : null;

        final itemsData = _extractArrayFromTemplate(topicFields, 'items');
        List<Map<String, dynamic>> processedItems = [];

        for (int j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          final String itemName = _extractStringValue(itemFields, 'name',
              defaultValue: 'Item sem nome');
          final String itemDescriptionValue =
              _extractStringValue(itemFields, 'description');
          final String? itemDescription =
              itemDescriptionValue.isNotEmpty ? itemDescriptionValue : null;

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

  // OFFLINE TEMPLATE SUPPORT METHODS
  Future<bool> _isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
    } catch (e) {
      debugPrint('TemplateService._isOnline: Error checking connectivity: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableTemplates() async {
    try {
      if (await _isOnline()) {
        // Try to fetch fresh templates from Firestore
        try {
          final templatesSnapshot = await _firebase.firestore
              .collection('templates')
              .get();
          
          final templates = <Map<String, dynamic>>[];
          for (final doc in templatesSnapshot.docs) {
            final templateData = doc.data();
            templateData['id'] = doc.id;
            templates.add(templateData);
            
            // Cache each template for offline use
            await _cacheService.cacheTemplate(doc.id, templateData);
          }
          
          debugPrint('TemplateService.getAvailableTemplates: Fetched and cached ${templates.length} templates');
          return templates;
        } catch (e) {
          debugPrint('TemplateService.getAvailableTemplates: Error fetching online templates, falling back to cache: $e');
        }
      }
      
      // Return cached templates
      final cachedTemplates = _cacheService.getAllCachedTemplates();
      debugPrint('TemplateService.getAvailableTemplates: Returning ${cachedTemplates.length} cached templates');
      
      // Log the first template for debugging
      if (cachedTemplates.isNotEmpty) {
        debugPrint('TemplateService.getAvailableTemplates: First cached template: ${cachedTemplates[0]}');
      }
      
      return cachedTemplates;
    } catch (e) {
      debugPrint('TemplateService.getAvailableTemplates: Error getting templates: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableTopicsFromTemplates() async {
    try {
      debugPrint('TemplateService.getAvailableTopicsFromTemplates: Starting to get templates');
      final templates = await getAvailableTemplates();
      debugPrint('TemplateService.getAvailableTopicsFromTemplates: Got ${templates.length} templates');
      
      final allTopics = <Map<String, dynamic>>[];
      
      for (final template in templates) {
        try {
          debugPrint('TemplateService.getAvailableTopicsFromTemplates: Processing template ${template['id']} - ${template['name']}');
          final topicsData = _extractArrayFromTemplate(template, 'topics');
          debugPrint('TemplateService.getAvailableTopicsFromTemplates: Template ${template['id']} has ${topicsData.length} topics');
          
          for (int i = 0; i < topicsData.length; i++) {
            final topicTemplate = topicsData[i];
            final topicFields = _extractFieldsFromTemplate(topicTemplate);
            
            if (topicFields == null) {
              debugPrint('TemplateService.getAvailableTopicsFromTemplates: Topic $i fields are null, skipping');
              continue;
            }
            
            final String topicName = _extractStringValue(topicFields, 'name',
                defaultValue: 'Tópico sem nome');
            final String topicDescription = _extractStringValue(topicFields, 'description');
            
            debugPrint('TemplateService.getAvailableTopicsFromTemplates: Found topic "$topicName" in template ${template['id']}');
            
            allTopics.add({
              'templateId': template['id'],
              'templateName': template['name'] ?? 'Template sem nome',
              'topicData': {
                'name': topicName,
                'description': topicDescription,
                'items': _extractArrayFromTemplate(topicFields, 'items'),
              },
            });
          }
        } catch (e) {
          debugPrint('TemplateService.getAvailableTopicsFromTemplates: Error processing template ${template['id']}: $e');
        }
      }
      
      debugPrint('TemplateService.getAvailableTopicsFromTemplates: Found ${allTopics.length} topics from templates');
      return allTopics;
    } catch (e) {
      debugPrint('TemplateService.getAvailableTopicsFromTemplates: Error getting template topics: $e');
      return [];
    }
  }

  Future<bool> applyTemplateToInspectionOfflineSafe(
      String inspectionId, String templateId) async {
    try {
      // Try online first if available
      if (await _isOnline()) {
        return await applyTemplateToInspection(inspectionId, templateId);
      }
      
      // If offline, use cached template
      final cachedTemplate = _cacheService.getCachedTemplate(templateId);
      if (cachedTemplate == null) {
        debugPrint('TemplateService.applyTemplateToInspectionOfflineSafe: Template $templateId not available offline');
        return false;
      }
      
      return await _applyTemplateDataToInspection(inspectionId, cachedTemplate);
    } catch (e) {
      debugPrint('TemplateService.applyTemplateToInspectionOfflineSafe: Error applying template offline: $e');
      return false;
    }
  }

  Future<bool> _applyTemplateDataToInspection(
      String inspectionId, Map<String, dynamic> templateData) async {
    try {
      final topicsData = _extractArrayFromTemplate(templateData, 'topics');
      List<Map<String, dynamic>> processedTopics = [];

      for (int i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];
        final topicFields = _extractFieldsFromTemplate(topicTemplate);

        if (topicFields == null) continue;

        final String topicName = _extractStringValue(topicFields, 'name',
            defaultValue: 'Tópico sem nome');
        final String topicDescriptionValue =
            _extractStringValue(topicFields, 'description');
        final String? topicDescription =
            topicDescriptionValue.isNotEmpty ? topicDescriptionValue : null;

        final itemsData = _extractArrayFromTemplate(topicFields, 'items');
        List<Map<String, dynamic>> processedItems = [];

        for (int j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          final String itemName = _extractStringValue(itemFields, 'name',
              defaultValue: 'Item sem nome');
          final String itemDescriptionValue =
              _extractStringValue(itemFields, 'description');
          final String? itemDescription =
              itemDescriptionValue.isNotEmpty ? itemDescriptionValue : null;

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

      // Use cache service to update inspection with template data
      final cachedInspection = _cacheService.getCachedInspection(inspectionId);
      if (cachedInspection != null) {
        final inspectionData = Map<String, dynamic>.from(cachedInspection.data);
        inspectionData['topics'] = processedTopics;
        inspectionData['is_templated'] = true;
        inspectionData['updated_at'] = DateTime.now();
        
        await _cacheService.markAsLocallyModified(inspectionId, inspectionData);
        debugPrint('TemplateService._applyTemplateDataToInspection: Applied template offline to inspection $inspectionId');
        return true;
      }

      debugPrint('TemplateService._applyTemplateDataToInspection: Inspection $inspectionId not found in cache');
      return false;
    } catch (e) {
      debugPrint('TemplateService._applyTemplateDataToInspection: Error applying template data: $e');
      return false;
    }
  }

  // Get topics from a specific template
  Future<List<Map<String, dynamic>>> getTopicsFromSpecificTemplate(String templateId) async {
    try {
      debugPrint('TemplateService.getTopicsFromSpecificTemplate: Getting topics from template $templateId');
      
      Map<String, dynamic>? templateData;
      
      if (await _isOnline()) {
        // Try to get from Firestore first
        try {
          final templateDoc = await _firebase.firestore
              .collection('templates')
              .doc(templateId)
              .get();
          
          if (templateDoc.exists) {
            templateData = templateDoc.data();
            templateData!['id'] = templateDoc.id;
            
            // Cache for offline use - use direct call to avoid extension issues
            try {
              await _cacheService.cacheTemplate(templateId, templateData);
            } catch (e) {
              debugPrint('TemplateService.getTopicsFromSpecificTemplate: Error caching template: $e');
            }
            debugPrint('TemplateService.getTopicsFromSpecificTemplate: Loaded template from Firestore and cached');
          }
        } catch (e) {
          debugPrint('TemplateService.getTopicsFromSpecificTemplate: Error loading from Firestore: $e');
        }
      }
      
      // If not found online, try cache
      if (templateData == null) {
        try {
          templateData = _cacheService.getCachedTemplate(templateId);
          if (templateData != null) {
            debugPrint('TemplateService.getTopicsFromSpecificTemplate: Loaded template from cache');
          }
        } catch (e) {
          debugPrint('TemplateService.getTopicsFromSpecificTemplate: Error loading from cache: $e');
        }
      }
      
      if (templateData == null) {
        debugPrint('TemplateService.getTopicsFromSpecificTemplate: Template $templateId not found');
        return [];
      }
      
      final topicsData = _extractArrayFromTemplate(templateData, 'topics');
      debugPrint('TemplateService.getTopicsFromSpecificTemplate: Template has ${topicsData.length} topics');
      
      final allTopics = <Map<String, dynamic>>[];
      
      for (int i = 0; i < topicsData.length; i++) {
        final topicTemplate = topicsData[i];
        final topicFields = _extractFieldsFromTemplate(topicTemplate);
        
        if (topicFields == null) {
          debugPrint('TemplateService.getTopicsFromSpecificTemplate: Topic $i fields are null, skipping');
          continue;
        }
        
        final String topicName = _extractStringValue(topicFields, 'name',
            defaultValue: 'Tópico sem nome');
        final String topicDescription = _extractStringValue(topicFields, 'description');
        
        debugPrint('TemplateService.getTopicsFromSpecificTemplate: Found topic "$topicName"');
        
        allTopics.add({
          'templateId': templateId,
          'templateName': templateData['name'] ?? 'Template sem nome',
          'topicData': {
            'name': topicName,
            'description': topicDescription,
            'items': _extractArrayFromTemplate(topicFields, 'items'),
          },
        });
      }
      
      debugPrint('TemplateService.getTopicsFromSpecificTemplate: Returning ${allTopics.length} topics from template $templateId');
      return allTopics;
    } catch (e) {
      debugPrint('TemplateService.getTopicsFromSpecificTemplate: Error getting topics from template $templateId: $e');
      return [];
    }
  }
}

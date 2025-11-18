// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/template_topic.dart';
import 'package:lince_inspecoes/models/template_item.dart';
import 'package:lince_inspecoes/models/template_detail.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';

class TemplateSelectorDialog extends StatefulWidget {
  final String title;
  final String type;
  final String parentName;
  final String? itemName;
  final String? templateId;
  final String? inspectionId; // Adicionado para suporte a tópicos

  const TemplateSelectorDialog({
    super.key,
    required this.title,
    required this.type,
    required this.parentName,
    this.itemName,
    this.templateId,
    this.inspectionId, // Adicionado para suporte a tópicos
  });

  @override
  State<TemplateSelectorDialog> createState() => _TemplateSelectorDialogState();
}

class _TemplateSelectorDialogState extends State<TemplateSelectorDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplateItems();
  }

  Future<List<Map<String, dynamic>>> _loadTopicsFromTemplate(String templateId) async {
    try {
      debugPrint('TemplateSelectorDialog: Loading topics from template $templateId');

      // Check if it's a custom template (custom topics from this inspection)
      if (templateId.startsWith('custom_')) {
        debugPrint('TemplateSelectorDialog: Loading custom template topics');
        return await _loadCustomTopics(templateId);
      }

      // Use TemplateService to get the complete template structure
      final template = await _serviceFactory.templateService.getTemplate(templateId);
      if (template == null) {
        debugPrint('TemplateSelectorDialog: Template $templateId not found');
        return [];
      }

      final templateName = template['name'] ?? 'Template';
      final topicsList = template['topics'] as List<dynamic>? ?? [];

      final availableTopics = <Map<String, dynamic>>[];
      for (final topicData in topicsList) {
        if (topicData is Map<String, dynamic>) {
          availableTopics.add({
            'topicData': topicData,
            'templateId': templateId,
            'templateName': templateName,
            'name': topicData['name'] ?? 'Tópico',
            'description': topicData['description'] ?? '',
          });
        }
      }

      debugPrint('TemplateSelectorDialog: Found ${availableTopics.length} topics in template $templateId');
      return availableTopics;
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error loading topics from template: $e');
      return [];
    }
  }

  /// Load custom topics saved for this inspection
  Future<List<Map<String, dynamic>>> _loadCustomTopics(String customTemplateId) async {
    try {
      final templateTopics = await DatabaseHelper.getTemplateTopicsByTemplate(customTemplateId);
      debugPrint('TemplateSelectorDialog: Found ${templateTopics.length} custom template topics');

      final availableTopics = <Map<String, dynamic>>[];

      for (final templateTopic in templateTopics) {
        final topicData = <String, dynamic>{
          'name': templateTopic.name,
          'description': templateTopic.description,
          'observation': templateTopic.observation,
          'direct_details': templateTopic.directDetails,
        };

        if (templateTopic.directDetails) {
          // Load direct details
          final details = await DatabaseHelper.getTemplateDetailsByTopic(templateTopic.id);
          topicData['details'] = details.map((d) => {
            'name': d.name,
            'type': d.type,
            'options': d.options,
            'required': d.required,
          }).toList();
        } else {
          // Load items and details
          final items = await DatabaseHelper.getTemplateItemsByTopic(templateTopic.id);
          final itemsJson = <Map<String, dynamic>>[];

          for (final item in items) {
            final itemJson = <String, dynamic>{
              'name': item.name,
              'description': item.description,
              'evaluable': item.evaluable,
              'evaluation_options': item.evaluationOptions,
            };

            final details = await DatabaseHelper.getTemplateDetailsByItem(item.id);
            if (details.isNotEmpty) {
              itemJson['details'] = details.map((d) => {
                'name': d.name,
                'type': d.type,
                'options': d.options,
                'required': d.required,
              }).toList();
            }

            itemsJson.add(itemJson);
          }

          topicData['items'] = itemsJson;
        }

        availableTopics.add({
          'topicData': topicData,
          'templateId': customTemplateId,
          'templateName': 'Tópicos Personalizados',
          'name': templateTopic.name,
          'description': templateTopic.description ?? '',
        });
      }

      return availableTopics;
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error loading custom topics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTopicsFromInspection() async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId!);

      // Get ALL topics from Hive box (including deleted ones with structure still intact)
      final topicsFromHive = await DatabaseHelper.getTopicsByInspection(widget.inspectionId!);
      if (topicsFromHive.isEmpty) return [];

      final topics = <Map<String, dynamic>>[];
      for (final topic in topicsFromHive) {
        // Get items for this topic
        final topicItems = DatabaseHelper.items.values.where((item) => item.topicId == topic.id).toList();

        // Get direct details for this topic (details without itemId)
        final topicDirectDetails = DatabaseHelper.details.values.where((detail) => detail.topicId == topic.id && detail.itemId == null).toList();

        // Include topics that currently have structure OR were created manually (even if empty now)
        if (topicItems.isNotEmpty || topicDirectDetails.isNotEmpty) {
          // Build topicData with complete structure
          final topicData = <String, dynamic>{
            'name': topic.topicName,
            'description': topic.topicLabel,
            'observation': topic.observation,
            'direct_details': topic.directDetails,
          };

          // Add items if present
          if (topicItems.isNotEmpty) {
            final itemsJson = <Map<String, dynamic>>[];
            for (final item in topicItems) {
              final itemJson = {
                'name': item.itemName,
                'description': item.itemLabel,
                'evaluable': item.evaluable,
                'evaluation_options': item.evaluationOptions,
              };

              // Get details for this item
              final itemDetails = DatabaseHelper.details.values.where((detail) => detail.itemId == item.id).toList();
              if (itemDetails.isNotEmpty) {
                itemJson['details'] = itemDetails.map((d) => {
                  'name': d.detailName,
                  'type': d.type,
                  'options': d.options,
                }).toList();
              }

              itemsJson.add(itemJson);
            }
            topicData['items'] = itemsJson;
          }

          // Add direct details if present
          if (topicDirectDetails.isNotEmpty) {
            topicData['details'] = topicDirectDetails.map((d) => {
              'name': d.detailName,
              'type': d.type,
              'options': d.options,
            }).toList();
          }

          topics.add({
            'topicData': topicData,
            'templateId': inspection?.templateId ?? 'inspection',
            'templateName': 'Tópicos Disponíveis',
            'name': topic.topicName,
            'description': topic.topicLabel ?? '',
          });
        }
      }

      if (topics.isNotEmpty) {
        debugPrint('TemplateSelectorDialog: Found ${topics.length} topics that can be reused from inspection');
        return topics;
      }

      return [];
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error loading topics from inspection: $e');
      return [];
    }
  }

Future<void> _loadTemplateItems() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    List<Map<String, dynamic>> items = [];

    if (widget.type == 'topic') {
      final allTopics = <Map<String, dynamic>>[];
      final existingNames = <String>{};

      // 1. Buscar tópicos do template oficial
      if (widget.templateId != null && widget.templateId!.isNotEmpty) {
        final templateTopics = await _loadTopicsFromTemplate(widget.templateId!);
        debugPrint('TemplateSelectorDialog: Loaded ${templateTopics.length} topics from template ${widget.templateId}');
        allTopics.addAll(templateTopics);
        existingNames.addAll(templateTopics.map((t) => t['name'] as String));
      }

      // 2. Buscar tópicos customizados salvos (criados/duplicados anteriormente)
      if (widget.inspectionId != null) {
        final customTemplateId = 'custom_${widget.inspectionId}';
        final customTopics = await _loadTopicsFromTemplate(customTemplateId);
        debugPrint('TemplateSelectorDialog: Loaded ${customTopics.length} custom topics');

        for (final customTopic in customTopics) {
          final topicName = customTopic['name'] as String;
          if (!existingNames.contains(topicName)) {
            allTopics.add(customTopic);
            existingNames.add(topicName);
            debugPrint('TemplateSelectorDialog: Added unique custom topic: $topicName');
          }
        }
      }

      // 3. Buscar tópicos atualmente na inspeção (que ainda não foram salvos como custom)
      if (widget.inspectionId != null) {
        final inspectionTopics = await _loadTopicsFromInspection();
        debugPrint('TemplateSelectorDialog: Loaded ${inspectionTopics.length} topics from current inspection');

        for (final inspectionTopic in inspectionTopics) {
          final topicName = inspectionTopic['name'] as String;
          if (!existingNames.contains(topicName)) {
            allTopics.add(inspectionTopic);
            existingNames.add(topicName);
            debugPrint('TemplateSelectorDialog: Added unique inspection topic: $topicName');
          }
        }
      }

      items = allTopics;
      debugPrint('TemplateSelectorDialog: Total topics available: ${items.length}');
    } else if (widget.type == 'item' && widget.parentName.isNotEmpty) {
      // Para itens, vamos manter a lógica original simplificada
      final template = await _serviceFactory.templateService.getTemplate(widget.templateId!);
      if (template != null && template['topics'] is List) {
        final topics = template['topics'] as List<dynamic>;
        for (final topic in topics) {
          if (topic is Map<String, dynamic> && 
              (topic['name'] == widget.parentName || topic['topic_name'] == widget.parentName)) {
            final itemsList = topic['items'] as List<dynamic>? ?? [];
            for (final item in itemsList) {
              if (item is Map<String, dynamic>) {
                items.add({
                  'name': item['name'] ?? item['item_name'] ?? 'Item sem nome',
                  'value': item['description'] ?? item['item_label'] ?? '',
                  'template_id': widget.templateId!,
                  'templateData': item,
                });
              }
            }
            break;
          }
        }
      }
    } else if (widget.type == 'detail' &&
        widget.parentName.isNotEmpty &&
        widget.itemName != null) {
      // Para detalhes, vamos manter a lógica original simplificada
      final template = await _serviceFactory.templateService.getTemplate(widget.templateId!);
      if (template != null && template['topics'] is List) {
        final topics = template['topics'] as List<dynamic>;
        for (final topic in topics) {
          if (topic is Map<String, dynamic> && 
              (topic['name'] == widget.parentName || topic['topic_name'] == widget.parentName)) {
            final itemsList = topic['items'] as List<dynamic>? ?? [];
            for (final item in itemsList) {
              if (item is Map<String, dynamic> && 
                  (item['name'] == widget.itemName || item['item_name'] == widget.itemName)) {
                final detailsList = item['details'] as List<dynamic>? ?? [];
                for (final detail in detailsList) {
                  if (detail is Map<String, dynamic>) {
                    items.add({
                      'name': detail['name'] ?? detail['detail_name'] ?? 'Detalhe sem nome',
                      'type': detail['type'] ?? 'text',
                      'options': detail['options'] ?? [],
                      'required': detail['required'] ?? false,
                      'template_id': widget.templateId!,
                      'templateData': detail,
                    });
                  }
                }
                break;
              }
            }
            break;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _templates = items;
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Erro ao carregar templates: $e');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


  // Métodos para suporte a tópicos
  Future<void> _addTopicFromTemplate(Map<String, dynamic> topicTemplate) async {
    if (widget.inspectionId == null) return;

    try {
      final topicData = topicTemplate['topicData'] as Map<String, dynamic>;

      // Sanitize topic data to ensure all values are Hive-compatible
      final sanitizedTopicData = <String, dynamic>{};
      for (final entry in topicData.entries) {
        if (entry.value != null) {
          if (entry.value is String ||
              entry.value is int ||
              entry.value is double ||
              entry.value is bool ||
              entry.value is List ||
              entry.value is Map) {
            sanitizedTopicData[entry.key] = entry.value;
          }
        }
      }

      // Generate unique topic name
      final originalName = sanitizedTopicData['name'] ?? sanitizedTopicData['title'] ?? 'Tópico do Template';
      final uniqueTopicName = await _generateTopicName(originalName.toString());

      // Determine if this topic has direct details
      bool hasDirectDetails = false;
      if (sanitizedTopicData['direct_details'] == true) {
        hasDirectDetails = true;
      } else if (sanitizedTopicData['details'] != null && sanitizedTopicData['items'] == null) {
        hasDirectDetails = true;
      } else if (sanitizedTopicData['items'] != null) {
        final items = sanitizedTopicData['items'] as List<dynamic>? ?? [];
        hasDirectDetails = items.isEmpty;
      }

      // Create topic with auto-generated UUID
      final topicOrder = await _getNextTopicOrder();
      final newTopic = Topic(
        inspectionId: widget.inspectionId!,
        topicName: uniqueTopicName,
        topicLabel: '',  // Simplified to avoid potential issues
        position: topicOrder,
        directDetails: hasDirectDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('TemplateSelectorDialog: About to save topic with inspectionId: ${newTopic.inspectionId}, name: ${newTopic.topicName}');
      debugPrint('TemplateSelectorDialog: Topic object details: ${newTopic.toString()}');
      final topicId = await _serviceFactory.dataService.saveTopic(newTopic);
      debugPrint('TemplateSelectorDialog: Successfully saved topic with ID: $topicId');

      // Create structure based on topic type
      debugPrint('TemplateSelectorDialog: hasDirectDetails=$hasDirectDetails for topic $topicId');
      debugPrint('TemplateSelectorDialog: sanitizedTopicData keys: ${sanitizedTopicData.keys}');
      if (hasDirectDetails) {
        debugPrint('TemplateSelectorDialog: Creating direct details for topic');
        await _createDirectDetails(topicId, sanitizedTopicData);
      } else {
        debugPrint('TemplateSelectorDialog: Creating items and details for topic');
        await _createItemsAndDetails(topicId, sanitizedTopicData);
      }

      // IMPORTANT: Save this topic structure as a TemplateTopic for the inspection
      // This allows it to be reused even after deletion
      await _saveTopicAsCustomTemplate(topicId, widget.inspectionId!, sanitizedTopicData, uniqueTopicName, hasDirectDetails);

      if (mounted) {
        Navigator.of(context).pop(newTopic);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tópico "$uniqueTopicName" adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error adding topic: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar tópico do template: $e')),
        );
      }
    }
  }

  Future<void> _createDirectDetails(String topicId, Map<String, dynamic> topicData) async {
    final templateDetails = topicData['details'] as List<dynamic>? ?? [];
    for (int detailIndex = 0; detailIndex < templateDetails.length; detailIndex++) {
      final templateDetail = templateDetails[detailIndex] as Map<String, dynamic>;

      // Sanitize template detail data
      List<String>? detailOptions;
      if (templateDetail['options'] != null) {
        final optionsData = templateDetail['options'];
        if (optionsData is List) {
          detailOptions = optionsData.map((e) => e.toString()).toList();
        } else if (optionsData is String) {
          detailOptions = optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }

      final newDetail = Detail(
        inspectionId: widget.inspectionId!,
        topicId: topicId,
        itemId: null,
        position: detailIndex,
        detailName: (templateDetail['name'] ?? templateDetail['detailName'] ?? 'Detalhe ${detailIndex + 1}').toString(),
        detailValue: templateDetail['type'] == 'boolean' ? 'não_se_aplica' : '',
        observation: '',
        type: (templateDetail['type'] ?? 'text').toString(),
        options: detailOptions,
      );

      await _serviceFactory.dataService.saveDetail(newDetail);
    }
  }

  Future<void> _createItemsAndDetails(String topicId, Map<String, dynamic> topicData) async {
    debugPrint('TemplateSelectorDialog: _createItemsAndDetails called for topic $topicId');
    debugPrint('TemplateSelectorDialog: topicData[items] = ${topicData['items']}');

    if (topicData['items'] != null) {
      final templateItems = topicData['items'] as List<dynamic>;
      debugPrint('TemplateSelectorDialog: Processing ${templateItems.length} items');

      for (int itemIndex = 0; itemIndex < templateItems.length; itemIndex++) {
        final templateItem = templateItems[itemIndex] as Map<String, dynamic>;
        debugPrint('TemplateSelectorDialog: Creating item $itemIndex: ${templateItem['name']}');

        bool isEvaluable = templateItem['evaluable'] == true;
        List<String>? evaluationOptions;

        if (templateItem['evaluation_options'] != null) {
          final optionsData = templateItem['evaluation_options'];
          if (optionsData is List) {
            evaluationOptions = optionsData.map((e) => e.toString()).toList();
            isEvaluable = true;
          } else if (optionsData is String) {
            evaluationOptions = optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            isEvaluable = true;
          }
        }

        final newItem = Item(
          inspectionId: widget.inspectionId!,
          topicId: topicId,
          position: itemIndex,
          itemName: (templateItem['name'] ?? templateItem['itemName'] ?? 'Item ${itemIndex + 1}').toString(),
          itemLabel: (templateItem['description'] ?? templateItem['itemLabel'] ?? '').toString(),
          evaluation: '',
          observation: '',
          evaluable: isEvaluable,
          evaluationOptions: evaluationOptions,
          evaluationValue: null,
        );

        await _serviceFactory.dataService.saveItem(newItem);

        // Get the auto-generated item ID
        final savedItemId = newItem.id;
        debugPrint('TemplateSelectorDialog: Saved item with UUID: $savedItemId');

        // Create details for the item
        if (templateItem['details'] != null) {
          final templateDetails = templateItem['details'] as List<dynamic>;
          debugPrint('TemplateSelectorDialog: Creating ${templateDetails.length} details for item');

          for (int detailIndex = 0; detailIndex < templateDetails.length; detailIndex++) {
            final templateDetail = templateDetails[detailIndex] as Map<String, dynamic>;
            debugPrint('TemplateSelectorDialog: Creating detail $detailIndex: ${templateDetail['name']}');

            List<String>? detailOptions;
            if (templateDetail['options'] != null) {
              final optionsData = templateDetail['options'];
              if (optionsData is List) {
                detailOptions = optionsData.map((e) => e.toString()).toList();
              } else if (optionsData is String) {
                detailOptions = optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              }
            }

            final newDetail = Detail(
              inspectionId: widget.inspectionId!,
              topicId: topicId,
              itemId: savedItemId,
              position: detailIndex,
              detailName: (templateDetail['name'] ?? templateDetail['detailName'] ?? 'Detalhe ${detailIndex + 1}').toString(),
              detailValue: templateDetail['type'] == 'boolean' ? 'não_se_aplica' : '',
              observation: '',
              type: (templateDetail['type'] ?? 'text').toString(),
              options: detailOptions,
            );

            await _serviceFactory.dataService.saveDetail(newDetail);
            debugPrint('TemplateSelectorDialog: Saved detail with UUID: ${newDetail.id}');
          }
        } else {
          debugPrint('TemplateSelectorDialog: No details found for item $itemIndex');
        }
      }
    } else {
      debugPrint('TemplateSelectorDialog: No items found in topicData');
    }
  }

  Future<String> _generateTopicName(String templateName) async {
    if (widget.inspectionId == null) return templateName;

    try {
      final topics = await _serviceFactory.dataService.getTopics(widget.inspectionId!);
      final existingNames = topics.map((t) => t.topicName).toSet();

      if (!existingNames.contains(templateName)) {
        return templateName;
      }

      int counter = 2;
      String newName;
      do {
        newName = '$templateName $counter';
        counter++;
      } while (existingNames.contains(newName));

      return newName;
    } catch (e) {
      debugPrint('Error generating topic name: $e');
      return templateName;
    }
  }

  Future<int> _getNextTopicOrder() async {
    if (widget.inspectionId == null) return 0;

    try {
      final topics = await _serviceFactory.dataService.getTopics(widget.inspectionId!);
      return topics.length;
    } catch (e) {
      debugPrint('Error getting next topic order: $e');
      return 0;
    }
  }

  /// Salva o tópico customizado como TemplateTopic para permitir reutilização
  Future<void> _saveTopicAsCustomTemplate(
    String topicId,
    String inspectionId,
    Map<String, dynamic> topicData,
    String topicName,
    bool hasDirectDetails,
  ) async {
    try {
      debugPrint('TemplateSelectorDialog: Saving custom topic as template for reuse');

      // Use inspection ID as template ID for custom topics
      final customTemplateId = 'custom_$inspectionId';

      // Get current count of custom topics for this inspection
      final existingCustomTopics = await DatabaseHelper.getTemplateTopicsByTemplate(customTemplateId);
      final position = existingCustomTopics.length;

      // Create TemplateTopic
      final templateTopic = TemplateTopic(
        id: '${customTemplateId}_topic_$position',
        templateId: customTemplateId,
        name: topicName,
        description: topicData['description']?.toString(),
        directDetails: hasDirectDetails,
        observation: topicData['observation']?.toString(),
        position: position,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.insertTemplateTopic(templateTopic);
      debugPrint('TemplateSelectorDialog: Saved TemplateTopic ${templateTopic.id}');

      // Save items and details structure
      if (hasDirectDetails) {
        // Save direct details
        final details = topicData['details'] as List<dynamic>? ?? [];
        for (int i = 0; i < details.length; i++) {
          final detailData = details[i] as Map<String, dynamic>;
          final templateDetail = TemplateDetail.fromJson(
            detailData,
            templateTopic.id,
            i,
          );
          await DatabaseHelper.insertTemplateDetail(templateDetail);
        }
      } else {
        // Save items and their details
        final items = topicData['items'] as List<dynamic>? ?? [];
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final itemData = items[itemIndex] as Map<String, dynamic>;
          final templateItem = TemplateItem.fromJson(itemData, templateTopic.id, itemIndex);
          await DatabaseHelper.insertTemplateItem(templateItem);

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
          }
        }
      }

      debugPrint('TemplateSelectorDialog: Custom topic saved as template for future reuse');
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error saving custom topic as template: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 300, // Altura fixa para evitar mudanças de layout
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              // Loading state
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AdaptiveProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Carregando tópicos...',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_templates.isEmpty) ...[
              // No templates available
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.library_books, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        widget.templateId != null
                            ? 'Nenhum tópico encontrado no template'
                            : 'Esta inspeção não possui template associado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Os tópicos do template devem vir junto com a inspeção',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Template topics list
              if (widget.type == 'topic') ...[
                Text(
                  'Escolha um tópico do template:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
              ],
              // Scroll para lista de templates
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    final templateName = template['name'] ?? '';
                    final templateDescription = template['description'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          templateName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: templateDescription.isNotEmpty
                            ? Text(templateDescription)
                            : (template['type'] != null ? Text('Tipo: ${template['type']}') : null),
                        leading: widget.type == 'topic'
                            ? const Icon(Icons.topic, color: Colors.purple)
                            : const Icon(Icons.library_books, color: Colors.blue),
                        onTap: () async {
                          if (widget.type == 'topic' && widget.inspectionId != null) {
                            // Para tópicos, adicionar diretamente
                            await _addTopicFromTemplate(template);
                          } else {
                            // Para itens e detalhes, retornar o template
                            Navigator.of(context).pop({
                              ...Map<String, dynamic>.from(template),
                              'isCustom': false,
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
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
      // First try to get template from DatabaseHelper
      final template = await DatabaseHelper.getTemplate(templateId);
      if (template != null) {
        return _extractTopicsFromTemplate(template.toMap());
      }

      // Try to get topics from the inspection's Hive box
      if (widget.inspectionId != null) {
        final topicsFromHive = await DatabaseHelper.getTopicsByInspection(widget.inspectionId!);
        if (topicsFromHive.isNotEmpty) {
          final availableTopics = <Map<String, dynamic>>[];
          for (final topic in topicsFromHive) {
            // Check if topic has items or direct details
            final hasItems = DatabaseHelper.items.values.any((item) => item.topicId == topic.id);
            final hasDirectDetails = DatabaseHelper.details.values.any((detail) => detail.topicId == topic.id && detail.itemId == null);

            if (hasItems || hasDirectDetails) {
              availableTopics.add({
                'topicData': {
                  'name': topic.topicName,
                  'description': topic.topicLabel,
                  'observation': topic.observation,
                },
                'templateId': templateId,
                'templateName': 'Template da Inspeção',
                'name': topic.topicName,
                'description': topic.topicLabel ?? '',
              });
            }
          }

          if (availableTopics.isNotEmpty) {
            return availableTopics;
          }
        }
      }

      debugPrint('TemplateSelectorDialog: Template not found locally and no internet download needed');

      return [];
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error loading topics: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractTopicsFromTemplate(Map<String, dynamic> template) {
    try {
      final List<Map<String, dynamic>> topics = [];

      if (template['structure'] != null) {
        final structure = template['structure'];
        if (structure is Map<String, dynamic> && structure['topics'] != null) {
          final topicsList = structure['topics'] as List<dynamic>? ?? [];
          for (final topicData in topicsList) {
            if (topicData is Map<String, dynamic>) {
              topics.add({
                'topicData': topicData,
                'templateId': template['id'],
                'templateName': template['name'],
                'name': topicData['name'] ?? 'Tópico',
                'description': topicData['description'] ?? '',
              });
            }
          }
        }
      } else if (template['topics'] != null) {
        final topicsList = template['topics'] as List<dynamic>? ?? [];
        for (final topicData in topicsList) {
          if (topicData is Map<String, dynamic>) {
            topics.add({
              'topicData': topicData,
              'templateId': template['id'],
              'templateName': template['name'],
              'name': topicData['name'] ?? 'Tópico',
              'description': topicData['description'] ?? '',
            });
          }
        }
      }

      return topics;
    } catch (e) {
      debugPrint('TemplateSelectorDialog: Error extracting topics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTopicsFromInspection() async {
    try {
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId!);

      // Get topics from Hive box
      final topicsFromHive = await DatabaseHelper.getTopicsByInspection(widget.inspectionId!);
      if (topicsFromHive.isEmpty) return [];

      final topics = <Map<String, dynamic>>[];
      for (final topic in topicsFromHive) {
        // Get items for this topic
        final topicItems = DatabaseHelper.items.values.where((item) => item.topicId == topic.id).toList();

        // Get direct details for this topic (details without itemId)
        final topicDirectDetails = DatabaseHelper.details.values.where((detail) => detail.topicId == topic.id && detail.itemId == null).toList();

        // Only include topics that have structure
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
                  'isRequired': d.isRequired,
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
              'isRequired': d.isRequired,
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
      // Para tópicos, buscar sempre da estrutura da inspeção primeiro
      if (widget.inspectionId != null) {
        items = await _loadTopicsFromInspection();
      }

      // Se não encontrou tópicos na inspeção e tem templateId, tentar do template
      if (items.isEmpty && widget.templateId != null && widget.templateId!.isNotEmpty) {
        items = await _loadTopicsFromTemplate(widget.templateId!);
      }
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
        isRequired: templateDetail['isRequired'] == true,
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
              isRequired: templateDetail['isRequired'] == true,
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
                      CircularProgressIndicator(),
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
                            : 'Esta vistoria não possui template associado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Os tópicos do template devem vir junto com a vistoria',
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

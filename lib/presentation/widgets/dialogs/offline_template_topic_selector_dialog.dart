// lib/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:inspection_app/services/enhanced_offline_service_factory.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class OfflineTemplateTopicSelectorDialog extends StatefulWidget {
  final String inspectionId;
  final String? templateId;

  const OfflineTemplateTopicSelectorDialog({
    super.key,
    required this.inspectionId,
    this.templateId,
  });

  @override
  State<OfflineTemplateTopicSelectorDialog> createState() => _OfflineTemplateTopicSelectorDialogState();
}

class _OfflineTemplateTopicSelectorDialogState extends State<OfflineTemplateTopicSelectorDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _templateTopics = [];

  @override
  void initState() {
    super.initState();
    _loadTemplateTopics();
  }

  Future<List<Map<String, dynamic>>> _loadTopicsFromTemplate(String templateId) async {
    try {
      // First try to get template from SQLite storage
      final template = await _serviceFactory.storageService.getTemplate(templateId);
      if (template != null) {
        debugPrint('OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Found template in SQLite storage');
        return _extractTopicsFromTemplate(template);
      }
      
      // Template not found in SQLite storage, check if we need to download it
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Template not found in local storage, would need to download from cloud');
      
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Template not found in local storage');
      return [];
    } catch (e) {
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Error loading template: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractTopicsFromTemplate(Map<String, dynamic> template) {
    try {
      final List<Map<String, dynamic>> topics = [];
      
      // Try different possible structures
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
            });
          }
        }
      }
      
      debugPrint('OfflineTemplateTopicSelectorDialog._extractTopicsFromTemplate: Extracted ${topics.length} topics from template');
      return topics;
    } catch (e) {
      debugPrint('OfflineTemplateTopicSelectorDialog._extractTopicsFromTemplate: Error extracting topics: $e');
      return [];
    }
  }

  Future<void> _loadTemplateTopics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Starting to load template topics for templateId: ${widget.templateId}');
      
      List<Map<String, dynamic>> topics = [];
      
      if (widget.templateId != null && widget.templateId!.isNotEmpty) {
        // Get topics from specific template
        topics = await _loadTopicsFromTemplate(widget.templateId!);
        debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Loaded ${topics.length} topics from template ${widget.templateId}');
      } else {
        // Fallback: try to get template from inspection
        final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
        if (inspection?.templateId != null) {
          topics = await _loadTopicsFromTemplate(inspection!.templateId!);
          debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Loaded ${topics.length} topics from inspection template ${inspection.templateId}');
        } else {
          debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: No template ID found for inspection');
        }
      }
      
      // Log each topic for debugging
      for (int i = 0; i < topics.length; i++) {
        debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Topic $i: ${topics[i]}');
      }
      
      if (mounted) {
        setState(() {
          _templateTopics = topics;
          _isLoading = false;
        });
        debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Updated state with ${_templateTopics.length} topics');
      }
    } catch (e, stackTrace) {
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Error loading template topics: $e');
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _templateTopics = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<int> _getNextTopicOrder() async {
    try {
      final topics = await _serviceFactory.dataService.getTopics(widget.inspectionId);
      return topics.length;
    } catch (e) {
      debugPrint('OfflineTemplateTopicSelectorDialog._getNextTopicOrder: Error: $e');
      return 0;
    }
  }

  Future<void> _addTopicFromTemplate(Map<String, dynamic> topicTemplate) async {
    try {
      final topicData = topicTemplate['topicData'] as Map<String, dynamic>;
      final selectedTemplateTopic = topicData; // Variável para o contexto do template
      
      // Create topic using the data service
      final newTopic = Topic(
        inspectionId: widget.inspectionId,
        topicName: topicData['name'] ?? topicData['title'] ?? 'Tópico do Template',
        topicLabel: topicData['description'] ?? '',
        position: await _getNextTopicOrder(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final topicId = await _serviceFactory.dataService.saveTopic(newTopic);
      
      debugPrint('OfflineTemplateTopicSelectorDialog._addTopicFromTemplate: Created topic $topicId from template');
        
      // Criar items e details do template se disponíveis
      try {
        if (selectedTemplateTopic['items'] != null) {
          final templateItems = selectedTemplateTopic['items'] as List<dynamic>;
          
          for (final templateItem in templateItems) {
            final itemId = const Uuid().v4();
            final newItem = Item(
              id: itemId,
              inspectionId: widget.inspectionId,
              topicId: topicId,
              itemId: itemId,
              position: templateItem['position'] ?? 0,
              itemName: templateItem['itemName'] ?? 'Item',
              itemLabel: templateItem['itemLabel'] ?? 'Item',
              evaluation: '',
              observation: '',
            );
            
            await _serviceFactory.dataService.saveItem(newItem);
            debugPrint('Created item $itemId from template');
            
            // Criar details do item se disponíveis
            if (templateItem['details'] != null) {
              final templateDetails = templateItem['details'] as List<dynamic>;
              
              for (final templateDetail in templateDetails) {
                final detailId = const Uuid().v4();
                final newDetail = Detail(
                  id: detailId,
                  inspectionId: widget.inspectionId,
                  topicId: topicId,
                  itemId: itemId,
                  detailId: detailId,
                  position: templateDetail['position'] ?? 0,
                  detailName: templateDetail['detailName'] ?? 'Detalhe',
                  detailValue: '',
                  observation: '',
                  type: templateDetail['type'] ?? 'text',
                  options: templateDetail['options'],
                  isRequired: templateDetail['isRequired'] ?? false,
                );
                
                await _serviceFactory.dataService.saveDetail(newDetail);
                debugPrint('Created detail $detailId from template');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao criar items e details do template: $e');
      }
      
      if (mounted) {
        Navigator.of(context).pop(newTopic);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tópico "${topicData['name'] ?? 'Tópico'}" adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('OfflineTemplateTopicSelectorDialog._addTopicFromTemplate: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar tópico do template: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Tópico'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              // Loading state
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (_templateTopics.isEmpty) ...[
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
                        widget.templateId != null
                          ? 'Conecte-se à internet para baixar o template'
                          : 'Nenhum tópico disponível no template',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Template topics list
              Text(
                'Escolha um tópico do template:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _templateTopics.length,
                  itemBuilder: (context, index) {
                    final topicTemplate = _templateTopics[index];
                    final topicData = topicTemplate['topicData'] as Map<String, dynamic>;
                    final topicName = topicData['name'] as String;
                    final topicDescription = topicData['description'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          topicName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: topicDescription.isNotEmpty 
                            ? Text(topicDescription)
                            : null,
                        leading: const Icon(Icons.topic, color: Colors.purple),
                        onTap: () => _addTopicFromTemplate(topicTemplate),
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
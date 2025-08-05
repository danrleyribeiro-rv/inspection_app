// lib/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';

class OfflineTemplateTopicSelectorDialog extends StatefulWidget {
  final String inspectionId;
  final String? templateId;

  const OfflineTemplateTopicSelectorDialog({
    super.key,
    required this.inspectionId,
    this.templateId,
  });

  @override
  State<OfflineTemplateTopicSelectorDialog> createState() =>
      _OfflineTemplateTopicSelectorDialogState();
}

class _OfflineTemplateTopicSelectorDialogState
    extends State<OfflineTemplateTopicSelectorDialog> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  bool _isLoading = true;
  bool _isDownloadingTemplate = false;
  String _downloadStatus = '';
  List<Map<String, dynamic>> _templateTopics = [];

  @override
  void initState() {
    super.initState();
    _loadTemplateTopics();
  }

  Future<List<Map<String, dynamic>>> _loadTopicsFromTemplate(
      String templateId) async {
    try {
      // First try to get template from SQLite storage
      final template =
          await _serviceFactory.storageService.getTemplate(templateId);
      if (template != null) {
        debugPrint(
            'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Found template in SQLite storage');
        return _extractTopicsFromTemplate(template);
      }

      // Try to get template from the inspection's nested structure
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection != null && inspection.topics != null) {
        debugPrint(
            'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Checking if inspection has template topics');
        
        // Check if inspection has template structure that can be used
        final availableTopics = <Map<String, dynamic>>[];
        for (final topic in inspection.topics!) {
          if (topic['items'] != null) {
            availableTopics.add({
              'topicData': topic,
              'templateId': templateId,
              'templateName': 'Template da Inspeção',
            });
          }
        }
        
        if (availableTopics.isNotEmpty) {
          debugPrint(
              'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Found ${availableTopics.length} topics in inspection template');
          return availableTopics;
        }
      }

      // Template not found locally, try to download it if we're online
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Template not found locally, attempting to download');
      
      // Show download status
      if (mounted) {
        setState(() {
          _isDownloadingTemplate = true;
          _downloadStatus = 'Baixando template...';
        });
      }
      
      final downloadSuccess = await _serviceFactory.templateService.downloadTemplateForOffline(templateId);
      if (downloadSuccess) {
        // Try to get template again after download
        final downloadedTemplate = await _serviceFactory.storageService.getTemplate(templateId);
        if (downloadedTemplate != null) {
          debugPrint(
              'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Successfully downloaded and loaded template');
          
          // Update download status
          if (mounted) {
            setState(() {
              _isDownloadingTemplate = false;
              _downloadStatus = 'Template baixado com sucesso!';
            });
          }
          
          return _extractTopicsFromTemplate(downloadedTemplate);
        }
      }

      // Failed to download
      if (mounted) {
        setState(() {
          _isDownloadingTemplate = false;
          _downloadStatus = 'Não foi possível baixar o template';
        });
      }

      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Template not available offline and could not be downloaded');
      return [];
    } catch (e) {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTopicsFromTemplate: Error loading template: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractTopicsFromTemplate(
      Map<String, dynamic> template) {
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

      debugPrint(
          'OfflineTemplateTopicSelectorDialog._extractTopicsFromTemplate: Extracted ${topics.length} topics from template');
      return topics;
    } catch (e) {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._extractTopicsFromTemplate: Error extracting topics: $e');
      return [];
    }
  }

  Future<void> _loadTemplateTopics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Starting to load template topics for templateId: ${widget.templateId}');

      List<Map<String, dynamic>> topics = [];

      if (widget.templateId != null && widget.templateId!.isNotEmpty) {
        // Get topics from specific template
        topics = await _loadTopicsFromTemplate(widget.templateId!);
        debugPrint(
            'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Loaded ${topics.length} topics from template ${widget.templateId}');
      } else {
        // Fallback: try to get template from inspection
        final inspection = await _serviceFactory.dataService
            .getInspection(widget.inspectionId);
        if (inspection?.templateId != null) {
          topics = await _loadTopicsFromTemplate(inspection!.templateId!);
          debugPrint(
              'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Loaded ${topics.length} topics from inspection template ${inspection.templateId}');
        } else {
          debugPrint(
              'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: No template ID found for inspection');
        }
      }

      // Log each topic for debugging
      for (int i = 0; i < topics.length; i++) {
        debugPrint(
            'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Topic $i: ${topics[i]}');
      }

      if (mounted) {
        setState(() {
          _templateTopics = topics;
          _isLoading = false;
        });
        debugPrint(
            'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Updated state with ${_templateTopics.length} topics');
      }
    } catch (e, stackTrace) {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Error loading template topics: $e');
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Stack trace: $stackTrace');
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
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);
      return topics.length;
    } catch (e) {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._getNextTopicOrder: Error: $e');
      return 0;
    }
  }

  Future<String> _generateTopicName(String templateName) async {
    try {
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);
      final existingNames = topics.map((t) => t.topicName).toSet();
      
      // Se o nome original não existe, use ele
      if (!existingNames.contains(templateName)) {
        return templateName;
      }
      
      // Senão, encontre o próximo número disponível baseado no nome original
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

  Future<void> _markInspectionAsModified() async {
    try {
      // Get the current inspection
      final inspection = await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection != null) {
        // Mark inspection as having local changes using update method instead of save
        final updatedInspection = inspection.copyWith(
          hasLocalChanges: true,
          updatedAt: DateTime.now(),
        );
        
        // Use updateInspection instead of saveInspection to avoid UNIQUE constraint error
        await _serviceFactory.dataService.updateInspection(updatedInspection);
        
        debugPrint('OfflineTemplateTopicSelectorDialog: Inspection ${widget.inspectionId} marked as having local changes');
      } else {
        debugPrint('OfflineTemplateTopicSelectorDialog: Could not find inspection ${widget.inspectionId} to mark as modified');
      }
    } catch (e) {
      debugPrint('OfflineTemplateTopicSelectorDialog: Error marking inspection as modified: $e');
    }
  }

  Future<void> _addTopicFromTemplate(Map<String, dynamic> topicTemplate) async {
    try {
      final topicData = topicTemplate['topicData'] as Map<String, dynamic>;
      final selectedTemplateTopic =
          topicData; // Variável para o contexto do template

      // Generate unique topic name
      final originalName = topicData['name'] ?? topicData['title'] ?? 'Tópico do Template';
      final uniqueTopicName = await _generateTopicName(originalName);
      debugPrint('OfflineTemplateTopicSelectorDialog: Original name: $originalName, Unique name: $uniqueTopicName');
      
      // Determine if this topic has direct details (no items, only details)
      bool hasDirectDetails = false;
      if (topicData['direct_details'] == true) {
        hasDirectDetails = true;
      } else if (topicData['details'] != null && topicData['items'] == null) {
        hasDirectDetails = true;
      } else if (topicData['items'] != null) {
        final items = topicData['items'] as List<dynamic>;
        hasDirectDetails = items.isEmpty;
      }

      debugPrint('OfflineTemplateTopicSelectorDialog: Topic "$uniqueTopicName" has directDetails: $hasDirectDetails');

      // Create topic using the data service
      final newTopic = Topic(
        inspectionId: widget.inspectionId,
        topicName: uniqueTopicName,
        topicLabel: topicData['description'] ?? '',
        position: await _getNextTopicOrder(),
        directDetails: hasDirectDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final topicId = await _serviceFactory.dataService.saveTopic(newTopic);

      debugPrint(
          'OfflineTemplateTopicSelectorDialog._addTopicFromTemplate: Created topic $topicId from template');

      // IMPORTANTE: Marcar a inspeção como tendo mudanças locais
      await _markInspectionAsModified();

      // Criar detalhes ou itens baseado na estrutura do tópico
      try {
        if (hasDirectDetails) {
          // Tópico com detalhes diretos (sem itens)
          debugPrint('Creating direct details for topic $topicId');
          
          final templateDetails = selectedTemplateTopic['details'] as List<dynamic>? ?? [];
          for (int detailIndex = 0; detailIndex < templateDetails.length; detailIndex++) {
            final templateDetail = templateDetails[detailIndex];
            final detailId = const Uuid().v4();
            
            // Convert options from List<dynamic> to List<String>?
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
              id: detailId,
              inspectionId: widget.inspectionId,
              topicId: topicId,
              itemId: null, // Detalhes diretos não têm itemId
              detailId: detailId,
              position: detailIndex,
              detailName: templateDetail['name'] ?? templateDetail['detailName'] ?? 'Detalhe ${detailIndex + 1}',
              detailValue: templateDetail['type'] == 'boolean' ? 'não_se_aplica' : '',
              observation: '',
              type: templateDetail['type'] ?? 'text',
              options: detailOptions,
              isRequired: templateDetail['isRequired'] ?? false,
            );

            await _serviceFactory.dataService.saveDetail(newDetail);
            debugPrint('Created direct detail $detailId for topic with name: ${newDetail.detailName}, type: ${newDetail.type}');
          }
        } else {
          // Tópico com itens (estrutura normal)
          debugPrint('Creating items for topic $topicId');
          
          if (selectedTemplateTopic['items'] != null) {
            final templateItems = selectedTemplateTopic['items'] as List<dynamic>;

            for (int itemIndex = 0; itemIndex < templateItems.length; itemIndex++) {
              final templateItem = templateItems[itemIndex];
              final itemId = const Uuid().v4();
              
              // Determinar se o item é avaliável
              bool isEvaluable = templateItem['evaluable'] == true;
              List<String>? evaluationOptions;
              
              if (templateItem['evaluation_options'] != null) {
                final optionsData = templateItem['evaluation_options'];
                if (optionsData is List) {
                  evaluationOptions = optionsData.map((e) => e.toString()).toList();
                  isEvaluable = true; // Se tem opções, é avaliável
                } else if (optionsData is String) {
                  evaluationOptions = optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  isEvaluable = true;
                }
              }

              debugPrint('Creating item: ${templateItem['name']}, evaluable: $isEvaluable, evaluationOptions: $evaluationOptions');

              final newItem = Item(
                id: itemId,
                inspectionId: widget.inspectionId,
                topicId: topicId,
                itemId: itemId,
                position: itemIndex,
                itemName: templateItem['name'] ?? templateItem['itemName'] ?? 'Item ${itemIndex + 1}',
                itemLabel: templateItem['description'] ?? templateItem['itemLabel'] ?? '',
                evaluation: '',
                observation: '',
                evaluable: isEvaluable,
                evaluationOptions: evaluationOptions,
                evaluationValue: null, // Inicialmente sem avaliação
              );

              await _serviceFactory.dataService.saveItem(newItem);
              debugPrint('Created item $itemId from template with name: ${newItem.itemName}, evaluable: ${newItem.evaluable}');

              // Criar details do item se disponíveis
              if (templateItem['details'] != null) {
                final templateDetails = templateItem['details'] as List<dynamic>;

                for (int detailIndex = 0; detailIndex < templateDetails.length; detailIndex++) {
                  final templateDetail = templateDetails[detailIndex];
                  final detailId = const Uuid().v4();
                  
                  // Convert options from List<dynamic> to List<String>?
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
                    id: detailId,
                    inspectionId: widget.inspectionId,
                    topicId: topicId,
                    itemId: itemId,
                    detailId: detailId,
                    position: detailIndex,
                    detailName: templateDetail['name'] ?? templateDetail['detailName'] ?? 'Detalhe ${detailIndex + 1}',
                    detailValue: templateDetail['type'] == 'boolean' ? 'não_se_aplica' : '',
                    observation: '',
                    type: templateDetail['type'] ?? 'text',
                    options: detailOptions,
                    isRequired: templateDetail['isRequired'] ?? false,
                  );

                  await _serviceFactory.dataService.saveDetail(newDetail);
                  debugPrint('Created detail $detailId for item with name: ${newDetail.detailName}, type: ${newDetail.type}');
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao criar items e details do template: $e');
        // Não deve bloquear a criação do tópico se apenas os items/details falharem
      }

      if (mounted) {
        Navigator.of(context).pop(newTopic);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Tópico "$uniqueTopicName" adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'OfflineTemplateTopicSelectorDialog._addTopicFromTemplate: Error: $e');
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
            if (_isLoading || _isDownloadingTemplate) ...[
              // Loading/Download state
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _isDownloadingTemplate ? _downloadStatus : 'Carregando templates...',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_templateTopics.isEmpty) ...[
              // No templates available
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.library_books,
                          size: 48, color: Colors.grey),
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Template topics list
              if (_downloadStatus.isNotEmpty && _downloadStatus.contains('sucesso')) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _downloadStatus,
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    final topicData =
                        topicTemplate['topicData'] as Map<String, dynamic>;
                    final topicName = topicData['name'] as String;
                    final topicDescription =
                        topicData['description'] as String? ?? '';

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

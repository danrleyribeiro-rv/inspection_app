// lib/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';

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
  final ServiceFactory _serviceFactory = ServiceFactory();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _templateTopics = [];

  @override
  void initState() {
    super.initState();
    _loadTemplateTopics();
  }

  Future<void> _loadTemplateTopics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Starting to load template topics for templateId: ${widget.templateId}');
      
      List<Map<String, dynamic>> topics = [];
      
      if (widget.templateId != null && widget.templateId!.isNotEmpty) {
        // Get topics from specific template
        topics = await _serviceFactory.coordinator.getTopicsFromSpecificTemplate(widget.templateId!);
        debugPrint('OfflineTemplateTopicSelectorDialog._loadTemplateTopics: Loaded ${topics.length} topics from template ${widget.templateId}');
      } else {
        // Fallback: try to get template from inspection
        final inspection = await _serviceFactory.coordinator.getInspection(widget.inspectionId);
        if (inspection?.templateId != null) {
          topics = await _serviceFactory.coordinator.getTopicsFromSpecificTemplate(inspection!.templateId!);
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


  Future<void> _addTopicFromTemplate(Map<String, dynamic> topicTemplate) async {
    try {
      final topic = await _serviceFactory.coordinator.addTopicFromTemplateOffline(
        widget.inspectionId,
        topicTemplate,
      );
      
      if (mounted) {
        Navigator.of(context).pop(topic);
      }
    } catch (e) {
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
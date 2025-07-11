// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class TemplateSelectorDialog extends StatefulWidget {
  final String title;
  final String type;
  final String parentName;
  final String? itemName;
  final String? templateId;

  const TemplateSelectorDialog({
    super.key,
    required this.title,
    required this.type,
    required this.parentName,
    this.itemName,
    this.templateId,
  });

  @override
  State<TemplateSelectorDialog> createState() => _TemplateSelectorDialogState();
}

class _TemplateSelectorDialogState extends State<TemplateSelectorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  bool _isCustom = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplateItems();
  }

Future<void> _loadTemplateItems() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    List<Map<String, dynamic>> items = [];

    // Verificar se templateId foi fornecido
    if (widget.templateId == null || widget.templateId!.isEmpty) {
      setState(() {
        _templates = [];
        _isLoading = false;
      });
      return;
    }

    if (widget.type == 'topic') {
      // Buscar tópicos do template usando o service
      items = await _serviceFactory.templateService.getTopicsFromSpecificTemplate(widget.templateId!);
      debugPrint('TemplateSelectorDialog: Loaded ${items.length} topics from template ${widget.templateId}');
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


  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
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
            // Alternar entre template e personalizado
            Row(
              children: [
                const Text('Personalizado'),
                Switch(
                  value: _isCustom,
                  onChanged: (value) => setState(() => _isCustom = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isCustom) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText:
                      '${widget.type.substring(0, 1).toUpperCase()}${widget.type.substring(1)} Nome',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'Rótulo (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else if (_isLoading) ...[
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (_templates.isEmpty) ...[
              const Expanded(
                child: Center(child: Text('Nenhum template disponível')),
              ),
            ] else ...[
              // Scroll para lista de templates
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return ListTile(
                      title: Text(template['name'] ?? ''),
                      subtitle: template['type'] != null
                          ? Text('Tipo: ${template['type']}')
                          : null,
                      onTap: () {
                        Navigator.of(context).pop({
                          ...Map<String, dynamic>.from(template),
                          'isCustom': false,
                        });
                      },
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
        if (_isCustom)
          TextButton(
            onPressed: () {
              if (_nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome é obrigatório')),
                );
                return;
              }
              Navigator.of(context).pop(<String, dynamic>{
                'name': _nameController.text,
                'value': _valueController.text.isEmpty
                    ? null
                    : _valueController.text,
                'isCustom': true,
              });
            },
            child: const Text('Adicionar'),
          ),
      ],
    );
  }
}

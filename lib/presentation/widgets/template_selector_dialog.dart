// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateSelectorDialog extends StatefulWidget {
  final String title;
  final String type;
  final String parentName;
  final String? itemName; // Adicionamos o nome do item para buscar detalhes

  const TemplateSelectorDialog({
    super.key,
    required this.title,
    required this.type,
    required this.parentName,
    this.itemName,
  });

  @override
  State<TemplateSelectorDialog> createState() => _TemplateSelectorDialogState();
}

class _TemplateSelectorDialogState extends State<TemplateSelectorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
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
      final firestore = FirebaseFirestore.instance;

      if (widget.type == 'topic') {
        // Buscar salas de templates
        final templatesSnapshot = await firestore.collection('templates').get();

        for (var templateDoc in templatesSnapshot.docs) {
          final templateData = templateDoc.data();
          if (templateData['topics'] is List) {
            for (var topic in templateData['topics']) {
              // Extrai o nome da sala do formato do template
              String topicName = "";
              if (topic is Map &&
                  topic['name'] is Map &&
                  topic['name']['stringValue'] != null) {
                topicName = topic['name']['stringValue'];
              } else if (topic is Map && topic['name'] is String) {
                topicName = topic['name'];
              }

              if (topicName.isNotEmpty) {
                items.add({
                  'name': topicName,
                  'template_id': templateDoc.id,
                  'description': templateData['description'] ?? '',
                });
              }
            }
          }
        }
      } else if (widget.type == 'item' && widget.parentName.isNotEmpty) {
        // Buscar itens de templates para uma sala específica
        final templatesSnapshot = await firestore.collection('templates').get();

        for (var templateDoc in templatesSnapshot.docs) {
          final templateData = templateDoc.data();
          if (templateData['topics'] is List) {
            for (var topic in templateData['topics']) {
              String topicName = "";
              if (topic is Map &&
                  topic['name'] is Map &&
                  topic['name']['stringValue'] != null) {
                topicName = topic['name']['stringValue'];
              } else if (topic is Map && topic['name'] is String) {
                topicName = topic['name'];
              }

              // Se o nome da sala corresponder
              if (topicName == widget.parentName) {
                // Extrair itens desta sala
                var topicItems = _extractArrayFromTemplate(topic, 'items');
                for (var item in topicItems) {
                  var fields = _extractFieldsFromTemplate(item);
                  if (fields != null) {
                    String itemName = _extractStringValueFromTemplate(
                        fields, 'name',
                        defaultValue: 'Item sem nome');
                    String? itemDesc =
                        _extractStringValueFromTemplate(fields, 'description');

                    if (itemName.isNotEmpty) {
                      items.add({
                        'name': itemName,
                        'value': itemDesc,
                        'template_id': templateDoc.id,
                      });
                    }
                  }
                }
              }
            }
          }
        }
      } else if (widget.type == 'detail' &&
          widget.parentName.isNotEmpty &&
          widget.itemName != null) {
        // Buscar detalhes de templates para um item específico
        final templatesSnapshot = await firestore.collection('templates').get();

        for (var templateDoc in templatesSnapshot.docs) {
          final templateData = templateDoc.data();
          if (templateData['topics'] is List) {
            for (var topic in templateData['topics']) {
              String topicName = "";
              if (topic is Map &&
                  topic['name'] is Map &&
                  topic['name']['stringValue'] != null) {
                topicName = topic['name']['stringValue'];
              } else if (topic is Map && topic['name'] is String) {
                topicName = topic['name'];
              }

              // Se o nome da sala corresponder
              if (topicName == widget.parentName) {
                // Extrair itens desta sala
                var topicItems = _extractArrayFromTemplate(topic, 'items');
                for (var item in topicItems) {
                  var fields = _extractFieldsFromTemplate(item);
                  if (fields != null) {
                    String itemName = _extractStringValueFromTemplate(
                        fields, 'name',
                        defaultValue: 'Item sem nome');

                    // Se o nome do item corresponder
                    if (itemName == widget.itemName) {
                      // Extrair detalhes deste item
                      var details =
                          _extractArrayFromTemplate(fields, 'details');
                      for (var detail in details) {
                        var detailFields = _extractFieldsFromTemplate(detail);
                        if (detailFields != null) {
                          String detailName = _extractStringValueFromTemplate(
                              detailFields, 'name',
                              defaultValue: 'Detalhe sem nome');
                          String detailType = _extractStringValueFromTemplate(
                              detailFields, 'type',
                              defaultValue: 'text');

                          // Extrair opções para o tipo "select"
                          List<String> options = [];
                          if (detailType == 'select') {
                            var optionsArray = _extractArrayFromTemplate(
                                detailFields, 'options');
                            for (var option in optionsArray) {
                              if (option is Map &&
                                  option.containsKey('stringValue')) {
                                options.add(option['stringValue']);
                              } else if (option is String) {
                                options.add(option);
                              }
                            }

                            // Verificar se há um campo optionsText como alternativa
                            if (options.isEmpty &&
                                detailFields.containsKey('optionsText')) {
                              String optionsText =
                                  _extractStringValueFromTemplate(
                                      detailFields, 'optionsText',
                                      defaultValue: '');
                              if (optionsText.isNotEmpty) {
                                options = optionsText
                                    .split(',')
                                    .map((e) => e.trim())
                                    .toList();
                              }
                            }
                          }

                          bool required = false;
                          if (detailFields.containsKey('required')) {
                            if (detailFields['required'] is bool) {
                              required = detailFields['required'];
                            } else if (detailFields['required'] is Map &&
                                detailFields['required']
                                    .containsKey('booleanValue')) {
                              required =
                                  detailFields['required']['booleanValue'];
                            }
                          }

                          items.add({
                            'name': detailName,
                            'type': detailType,
                            'options': options,
                            'required': required,
                            'template_id': templateDoc.id,
                          });
                        }
                      }
                    }
                  }
                }
              }
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
      print('Erro ao carregar templates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Métodos auxiliares para extrair dados do template
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];

    // Caso 1: Já é uma lista
    if (data[key] is List) {
      return data[key];
    }

    // Caso 2: Formato Firestore (arrayValue)
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

    // Caso 1: Já é um mapa de campos
    if (data is Map && data.containsKey('fields')) {
      return Map<String, dynamic>.from(data['fields']);
    }

    // Caso 2: Formato complexo Firestore
    if (data is Map &&
        data.containsKey('mapValue') &&
        data['mapValue'] is Map &&
        data['mapValue'].containsKey('fields')) {
      return Map<String, dynamic>.from(data['mapValue']['fields']);
    }

    // Caso 3: Mapa simples
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  String _extractStringValueFromTemplate(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    // Caso 1: Direto como string
    if (data[key] is String) {
      return data[key];
    }

    // Caso 2: Formato Firestore (stringValue)
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }

    return defaultValue;
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

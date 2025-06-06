// lib/presentation/screens/inspection/components/non_conformity_form.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NonConformityForm extends StatefulWidget {
  final List<Topic> topics;
  final List<Item> items;
  final List<Detail> details;
  final Topic? selectedTopic;
  final Item? selectedItem;
  final Detail? selectedDetail;
  final String inspectionId;
  final bool isOffline;
  final Function(Topic) onTopicSelected;
  final Function(Item) onItemSelected;
  final Function(Detail) onDetailSelected;
  final VoidCallback onNonConformitySaved;

  const NonConformityForm({
    super.key,
    required this.topics,
    required this.items,
    required this.details,
    required this.selectedTopic,
    required this.selectedItem,
    required this.selectedDetail,
    required this.inspectionId,
    required this.isOffline,
    required this.onTopicSelected,
    required this.onItemSelected,
    required this.onDetailSelected,
    required this.onNonConformitySaved,
  });

  @override
  State<NonConformityForm> createState() => _NonConformityFormState();
}

class _NonConformityFormState extends State<NonConformityForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _correctiveActionController = TextEditingController();
  final ServiceFactory _serviceFactory = ServiceFactory();

  bool _isCreating = false;
  DateTime? _deadline;
  String _severity = 'Média'; // Valor padrão

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  Future<void> _saveNonConformity() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.selectedTopic == null ||
        widget.selectedItem == null ||
        widget.selectedDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um tópico, item e detalhe')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Extract necessary IDs
      final topicId = widget.selectedTopic!.id;
      final itemId = widget.selectedItem!.id;
      final detailId = widget.selectedDetail!.id;

      if (topicId == null || itemId == null || detailId == null) {
        throw Exception('Tópico, item ou detalhe sem ID válido');
      }

      // Prepare non-conformity data
      final nonConformityData = {
        'description': _descriptionController.text,
        'severity': _severity,
        'corrective_action': _correctiveActionController.text.isEmpty
            ? null
            : _correctiveActionController.text,
        'deadline': _deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Add the non-conformity to the appropriate subcollection
      await _serviceFactory.coordinator.saveNonConformity({
        'inspection_id': widget.inspectionId,
        'topic_id': topicId,
        'item_id': itemId,
        'detail_id': detailId,
        ...nonConformityData,
      });

      // Reset the form
      _descriptionController.clear();
      _correctiveActionController.clear();
      setState(() {
        _deadline = null;
        _severity = 'Média';
        _isCreating = false;
      });

      // Notify parent
      widget.onNonConformitySaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar não conformidade: $e')),
        );
        debugPrint(e as String?);
      }
    }
  }

  Future<void> _pickDeadlineDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(), // Only Topic, Item, Detail selection
            const SizedBox(height: 5),
            Card(
              // Card for non-conformity details
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      // Description
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição', // Translated
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe uma descrição' // Translated
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      // Corrective Action
                      controller: _correctiveActionController,
                      decoration: const InputDecoration(
                        labelText: 'Ação Corretiva (opcional)', // Translated
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      // Deadline
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Prazo', // Translated
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDeadlineDate,
                        ),
                      ),
                      controller: TextEditingController(
                        text: _deadline != null
                            ? DateFormat('dd/MM/yyyy').format(_deadline!)
                            : '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // Severity
                      decoration: const InputDecoration(
                        labelText: 'Severidade', // Translated
                        border: OutlineInputBorder(),
                      ),
                      value: _severity,
                      items: const [
                        DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                        DropdownMenuItem(value: 'Média', child: Text('Média')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _severity = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              // Save Button
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _saveNonConformity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrar Não Conformidade'), // Translated
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    // Now only contains Topic, Item, and Detail dropdowns
    return Card(
      margin: const EdgeInsets.only(bottom: 0), // Adjusted margin
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Localização da Não Conformidade', // Translated
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Topic dropdown
            DropdownButtonFormField<Topic>(
              decoration: const InputDecoration(
                labelText: 'Tópico', // Updated from 'Ambiente'
                border: OutlineInputBorder(),
              ),
              value: widget.selectedTopic,
              items: widget.topics.map((topic) {
                return DropdownMenuItem<Topic>(
                  value: topic,
                  child: Text(topic.topicName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onTopicSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Selecione um tópico' : null, // Updated
            ),
            const SizedBox(height: 10),

            // Item dropdown
            DropdownButtonFormField<Item>(
              decoration: const InputDecoration(
                labelText: 'Item', // Translated
                border: OutlineInputBorder(),
              ),
              value: widget.selectedItem,
              items: widget.items.map((item) {
                return DropdownMenuItem<Item>(
                  value: item,
                  child: Text(item.itemName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onItemSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Selecione um item' : null, // Translated
            ),
            const SizedBox(height: 10),

            // Detail dropdown
            DropdownButtonFormField<Detail>(
              decoration: const InputDecoration(
                labelText: 'Detalhe', // Translated
                border: OutlineInputBorder(),
              ),
              value: widget.selectedDetail,
              items: widget.details.map((detail) {
                return DropdownMenuItem<Detail>(
                  value: detail,
                  child: Text(detail.detailName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onDetailSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Selecione um detalhe' : null, // Translated
            ),
          ],
        ),
      ),
    );
  }
}

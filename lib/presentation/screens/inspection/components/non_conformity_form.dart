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
  String _severity = 'Média';

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  Future<void> _editDescriptionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _descriptionController.text);
        return AlertDialog(
          title: const Text('Descrição da Não Conformidade'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: TextFormField(
                controller: controller,
                maxLines: 8,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Descreva a não conformidade encontrada...',
                    hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      _descriptionController.text = result;
      setState(() {});
    }
  }

  Future<void> _editCorrectiveActionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _correctiveActionController.text);
        return AlertDialog(
          title: const Text('Ação Corretiva'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: TextFormField(
                controller: controller,
                maxLines: 6,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Descreva as ações necessárias para correção...',
                    hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      _correctiveActionController.text = result;
      setState(() {});
    }
  }

  Future<void> _saveNonConformity() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A descrição é obrigatória')),
      );
      return;
    }
    
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
      final topicId = widget.selectedTopic!.id;
      final itemId = widget.selectedItem!.id;
      final detailId = widget.selectedDetail!.id;

      if (topicId == null || itemId == null || detailId == null) {
        throw Exception('Tópico, item ou detalhe sem ID válido');
      }

      final nonConformityData = {
        'description': _descriptionController.text.trim(),
        'severity': _severity,
        'corrective_action': _correctiveActionController.text.trim().isEmpty
            ? null
            : _correctiveActionController.text.trim(),
        'deadline': _deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _serviceFactory.coordinator.saveNonConformity({
        'inspection_id': widget.inspectionId,
        'topic_id': topicId,
        'item_id': itemId,
        'detail_id': detailId,
        ...nonConformityData,
      });

      _resetForm();
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
          SnackBar(
            content: Text('Erro ao registrar não conformidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    _descriptionController.clear();
    _correctiveActionController.clear();
    setState(() {
      _deadline = null;
      _severity = 'Média';
      _isCreating = false;
    });
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
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(),
            const SizedBox(height: 8),
            _buildNonConformityDetailsCard(),
            const SizedBox(height: 8),
            _buildSaveButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Localização da Não Conformidade',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDropdown<Topic>(
              label: 'Tópico',
              value: widget.selectedTopic,
              items: widget.topics,
              onChanged: (value) {
                if (value != null) widget.onTopicSelected(value);
              },
              displayText: (topic) => topic.topicName,
              icon: Icons.home_work_outlined,
            ),
            const SizedBox(height: 12),

            _buildDropdown<Item>(
              label: 'Item',
              value: widget.selectedItem,
              items: widget.items,
              onChanged: (value) {
                if (value != null) widget.onItemSelected(value);
              },
              displayText: (item) => item.itemName,
              icon: Icons.list_alt,
              enabled: widget.selectedTopic != null,
            ),
            const SizedBox(height: 12),

            _buildDropdown<Detail>(
              label: 'Detalhe',
              value: widget.selectedDetail,
              items: widget.details,
              onChanged: (value) {
                if (value != null) widget.onDetailSelected(value);
              },
              displayText: (detail) => detail.detailName,
              icon: Icons.details,
              enabled: widget.selectedItem != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonConformityDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Detalhes da Não Conformidade',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildSeverityDropdown(),
            const SizedBox(height: 12),

            // Description field with popup
            GestureDetector(
              onTap: _editDescriptionDialog,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descrição *',
                    hintText: _descriptionController.text.isEmpty 
                        ? 'Toque para adicionar descrição...' 
                        : null,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description),
                    suffixIcon: const Icon(Icons.edit, size: 18),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Corrective action field with popup
            GestureDetector(
              onTap: _editCorrectiveActionDialog,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _correctiveActionController,
                  decoration: InputDecoration(
                    labelText: 'Ação Corretiva (opcional)',
                    hintText: _correctiveActionController.text.isEmpty 
                        ? 'Toque para adicionar ação corretiva...' 
                        : null,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.build),
                    suffixIcon: const Icon(Icons.edit, size: 18),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildDeadlinePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) displayText,
    required IconData icon,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayText(item), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
    );
  }

  Widget _buildSeverityDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Severidade',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.priority_high),
      ),
      value: _severity,
      items: const [
        DropdownMenuItem(
          value: 'Baixa',
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.blue, size: 12),
              SizedBox(width: 8),
              Text('Baixa'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'Média',
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.orange, size: 12),
              SizedBox(width: 8),
              Text('Média'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'Alta',
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text('Alta'),
            ],
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _severity = value);
      },
    );
  }

  Widget _buildDeadlinePicker() {
    return GestureDetector(
      onTap: _pickDeadlineDate,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Prazo (opcional)',
            hintText: 'Selecione uma data limite',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          controller: TextEditingController(
            text: _deadline != null
                ? DateFormat('dd/MM/yyyy').format(_deadline!)
                : '',
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isCreating ? null : _saveNonConformity,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(
          _isCreating ? 'Salvando...' : 'Registrar Não Conformidade',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
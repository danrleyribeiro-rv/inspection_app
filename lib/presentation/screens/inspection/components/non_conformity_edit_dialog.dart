// lib/presentation/screens/inspection/components/non_conformity_edit_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NonConformityEditDialog extends StatefulWidget {
  final Map<String, dynamic> nonConformity;
  final Function(Map<String, dynamic>) onSave;

  const NonConformityEditDialog({
    super.key,
    required this.nonConformity,
    required this.onSave,
  });

  @override
  State<NonConformityEditDialog> createState() =>
      _NonConformityEditDialogState();
}

class _NonConformityEditDialogState extends State<NonConformityEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _correctiveActionController;
  late String _severity;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.nonConformity['description'] ?? '');
    _correctiveActionController = TextEditingController(
        text: widget.nonConformity['corrective_action'] ?? '');
    _severity = widget.nonConformity['severity'] ?? 'Média';

    // Parse deadline if available
    if (widget.nonConformity['deadline'] != null) {
      try {
        _deadline = DateTime.parse(widget.nonConformity['deadline']);
      } catch (e) {
        debugPrint('Error parsing deadline: $e');
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
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
    return AlertDialog(
      title: const Text('Editar Não Conformidade'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity dropdown
              const Text('Severidade:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
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

              const SizedBox(height: 16),

              // Description field
              const Text('Descrição:'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty
                    ? 'A descrição é obrigatória'
                    : null,
              ),

              const SizedBox(height: 16),

              // Corrective action field
              const Text('Ação Corretiva (opcional):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _correctiveActionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Deadline picker
              const Text('Prazo:'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDeadlineDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    controller: TextEditingController(
                      text: _deadline != null
                          ? DateFormat('dd/MM/yyyy').format(_deadline!)
                          : '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Create updated non-conformity data
              final updatedData = {
                ...widget.nonConformity,
                'description': _descriptionController.text,
                'corrective_action': _correctiveActionController.text.isEmpty
                    ? null
                    : _correctiveActionController.text,
                'severity': _severity,
                'deadline': _deadline?.toIso8601String(),
              };

              widget.onSave(updatedData);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// lib/presentation/screens/inspection/components/non_conformity_edit_dialog.dart
import 'package:flutter/material.dart';

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
  String? _severity;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.nonConformity['description'] ?? '');
    _correctiveActionController = TextEditingController(
        text: widget.nonConformity['corrective_action'] ?? '');
    
    // Normalize severity value to match dropdown options (can be null)
    final severityValue = widget.nonConformity['severity'];
    _severity = severityValue != null && severityValue.isNotEmpty ? _normalizeSeverity(severityValue) : null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  /// Normalize severity values to match dropdown options
  String? _normalizeSeverity(String value) {
    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'baixa':
      case 'low':
        return 'Baixa';
      case 'média':
      case 'media':
      case 'medium':
        return 'Média';
      case 'alta':
      case 'high':
        return 'Alta';
      case 'crítica':
      case 'critica':
      case 'critical':
        return 'Crítica';
      default:
        return null; // No default fallback, return null for unknown values
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

              // Severity dropdown (optional, moved to end)
              const Text('Severidade (opcional):'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.grey, size: 12),
                        SizedBox(width: 8),
                        Text('Não definida'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Baixa',
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Baixa'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Média',
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Média'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Alta',
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Alta'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Crítica',
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Crítica'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _severity = value);
                },
              ),

              const SizedBox(height: 16),

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
                'severity': _severity?.isNotEmpty == true ? _severity : null,
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

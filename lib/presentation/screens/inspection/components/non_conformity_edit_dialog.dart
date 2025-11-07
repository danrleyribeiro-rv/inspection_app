// lib/presentation/screens/inspection/components/non_conformity_edit_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';

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



  Widget _buildCupertinoContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _descriptionController,
          placeholder: 'Digite a descrição',
          maxLines: 3,
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 16),
        const Text('Ação Corretiva (opcional):', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _correctiveActionController,
          placeholder: 'Digite a ação corretiva',
          maxLines: 3,
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 16),
        const Text('Severidade:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCupertinoPicker(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _severity ?? 'Não definida',
                  style: TextStyle(
                    color: _severity == null
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.label,
                  ),
                ),
                const Icon(CupertinoIcons.chevron_down, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCupertinoPicker(BuildContext context) {
    final severities = [null, 'Baixa', 'Média', 'Alta', 'Crítica'];
    int selectedIndex = severities.indexOf(_severity);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Confirmar'),
                  onPressed: () {
                    setState(() => _severity = severities[selectedIndex]);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) => selectedIndex = index,
                children: severities.map((s) => Center(
                  child: Text(s ?? 'Não definida'),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoAlertDialog(
        title: const Text('Editar Não Conformidade'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SingleChildScrollView(
            child: _buildCupertinoContent(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (_descriptionController.text.isEmpty) {
                return; // Simple validation
              }
              final updatedData = {
                ...widget.nonConformity,
                'description': _descriptionController.text,
                'corrective_action': _correctiveActionController.text.isEmpty
                    ? null
                    : _correctiveActionController.text,
                'severity': _severity?.isNotEmpty == true ? _severity : null,
              };
              widget.onSave(updatedData);
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Editar Não Conformidade'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
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
                initialValue: _severity,
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

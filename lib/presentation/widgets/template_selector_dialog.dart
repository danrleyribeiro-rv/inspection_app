// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';

class TemplateSelectorDialog extends StatefulWidget {
  final String title;
  final String type;
  final String parentName;

  const TemplateSelectorDialog({
    super.key,
    required this.title,
    required this.type,
    required this.parentName,
  });

  @override
  State<TemplateSelectorDialog> createState() => _TemplateSelectorDialogState();
}

class _TemplateSelectorDialogState extends State<TemplateSelectorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  bool _isCustom = false;

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
      content: SingleChildScrollView(
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
            ] else
              // Lista de templates seria aqui
              const Text('Templates ainda não implementados'),
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
              Navigator.of(context).pop({
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

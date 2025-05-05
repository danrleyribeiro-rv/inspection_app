// lib/presentation/widgets/rename_dialog.dart
import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  const RenameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
  });

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Digite o novo nome',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, text.isNotEmpty ? text : null);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
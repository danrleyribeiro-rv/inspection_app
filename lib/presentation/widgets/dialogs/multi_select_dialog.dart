import 'package:flutter/material.dart';

class MultiSelectDialog extends StatefulWidget {
  final List<String> options;
  final Set<String> selectedValues;
  final String title;

  const MultiSelectDialog({
    super.key,
    required this.options,
    required this.selectedValues,
    this.title = 'Selecione as opções',
  });

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late Set<String> _tempSelected;
  late List<String> _availableOptions;

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selectedValues);
    _availableOptions = List.from(widget.options);
  }

  void _selectAll() {
    setState(() {
      _tempSelected.clear();
      _tempSelected.addAll(_availableOptions);
    });
  }

  void _clearSelection() {
    setState(() {
      _tempSelected.clear();
    });
  }

  Future<void> _createNewOption() async {
    final newOption = await _showCreateOptionDialog();
    if (newOption != null && newOption.isNotEmpty) {
      setState(() {
        if (!_availableOptions.contains(newOption)) {
          _availableOptions.add(newOption);
        }
        _tempSelected.add(newOption);
      });
    }
  }

  Future<String?> _showCreateOptionDialog() async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text(
            'Nova Opção',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Digite a nova opção...',
              hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOption(int index) async {
    final option = _availableOptions[index];
    final confirmed = await _confirmDeleteOption(option);

    if (confirmed == true) {
      setState(() {
        _availableOptions.removeAt(index);
        _tempSelected.remove(option);
      });
    }
  }

  Future<bool?> _confirmDeleteOption(String option) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Remover Opção',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Deseja remover a opção "$option"?\n\nEsta ação não pode ser desfeita.',
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  void _toggleOption(String option, bool? value) {
    setState(() {
      if (value == true) {
        _tempSelected.add(option);
      } else {
        _tempSelected.remove(option);
      }
    });
  }

  void _confirm() {
    // Retorna um Map com as seleções e opções modificadas
    Navigator.of(context).pop({
      'selectedValues': _tempSelected,
      'options': _availableOptions,
      'optionsModified': _availableOptions.length != widget.options.length ||
          !_availableOptions.every((opt) => widget.options.contains(opt)),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de ações com ícones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Selecionar todas
                IconButton(
                  icon: const Icon(Icons.check_box, color: Colors.green, size: 28),
                  tooltip: 'Selecionar todas',
                  onPressed: _selectAll,
                ),
                // Limpar seleção
                IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.red, size: 28),
                  tooltip: 'Limpar seleção',
                  onPressed: _clearSelection,
                ),
                // Criar nova opção
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 28),
                  tooltip: 'Criar nova opção',
                  onPressed: _createNewOption,
                ),
              ],
            ),
            const Divider(),
            // Lista de opções disponíveis (máximo 5 visíveis, scroll para demais)
            Flexible(
              child: LimitedBox(
                maxHeight: 250, // ~5 itens de altura 50px cada
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableOptions.length,
                  itemBuilder: (context, index) {
                    final option = _availableOptions[index];
                    final isSelected = _tempSelected.contains(option);

                    return CheckboxListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          // Botão para remover opção
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Remover opção',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteOption(index),
                          ),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (value) => _toggleOption(option, value),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

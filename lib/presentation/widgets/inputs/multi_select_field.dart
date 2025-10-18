import 'package:flutter/material.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/multi_select_dialog.dart';

class MultiSelectField extends StatelessWidget {
  final List<String> options;
  final Set<String> selectedValues;
  final Function(Set<String> selectedValues, List<String> updatedOptions, bool optionsModified) onChanged;
  final Color? accentColor;
  final Color? textColor;

  const MultiSelectField({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.accentColor,
    this.textColor,
  });

  Future<void> _showDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MultiSelectDialog(
        options: options,
        selectedValues: selectedValues,
      ),
    );

    if (result != null) {
      final Set<String> newSelectedValues = result['selectedValues'] as Set<String>;
      final List<String> newOptions = result['options'] as List<String>;
      final bool optionsModified = result['optionsModified'] as bool;

      onChanged(newSelectedValues, newOptions, optionsModified);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveAccentColor = accentColor ?? (isDark ? const Color(0xFF81C784) : Colors.green);
    final effectiveTextColor = textColor ?? (isDark ? theme.colorScheme.onSurface : const Color(0xFF1B5E20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedValues.isEmpty
                      ? Text(
                          'Selecione uma ou mais opções',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: selectedValues
                              .map((value) => Chip(
                                    label: Text(
                                      value,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onDeleted: () {
                                      final newSelected = Set<String>.from(selectedValues);
                                      newSelected.remove(value);
                                      onChanged(newSelected, options, false);
                                    },
                                    deleteIconColor: Colors.white,
                                    backgroundColor: effectiveAccentColor,
                                    labelStyle: const TextStyle(color: Colors.white),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ))
                              .toList(),
                        ),
                ),
                Icon(Icons.arrow_drop_down, color: effectiveTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

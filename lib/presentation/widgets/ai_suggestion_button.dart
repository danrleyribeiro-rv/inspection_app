// lib/presentation/widgets/ai_suggestion_button.dart
import 'package:flutter/material.dart';
// No changes needed to GeminiService import

class AISuggestionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  // Keep dynamic for flexibility, but expect List<Map<String, dynamic>>
  final Function(dynamic) onSuggestionSelected;
  final Function() onGeneratingSuggestions;
  final Function(String) onError;
  // Expect Future<List<Map<String, dynamic>>>
  final Future<List<dynamic>> Function() generateSuggestions;

  const AISuggestionButton({
    super.key,
    this.icon = Icons.lightbulb_outline,
    this.color = Colors.blue, // Consider using Theme.of(context).colorScheme.secondary
    required this.tooltip,
    required this.onSuggestionSelected,
    required this.onGeneratingSuggestions,
    required this.onError,
    required this.generateSuggestions,
  });

  @override
  State<AISuggestionButton> createState() => _AISuggestionButtonState();
}

class _AISuggestionButtonState extends State<AISuggestionButton> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isGenerating
          ? SizedBox(
              width: 24,
              height: 24,
              // Use theme color for progress indicator
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              ),
            )
          : Icon(widget.icon),
      color: widget.color,
      tooltip: widget.tooltip,
      onPressed: _isGenerating ? null : _showSuggestions,
    );
  }

  void _showSuggestions() async {
    setState(() => _isGenerating = true);
    widget.onGeneratingSuggestions(); // Notify parent that generation started

    try {
      final suggestions = await widget.generateSuggestions();

      if (!mounted) return; // Check if widget is still in the tree

      setState(() => _isGenerating = false);

      if (suggestions.isEmpty) {
        // Use a more specific message if possible (e.g., based on GeminiService output)
        widget.onError('Nenhuma sugestão gerada ou falha na comunicação com IA.');
        return;
      }

      // Improve the dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sugestões de Tópicos'),
          content: SizedBox(
            width: double.maxFinite, // Make dialog use available width
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                // Defensive programming: Check if suggestion is a Map
                if (suggestion is Map<String, dynamic>) {
                  final roomName = suggestion['room_name'] as String? ?? 'Desconhecido';
                  final items = suggestion['items'] as List<dynamic>?;
                  final itemCount = items?.length ?? 0;
                  return ListTile(
                    leading: const Icon(Icons.meeting_room_outlined), // Add an icon
                    title: Text(roomName),
                    subtitle: Text('$itemCount ${itemCount == 1 ? 'tópico' : 'tópicos'} sugeridos'), // Show item count
                    onTap: () {
                      Navigator.of(context).pop(); // Close dialog first
                      widget.onSuggestionSelected(suggestion); // Pass the selected suggestion map
                    },
                  );
                } else {
                  // Handle unexpected suggestion format
                   return ListTile(
                     leading: Icon(Icons.error_outline, color: Colors.red),
                     title: Text('Formato inválido'),
                     subtitle: Text('Sugestão $index não pôde ser lida.'),
                   );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        print("Error caught in _showSuggestions: $e"); // Log the error
        widget.onError('Erro ao gerar sugestões: ${e.toString()}'); // Pass error message
      }
    }
  }
}
// lib/presentation/screens/inspection/components/empty_topic_state.dart
import 'package:flutter/material.dart';

class EmptyTopicState extends StatelessWidget {
  final VoidCallback onAddTopic;

  const EmptyTopicState({
    super.key,
    required this.onAddTopic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 80, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            'Nenhum tópico adicionado',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Clique no botão + para adicionar tópicos',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color
                  ?.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddTopic,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar tópico'),
          ),
        ],
      ),
    );
  }
}

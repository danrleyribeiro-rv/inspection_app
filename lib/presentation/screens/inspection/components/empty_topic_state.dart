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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Nenhum tópico adicionado',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Clique no botão + para adicionar tópicos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
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

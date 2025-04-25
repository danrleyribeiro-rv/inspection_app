// lib/presentation/screens/inspection/components/empty_room_state.dart
import 'package:flutter/material.dart';

class EmptyRoomState extends StatelessWidget {
  final VoidCallback onAddRoom;

  const EmptyRoomState({
    super.key,
    required this.onAddRoom,
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
            'No rooms added',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the + button to add rooms',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddRoom,
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
          ),
        ],
      ),
    );
  }
}
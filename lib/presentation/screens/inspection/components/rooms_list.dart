// lib/presentation/screens/inspection/components/rooms_list.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';

class RoomsList extends StatelessWidget {
  final List<Room> rooms;
  final int expandedRoomIndex;
  final Function(Room) onRoomUpdated;
  final Function(int) onRoomDeleted;
  final Function(Room) onRoomDuplicated;
  final Function(int) onExpansionChanged;

  const RoomsList({
    super.key,
    required this.rooms,
    required this.expandedRoomIndex,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.onRoomDuplicated,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        
        return RoomWidget(
          room: room,
          onRoomUpdated: onRoomUpdated,
          onRoomDeleted: onRoomDeleted,
          onRoomDuplicated: onRoomDuplicated,
          isExpanded: index == expandedRoomIndex,
          onExpansionChanged: () => onExpansionChanged(index),
        );
      },
    );
  }
}
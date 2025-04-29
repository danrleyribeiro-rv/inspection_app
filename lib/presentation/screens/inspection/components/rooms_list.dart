// lib/presentation/screens/inspection/components/rooms_list.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';

class RoomsList extends StatefulWidget {
  final List<Room> rooms;
  final int expandedRoomIndex;
  final Function(Room) onRoomUpdated;
  final Function(String) onRoomDeleted;
  final Function(Room) onRoomDuplicated;
  final Function(int) onExpansionChanged;
  final String inspectionId;

  const RoomsList({
    super.key,
    required this.rooms,
    required this.expandedRoomIndex,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.onRoomDuplicated,
    required this.onExpansionChanged,
    required this.inspectionId,
  });

  @override
  State<RoomsList> createState() => _RoomsListState();
}

class _RoomsListState extends State<RoomsList> {
  final _inspectionService = FirebaseInspectionService();
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      itemCount: widget.rooms.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final room = widget.rooms[index];
        
        return RoomWidget(
          key: ValueKey(room.id),
          room: room,
          onRoomUpdated: widget.onRoomUpdated,
          onRoomDeleted: widget.onRoomDeleted,
          onRoomDuplicated: widget.onRoomDuplicated,
          isExpanded: index == widget.expandedRoomIndex,
          onExpansionChanged: () => widget.onExpansionChanged(index),
        );
      },
    );
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (_isReordering) return;
    setState(() => _isReordering = true);

    // Ajustar o newIndex quando arrastar para baixo
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    try {
      // Criar uma cópia da lista atual
      final List<Room> updatedRooms = List.from(widget.rooms);
      
      // Reordenar a lista localmente
      final Room item = updatedRooms.removeAt(oldIndex);
      updatedRooms.insert(newIndex, item);
      
      // Obter a lista de IDs na nova ordem
      final List<String> roomIds = updatedRooms
          .where((room) => room.id != null)
          .map((room) => room.id!)
          .toList();
      
      // Atualizar no Firestore
      await _inspectionService.reorderRooms(widget.inspectionId, roomIds);
      
      // A tela será atualizada pelo carregamento automático de dados
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reordenar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
    }
  }
}
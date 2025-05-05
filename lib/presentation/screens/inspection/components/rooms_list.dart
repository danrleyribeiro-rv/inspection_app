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
  final VoidCallback? onRoomsReordered;

  const RoomsList({
    super.key,
    required this.rooms,
    required this.expandedRoomIndex,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
    required this.onRoomDuplicated,
    required this.onExpansionChanged,
    required this.inspectionId,
    this.onRoomsReordered,
  });

  @override
  State<RoomsList> createState() => _RoomsListState();
}

class _RoomsListState extends State<RoomsList> {
  final _inspectionService = FirebaseInspectionService();
  bool _isReordering = false;
  late List<Room> _localRooms;

  @override
  void initState() {
    super.initState();
    _localRooms = List.from(widget.rooms);
  }

  @override
  void didUpdateWidget(RoomsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rooms != oldWidget.rooms) {
      _localRooms = List.from(widget.rooms);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      itemCount: _localRooms.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final room = _localRooms[index];
        
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
      // Reordenar a lista local primeiro
      setState(() {
        final room = _localRooms.removeAt(oldIndex);
        _localRooms.insert(newIndex, room);
      });
      
      // Obter a lista de IDs na nova ordem
      final List<String> roomIds = _localRooms
          .where((room) => room.id != null)
          .map((room) => room.id!)
          .toList();
      
      // Atualizar no Firestore
      await _inspectionService.reorderRooms(widget.inspectionId, roomIds);
      
      // Chamar o callback para atualizar os dados
      widget.onRoomsReordered?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambientes reordenados com sucesso'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Em caso de erro, reverter para a ordem original
      setState(() {
        _localRooms = List.from(widget.rooms);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reordenar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
    }
  }
}
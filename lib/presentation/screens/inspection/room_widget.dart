// lib/presentation/screens/inspection/room_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/inspection/item_widget.dart';

class RoomWidget extends StatefulWidget {
  final dynamic room;
  final int roomIndex;
  final int inspectionId;
  final Function(String, String, Map<String, dynamic>) onDataChanged;
  final Map<String, Map<String, dynamic>> inspectionData;
  final List<dynamic> rooms;
  final Map<int, int> roomIndexToIdMap;
  final Map<String, int> itemIndexToIdMap;

  const RoomWidget({
    super.key,
    required this.room,
    required this.roomIndex,
    required this.inspectionId,
    required this.onDataChanged,
    required this.inspectionData,
    required this.rooms,
    required this.roomIndexToIdMap,
    required this.itemIndexToIdMap,
  });

  @override
  State<RoomWidget> createState() => _RoomWidgetState();
}

class _RoomWidgetState extends State<RoomWidget> {
  int _expandedItemIndex = -1; // Track expanded item index

  @override
  Widget build(BuildContext context) {
    final roomName = widget.room['name'] ?? 'Unnamed Room';
    final roomId = widget.room['id'];
    final roomKey = 'room_${roomId ?? widget.roomIndex}';

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.room['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.room['description'],
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            ExpansionPanelList.radio(
              // Use ExpansionPanelList.radio here as well
              expandedHeaderPadding: EdgeInsets.zero,
              elevation: 0,
              children: List.generate(widget.room['items'].length, (itemIndex) {
                final item = widget.room['items'][itemIndex];
                return ExpansionPanelRadio(
                  value: itemIndex,
                  canTapOnHeader: true,
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      title: Text(item['name'] ?? 'Unnamed Item'),
                    );
                  },
                  body: ItemWidget(
                    item: item,
                    itemIndex: itemIndex,
                    roomKey: roomKey,
                    inspectionId: widget.inspectionId,
                    onDataChanged: widget.onDataChanged,
                    inspectionData: widget.inspectionData,
                    rooms: widget.rooms,
                    expandedDetailIndex: -1,
                    onDetailExpanded: (detailIndex) {
                      setState(() {
                        _expandedItemIndex =
                            _expandedItemIndex == itemIndex ? -1 : itemIndex;
                      });
                    },
                    roomIndexToIdMap: widget.roomIndexToIdMap,
                    itemIndexToIdMap: widget.itemIndexToIdMap,
                    isExpanded: _expandedItemIndex == itemIndex,
                    onExpansionChanged: () {
                      setState(() {
                        _expandedItemIndex =
                            _expandedItemIndex == itemIndex ? -1 : itemIndex;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
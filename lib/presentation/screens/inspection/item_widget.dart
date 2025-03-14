// lib/presentation/screens/inspection/item_widget.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';

class ItemWidget extends StatefulWidget {
  final dynamic item;
  final int itemIndex;
  final String roomKey;
  final int inspectionId;
  final Function(String, String, Map<String, dynamic>) onDataChanged;
  final Map<String, Map<String, dynamic>> inspectionData;
  final List<dynamic> rooms;
  final int expandedDetailIndex; // Track expanded detail index
  final ValueChanged<int> onDetailExpanded;
  final Map<int, int> roomIndexToIdMap;
  final Map<String, int> itemIndexToIdMap;
  final bool isExpanded; // Added isExpanded
  final VoidCallback onExpansionChanged; // Added onExpansionChanged

  const ItemWidget({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.roomKey,
    required this.inspectionId,
    required this.onDataChanged,
    required this.inspectionData,
    required this.rooms,
    required this.expandedDetailIndex,
    required this.onDetailExpanded,
    required this.roomIndexToIdMap,
    required this.itemIndexToIdMap,
    required this.isExpanded, // Initialize isExpanded
    required this.onExpansionChanged, // Initialize onExpansionChanged
  });

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(covariant ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.item['name'] ?? 'Unnamed Item';
    final itemId = widget.item['id'];
    final itemKey = '${widget.roomKey}-item_${itemId ?? widget.itemIndex}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (widget.item['description'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.item['description'],
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              ExpansionPanelList.radio(
                expandedHeaderPadding: EdgeInsets.zero,
                elevation: 0,
                children: List.generate(widget.item['details'].length,
                    (detailIndex) {
                  final detail = widget.item['details'][detailIndex];
                  return ExpansionPanelRadio(
                    value: detailIndex,
                    canTapOnHeader: true,
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text(detail['name'] ?? 'Unnamed Detail'),
                      );
                    },
                    body: DetailWidget(
                      detail: detail,
                      itemKey: itemKey,
                      inspectionId: widget.inspectionId,
                      onDataChanged: widget.onDataChanged,
                      inspectionData: widget.inspectionData,
                      rooms: widget.rooms,
                      roomIndexToIdMap: widget.roomIndexToIdMap,
                      itemIndexToIdMap: widget.itemIndexToIdMap,
                      isExpanded: widget.expandedDetailIndex == detailIndex,
                      onExpansionChanged: () {
                        widget.onDetailExpanded(detailIndex);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
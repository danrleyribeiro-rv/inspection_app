// lib/presentation/screens/media/components/media_filter_panel.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';

class MediaFilterPanel extends StatefulWidget {
  final String inspectionId;
  final List<Room> rooms;
  final String? selectedRoomId;
  final String? selectedItemId;
  final String? selectedDetailId;
  final bool? isNonConformityOnly;
  final String? mediaType;
  final Function({
    String? roomId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) onApplyFilters;
  final VoidCallback onClearFilters;

  const MediaFilterPanel({
    super.key,
    required this.inspectionId,
    required this.rooms,
    this.selectedRoomId,
    this.selectedItemId,
    this.selectedDetailId,
    this.isNonConformityOnly,
    this.mediaType,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<MediaFilterPanel> createState() => _MediaFilterPanelState();
}

class _MediaFilterPanelState extends State<MediaFilterPanel> {
  final _inspectionService = FirebaseInspectionService();

  // Local state
  String? _roomId;
  String? _itemId;
  String? _detailId;
  bool _isNonConformityOnly = false;
  String? _mediaType;

  // Data lists
  List<Item> _items = [];
  List<Detail> _details = [];

  // Loading flags
  bool _isLoadingItems = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();

    // Initialize with provided values
    _roomId = widget.selectedRoomId;
    _itemId = widget.selectedItemId;
    _detailId = widget.selectedDetailId;
    _isNonConformityOnly = widget.isNonConformityOnly ?? false;
    _mediaType = widget.mediaType;

    // Load items and details if room/item is selected
    if (_roomId != null) {
      _loadItems(_roomId!);
    }

    if (_roomId != null && _itemId != null) {
      _loadDetails(_roomId!, _itemId!);
    }
  }

  Future<void> _loadItems(String roomId) async {
    setState(() => _isLoadingItems = true);

    try {
      final items = await _inspectionService.getItems(
        widget.inspectionId,
        roomId,
      );

      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      print('Error loading items: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadDetails(String roomId, String itemId) async {
    setState(() => _isLoadingDetails = true);

    try {
      final details = await _inspectionService.getDetails(
        widget.inspectionId,
        roomId,
        itemId,
      );

      setState(() {
        _details = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      print('Error loading details: $e');
      setState(() => _isLoadingDetails = false);
    }
  }

  void _applyFilters() {
    // Call the parent function with the selected filters
    widget.onApplyFilters(
      roomId: _roomId,
      itemId: _itemId,
      detailId: _detailId,
      isNonConformityOnly: _isNonConformityOnly,
      mediaType: _mediaType,
    );

    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _roomId = null;
      _itemId = null;
      _detailId = null;
      _isNonConformityOnly = false;
      _mediaType = null;
      _items = [];
      _details = [];
    });

    widget.onClearFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtrar Mídia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Room filter
          const Text('Tópico'),
          DropdownButtonFormField<String>(
            value: _roomId,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Selecione um tópico',
            ),
            items: widget.rooms.map((room) {
              return DropdownMenuItem<String>(
                value: room.id,
                child: Text(room.roomName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _roomId = value;
                _itemId = null;
                _detailId = null;
                _items = [];
                _details = [];
              });

              if (value != null) {
                _loadItems(value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Item filter
          const Text('Item'),
          _isLoadingItems
              ? const Center(child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  value: _itemId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Selecione um item',
                  ),
                  items: _items.map((item) {
                    return DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.itemName),
                    );
                  }).toList(),
                  onChanged: _roomId == null
                      ? null
                      : (value) {
                          setState(() {
                            _itemId = value;
                            _detailId = null;
                            _details = [];
                          });

                          if (value != null && _roomId != null) {
                            _loadDetails(_roomId!, value);
                          }
                        },
                ),
          const SizedBox(height: 16),

          // Detail filter
          const Text('Detalhe'),
          _isLoadingDetails
              ? const Center(child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  value: _detailId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Selecione um detalhe',
                  ),
                  items: _details.map((detail) {
                    return DropdownMenuItem<String>(
                      value: detail.id,
                      child: Text(detail.detailName),
                    );
                  }).toList(),
                  onChanged: _itemId == null
                      ? null
                      : (value) {
                          setState(() {
                            _detailId = value;
                          });
                        },
                ),
          const SizedBox(height: 16),

          // Non-conformity filter
          SwitchListTile(
            title: const Text('Apenas Não Conformidades'),
            value: _isNonConformityOnly,
            onChanged: (value) {
              setState(() {
                _isNonConformityOnly = value;
              });
            },
            activeColor: Colors.orange,
          ),

          // Media type filter
          const Text('Tipo de Mídia'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String?>(
                  title: const Text('Todos'),
                  value: null,
                  groupValue: _mediaType,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Fotos'),
                  value: 'image',
                  groupValue: _mediaType,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Vídeos'),
                  value: 'video',
                  groupValue: _mediaType,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpar Filtros'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Aplicar Filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

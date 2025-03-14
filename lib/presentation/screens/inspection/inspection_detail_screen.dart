// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/presentation/screens/home/chat_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/detail_widget.dart';

class InspectionDetailScreen extends StatefulWidget {
  final int inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _inspection;
  List<dynamic> _rooms = [];
  final Map<String, Map<String, dynamic>> _inspectionData = {};
  int _expandedRoomIndex = -1;
  int _selectedRoomIndex = -1; // Track selected room in landscape
  int _selectedItemIndex = -1; // Track selected item in landscape

  Map<int, int> _roomIndexToIdMap = {};
  Map<String, int> _itemIndexToIdMap = {};

  @override
  void initState() {
    super.initState();
    _loadInspection();
  }

  Future<void> _loadInspection() async {
    // ... (rest of the _loadInspection function is the same)
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('inspections')
          .select('*, templates!left(rooms)')
          .eq('id', widget.inspectionId)
          .single();

      _inspection = data;
      if (data['templates'] != null && data['templates']['rooms'] != null) {
        _rooms = List<dynamic>.from(data['templates']['rooms']);
      } else {
        _rooms = _getFreeModeStructure();
      }

      await _loadInspectionData();
      if (_roomIndexToIdMap.isEmpty) {
        await _initializeInspectionData();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading inspection: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inspection: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadInspectionData() async {
    // ... (rest of the _loadInspectionData function is the same)
     try {
      final roomsData = await _supabase
          .from('rooms')
          .select('id, room_name, position')
          .eq('inspection_id', widget.inspectionId);

      if (roomsData.isEmpty) return;

      Map<int, String> roomIdToName = {};
      _roomIndexToIdMap = {};
      for (final room in roomsData) {
        roomIdToName[room['id'] as int] = room['room_name'] as String;
        _roomIndexToIdMap[room['position'] as int] = room['id'] as int;
      }

      final itemsData = await _supabase
          .from('room_items')
          .select('id, room_id, item_name, position')
          .eq('inspection_id', widget.inspectionId);

      _itemIndexToIdMap = {};
      for (final item in itemsData) {
        final roomId = item['room_id'] as int;
        final roomIndex =
            roomsData.firstWhere((r) => r['id'] == roomId)['position'] as int;
        final itemIndex = item['position'] as int;
        _itemIndexToIdMap['$roomIndex-$itemIndex'] = item['id'] as int;
      }

      final detailsData = await _supabase
          .from('item_details')
          .select(
              'room_id, room_item_id, detail_name, detail_value, observation, is_damaged')
          .eq('inspection_id', widget.inspectionId);

      for (final detail in detailsData) {
        final roomId = detail['room_id'] as int?;
        final itemId = detail['room_item_id'] as int?;
        final detailName = detail['detail_name'] as String?;

        if (roomId == null || itemId == null || detailName == null) {
          print('Warning: Missing data in item_details. Skipping.');
          continue;
        }

        final itemPosition =
            itemsData.firstWhere((item) => item['id'] == itemId)['position']
                as int;
        final itemName = itemsData.firstWhere(
              (item) => item['id'] == itemId,
              orElse: () => {'item_name': 'Unknown Item'},
            )['item_name'] as String? ??
            'Unknown Item';

        final roomName = roomIdToName[roomId] ?? 'Unknown Room';

        final roomKey = 'room_$roomId';
        final roomIndex =
            roomsData.firstWhere((r) => r['id'] == roomId)['position'] as int;
        final itemKey = 'room_$roomIndex-item_$itemPosition';

        _inspectionData.putIfAbsent(roomKey, () => {});
        _inspectionData[roomKey]!.putIfAbsent(itemKey, () => {});
        _inspectionData[roomKey]![itemKey] = {
          'roomName': roomName,
          'itemName': itemName,
          'detail_name': detailName,
          'detail_value': detail['detail_value'],
          'observation': detail['observation'],
          'is_damaged': detail['is_damaged'] ?? false,
        };
      }
      print('Inspection data loaded successfully');
    } catch (e) {
      print('Error loading existing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading existing data: $e')),
        );
      }
    }
  }

  Future<void> _initializeInspectionData() async {
    // ... (rest of the _initializeInspectionData function is the same)
      try {
      for (int roomIndex = 0; roomIndex < _rooms.length; roomIndex++) {
        final room = _rooms[roomIndex];
        final roomResponse = await _supabase.from('rooms').insert({
          'inspection_id': widget.inspectionId,
          'room_name': room['name'],
          'position': roomIndex,
          'room_label': room['description'],
          'tags': room['tags'],
        }).select('id');
        print('Room inserted: ${room['name']}');

        final roomId = roomResponse[0]['id'] as int;
        _roomIndexToIdMap[roomIndex] = roomId;

        if (room['items'] != null) {
          for (int itemIndex = 0; itemIndex < room['items'].length; itemIndex++) {
            final item = room['items'][itemIndex];
            final itemResponse = await _supabase.from('room_items').insert({
              'room_id': roomId,
              'inspection_id': widget.inspectionId,
              'item_name': item['name'],
              'position': itemIndex,
              'item_label': item['description'],
            }).select('id');
            print('Item inserted: ${item['name']} in Room ID: $roomId');

            final itemId = itemResponse[0]['id'] as int;
            _itemIndexToIdMap['$roomIndex-$itemIndex'] = itemId;

            if (item['details'] != null) {
              for (final detail in item['details']) {
                await _supabase.from('item_details').insert({
                  'room_item_id': itemId,
                  'inspection_id': widget.inspectionId,
                  'room_id': roomId,
                  'detail_name': detail['name'],
                  'position': itemIndex,
                  'detail_value': null,
                  'observation': null,
                  'is_damaged': false,
                  'tags': detail['tags']
                });
                print('Detail inserted: ${detail['name']} for Item ID: $itemId');
              }
            }
          }
        }
      }
      print('Inspection data initialized successfully');
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing data: $e')),
        );
        rethrow;
      }
    }
  }

  List<dynamic> _getFreeModeStructure() {
    return [
       {
        "name": "Sala de Estar",
        "description": "Área principal de convivência",
        "media_requirements": {
          "images": {"max": 5, "min": 0},
          "videos": {"max": 1, "min": 0}
        },
        "items": [
          {
            "name": "Paredes",
            "description": "Verificar pintura, rachaduras, etc.",
            "media_requirements": {
              "images": {"max": 3, "min": 1},
              "videos": {"max": 0, "min": 0}
            },
            "details": [
              {
                "name": "Condição da Pintura",
                "type": "select",
                "options": ["Ótima", "Boa", "Regular", "Ruim"],
                "optionsText": "Ótima, Boa, Regular, Ruim",
                "required": true,
                "media_requirements": {
                  "images": {"max": 2, "min": 1},
                  "videos": {"max": 0, "min": 0}
                }
              },
              {
                "name": "Rachaduras",
                "type": "text",
                "required": false,
                "media_requirements": {
                  "images": {"max": 3, "min": 0},
                  "videos": {"max": 1, "min": 0}
                }
              }
            ]
          },
          {
            "name": "Piso",
            "description": "Verificar estado, etc.",
            "media_requirements": {
              "images": {"max": 3, "min": 1},
              "videos": {"max": 0, "min": 0}
            },
            "details": [
              {
                "name": "Tipo de piso",
                "type": "select",
                "options": ["Cerâmica", "Madeira", "Porcelanato", "Outro"],
                "optionsText": "Cerâmica, Madeira, Porcelanato, Outro",
                "required": true,
                "media_requirements": {
                  "images": {"max": 2, "min": 1},
                  "videos": {"max": 0, "min": 0}
                }
              },
              {
                "name": "Estado geral",
                "type": "text",
                "required": false,
                "media_requirements": {
                  "images": {"max": 3, "min": 0},
                  "videos": {"max": 1, "min": 0}
                }
              }
            ]
          }
        ]
      }
    ];
  }

  bool _validateForm() {
    return true;
  }

  Future<void> _saveInspectionData() async {
    // ... (rest of the _saveInspectionData function is the same)
     if (!_validateForm()) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Salvamento'),
        content:
            const Text('Tem certeza que deseja salvar os dados da vistoria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _saveRoomsData(); // Save rooms and their children
      print('Inspection data saved successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection data saved!')),
        );
        _loadInspection();
      }
    } catch (e) {
      print('Error saving inspection data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving inspection data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveRoomsData() async {
    // ... (rest of the _saveRoomsData function is the same)
     final existingRooms = await _supabase
        .from('rooms')
        .select('id, position')
        .eq('inspection_id', widget.inspectionId);

    Map<int, int> existingRoomIndexToId = {};
    for (final room in existingRooms) {
      existingRoomIndexToId[room['position'] as int] = room['id'] as int;
    }

    for (int roomIndex = 0; roomIndex < _rooms.length; roomIndex++) {
      final room = _rooms[roomIndex];
      int roomId;

      if (existingRoomIndexToId.containsKey(roomIndex)) {
        roomId = existingRoomIndexToId[roomIndex]!;
        await _supabase.from('rooms').update({
          'room_name': room['name'],
          'position': roomIndex,
          'room_label': room['description'],
          'tags': room['tags'],
        }).eq('id', roomId);
      } else {
        final roomResponse = await _supabase.from('rooms').insert({
          'inspection_id': widget.inspectionId,
          'room_name': room['name'],
          'position': roomIndex,
          'room_label': room['description'],
          'tags': room['tags'],
        }).select('id');

        roomId = roomResponse[0]['id'] as int;
        _roomIndexToIdMap[roomIndex] = roomId;
      }
      await _saveItemsData(room, roomId, roomIndex, existingRooms);
    }
  }

  Future<void> _saveItemsData(room, int roomId, int roomIndex, var existingRooms) async {
    // ... (rest of the _saveItemsData function is the same)
     final existingItems = await _supabase
          .from('room_items')
          .select('id, position')
          .eq('room_id', roomId);

      Map<int, int> existingItemPositionToId = {};
      for (final item in existingItems) {
        existingItemPositionToId[item['position'] as int] = item['id'] as int;
      }

      if (room['items'] != null) {
        for (int itemIndex = 0;
            itemIndex < room['items'].length;
            itemIndex++) {
          final item = room['items'][itemIndex];
          int itemId;
          final itemKey = '$roomIndex-$itemIndex';

          if (existingItemPositionToId.containsKey(itemIndex)) {
            itemId = existingItemPositionToId[itemIndex]!;
            await _supabase.from('room_items').update({
              'item_name': item['name'],
              'position': itemIndex,
              'item_label': item['description']
            }).eq('id', itemId);
          } else {
            final itemResponse = await _supabase.from('room_items').insert({
              'room_id': roomId,
              'inspection_id': widget.inspectionId,
              'item_name': item['name'],
              'position': itemIndex,
              'item_label': item['description']
            }).select('id');
            itemId = itemResponse[0]['id'] as int;
          }
          _itemIndexToIdMap[itemKey] = itemId;
          await _saveDetailsData(roomIndex, itemIndex, item, itemId);
        }
      }
       final currentItemPositions =
            List<int>.generate(room['items']?.length ?? 0, (i) => i);
        for (final existingItem in existingItems) {
          if (!currentItemPositions
              .contains(existingItemPositionToId[existingItem['id']])) {
            await _supabase
                .from('item_details')
                .delete()
                .eq('room_item_id', existingItem['id']);
            await _supabase.from('room_items').delete().eq('id', existingItem['id']);
          }
        }
  }

   Future<void> _saveDetailsData(int roomIndex, int itemIndex, var item, int itemId) async {
     // ... (rest of the _saveDetailsData function is the same)
        final existingDetails = await _supabase
                .from('item_details')
                .select('id, detail_name')
                .eq('room_item_id', itemId);

            Set<String> existingDetailNames = {};
            for (final detail in existingDetails) {
              existingDetailNames.add(detail['detail_name'] as String);
            }

            if (item['details'] != null) {
              for (final detail in item['details']) {

                final savedDetail = _inspectionData['room_$roomIndex']
                    ?['room_$roomIndex-item_$itemIndex'];

                if (existingDetailNames.contains(detail['name'])) {
                  await _supabase
                      .from('item_details')
                      .update({
                        'detail_value': savedDetail?['detail_value'],
                        'observation': savedDetail?['observation'],
                        'is_damaged': savedDetail?['is_damaged'] ?? false,
                        'tags': detail['tags']
                      })
                      .eq('room_item_id', itemId)
                      .eq('detail_name', detail['name']);
                } else {
                    // Não precisamos mais do insert, já foi criado
                }
              }
            }

            // Delete details that are no longer present
            for (final existingDetail in existingDetails) {
              if (!item['details']!.any((detail) =>
                  detail['name'] == existingDetail['detail_name'])) {
                await _supabase
                    .from('item_details')
                    .delete()
                    .eq('id', existingDetail['id']);
              }
            }
   }


  Future<void> _startChat() async {
    // ... (rest of the _startChat function is the same)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_inspection?['title'] ?? 'Vistoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveInspectionData,
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: _isLoading ? null : _startChat,
          ),
        ],
      ),
      body: OrientationBuilder(builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout();
        } else {
          return _buildPortraitLayout();
        }
      }),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      child: ExpansionPanelList.radio(
        expandedHeaderPadding: EdgeInsets.zero,
        elevation: 1,
        children: _rooms.map<ExpansionPanelRadio>((room) {
          final roomIndex = _rooms.indexOf(room);
          return ExpansionPanelRadio(
            value: roomIndex,
            headerBuilder: (BuildContext context, bool isExpanded) {
              return ListTile(
                title: Text(
                  roomName(room),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: roomDescription(room),
              );
            },
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RoomWidget(
                room: room,
                roomIndex: roomIndex,
                inspectionId: widget.inspectionId,
                onDataChanged: (roomKey, itemKey, detailData) {
                  _inspectionData.putIfAbsent(roomKey, () => {});
                  _inspectionData[roomKey]![itemKey] = detailData;
                },
                inspectionData: _inspectionData,
                rooms: _rooms,
                roomIndexToIdMap: _roomIndexToIdMap,
                itemIndexToIdMap: _itemIndexToIdMap,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        _buildRoomsColumn(),
        if (_selectedRoomIndex != -1) _buildItemsColumn(),
        if (_selectedItemIndex != -1 && _selectedRoomIndex != -1) _buildDetailsColumn(),
      ],
    );
  }

  Widget _buildRoomsColumn() {
    return Expanded(
      flex: 2,
      child: ListView.builder(
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return ListTile(
            tileColor: _selectedRoomIndex == index ? Colors.grey[200] : null, // Highlight selected
            title: Text(roomName(room)),
            onTap: () {
              setState(() {
                _selectedRoomIndex = index;
                _selectedItemIndex = -1; // Reset item selection
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildItemsColumn() {
    final selectedRoom = _rooms[_selectedRoomIndex];
    return Expanded(
      flex: 3,
      child: ListView.builder(
        itemCount: selectedRoom['items']?.length ?? 0,
        itemBuilder: (context, index) {
          final item = selectedRoom['items'][index];
          return ListTile(
             tileColor: _selectedItemIndex == index ? Colors.grey[200] : null, // Highlight selected
            title: Text(item['name'] ?? 'Unnamed Item'),
            onTap: () {
              setState(() {
                _selectedItemIndex = index;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailsColumn() {
    final selectedRoom = _rooms[_selectedRoomIndex];
    final selectedItem = selectedRoom['items'][_selectedItemIndex];
    final roomKey = 'room_${_roomIndexToIdMap[_selectedRoomIndex] ?? _selectedRoomIndex}'; // Construct roomKey
    final itemKey = '$roomKey-item_${selectedItem['id'] ?? _selectedItemIndex}'; // Construct itemKey

    return Expanded(
      flex: 5,
      child:  Padding(
          padding: const EdgeInsets.all(16),
          child: selectedItem['details'] != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedItem['name'] ?? 'Unnamed Item',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    if (selectedItem['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectedItem['description'],
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...List.generate(selectedItem['details'].length,
                        (detailIndex) {
                      final detail = selectedItem['details'][detailIndex];
                      return DetailWidget(
                        detail: detail,
                        itemKey: itemKey,
                        inspectionId: widget.inspectionId,
                        onDataChanged: _onDataChangedForLandscape, // Use different callback for landscape
                        inspectionData: _inspectionData,
                        rooms: _rooms,
                        roomIndexToIdMap: _roomIndexToIdMap,
                        itemIndexToIdMap: _itemIndexToIdMap,
                        isExpanded: false, // Not using expansion in landscape
                        onExpansionChanged: () {}, // Dummy callback
                      );
                    }),
                  ],
                ) : const Center(child: Text("Selecione um item para ver os detalhes")),
        )

    );
  }

    void _onDataChangedForLandscape(String roomKey, String itemKey, Map<String, dynamic> detailData) {
    // Directly update inspection data
    _inspectionData.putIfAbsent(roomKey, () => {});
    _inspectionData[roomKey]![itemKey] = detailData;
  }


  String roomName(dynamic room) => room['name'] ?? 'Unnamed Room';
  Widget roomDescription(dynamic room) => room['description'] != null
      ? Text(
          room['description'],
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        )
      : const SizedBox();
}
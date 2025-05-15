import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:uuid/uuid.dart';

class FirebaseInspectionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // INSPECTION METHODS
  Future<Inspection?> getInspection(String inspectionId) async {
    final docSnapshot =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!docSnapshot.exists) {
      return null;
    }

    return Inspection.fromMap({
      'id': docSnapshot.id,
      ...docSnapshot.data() ?? {},
    });
  }

  Future<void> saveInspection(Inspection inspection) async {
    await firestore.collection('inspections').doc(inspection.id).set(
          inspection.toMap()..remove('id'),
          SetOptions(merge: true),
        );
  }

  // ROOMS METHODS
  Future<List<Room>> getRooms(String inspectionId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!inspectionDoc.exists) {
      return [];
    }

    final data = inspectionDoc.data();
    final roomsData = data?['rooms'] as List<dynamic>? ?? [];

    List<Room> rooms = [];
    for (var i = 0; i < roomsData.length; i++) {
      final roomData = roomsData[i];
      if (roomData != null) {
        rooms.add(Room.fromMap({
          ...roomData,
          'id': roomData['id'] ?? i.toString(),
          'inspection_id': inspectionId,
        }));
      }
    }

    // Sort by position
    rooms.sort((a, b) => a.position.compareTo(b.position));
    return rooms;
  }

  Future<Room> addRoom(String inspectionId, String roomName,
      {String? label, int? position, String? observation}) async {
    final existingRooms = await getRooms(inspectionId);

    // Create the new room with sequential ID
    final roomId =
        existingRooms.isEmpty ? '0' : (existingRooms.length).toString();
    final newPosition = position ??
        (existingRooms.isEmpty ? 0 : existingRooms.last.position + 1);

    final room = Room(
      id: roomId,
      inspectionId: inspectionId,
      roomName: roomName,
      roomLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Update the rooms array in the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'rooms': FieldValue.arrayUnion([room.toMap()..remove('inspection_id')]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return room;
  }

  Future<void> updateRoom(Room updatedRoom) async {
    final inspectionId = updatedRoom.inspectionId;
    final roomId = updatedRoom.id;

    if (roomId == null) {
      throw Exception('Room ID is required for updates');
    }

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final roomsData = List<Map<String, dynamic>>.from(data['rooms'] ?? []);

    // Find the index of the room to update
    final roomIndex = roomsData.indexWhere((room) => room['id'] == roomId);
    if (roomIndex < 0) {
      throw Exception('Room not found in inspection');
    }

    // Update the room data
    roomsData[roomIndex] = updatedRoom.toMap()..remove('inspection_id');

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'rooms': roomsData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoom(String inspectionId, String roomId) async {
    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final roomsData = List<Map<String, dynamic>>.from(data['rooms'] ?? []);

    // Find the room to delete
    final roomIndex = roomsData.indexWhere((room) => room['id'] == roomId);
    if (roomIndex < 0) {
      throw Exception('Room not found in inspection');
    }

    // Remove the room
    roomsData.removeAt(roomIndex);

    // Also remove all items for this room
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);
    itemsData.removeWhere((item) => item['room_id'] == roomId);

    // Also remove all details for items in this room
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);
    detailsData.removeWhere((detail) => detail['room_id'] == roomId);

    // Also remove all media for this room
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);
    mediaData.removeWhere((media) => media['room_id'] == roomId);

    // Also remove all non-conformities for this room
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);
    ncData.removeWhere((nc) => nc['room_id'] == roomId);

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'rooms': roomsData,
      'items': itemsData,
      'details': detailsData,
      'media': mediaData,
      'non_conformities': ncData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reorderRooms(String inspectionId, List<String> roomIds) async {
    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final roomsData = List<Map<String, dynamic>>.from(data['rooms'] ?? []);

    // Create a new list of rooms in the desired order
    List<Map<String, dynamic>> reorderedRooms = [];
    for (var id in roomIds) {
      final roomIndex = roomsData.indexWhere((room) => room['id'] == id);
      if (roomIndex >= 0) {
        final roomData = roomsData[roomIndex];
        roomData['position'] = reorderedRooms.length;
        reorderedRooms.add(roomData);
      }
    }

    // Add any rooms not in the roomIds list at the end
    for (var room in roomsData) {
      if (!roomIds.contains(room['id'])) {
        room['position'] = reorderedRooms.length;
        reorderedRooms.add(room);
      }
    }

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'rooms': reorderedRooms,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<Room> isRoomDuplicate(String inspectionId, String roomName) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final roomsData = List<Map<String, dynamic>>.from(data['rooms'] ?? []);

    // Create a copy of the room
    final sourceRoomIndex =
        roomsData.indexWhere((room) => room['room_name'] == roomName);
    if (sourceRoomIndex < 0) {
      throw Exception('Source room not found');
    }

    final sourceRoom = roomsData[sourceRoomIndex];
    final newRoomId = roomsData.length.toString();

    // Create new room with a duplicated name
    final newRoomName = '$roomName (copy)';
    final newRoom = {
      ...Map<String, dynamic>.from(sourceRoom),
      'id': newRoomId,
      'room_name': newRoomName,
      'position': roomsData.length,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Also duplicate all items for this room
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final sourceRoomItems =
        itemsData.where((item) => item['room_id'] == sourceRoom['id']).toList();

    List<Map<String, dynamic>> newItems = [];
    Map<String, String> itemIdMapping = {}; // Map of old item ID to new item ID

    for (var i = 0; i < sourceRoomItems.length; i++) {
      final sourceItem = sourceRoomItems[i];
      final newItemId = i.toString();

      // Map old item ID to new item ID
      itemIdMapping[sourceItem['id']] = newItemId;

      // Create new item
      final newItem = {
        ...Map<String, dynamic>.from(sourceItem),
        'id': newItemId,
        'room_id': newRoomId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      newItems.add(newItem);
    }

    // Also duplicate all details for items in this room
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);
    List<Map<String, dynamic>> newDetails = [];

    for (var sourceItemId in itemIdMapping.keys) {
      final sourceItemDetails = detailsData
          .where((detail) =>
              detail['room_id'] == sourceRoom['id'] &&
              detail['item_id'] == sourceItemId)
          .toList();

      for (var i = 0; i < sourceItemDetails.length; i++) {
        final sourceDetail = sourceItemDetails[i];
        final newItemId = itemIdMapping[sourceItemId]!;
        final newDetailId = i.toString();

        // Create new detail
        final newDetail = {
          ...Map<String, dynamic>.from(sourceDetail),
          'id': newDetailId,
          'room_id': newRoomId,
          'item_id': newItemId,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        newDetails.add(newDetail);
      }
    }

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'rooms': FieldValue.arrayUnion([newRoom]),
      'items': FieldValue.arrayUnion(newItems),
      'details': FieldValue.arrayUnion(newDetails),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return Room.fromMap({
      ...newRoom,
      'inspection_id': inspectionId,
    });
  }

  // ITEMS METHODS
  Future<List<Item>> getItems(String inspectionId, String roomId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!inspectionDoc.exists) {
      return [];
    }

    final data = inspectionDoc.data();
    final itemsData = data?['items'] as List<dynamic>? ?? [];

    List<Item> items = [];
    for (var itemData in itemsData) {
      if (itemData['room_id'] == roomId) {
        items.add(Item.fromMap({
          ...itemData,
          'inspection_id': inspectionId,
        }));
      }
    }

    // Sort by position
    items.sort((a, b) => a.position.compareTo(b.position));
    return items;
  }

  Future<Item> addItem(String inspectionId, String roomId, String itemName,
      {String? label, String? observation}) async {
    final existingItems = await getItems(inspectionId, roomId);

    // Create the new item with sequential ID
    final itemId =
        existingItems.isEmpty ? '0' : (existingItems.length).toString();
    final newPosition =
        existingItems.isEmpty ? 0 : existingItems.last.position + 1;

    final item = Item(
      id: itemId,
      roomId: roomId,
      inspectionId: inspectionId,
      itemName: itemName,
      itemLabel: label,
      observation: observation,
      position: newPosition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Update the items array in the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'items': FieldValue.arrayUnion([item.toMap()..remove('inspection_id')]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return item;
  }

  Future<void> updateItem(Item updatedItem) async {
    final inspectionId = updatedItem.inspectionId;
    final roomId = updatedItem.roomId;
    final itemId = updatedItem.id;

    if (roomId == null || itemId == null) {
      throw Exception('Room ID and Item ID are required for updates');
    }

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);

    // Find the index of the item to update
    final itemIndex = itemsData.indexWhere(
        (item) => item['room_id'] == roomId && item['id'] == itemId);

    if (itemIndex < 0) {
      throw Exception('Item not found in inspection');
    }

    // Update the item data
    itemsData[itemIndex] = updatedItem.toMap()..remove('inspection_id');

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'items': itemsData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(
      String inspectionId, String roomId, String itemId) async {
    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);

    // Find the item to delete
    final itemIndex = itemsData.indexWhere(
        (item) => item['room_id'] == roomId && item['id'] == itemId);

    if (itemIndex < 0) {
      throw Exception('Item not found in inspection');
    }

    // Remove the item
    itemsData.removeAt(itemIndex);

    // Also remove all details for this item
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);
    detailsData.removeWhere(
        (detail) => detail['room_id'] == roomId && detail['item_id'] == itemId);

    // Also remove all media for this item
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);
    mediaData.removeWhere((media) =>
        media['room_id'] == roomId && media['room_item_id'] == itemId);

    // Also remove all non-conformities for this item
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);
    ncData.removeWhere(
        (nc) => nc['room_id'] == roomId && nc['item_id'] == itemId);

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'items': itemsData,
      'details': detailsData,
      'media': mediaData,
      'non_conformities': ncData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<Item> isItemDuplicate(
      String inspectionId, String roomId, String itemName) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);

    // Find the source item
    final sourceItemIndex = itemsData.indexWhere(
        (item) => item['room_id'] == roomId && item['item_name'] == itemName);

    if (sourceItemIndex < 0) {
      throw Exception('Source item not found');
    }

    final sourceItem = itemsData[sourceItemIndex];
    final existingItems =
        itemsData.where((item) => item['room_id'] == roomId).toList();
    final newItemId = existingItems.length.toString();

    // Create new item with a duplicated name
    final newItemName = '$itemName (copy)';
    final newItem = {
      ...Map<String, dynamic>.from(sourceItem),
      'id': newItemId,
      'item_name': newItemName,
      'position': existingItems.length,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Also duplicate all details for this item
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);
    final sourceItemDetails = detailsData
        .where((detail) =>
            detail['room_id'] == roomId &&
            detail['item_id'] == sourceItem['id'])
        .toList();

    List<Map<String, dynamic>> newDetails = [];

    for (var i = 0; i < sourceItemDetails.length; i++) {
      final sourceDetail = sourceItemDetails[i];
      final newDetailId = i.toString();

      // Create new detail
      final newDetail = {
        ...Map<String, dynamic>.from(sourceDetail),
        'id': newDetailId,
        'item_id': newItemId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      newDetails.add(newDetail);
    }

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'items': FieldValue.arrayUnion([newItem]),
      'details': FieldValue.arrayUnion(newDetails),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return Item.fromMap({
      ...newItem,
      'inspection_id': inspectionId,
    });
  }

  // DETAILS METHODS
  Future<List<Detail>> getDetails(
      String inspectionId, String roomId, String itemId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!inspectionDoc.exists) {
      return [];
    }

    final data = inspectionDoc.data();
    final detailsData = data?['details'] as List<dynamic>? ?? [];

    List<Detail> details = [];
    for (var detailData in detailsData) {
      if (detailData['room_id'] == roomId && detailData['item_id'] == itemId) {
        details.add(Detail.fromMap({
          ...detailData,
          'inspection_id': inspectionId,
        }));
      }
    }

    // Sort by position
    details.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
    return details;
  }

  Future<Detail> addDetail(
    String inspectionId,
    String roomId,
    String itemId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
  }) async {
    final existingDetails = await getDetails(inspectionId, roomId, itemId);

    // Create the new detail with sequential ID
    final detailId =
        existingDetails.isEmpty ? '0' : (existingDetails.length).toString();
    final newPosition =
        existingDetails.isEmpty ? 0 : (existingDetails.last.position ?? 0) + 1;

    final detail = Detail(
      id: detailId,
      roomId: roomId,
      itemId: itemId,
      inspectionId: inspectionId,
      detailName: detailName,
      type: type ?? 'text',
      options: options,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? false,
      position: newPosition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Update the details array in the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'details':
          FieldValue.arrayUnion([detail.toMap()..remove('inspection_id')]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return detail;
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    final inspectionId = updatedDetail.inspectionId;
    final roomId = updatedDetail.roomId;
    final itemId = updatedDetail.itemId;
    final detailId = updatedDetail.id;

    if (roomId == null || itemId == null || detailId == null) {
      throw Exception(
          'Room ID, Item ID, and Detail ID are required for updates');
    }

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);

    // Find the index of the detail to update
    final detailIndex = detailsData.indexWhere((detail) =>
        detail['room_id'] == roomId &&
        detail['item_id'] == itemId &&
        detail['id'] == detailId);

    if (detailIndex < 0) {
      throw Exception('Detail not found in inspection');
    }

    // Update the detail data
    detailsData[detailIndex] = updatedDetail.toMap()..remove('inspection_id');

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'details': detailsData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDetail(String inspectionId, String roomId, String itemId,
      String detailId) async {
    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);

    // Find the detail to delete
    final detailIndex = detailsData.indexWhere((detail) =>
        detail['room_id'] == roomId &&
        detail['item_id'] == itemId &&
        detail['id'] == detailId);

    if (detailIndex < 0) {
      throw Exception('Detail not found in inspection');
    }

    // Remove the detail
    detailsData.removeAt(detailIndex);

    // Also remove all media for this detail
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);
    mediaData.removeWhere((media) =>
        media['room_id'] == roomId &&
        media['room_item_id'] == itemId &&
        media['detail_id'] == detailId);

    // Also remove all non-conformities for this detail
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);
    ncData.removeWhere((nc) =>
        nc['room_id'] == roomId &&
        nc['item_id'] == itemId &&
        nc['detail_id'] == detailId);

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'details': detailsData,
      'media': mediaData,
      'non_conformities': ncData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String roomId,
      String itemId, String detailName) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final detailsData = List<Map<String, dynamic>>.from(data['details'] ?? []);

    // Find the source detail
    final sourceDetailIndex = detailsData.indexWhere((detail) =>
        detail['room_id'] == roomId &&
        detail['item_id'] == itemId &&
        detail['detail_name'] == detailName);

    if (sourceDetailIndex < 0) {
      throw Exception('Source detail not found');
    }

    final sourceDetail = detailsData[sourceDetailIndex];
    final existingDetails = detailsData
        .where((detail) =>
            detail['room_id'] == roomId && detail['item_id'] == itemId)
        .toList();
    final newDetailId = existingDetails.length.toString();

    // Create new detail with a duplicated name
    final newDetailName = '$detailName (copy)';
    final newDetail = {
      ...Map<String, dynamic>.from(sourceDetail),
      'id': newDetailId,
      'detail_name': newDetailName,
      'position': existingDetails.length,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'details': FieldValue.arrayUnion([newDetail]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return Detail.fromMap({
      ...newDetail,
      'inspection_id': inspectionId,
    });
  }

  // NON-CONFORMITY METHODS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!inspectionDoc.exists) {
      return [];
    }

    final data = inspectionDoc.data();
    final ncData = data?['non_conformities'] as List<dynamic>? ?? [];

    List<Map<String, dynamic>> nonConformities = [];
    for (var ncItem in ncData) {
      final roomId = ncItem['room_id'];
      final itemId = ncItem['item_id'];
      final detailId = ncItem['detail_id'];

      // Get room data
      final roomsData = data?['rooms'] as List<dynamic>? ?? [];
      final room = roomsData.firstWhere(
        (room) => room['id'] == roomId,
        orElse: () => {'room_name': 'Room not found'},
      );

      // Get item data
      final itemsData = data?['items'] as List<dynamic>? ?? [];
      final item = itemsData.firstWhere(
        (item) => item['room_id'] == roomId && item['id'] == itemId,
        orElse: () => {'item_name': 'Item not found'},
      );

      // Get detail data
      final detailsData = data?['details'] as List<dynamic>? ?? [];
      final detail = detailsData.firstWhere(
        (detail) =>
            detail['room_id'] == roomId &&
            detail['item_id'] == itemId &&
            detail['id'] == detailId,
        orElse: () => {'detail_name': 'Detail not found'},
      );

      nonConformities.add({
        ...Map<String, dynamic>.from(ncItem),
        'rooms': room,
        'room_items': item,
        'item_details': detail,
      });
    }

    return nonConformities;
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    final inspectionId = nonConformityData['inspection_id'];
    final roomId = nonConformityData['room_id'];
    final itemId = nonConformityData['item_id'];
    final detailId = nonConformityData['detail_id'];

    // Generate a unique ID based on the hierarchical structure
    final nonConformityId =
        '$inspectionId-$roomId-$itemId-$detailId-${_uuid.v4().substring(0, 8)}';

    final ncData = {
      ...nonConformityData,
      'id': nonConformityId,
    };

    // Update the non-conformities array in the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'non_conformities': FieldValue.arrayUnion([ncData]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Also update the detail to mark as damaged
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (inspectionDoc.exists) {
      final data = inspectionDoc.data() ?? {};
      final detailsData =
          List<Map<String, dynamic>>.from(data['details'] ?? []);

      final detailIndex = detailsData.indexWhere((detail) =>
          detail['room_id'] == roomId &&
          detail['item_id'] == itemId &&
          detail['id'] == detailId);

      if (detailIndex >= 0) {
        detailsData[detailIndex]['is_damaged'] = true;
        detailsData[detailIndex]['updated_at'] = FieldValue.serverTimestamp();

        await firestore.collection('inspections').doc(inspectionId).update({
          'details': detailsData,
        });
      }
    }
  }

  Future<void> updateNonConformityStatus(
      String nonConformityId, String newStatus) async {
    // Parse the composite ID to get the inspection ID
    final parts = nonConformityId.split('-');
    if (parts.length < 4) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);

    // Find the non-conformity to update
    final ncIndex = ncData.indexWhere((nc) => nc['id'] == nonConformityId);
    if (ncIndex < 0) {
      throw Exception('Non-conformity not found');
    }

    // Update the status
    ncData[ncIndex]['status'] = newStatus;
    ncData[ncIndex]['updated_at'] = FieldValue.serverTimestamp();

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'non_conformities': ncData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNonConformity(
      String nonConformityId, Map<String, dynamic> updatedData) async {
    // Parse the composite ID to get the inspection ID
    final parts = nonConformityId.split('-');
    if (parts.length < 4) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);

    // Find the non-conformity to update
    final ncIndex = ncData.indexWhere((nc) => nc['id'] == nonConformityId);
    if (ncIndex < 0) {
      throw Exception('Non-conformity not found');
    }

    // Update the data
    ncData[ncIndex] = {
      ...ncData[ncIndex],
      ...updatedData,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'non_conformities': ncData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNonConformity(
      String nonConformityId, String inspectionId) async {
    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final ncData =
        List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);

    // Find the non-conformity to delete
    final ncIndex = ncData.indexWhere((nc) => nc['id'] == nonConformityId);
    if (ncIndex < 0) {
      throw Exception('Non-conformity not found');
    }

    // Get the reference info before removing it
    final roomId = ncData[ncIndex]['room_id'];
    final itemId = ncData[ncIndex]['item_id'];
    final detailId = ncData[ncIndex]['detail_id'];

    // Remove the non-conformity
    ncData.removeAt(ncIndex);

    // Also remove all media associated with this non-conformity
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);
    mediaData
        .removeWhere((media) => media['non_conformity_id'] == nonConformityId);

    // Check if there are any other non-conformities for the same detail
    final hasOtherNCs = ncData.any((nc) =>
        nc['room_id'] == roomId &&
        nc['item_id'] == itemId &&
        nc['detail_id'] == detailId);

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'non_conformities': ncData,
      'media': mediaData,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // If there are no other non-conformities for this detail, update the detail's damage status
    if (!hasOtherNCs) {
      final detailsData =
          List<Map<String, dynamic>>.from(data['details'] ?? []);
      final detailIndex = detailsData.indexWhere((detail) =>
          detail['room_id'] == roomId &&
          detail['item_id'] == itemId &&
          detail['id'] == detailId);

      if (detailIndex >= 0) {
        detailsData[detailIndex]['is_damaged'] = false;
        detailsData[detailIndex]['updated_at'] = FieldValue.serverTimestamp();

        await firestore.collection('inspections').doc(inspectionId).update({
          'details': detailsData,
        });
      }
    }
  }

  // MEDIA METHODS
  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    final inspectionId = mediaData['inspection_id'];
    final roomId = mediaData['room_id'];
    final itemId = mediaData['room_item_id'];
    final detailId = mediaData['detail_id'];

    // Generate a unique ID based on the hierarchical structure
    final mediaId =
        '$inspectionId-$roomId-$itemId-$detailId-${_uuid.v4().substring(0, 8)}';

    final media = {
      ...mediaData,
      'id': mediaId,
    };

    // Update the media array in the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'media': FieldValue.arrayUnion([media]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMedia(String mediaId) async {
    // Parse the composite ID to get the inspection ID
    final parts = mediaId.split('-');
    if (parts.length < 4) {
      throw Exception('Invalid media ID format');
    }

    final inspectionId = parts[0];

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);

    // Find the media to delete
    final mediaIndex = mediaData.indexWhere((media) => media['id'] == mediaId);
    if (mediaIndex < 0) {
      throw Exception('Media not found');
    }

    // Remove the media
    mediaData.removeAt(mediaIndex);

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'media': mediaData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMedia(
      String mediaId, Map<String, dynamic> updatedData) async {
    // Parse the composite ID to get the inspection ID
    final parts = mediaId.split('-');
    if (parts.length < 4) {
      throw Exception('Invalid media ID format');
    }

    final inspectionId = parts[0];

    // Get the current inspection document
    final inspectionDoc =
        await firestore.collection('inspections').doc(inspectionId).get();
    if (!inspectionDoc.exists) {
      throw Exception('Inspection not found');
    }

    final data = inspectionDoc.data() ?? {};
    final mediaData = List<Map<String, dynamic>>.from(data['media'] ?? []);

    // Find the media to update
    final mediaIndex = mediaData.indexWhere((media) => media['id'] == mediaId);
    if (mediaIndex < 0) {
      throw Exception('Media not found');
    }

    // Update the data
    mediaData[mediaIndex] = {
      ...mediaData[mediaIndex],
      ...updatedData,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Update the inspection document
    await firestore.collection('inspections').doc(inspectionId).update({
      'media': mediaData,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // TEMPLATE APPLICATION
  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    try {
      // Get the template
      final templateDoc =
          await firestore.collection('templates').doc(templateId).get();
      if (!templateDoc.exists) {
        return false;
      }

      final templateData = templateDoc.data() ?? {};
      final roomsData = templateData['rooms'] as List<dynamic>? ?? [];

      // Create rooms from template
      for (var i = 0; i < roomsData.length; i++) {
        final roomTemplate = roomsData[i];

        // Extract room name
        String roomName = '';
        if (roomTemplate is Map &&
            roomTemplate['name'] is Map &&
            roomTemplate['name']['stringValue'] != null) {
          roomName = roomTemplate['name']['stringValue'];
        } else if (roomTemplate is Map && roomTemplate['name'] is String) {
          roomName = roomTemplate['name'];
        }

        if (roomName.isEmpty) continue;

        // Create room
        final room = await addRoom(
          inspectionId,
          roomName,
          position: i,
        );

        // Extract items
        final itemsData = _extractArrayFromTemplate(roomTemplate, 'items');

        // Create items from template
        for (var j = 0; j < itemsData.length; j++) {
          final itemTemplate = itemsData[j];
          final itemFields = _extractFieldsFromTemplate(itemTemplate);

          if (itemFields == null) continue;

          String itemName = _extractStringValueFromTemplate(itemFields, 'name',
              defaultValue: 'Item sem nome');

          // Create item
          final item = await addItem(
            inspectionId,
            room.id!,
            itemName,
            observation:
                _extractStringValueFromTemplate(itemFields, 'description'),
          );

          // Extract details
          final detailsData = _extractArrayFromTemplate(itemFields, 'details');

          // Create details from template
          for (var k = 0; k < detailsData.length; k++) {
            final detailTemplate = detailsData[k];
            final detailFields = _extractFieldsFromTemplate(detailTemplate);

            if (detailFields == null) continue;

            String detailName = _extractStringValueFromTemplate(
                detailFields, 'name',
                defaultValue: 'Detalhe sem nome');

            String detailType = _extractStringValueFromTemplate(
                detailFields, 'type',
                defaultValue: 'text');

            // Extract options for select type
            List<String>? options;
            if (detailType == 'select') {
              final optionsArray =
                  _extractArrayFromTemplate(detailFields, 'options');
              options = [];

              for (var option in optionsArray) {
                if (option is Map && option.containsKey('stringValue')) {
                  options.add(option['stringValue']);
                } else if (option is String) {
                  options.add(option);
                }
              }

              // Check for optionsText field as alternative
              if (options.isEmpty && detailFields.containsKey('optionsText')) {
                final optionsText = _extractStringValueFromTemplate(
                    detailFields, 'optionsText',
                    defaultValue: '');

                if (optionsText.isNotEmpty) {
                  options =
                      optionsText.split(',').map((e) => e.trim()).toList();
                }
              }
            }

            // Create detail
            await addDetail(
              inspectionId,
              room.id!,
              item.id!,
              detailName,
              type: detailType,
              options: options,
            );
          }
        }
      }

      // Update inspection to mark as templated
      await firestore.collection('inspections').doc(inspectionId).update({
        'is_templated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error applying template: $e');
      return false;
    }
  }

  // Helper methods for template handling
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];

    // Case 1: Already a list
    if (data[key] is List) {
      return data[key];
    }

    // Case 2: Firestore format (arrayValue)
    if (data[key] is Map &&
        data[key].containsKey('arrayValue') &&
        data[key]['arrayValue'] is Map &&
        data[key]['arrayValue'].containsKey('values')) {
      return data[key]['arrayValue']['values'] ?? [];
    }

    return [];
  }

  Map<String, dynamic>? _extractFieldsFromTemplate(dynamic data) {
    if (data == null) return null;

    // Case 1: Already a map of fields
    if (data is Map && data.containsKey('fields')) {
      return Map<String, dynamic>.from(data['fields']);
    }

    // Case 2: Complex Firestore format
    if (data is Map &&
        data.containsKey('mapValue') &&
        data['mapValue'] is Map &&
        data['mapValue'].containsKey('fields')) {
      return Map<String, dynamic>.from(data['mapValue']['fields']);
    }

    // Case 3: Simple map
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  String _extractStringValueFromTemplate(dynamic data, String key,
      {String defaultValue = ''}) {
    if (data == null) return defaultValue;

    // Case 1: Direct string
    if (data[key] is String) {
      return data[key];
    }

    // Case 2: Firestore format (stringValue)
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }

    return defaultValue;
  }
}

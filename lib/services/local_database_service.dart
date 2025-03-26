// lib/services/local_database_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LocalDatabaseService {
  static const String inspectionsBoxName = 'inspections';
  static const String roomsBoxName = 'rooms';
  static const String itemsBoxName = 'items';
  static const String detailsBoxName = 'details';
  static const String mediaBoxName = 'media';
  static const String syncStatusBoxName = 'syncStatus';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters for our model classes
    Hive.registerAdapter(InspectionAdapter());
    Hive.registerAdapter(RoomAdapter());
    Hive.registerAdapter(ItemAdapter());
    Hive.registerAdapter(DetailAdapter());
    
    // Open boxes
    await Hive.openBox<Inspection>(inspectionsBoxName);
    await Hive.openBox<Room>(roomsBoxName);
    await Hive.openBox<Item>(itemsBoxName);
    await Hive.openBox<Detail>(detailsBoxName);
    await Hive.openBox<String>(mediaBoxName);
    await Hive.openBox<bool>(syncStatusBoxName);
  }

  // Inspection Methods
  static Future<void> saveInspection(Inspection inspection) async {
    final box = Hive.box<Inspection>(inspectionsBoxName);
    await box.put(inspection.id.toString(), inspection);
    await setSyncStatus(inspection.id, false);
  }

  static Future<Inspection?> getInspection(int id) async {
    final box = Hive.box<Inspection>(inspectionsBoxName);
    return box.get(id.toString());
  }

  static Future<List<Inspection>> getAllInspections() async {
    final box = Hive.box<Inspection>(inspectionsBoxName);
    return box.values.toList();
  }

  static Future<List<Inspection>> getPendingSyncInspections() async {
    final inspectionsBox = Hive.box<Inspection>(inspectionsBoxName);
    final syncStatusBox = Hive.box<bool>(syncStatusBoxName);
    
    List<Inspection> pendingInspections = [];
    
    for (var key in syncStatusBox.keys) {
      if (syncStatusBox.get(key) == false) {
        final inspectionId = key.toString().replaceAll('sync_', '');
        final inspection = inspectionsBox.get(inspectionId);
        if (inspection != null) {
          pendingInspections.add(inspection);
        }
      }
    }
    
    return pendingInspections;
  }

  static Future<void> deleteInspection(int id) async {
    final inspectionsBox = Hive.box<Inspection>(inspectionsBoxName);
    await inspectionsBox.delete(id.toString());
    
    // Delete related data
    await _deleteRelatedRooms(id);
    await _deleteRelatedItems(id);
    await _deleteRelatedDetails(id);
    await _deleteRelatedMedia(id);
    
    // Delete sync status
    final syncStatusBox = Hive.box<bool>(syncStatusBoxName);
    await syncStatusBox.delete('sync_${id}');
  }

  // Room Methods
  static Future<void> saveRoom(Room room) async {
    final box = Hive.box<Room>(roomsBoxName);
    final key = '${room.inspectionId}_${room.id}';
    await box.put(key, room);
    await setSyncStatus(room.inspectionId, false);
  }

  static Future<List<Room>> getRoomsByInspection(int inspectionId) async {
    final box = Hive.box<Room>(roomsBoxName);
    return box.values
        .where((room) => room.inspectionId == inspectionId)
        .toList();
  }

  static Future<void> deleteRoom(int inspectionId, int roomId) async {
    final roomsBox = Hive.box<Room>(roomsBoxName);
    final key = '${inspectionId}_${roomId}';
    await roomsBox.delete(key);
    
    // Delete related items and details
    await _deleteRelatedItemsByRoom(inspectionId, roomId);
    
    // Mark as needing sync
    await setSyncStatus(inspectionId, false);
  }

  // Item Methods
  static Future<void> saveItem(Item item) async {
    final box = Hive.box<Item>(itemsBoxName);
    final key = '${item.inspectionId}_${item.roomId}_${item.id}';
    await box.put(key, item);
    await setSyncStatus(item.inspectionId, false);
  }

  static Future<List<Item>> getItemsByRoom(int inspectionId, int roomId) async {
    final box = Hive.box<Item>(itemsBoxName);
    return box.values
        .where((item) => item.inspectionId == inspectionId && item.roomId == roomId)
        .toList();
  }

  static Future<void> deleteItem(int inspectionId, int roomId, int itemId) async {
    final itemsBox = Hive.box<Item>(itemsBoxName);
    final key = '${inspectionId}_${roomId}_${itemId}';
    await itemsBox.delete(key);
    
    // Delete related details
    await _deleteRelatedDetailsByItem(inspectionId, roomId, itemId);
    
    // Mark as needing sync
    await setSyncStatus(inspectionId, false);
  }

  // Detail Methods
  static Future<void> saveDetail(Detail detail) async {
    final box = Hive.box<Detail>(detailsBoxName);
    final key = '${detail.inspectionId}_${detail.roomId}_${detail.itemId}_${detail.id}';
    await box.put(key, detail);
    await setSyncStatus(detail.inspectionId, false);
  }

  static Future<List<Detail>> getDetailsByItem(int inspectionId, int roomId, int itemId) async {
    final box = Hive.box<Detail>(detailsBoxName);
    return box.values
        .where((detail) => 
            detail.inspectionId == inspectionId && 
            detail.roomId == roomId && 
            detail.itemId == itemId)
        .toList();
  }

  static Future<void> deleteDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    final detailsBox = Hive.box<Detail>(detailsBoxName);
    final key = '${inspectionId}_${roomId}_${itemId}_${detailId}';
    await detailsBox.delete(key);
    
    // Delete related media
    await _deleteRelatedMediaByDetail(inspectionId, roomId, itemId, detailId);
    
    // Mark as needing sync
    await setSyncStatus(inspectionId, false);
  }

  // Media Methods
  static Future<void> saveMedia(int inspectionId, int roomId, int itemId, int detailId, String mediaPath) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    // Generate a unique ID for the media
    final mediaId = '${DateTime.now().millisecondsSinceEpoch}_${mediaBox.length}';
    final key = '${inspectionId}_${roomId}_${itemId}_${detailId}_${mediaId}';
    
    // Store the file path
    await mediaBox.put(key, mediaPath);
    
    // Mark as needing sync
    await setSyncStatus(inspectionId, false);
  }

  static Future<List<String>> getMediaByDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    final prefix = '${inspectionId}_${roomId}_${itemId}_${detailId}_';
    
    List<String> media = [];
    
    for (var key in mediaBox.keys) {
      if (key.toString().startsWith(prefix)) {
        final mediaPath = mediaBox.get(key.toString());
        if (mediaPath != null) {
          media.add(mediaPath);
        }
      }
    }
    
    return media;
  }

  static Future<void> deleteMedia(String mediaKey) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    
    // Get the file path before deleting
    final mediaPath = mediaBox.get(mediaKey);
    
    // Delete from Hive
    await mediaBox.delete(mediaKey);
    
    // Delete the actual file
    if (mediaPath != null) {
      final file = File(mediaPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Parse the inspection ID from the key and mark as needing sync
    final parts = mediaKey.split('_');
    if (parts.length > 0) {
      final inspectionId = int.tryParse(parts[0]);
      if (inspectionId != null) {
        await setSyncStatus(inspectionId, false);
      }
    }
  }

  static Future<void> moveMedia(String mediaKey, int newRoomId, int newItemId, int newDetailId) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    
    // Get the media path
    final mediaPath = mediaBox.get(mediaKey);
    if (mediaPath == null) return;
    
    // Parse the current key
    final parts = mediaKey.split('_');
    if (parts.length < 5) return;
    
    final inspectionId = int.parse(parts[0]);
    final mediaId = parts[4]; // Keep the same media ID
    
    // Create the new key
    final newKey = '${inspectionId}_${newRoomId}_${newItemId}_${newDetailId}_${mediaId}';
    
    // Save to the new location
    await mediaBox.put(newKey, mediaPath);
    
    // Delete from the old location
    await mediaBox.delete(mediaKey);
    
    // Mark as needing sync
    await setSyncStatus(inspectionId, false);
  }

  // Sync Status Methods
  static Future<void> setSyncStatus(int inspectionId, bool isSynced) async {
    final syncStatusBox = Hive.box<bool>(syncStatusBoxName);
    await syncStatusBox.put('sync_${inspectionId}', isSynced);
  }

  static Future<bool> getSyncStatus(int inspectionId) async {
    final syncStatusBox = Hive.box<bool>(syncStatusBoxName);
    return syncStatusBox.get('sync_${inspectionId}') ?? false;
  }

  // Helper methods for cascade deletes
  static Future<void> _deleteRelatedRooms(int inspectionId) async {
    final roomsBox = Hive.box<Room>(roomsBoxName);
    
    // Find all rooms for this inspection
    List<dynamic> keysToDelete = [];
    
    for (var key in roomsBox.keys) {
      final room = roomsBox.get(key);
      if (room != null && room.inspectionId == inspectionId) {
        keysToDelete.add(key);
        
        // Delete related items and details
        await _deleteRelatedItemsByRoom(inspectionId, room.id!);
      }
    }
    
    // Batch delete the rooms
    for (var key in keysToDelete) {
      await roomsBox.delete(key);
    }
  }

  static Future<void> _deleteRelatedItems(int inspectionId) async {
    final itemsBox = Hive.box<Item>(itemsBoxName);
    
    // Find all items for this inspection
    List<dynamic> keysToDelete = [];
    
    for (var key in itemsBox.keys) {
      final item = itemsBox.get(key);
      if (item != null && item.inspectionId == inspectionId) {
        keysToDelete.add(key);
        
        // Delete related details
        await _deleteRelatedDetailsByItem(inspectionId, item.roomId!, item.id!);
      }
    }
    
    // Batch delete the items
    for (var key in keysToDelete) {
      await itemsBox.delete(key);
    }
  }

  static Future<void> _deleteRelatedItemsByRoom(int inspectionId, int roomId) async {
    final itemsBox = Hive.box<Item>(itemsBoxName);
    
    // Find all items for this room
    List<dynamic> keysToDelete = [];
    
    for (var key in itemsBox.keys) {
      final item = itemsBox.get(key);
      if (item != null && item.inspectionId == inspectionId && item.roomId == roomId) {
        keysToDelete.add(key);
        
        // Delete related details
        await _deleteRelatedDetailsByItem(inspectionId, roomId, item.id!);
      }
    }
    
    // Batch delete the items
    for (var key in keysToDelete) {
      await itemsBox.delete(key);
    }
  }

  static Future<void> _deleteRelatedDetails(int inspectionId) async {
    final detailsBox = Hive.box<Detail>(detailsBoxName);
    
    // Find all details for this inspection
    List<dynamic> keysToDelete = [];
    
    for (var key in detailsBox.keys) {
      final detail = detailsBox.get(key);
      if (detail != null && detail.inspectionId == inspectionId) {
        keysToDelete.add(key);
        
        // Delete related media
        await _deleteRelatedMediaByDetail(
          inspectionId, 
          detail.roomId!, 
          detail.itemId!, 
          detail.id!
        );
      }
    }
    
    // Batch delete the details
    for (var key in keysToDelete) {
      await detailsBox.delete(key);
    }
  }

  static Future<void> _deleteRelatedDetailsByItem(int inspectionId, int roomId, int itemId) async {
    final detailsBox = Hive.box<Detail>(detailsBoxName);
    
    // Find all details for this item
    List<dynamic> keysToDelete = [];
    
    for (var key in detailsBox.keys) {
      final detail = detailsBox.get(key);
      if (detail != null && 
          detail.inspectionId == inspectionId && 
          detail.roomId == roomId && 
          detail.itemId == itemId) {
        keysToDelete.add(key);
        
        // Delete related media
        await _deleteRelatedMediaByDetail(inspectionId, roomId, itemId, detail.id!);
      }
    }
    
    // Batch delete the details
    for (var key in keysToDelete) {
      await detailsBox.delete(key);
    }
  }

  static Future<void> _deleteRelatedMedia(int inspectionId) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    
    // Find all media for this inspection
    List<dynamic> keysToDelete = [];
    List<String> filesToDelete = [];
    
    for (var key in mediaBox.keys) {
      final keyString = key.toString();
      if (keyString.startsWith('${inspectionId}_')) {
        keysToDelete.add(key);
        
        // Get the file path to delete
        final mediaPath = mediaBox.get(keyString);
        if (mediaPath != null) {
          filesToDelete.add(mediaPath);
        }
      }
    }
    
    // Batch delete from Hive
    for (var key in keysToDelete) {
      await mediaBox.delete(key);
    }
    
    // Delete the actual files
    for (var filePath in filesToDelete) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> _deleteRelatedMediaByDetail(
      int inspectionId, int roomId, int itemId, int detailId) async {
    final mediaBox = Hive.box<String>(mediaBoxName);
    final prefix = '${inspectionId}_${roomId}_${itemId}_${detailId}_';
    
    // Find all media for this detail
    List<dynamic> keysToDelete = [];
    List<String> filesToDelete = [];
    
    for (var key in mediaBox.keys) {
      final keyString = key.toString();
      if (keyString.startsWith(prefix)) {
        keysToDelete.add(key);
        
        // Get the file path to delete
        final mediaPath = mediaBox.get(keyString);
        if (mediaPath != null) {
          filesToDelete.add(mediaPath);
        }
      }
    }
    
    // Batch delete from Hive
    for (var key in keysToDelete) {
      await mediaBox.delete(key);
    }
    
    // Delete the actual files
    for (var filePath in filesToDelete) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // Get local media directory
  static Future<Directory> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }
}

// Hive adapters for our models
class InspectionAdapter extends TypeAdapter<Inspection> {
  @override
  final int typeId = 0;

  @override
  Inspection read(BinaryReader reader) {
    final Map<String, dynamic> json = jsonDecode(reader.readString());
    return Inspection.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, Inspection obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

class RoomAdapter extends TypeAdapter<Room> {
  @override
  final int typeId = 1;

  @override
  Room read(BinaryReader reader) {
    final Map<String, dynamic> json = jsonDecode(reader.readString());
    return Room.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, Room obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 2;

  @override
  Item read(BinaryReader reader) {
    final Map<String, dynamic> json = jsonDecode(reader.readString());
    return Item.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

class DetailAdapter extends TypeAdapter<Detail> {
  @override
  final int typeId = 3;

  @override
  Detail read(BinaryReader reader) {
    final Map<String, dynamic> json = jsonDecode(reader.readString());
    return Detail.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, Detail obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}
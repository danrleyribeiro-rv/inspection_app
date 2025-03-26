// lib/services/inspection_service.dart
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:uuid/uuid.dart';

class InspectionService {
  final SyncService _syncService = SyncService();
  final _uuid = Uuid();
  
  // Get all locally stored inspections
  Future<List<Inspection>> getAllInspections() async {
    return await LocalDatabaseService.getAllInspections();
  }
  
  // Get a specific inspection with complete details
  Future<Inspection?> getInspection(int id) async {
    return await LocalDatabaseService.getInspection(id);
  }
  
  // Download an inspection from the server
  Future<bool> downloadInspection(int id) async {
    return await _syncService.downloadInspection(id);
  }
  
  // Save an inspection locally and attempt to sync
  Future<void> saveInspection(Inspection inspection, {bool syncNow = true}) async {
    // Save locally
    await LocalDatabaseService.saveInspection(inspection);
    
    // Try to sync if requested
    if (syncNow) {
      await _syncService.uploadInspection(inspection);
    }
  }
  
  // Get rooms for an inspection
  Future<List<Room>> getRooms(int inspectionId) async {
    return await LocalDatabaseService.getRoomsByInspection(inspectionId);
  }
  
  // Add a new room to an inspection
  Future<Room> addRoom(int inspectionId, String name, {String? label, int? position}) async {
    // Generate a temporary negative ID to identify it locally
    // This will be replaced with a server ID after sync
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    
    // Create the room
    final room = Room(
      id: tempId,
      inspectionId: inspectionId,
      roomId: tempId, // Using same value for both
      position: position ?? 0,
      roomName: name,
      roomLabel: label,
      isDamaged: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Save locally
    await LocalDatabaseService.saveRoom(room);
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return room;
  }
  
  // Update a room
  Future<void> updateRoom(Room room) async {
    await LocalDatabaseService.saveRoom(room);
    await LocalDatabaseService.setSyncStatus(room.inspectionId, false);
  }
  
  // Delete a room
  Future<void> deleteRoom(int inspectionId, int roomId) async {
    await LocalDatabaseService.deleteRoom(inspectionId, roomId);
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Get items for a room
  Future<List<Item>> getItems(int inspectionId, int roomId) async {
    return await LocalDatabaseService.getItemsByRoom(inspectionId, roomId);
  }
  
  // Add a new item to a room
  Future<Item> addItem(int inspectionId, int roomId, String name, {String? label, int? position}) async {
    // Generate a temporary negative ID to identify it locally
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    
    // Create the item
    final item = Item(
      id: tempId,
      inspectionId: inspectionId,
      roomId: roomId,
      itemId: tempId, // Using same value for both
      position: position ?? 0,
      itemName: name,
      itemLabel: label,
      isDamaged: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Save locally
    await LocalDatabaseService.saveItem(item);
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return item;
  }
  
  // Update an item
  Future<void> updateItem(Item item) async {
    await LocalDatabaseService.saveItem(item);
    await LocalDatabaseService.setSyncStatus(item.inspectionId, false);
  }
  
  // Delete an item
  Future<void> deleteItem(int inspectionId, int roomId, int itemId) async {
    await LocalDatabaseService.deleteItem(inspectionId, roomId, itemId);
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Get details for an item
  Future<List<Detail>> getDetails(int inspectionId, int roomId, int itemId) async {
    return await LocalDatabaseService.getDetailsByItem(inspectionId, roomId, itemId);
  }
  
  // Add a new detail to an item
  Future<Detail> addDetail(int inspectionId, int roomId, int itemId, String name, {String? value, int? position}) async {
    // Generate a temporary negative ID to identify it locally
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    
    // Create the detail
    final detail = Detail(
      id: tempId,
      inspectionId: inspectionId,
      roomId: roomId,
      itemId: itemId,
      detailId: tempId, // Using same value for both
      position: position ?? 0,
      detailName: name,
      detailValue: value,
      isDamaged: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Save locally
    await LocalDatabaseService.saveDetail(detail);
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return detail;
  }
  
  // Update a detail
  Future<void> updateDetail(Detail detail) async {
    await LocalDatabaseService.saveDetail(detail);
    await LocalDatabaseService.setSyncStatus(detail.inspectionId, false);
  }
  
  // Delete a detail
  Future<void> deleteDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    await LocalDatabaseService.deleteDetail(inspectionId, roomId, itemId, detailId);
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Get media for a detail
  Future<List<String>> getMediaPaths(int inspectionId, int roomId, int itemId, int detailId) async {
    return await LocalDatabaseService.getMediaByDetail(inspectionId, roomId, itemId, detailId);
  }
  
  // Add media to a detail
  Future<void> addMedia(int inspectionId, int roomId, int itemId, int detailId, String mediaPath) async {
    await LocalDatabaseService.saveMedia(inspectionId, roomId, itemId, detailId, mediaPath);
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Delete media
  Future<void> deleteMedia(String mediaKey) async {
    await LocalDatabaseService.deleteMedia(mediaKey);
  }
  
  // Move media to another detail
  Future<void> moveMedia(String mediaKey, int newRoomId, int newItemId, int newDetailId) async {
    await LocalDatabaseService.moveMedia(mediaKey, newRoomId, newItemId, newDetailId);
  }
  
  // Check if an inspection is synced
  Future<bool> isInspectionSynced(int inspectionId) async {
    return await LocalDatabaseService.getSyncStatus(inspectionId);
  }
  
  // Force sync an inspection
  Future<bool> syncInspection(int inspectionId) async {
    final inspection = await LocalDatabaseService.getInspection(inspectionId);
    if (inspection == null) return false;
    
    return await _syncService.uploadInspection(inspection);
  }
  
  // Force sync all pending inspections
  Future<void> syncAllPending() async {
    await _syncService.syncAllPendingInspections();
  }
  
  // Calculate completion percentage for an inspection
  Future<double> calculateCompletionPercentage(int inspectionId) async {
    try {
      // Get all rooms
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspectionId);
      
      int totalDetails = 0;
      int filledDetails = 0;
      
      for (var room in rooms) {
        // Get all items for this room
        final items = await LocalDatabaseService.getItemsByRoom(inspectionId, room.id!);
        
        for (var item in items) {
          // Get all details for this item
          final details = await LocalDatabaseService.getDetailsByItem(inspectionId, room.id!, item.id!);
          
          totalDetails += details.length;
          
          // Count filled details
          for (var detail in details) {
            if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
              filledDetails++;
            }
          }
        }
      }
      
      // Avoid division by zero
      if (totalDetails == 0) return 0.0;
      
      return filledDetails / totalDetails;
    } catch (e) {
      print('Error calculating completion percentage: $e');
      return 0.0;
    }
  }
}
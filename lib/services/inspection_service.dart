// lib/services/inspection_service.dart
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InspectionService {
  final SyncService _syncService = SyncService();
  final _uuid = Uuid();
  final _supabase = Supabase.instance.client;
  
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
  
  // Get rooms for an inspection - IMPROVED
  Future<List<Room>> getRooms(int inspectionId) async {
    try {
      // First check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline = connectivityResult == ConnectivityResult.none;
      
      // If we have local rooms stored, use them first
      final localRooms = await LocalDatabaseService.getRoomsByInspection(inspectionId);
      if (localRooms.isNotEmpty || isOffline) {
        return localRooms;
      }
      
      // If online with no local rooms, try to fetch from Supabase
      try {
        final roomsData = await _supabase
            .from('rooms')
            .select('*')
            .eq('inspection_id', inspectionId)
            .order('position', ascending: true);
            
        print('Fetched ${roomsData.length} rooms from server');
        
        // Convert and save each room locally
        List<Room> rooms = [];
        for (var data in roomsData) {
          final room = Room.fromJson(data);
          await LocalDatabaseService.saveRoom(room);
          rooms.add(room);
        }
        
        return rooms;
      } catch (e) {
        print('Error fetching rooms from Supabase: $e');
        // If fetch fails, return whatever is in local storage
        return localRooms;
      }
    } catch (e) {
      print('Error in getRooms: $e');
      return [];
    }
  }
  
  // Add a new room to an inspection
  Future<Room> addRoom(int inspectionId, String name, {String? label, int? position}) async {
    // Generate a temporary ID
    final tempId = 1 + (DateTime.now().millisecondsSinceEpoch % 999);
    
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
  
  // Get items for a room - IMPROVED
  Future<List<Item>> getItems(int inspectionId, int roomId) async {
    try {
      // First check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline = connectivityResult == ConnectivityResult.none;
      
      // If we have local items stored, use them first
      final localItems = await LocalDatabaseService.getItemsByRoom(inspectionId, roomId);
      if (localItems.isNotEmpty || isOffline) {
        return localItems;
      }
      
      // If online with no local items, try to fetch from Supabase
      try {
        final itemsData = await _supabase
            .from('room_items')
            .select('*')
            .eq('inspection_id', inspectionId)
            .eq('room_id', roomId)
            .order('position', ascending: true);
            
        print('Fetched ${itemsData.length} items from server for room $roomId');
        
        // Convert and save each item locally
        List<Item> items = [];
        for (var data in itemsData) {
          final item = Item.fromJson(data);
          await LocalDatabaseService.saveItem(item);
          items.add(item);
        }
        
        return items;
      } catch (e) {
        print('Error fetching items from Supabase: $e');
        // If fetch fails, return whatever is in local storage
        return localItems;
      }
    } catch (e) {
      print('Error in getItems: $e');
      return [];
    }
  }
  
  // Add a new item to a room
  Future<Item> addItem(int inspectionId, int roomId, String name, {String? label, int? position}) async {
    // Generate a temporary positive ID
    final tempId = 1 + (DateTime.now().millisecondsSinceEpoch % 999);
    
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
  
  // Get details for an item - IMPROVED
  Future<List<Detail>> getDetails(int inspectionId, int roomId, int itemId) async {
    try {
      // First check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline = connectivityResult == ConnectivityResult.none;
      
      // If we have local details stored, use them first
      final localDetails = await LocalDatabaseService.getDetailsByItem(inspectionId, roomId, itemId);
      if (localDetails.isNotEmpty || isOffline) {
        return localDetails;
      }
      
      // If online with no local details, try to fetch from Supabase
      try {
        final detailsData = await _supabase
            .from('item_details')
            .select('*')
            .eq('inspection_id', inspectionId)
            .eq('room_id', roomId)
            .eq('room_item_id', itemId)
            .order('position', ascending: true);
            
        print('Fetched ${detailsData.length} details from server for item $itemId');
        
        // Convert and save each detail locally
        List<Detail> details = [];
        for (var data in detailsData) {
          final detail = Detail.fromJson(data);
          await LocalDatabaseService.saveDetail(detail);
          details.add(detail);
        }
        
        return details;
      } catch (e) {
        print('Error fetching details from Supabase: $e');
        // If fetch fails, return whatever is in local storage
        return localDetails;
      }
    } catch (e) {
      print('Error in getDetails: $e');
      return [];
    }
  }
  
  // Add a new detail to an item
  Future<Detail> addDetail(int inspectionId, int roomId, int itemId, String name, {String? value, int? position}) async {
    // Generate a temporary positive ID
    final tempId = 1 + (DateTime.now().millisecondsSinceEpoch % 999);
    
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
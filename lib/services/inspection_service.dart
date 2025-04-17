// lib/services/inspection_service.dart
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:inspection_app/services/firestore_service.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class InspectionService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = Uuid();
  
  // Get all locally stored inspections
  Future<List<Inspection>> getAllInspections() async {
    return await LocalDatabaseService.getAllInspections();
  }
  
  // Get a specific inspection with complete details
  Future<Inspection?> getInspection(int id) async {
    // First try to get from local storage
    final localInspection = await LocalDatabaseService.getInspection(id);
    
    // If found locally, return it
    if (localInspection != null) {
      return localInspection;
    }
    
    // If not found locally and online, try to get from Firestore
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final data = await _firestoreService.getInspection(id);
        if (data != null) {
          final inspection = Inspection.fromJson(data);
          
          // Save to local storage for offline access
          await LocalDatabaseService.saveInspection(inspection);
          
          return inspection;
        }
      } catch (e) {
        print('Error fetching inspection from Firestore: $e');
      }
    }
    
    // Not found anywhere
    return null;
  }
  
  // Download an inspection from the server
  Future<bool> downloadInspection(int id) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    
    try {
      // Get inspection data
      final inspectionData = await _firestoreService.getInspection(id);
      if (inspectionData == null) return false;
      
      // Convert to model and save locally
      final inspection = Inspection.fromJson(inspectionData);
      await LocalDatabaseService.saveInspection(inspection);
      
      // Get rooms
      final roomsData = await _firestoreService.getRoomsByInspection(id);
      for (final roomData in roomsData) {
        final room = Room.fromJson(roomData);
        await LocalDatabaseService.saveRoom(room);
        
        // Get items for this room
        if (room.id != null) {
          final itemsData = await _firestoreService.getItemsByRoom(id, room.id!);
          for (final itemData in itemsData) {
            final item = Item.fromJson(itemData);
            await LocalDatabaseService.saveItem(item);
            
            // Get details for this item
            if (item.id != null) {
              final detailsData = await _firestoreService.getDetailsByItem(id, room.id!, item.id!);
              for (final detailData in detailsData) {
                final detail = Detail.fromJson(detailData);
                await LocalDatabaseService.saveDetail(detail);
              }
            }
          }
        }
      }
      
      // Mark as synced
      await LocalDatabaseService.setSyncStatus(id, true);
      
      return true;
    } catch (e) {
      print('Error downloading inspection: $e');
      return false;
    }
  }
  
  // Save an inspection locally and attempt to sync
  Future<void> saveInspection(Inspection inspection, {bool syncNow = true}) async {
    // Save locally
    await LocalDatabaseService.saveInspection(inspection);
    
    // Try to sync if requested and online
    if (syncNow) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          await _firestoreService.saveInspection(inspection);
          await LocalDatabaseService.setSyncStatus(inspection.id, true);
        } catch (e) {
          print('Error syncing inspection: $e');
          await LocalDatabaseService.setSyncStatus(inspection.id, false);
        }
      } else {
        await LocalDatabaseService.setSyncStatus(inspection.id, false);
      }
    } else {
      await LocalDatabaseService.setSyncStatus(inspection.id, false);
    }
  }
  
  // Get rooms for an inspection
  Future<List<Room>> getRooms(int inspectionId) async {
    // First try to get from local storage
    final localRooms = await LocalDatabaseService.getRoomsByInspection(inspectionId);
    
    // If we have rooms locally, return them
    if (localRooms.isNotEmpty) {
      return localRooms;
    }
    
    // If online with no local rooms, try to fetch from Firestore
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final roomsData = await _firestoreService.getRoomsByInspection(inspectionId);
            
        // Convert and save each room locally
        List<Room> rooms = [];
        for (var data in roomsData) {
          final room = Room.fromJson(data);
          await LocalDatabaseService.saveRoom(room);
          rooms.add(room);
        }
        
        return rooms;
      } catch (e) {
        print('Error fetching rooms from Firestore: $e');
      }
    }
    
    // Return whatever we have (might be empty)
    return localRooms;
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
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveRoom(room);
      } catch (e) {
        print('Error saving room to Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return room;
  }
  
  // Update a room
  Future<void> updateRoom(Room room) async {
    // Save locally
    await LocalDatabaseService.saveRoom(room);
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveRoom(room);
      } catch (e) {
        print('Error updating room in Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(room.inspectionId, false);
  }
  
  // Delete a room
  Future<void> deleteRoom(int inspectionId, int roomId) async {
    // Delete locally
    await LocalDatabaseService.deleteRoom(inspectionId, roomId);
    
    // Try to delete from Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.getRoomsCollection(inspectionId).doc(roomId.toString()).delete();
      } catch (e) {
        print('Error deleting room from Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Get items for a room
  Future<List<Item>> getItems(int inspectionId, int roomId) async {
    // First try to get from local storage
    final localItems = await LocalDatabaseService.getItemsByRoom(inspectionId, roomId);
    
    // If we have items locally, return them
    if (localItems.isNotEmpty) {
      return localItems;
    }
    
    // If online with no local items, try to fetch from Firestore
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final itemsData = await _firestoreService.getItemsByRoom(inspectionId, roomId);
            
        // Convert and save each item locally
        List<Item> items = [];
        for (var data in itemsData) {
          final item = Item.fromJson(data);
          await LocalDatabaseService.saveItem(item);
          items.add(item);
        }
        
        return items;
      } catch (e) {
        print('Error fetching items from Firestore: $e');
      }
    }
    
    // Return whatever we have (might be empty)
    return localItems;
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
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveItem(item);
      } catch (e) {
        print('Error saving item to Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return item;
  }
  
  // Update an item
  Future<void> updateItem(Item item) async {
    // Save locally
    await LocalDatabaseService.saveItem(item);
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveItem(item);
      } catch (e) {
        print('Error updating item in Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(item.inspectionId, false);
  }
  
  // Delete an item
  Future<void> deleteItem(int inspectionId, int roomId, int itemId) async {
    // Delete locally
    await LocalDatabaseService.deleteItem(inspectionId, roomId, itemId);
    
    // Try to delete from Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.getItemsCollection(inspectionId, roomId).doc(itemId.toString()).delete();
      } catch (e) {
        print('Error deleting item from Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Get details for an item
  Future<List<Detail>> getDetails(int inspectionId, int roomId, int itemId) async {
    // First try to get from local storage
    final localDetails = await LocalDatabaseService.getDetailsByItem(inspectionId, roomId, itemId);
    
    // If we have details locally, return them
    if (localDetails.isNotEmpty) {
      return localDetails;
    }
    
    // If online with no local details, try to fetch from Firestore
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final detailsData = await _firestoreService.getDetailsByItem(inspectionId, roomId, itemId);
            
        // Convert and save each detail locally
        List<Detail> details = [];
        for (var data in detailsData) {
          final detail = Detail.fromJson(data);
          await LocalDatabaseService.saveDetail(detail);
          details.add(detail);
        }
        
        return details;
      } catch (e) {
        print('Error fetching details from Firestore: $e');
      }
    }
    
    // Return whatever we have (might be empty)
    return localDetails;
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
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveDetail(detail);
      } catch (e) {
        print('Error saving detail to Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    
    return detail;
  }
  
  // Update a detail
  Future<void> updateDetail(Detail detail) async {
    // Save locally
    await LocalDatabaseService.saveDetail(detail);
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveDetail(detail);
      } catch (e) {
        print('Error updating detail in Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(detail.inspectionId, false);
  }
  
  // Delete a detail
  Future<void> deleteDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    // Delete locally
    await LocalDatabaseService.deleteDetail(inspectionId, roomId, itemId, detailId);
    
    // Try to delete from Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.getDetailsCollection(inspectionId, roomId, itemId).doc(detailId.toString()).delete();
      } catch (e) {
        await _firestoreService.getDetailsCollection(inspectionId, roomId, itemId).doc(detailId.toString()).delete();
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
  }
  
  // Upload media file to an inspection detail
  Future<String?> uploadMedia(
    int inspectionId, 
    int roomId, 
    int itemId, 
    int detailId,
    String localFilePath,
    String mediaType,
  ) async {
    // Save locally first
    await LocalDatabaseService.saveMedia(inspectionId, roomId, itemId, detailId, localFilePath);
    
    // Try to upload to Firebase Storage if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final file = File(localFilePath);
        if (await file.exists()) {
          final downloadUrl = await _firestoreService.uploadMediaFile(
            file, 
            inspectionId, 
            roomId, 
            itemId, 
            detailId, 
            mediaType,
          );
          return downloadUrl;
        }
      } catch (e) {
        print('Error uploading media to Firebase Storage: $e');
      }
    }
    
    // Mark inspection as needing sync
    await LocalDatabaseService.setSyncStatus(inspectionId, false);
    return null;
  }
  
  // Get media for a detail
  Future<List<String>> getMediaPaths(int inspectionId, int roomId, int itemId, int detailId) async {
    return await LocalDatabaseService.getMediaByDetail(inspectionId, roomId, itemId, detailId);
  }
  
  // Delete media
  Future<void> deleteMedia(String mediaKey) async {
    // Delete locally
    await LocalDatabaseService.deleteMedia(mediaKey);
    
    // Extract the inspection ID from the key
    final parts = mediaKey.split('_');
    if (parts.length > 0) {
      final inspectionId = int.tryParse(parts[0]);
      if (inspectionId != null) {
        // Mark inspection as needing sync
        await LocalDatabaseService.setSyncStatus(inspectionId, false);
      }
    }
  }
  
  // Move media to another detail
  Future<void> moveMedia(String mediaKey, int newRoomId, int newItemId, int newDetailId) async {
    // Move locally
    await LocalDatabaseService.moveMedia(mediaKey, newRoomId, newItemId, newDetailId);
    
    // Extract the inspection ID from the key
    final parts = mediaKey.split('_');
    if (parts.length > 0) {
      final inspectionId = int.tryParse(parts[0]);
      if (inspectionId != null) {
        // Mark inspection as needing sync
        await LocalDatabaseService.setSyncStatus(inspectionId, false);
      }
    }
  }
  
  // Save non-conformity
  Future<void> saveNonConformity(Map<String, dynamic> nonConformity) async {
    // Save locally
    await LocalDatabaseService.saveNonConformity(nonConformity);
    
    // Try to save to Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.saveNonConformity(nonConformity);
      } catch (e) {
        print('Error saving non-conformity to Firestore: $e');
      }
    }
    
    // Mark inspection as needing sync
    if (nonConformity.containsKey('inspectionId')) {
      final inspectionId = nonConformity['inspectionId'];
      await LocalDatabaseService.setSyncStatus(inspectionId, false);
    }
  }
  
  // Get non-conformities for an inspection
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(int inspectionId) async {
    // First try to get from local storage
    final localNCs = await LocalDatabaseService.getNonConformitiesByInspection(inspectionId);
    
    // If we have non-conformities locally, return them
    if (localNCs.isNotEmpty) {
      return localNCs;
    }
    
    // If online with no local non-conformities, try to fetch from Firestore
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final nonConformitiesData = await _firestoreService.getNonConformitiesByInspection(inspectionId);
        
        // Save each to local storage
        for (final nc in nonConformitiesData) {
          await LocalDatabaseService.saveNonConformity(nc);
        }
        
        return nonConformitiesData;
      } catch (e) {
        print('Error fetching non-conformities from Firestore: $e');
      }
    }
    
    // Return whatever we have (might be empty)
    return localNCs;
  }
  
  // Update non-conformity status
  Future<void> updateNonConformityStatus(int nonConformityId, String newStatus) async {
    // Update locally
    await LocalDatabaseService.updateNonConformityStatus(nonConformityId, newStatus);
    
    // Try to update in Firestore if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        await _firestoreService.nonConformitiesCollection.doc(nonConformityId.toString()).update({
          'status': newStatus,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error updating non-conformity status in Firestore: $e');
      }
    }
  }
  
  // Check if an inspection is synced
  Future<bool> isInspectionSynced(int inspectionId) async {
    return await LocalDatabaseService.getSyncStatus(inspectionId);
  }
  
  // Force sync an inspection
  Future<bool> syncInspection(int inspectionId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    
    try {
      // Get inspection from local storage
      final inspection = await LocalDatabaseService.getInspection(inspectionId);
      if (inspection == null) return false;
      
      // Upload inspection to Firestore
      await _firestoreService.saveInspection(inspection);
      
      // Get all rooms for this inspection
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspectionId);
      
      // Upload each room and its items/details
      for (final room in rooms) {
        if (room.id == null) continue;
        
        await _firestoreService.saveRoom(room);
        
        // Get all items for this room
        final items = await LocalDatabaseService.getItemsByRoom(inspectionId, room.id!);
        
        for (final item in items) {
          if (item.id == null) continue;
          
          await _firestoreService.saveItem(item);
          
          // Get all details for this item
          final details = await LocalDatabaseService.getDetailsByItem(inspectionId, room.id!, item.id!);
          
          for (final detail in details) {
            if (detail.id == null) continue;
            
            await _firestoreService.saveDetail(detail);
            
            // TODO: Add media sync when needed
          }
        }
      }
      
      // Mark inspection as synced
      await LocalDatabaseService.setSyncStatus(inspectionId, true);
      
      return true;
    } catch (e) {
      print('Error syncing inspection: $e');
      return false;
    }
  }
  
  // Force sync all pending inspections
  Future<void> syncAllPending() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }
    
    try {
      // Get all inspections that need to be synced
      final pendingInspections = await LocalDatabaseService.getPendingSyncInspections();
      
      for (final inspection in pendingInspections) {
        await syncInspection(inspection.id);
      }
    } catch (e) {
      print('Error syncing pending inspections: $e');
    }
  }
  
  // Calculate completion percentage for an inspection
  Future<double> calculateCompletionPercentage(int inspectionId) async {
    try {
      // Get all rooms
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspectionId);
      
      int totalDetails = 0;
      int filledDetails = 0;
      
      for (var room in rooms) {
        // Skip rooms with no ID
        if (room.id == null) continue;
        
        // Get all items for this room
        final items = await LocalDatabaseService.getItemsByRoom(inspectionId, room.id!);
        
        for (var item in items) {
          // Skip items with no ID
          if (item.id == null) continue;
          
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
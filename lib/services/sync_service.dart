// lib/services/sync_service.dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  
  // Download an inspection with all its related data - IMPROVED
  Future<bool> downloadInspection(int inspectionId) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No connectivity, download canceled');
        return false;
      }
      
      print('Started download of inspection $inspectionId');
      
      // 1. Fetch inspection details
      final inspectionData = await _supabase
          .from('inspections')
          .select()
          .eq('id', inspectionId)
          .maybeSingle();
      
      if (inspectionData == null) {
        print('Inspection not found on server');
        return false;
      }
      
      print('Inspection data loaded: ${inspectionData['title']}');
      
      final inspection = Inspection.fromJson(inspectionData);
      await LocalDatabaseService.saveInspection(inspection);
      
      // 2. Fetch rooms
      final roomsData = await _supabase
          .from('rooms')
          .select()
          .eq('inspection_id', inspectionId);
      
      print('Fetched ${roomsData.length} rooms');
      
      // Create a list to store room IDs for later use
      List<int> roomIds = [];
      
      for (var roomData in roomsData) {
        try {
          final room = Room.fromJson(roomData);
          await LocalDatabaseService.saveRoom(room);
          
          if (room.id != null) {
            roomIds.add(room.id!);
          }
        } catch (e) {
          print('Error saving room: $e');
        }
      }
      
      // 3. Fetch items for all rooms
      for (int roomId in roomIds) {
        try {
          final itemsData = await _supabase
              .from('room_items')
              .select()
              .eq('inspection_id', inspectionId)
              .eq('room_id', roomId);
          
          print('Fetched ${itemsData.length} items for room $roomId');
          
          // Create a list to store item IDs for later use
          List<int> itemIds = [];
          
          for (var itemData in itemsData) {
            try {
              final item = Item.fromJson(itemData);
              await LocalDatabaseService.saveItem(item);
              
              if (item.id != null) {
                itemIds.add(item.id!);
              }
            } catch (e) {
              print('Error saving item: $e');
            }
          }
          
          // 4. Fetch details for all items in this room
          for (int itemId in itemIds) {
            try {
              final detailsData = await _supabase
                  .from('item_details')
                  .select()
                  .eq('inspection_id', inspectionId)
                  .eq('room_id', roomId)
                  .eq('room_item_id', itemId);
              
              print('Fetched ${detailsData.length} details for item $itemId');
              
              // Create a list to store detail IDs for later use
              List<int> detailIds = [];
              
              for (var detailData in detailsData) {
                try {
                  final detail = Detail.fromJson(detailData);
                  await LocalDatabaseService.saveDetail(detail);
                  
                  if (detail.id != null) {
                    detailIds.add(detail.id!);
                  }
                } catch (e) {
                  print('Error saving detail: $e');
                }
              }
              
              // 5. Fetch media for each detail
              for (int detailId in detailIds) {
                try {
                  final mediaData = await _supabase
                      .from('media')
                      .select()
                      .eq('inspection_id', inspectionId)
                      .eq('room_id', roomId)
                      .eq('room_item_id', itemId)
                      .eq('detail_id', detailId);
                  
                  print('Fetched ${mediaData.length} media files for detail $detailId');
                  
                  for (var media in mediaData) {
                    await _downloadMedia(
                      media['url'],
                      inspectionId,
                      roomId,
                      itemId,
                      detailId
                    );
                  }
                } catch (e) {
                  print('Error fetching media for detail $detailId: $e');
                }
              }
            } catch (e) {
              print('Error fetching details for item $itemId: $e');
            }
          }
        } catch (e) {
          print('Error fetching items for room $roomId: $e');
        }
      }
      
      // Fetch non-conformities for this inspection
      try {
        final nonConformitiesData = await _supabase
            .from('non_conformities')
            .select('*, rooms!inner(*), room_items!inner(*), item_details!inner(*)')
            .eq('inspection_id', inspectionId);
            
        print('Fetched ${nonConformitiesData.length} non-conformities');
        
        for (var ncData in nonConformitiesData) {
          await LocalDatabaseService.saveNonConformity(ncData);
        }
      } catch (e) {
        print('Error fetching non-conformities: $e');
      }
      
      // Mark as synced
      await LocalDatabaseService.setSyncStatus(inspectionId, true);
      
      print('Successfully downloaded inspection $inspectionId');
      return true;
    } catch (e) {
      print('Error downloading inspection: $e');
      return false;
    }
  }
  
  // Upload an inspection with all its related data
  Future<bool> uploadInspection(Inspection inspection) async {
    try {
      print('Starting upload of inspection ${inspection.id}');
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No connectivity, upload canceled');
        return false;
      }
      
      // 1. Update inspection in Supabase
      final Map<String, dynamic> inspectionData = inspection.toJson();
      
      try {
        print('Updating inspection in Supabase');
        await _supabase
            .from('inspections')
            .update(inspectionData)
            .eq('id', inspection.id);
      } catch (e) {
        print('Error updating inspection: $e');
      }
      
      // 2. Get rooms from local database
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspection.id);
      print('Found ${rooms.length} rooms to upload');
      
      // Maps to keep track of new IDs
      Map<int, int> localRoomIdToServerMap = {};
      
      for (var room in rooms) {
        if (room.id == null) continue;
        
        try {
          final roomData = room.toJson();
          bool isLocalId = room.id! > 0 && room.id! < 1000;
          
          if (isLocalId) {
            // Create new room in server
            print('Inserting new room ${room.roomName}');
            roomData.remove('id');
            roomData.remove('room_id');
            
            final result = await _supabase
                .from('rooms')
                .insert(roomData)
                .select('id, room_id')
                .single();
                
            final newRoomId = result['id'];
            final newRoomRoomId = result['room_id'];
            
            if (newRoomId != null) {
              // Remember the mapping from local to server ID
              localRoomIdToServerMap[room.id!] = newRoomId;
              
              // Update local room with server ID
              final updatedRoom = room.copyWith(
                id: newRoomId,
                roomId: newRoomRoomId,
              );
              await LocalDatabaseService.saveRoom(updatedRoom);
            }
          } else {
            // Update existing room
            print('Updating existing room ${room.id}');
            await _supabase
                .from('rooms')
                .update(roomData)
                .eq('id', room.id!);
          }
          
          // Now upload all items for this room
          await _uploadItemsForRoom(inspection.id, room.id!, localRoomIdToServerMap);
          
        } catch (e) {
          print('Error uploading room ${room.id}: $e');
        }
      }
      
      // Mark as synced
      await LocalDatabaseService.setSyncStatus(inspection.id, true);
      return true;
    } catch (e) {
      print('Error uploading inspection: $e');
      return false;
    }
  }
  
  // Helper method to upload all items for a room
  Future<void> _uploadItemsForRoom(int inspectionId, int roomId, Map<int, int> roomIdMap) async {
    // Get actual server room ID
    int serverRoomId = roomIdMap[roomId] ?? roomId;
    
    // Get all items for this room
    final items = await LocalDatabaseService.getItemsByRoom(inspectionId, roomId);
    print('Uploading ${items.length} items for room $roomId (server ID: $serverRoomId)');
    
    // Maps to keep track of new IDs
    Map<int, int> localItemIdToServerMap = {};
    
    for (var item in items) {
      if (item.id == null) continue;
      
      try {
        final itemData = item.toJson();
        // Update with server room ID
        itemData['room_id'] = serverRoomId;
        
        bool isLocalId = item.id! > 0 && item.id! < 1000;
        
        if (isLocalId) {
          // Create new item in server
          print('Inserting new item ${item.itemName}');
          itemData.remove('id');
          itemData.remove('item_id');
          
          final result = await _supabase
              .from('room_items')
              .insert(itemData)
              .select('id, item_id')
              .single();
              
          final newItemId = result['id'];
          final newItemItemId = result['item_id'];
          
          if (newItemId != null) {
            // Remember the mapping from local to server ID
            localItemIdToServerMap[item.id!] = newItemId;
            
            // Update local item with server ID
            final updatedItem = item.copyWith(
              id: newItemId,
              roomId: serverRoomId,
              itemId: newItemItemId,
            );
            await LocalDatabaseService.saveItem(updatedItem);
          }
        } else {
          // Update existing item
          print('Updating existing item ${item.id}');
          await _supabase
              .from('room_items')
              .update(itemData)
              .eq('id', item.id!);
        }
        
        // Now upload all details for this item
        await _uploadDetailsForItem(inspectionId, roomId, item.id!, roomIdMap, localItemIdToServerMap);
        
      } catch (e) {
        print('Error uploading item ${item.id}: $e');
      }
    }
  }
  
  // Helper method to upload all details for an item
  Future<void> _uploadDetailsForItem(
    int inspectionId, 
    int roomId, 
    int itemId, 
    Map<int, int> roomIdMap, 
    Map<int, int> itemIdMap
  ) async {
    // Get actual server room and item IDs
    int serverRoomId = roomIdMap[roomId] ?? roomId;
    int serverItemId = itemIdMap[itemId] ?? itemId;
    
    // Get all details for this item
    final details = await LocalDatabaseService.getDetailsByItem(inspectionId, roomId, itemId);
    print('Uploading ${details.length} details for item $itemId (server ID: $serverItemId)');
    
    for (var detail in details) {
      if (detail.id == null) continue;
      
      try {
        final detailData = detail.toJson();
        // Update with server room and item IDs
        detailData['room_id'] = serverRoomId;
        detailData['room_item_id'] = serverItemId;
        
        bool isLocalId = detail.id! > 0 && detail.id! < 1000;
        
        if (isLocalId) {
          // Create new detail in server
          print('Inserting new detail ${detail.detailName}');
          detailData.remove('id');
          detailData.remove('detail_id');
          
          final result = await _supabase
              .from('item_details')
              .insert(detailData)
              .select('id, detail_id')
              .single();
              
          final newDetailId = result['id'];
          final newDetailDetailId = result['detail_id'];
          
          if (newDetailId != null) {
            // Update local detail with server ID
            final updatedDetail = detail.copyWith(
              id: newDetailId,
              roomId: serverRoomId,
              itemId: serverItemId,
              detailId: newDetailDetailId,
            );
            await LocalDatabaseService.saveDetail(updatedDetail);
            
            // Now upload all media for this detail
            await _uploadMediaForDetail(inspectionId, roomId, itemId, detail.id!, serverRoomId, serverItemId, newDetailId);
          }
        } else {
          // Update existing detail
          print('Updating existing detail ${detail.id}');
          await _supabase
              .from('item_details')
              .update(detailData)
              .eq('id', detail.id!);
              
          // Now upload all media for this detail
          await _uploadMediaForDetail(inspectionId, roomId, itemId, detail.id!, serverRoomId, serverItemId, detail.id!);
        }
      } catch (e) {
        print('Error uploading detail ${detail.id}: $e');
      }
    }
  }
  
  // Helper to upload all media for a detail (continued)
  Future<void> _uploadMediaForDetail(
    int inspectionId, 
    int localRoomId, 
    int localItemId, 
    int localDetailId,
    int serverRoomId,
    int serverItemId,
    int serverDetailId
  ) async {
    try {
      // Get all media for this detail from local database
      final mediaList = await LocalDatabaseService.getMediaByDetail(
        inspectionId,
        localRoomId,
        localItemId,
        localDetailId
      );
      
      print('Uploading ${mediaList.length} media files for detail $localDetailId (server ID: $serverDetailId)');
      
      for (var mediaPath in mediaList) {
        // Check if the file exists
        final file = File(mediaPath);
        if (!await file.exists()) continue;
        
        // Create a unique path in storage
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = path.basename(mediaPath);
        final storagePath = 'inspections/$inspectionId/$serverRoomId/$serverItemId/$serverDetailId/${timestamp}_$filename';
        
        // Upload to storage
        try {
          final storageResponse = await _supabase.storage
              .from('inspection_media')
              .upload(storagePath, file);
          
          // Get the public URL
          final publicUrl = _supabase.storage
              .from('inspection_media')
              .getPublicUrl(storageResponse);
          
          // Check if media already exists in the database
          final existingMedia = await _supabase
              .from('media')
              .select()
              .eq('inspection_id', inspectionId)
              .eq('room_id', serverRoomId)
              .eq('room_item_id', serverItemId)
              .eq('detail_id', serverDetailId)
              .eq('url', mediaPath)
              .maybeSingle();
          
          if (existingMedia != null) {
            // Update existing media
            await _supabase
                .from('media')
                .update({
                  'url': publicUrl,
                })
                .eq('id', existingMedia['id']);
          } else {
            // Determine media type based on extension
            final mediaType = _getMediaType(mediaPath);
            
            // Insert new media
            await _supabase
                .from('media')
                .insert({
                  'inspection_id': inspectionId,
                  'room_id': serverRoomId,
                  'room_item_id': serverItemId,
                  'detail_id': serverDetailId,
                  'url': publicUrl,
                  'type': mediaType,
                  'media_id': _uuid.v4(), // Generate a UUID
                  'created_at': DateTime.now().toIso8601String()
                });
          }
        } catch (e) {
          print('Error uploading media file $mediaPath: $e');
        }
      }
    } catch (e) {
      print('Error uploading media for detail $localDetailId: $e');
    }
  }
  
  // Sync all pending inspections
  Future<void> syncAllPendingInspections() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No connectivity, sync canceled');
        return;
      }
      
      // Get all pending inspections
      final pendingInspections = await LocalDatabaseService.getPendingSyncInspections();
      print('Found ${pendingInspections.length} pending inspections to sync');
      
      for (var inspection in pendingInspections) {
        await uploadInspection(inspection);
      }
    } catch (e) {
      print('Error syncing pending inspections: $e');
    }
  }
  
  // Helper to download media file
  Future<void> _downloadMedia(String url, int inspectionId, int roomId, int itemId, int detailId) async {
    try {
      // Create a unique filename
      final filename = path.basename(url);
      final mediaDir = await LocalDatabaseService.getMediaDirectory();
      final localPath = '${mediaDir.path}/$filename';
      
      try {
        // Parse URL to get storage path
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        
        // Skip the first segment which is usually the bucket name
        final storagePath = pathSegments.skip(1).join('/');
        
        // Download the file
        final response = await _supabase.storage
            .from('inspection_media')
            .download(storagePath);
        
        // Save to local file
        final file = File(localPath);
        await file.writeAsBytes(response);
        
        // Save reference in local database
        await LocalDatabaseService.saveMedia(
          inspectionId,
          roomId,
          itemId,
          detailId,
          localPath
        );
        
        print('Media downloaded successfully: $filename');
      } catch (e) {
        print('Error downloading media from $url: $e');
        
        // Try direct download as fallback
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final file = File(localPath);
            await file.writeAsBytes(response.bodyBytes);
            
            // Save reference in local database
            await LocalDatabaseService.saveMedia(
              inspectionId,
              roomId,
              itemId,
              detailId,
              localPath
            );
            
            print('Media downloaded with fallback method: $filename');
          }
        } catch (directError) {
          print('Direct download also failed: $directError');
        }
      }
    } catch (e) {
      print('Error in _downloadMedia: $e');
    }
  }
  
  // Helper to determine media type based on extension
  String _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
      return 'image';
    } else if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext)) {
      return 'video';
    } else {
      return 'other';
    }
  }
  
  // Create a UUID instance for media IDs
  final _uuid = Uuid();
}
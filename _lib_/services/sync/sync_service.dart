// lib/services/sync/sync_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/services/local_database_service.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  
  // Download an inspection with all related data
  Future<bool> downloadInspection(int inspectionId) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // 1. Fetch inspection details
      final inspectionData = await _supabase
          .from('inspections')
          .select()
          .eq('id', inspectionId)
          .maybeSingle();
      
      if (inspectionData == null) {
        return false;
      }
      
      final inspection = Inspection.fromJson(inspectionData);
      await LocalDatabaseService.saveInspection(inspection);
      
      // 2. Fetch rooms
      final roomsData = await _supabase
          .from('rooms')
          .select()
          .eq('inspection_id', inspectionId);
      
      for (var roomData in roomsData) {
        final room = Room.fromJson(roomData);
        await LocalDatabaseService.saveRoom(room);
        
        // Skip if room ID is null
        if (room.id == null) continue;
        
        // 3. Fetch items for each room
        final itemsData = await _supabase
            .from('room_items')
            .select()
            .eq('inspection_id', inspectionId)
            .eq('room_id', room.id!);
        
        for (var itemData in itemsData) {
          final item = Item.fromJson(itemData);
          await LocalDatabaseService.saveItem(item);
          
          // Skip if item ID is null
          if (item.id == null || item.roomId == null) continue;
          
          // 4. Fetch details for each item
          final detailsData = await _supabase
              .from('item_details')
              .select()
              .eq('inspection_id', inspectionId)
              .eq('room_id', room.id!)
              .eq('room_item_id', item.id!);
          
          for (var detailData in detailsData) {
            final detail = Detail.fromJson(detailData);
            await LocalDatabaseService.saveDetail(detail);
            
            // 5. Fetch non-conformities for each detail
            await _downloadNonConformities(inspectionId, room.id!, item.id!, detail.id!);
            
            // 6. Download media files
            await _downloadMediaForDetail(inspectionId, room.id!, item.id!, detail.id!);
          }
        }
      }
      
      // Mark as synced
      await LocalDatabaseService.setSyncStatus(inspectionId, true);
      return true;
    } catch (e) {
      print('Error downloading inspection: $e');
      return false;
    }
  }
  
  // Upload an inspection with all related data
  Future<bool> uploadInspection(Inspection inspection) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // 1. Update inspection in Supabase
      await _supabase
          .from('inspections')
          .update(inspection.toJson())
          .eq('id', inspection.id);
      
      // 2. Get rooms from local database
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspection.id);
      
      for (var room in rooms) {
        if (room.id == null) continue;
        
        // Handle room upload based on whether it's a new or existing room
        await _syncRoom(room);
        
        // 3. Get items for this room
        final items = await LocalDatabaseService.getItemsByRoom(inspection.id, room.id!);
        
        for (var item in items) {
          if (item.id == null || item.roomId == null) continue;
          
          // Handle item upload
          await _syncItem(item);
          
          // 4. Get details for this item
          final details = await LocalDatabaseService.getDetailsByItem(
            inspection.id, item.roomId!, item.id!);
          
          for (var detail in details) {
            if (detail.id == null || detail.roomId == null || detail.itemId == null) continue;
            
            // Handle detail upload
            await _syncDetail(detail);
            
            // 5. Upload media for this detail
            await _syncMediaForDetail(detail);
            
            // 6. Sync non-conformities for this detail
            await _syncNonConformities(inspection.id, detail.roomId!, detail.itemId!, detail.id!);
          }
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

  // Helper method to sync a room
  Future<void> _syncRoom(Room room) async {
    try {
      if (room.id == null) return;
      
      // Check if room exists on server
      final existingRoom = await _supabase
          .from('rooms')
          .select('id')
          .eq('inspection_id', room.inspectionId)
          .eq('room_id', room.id)
          .maybeSingle();
      
      if (existingRoom != null) {
        // Update existing room
        await _supabase
            .from('rooms')
            .update(room.toJson())
            .eq('inspection_id', room.inspectionId)
            .eq('room_id', room.id);
      } else {
        // Insert new room
        await _supabase
            .from('rooms')
            .insert(room.toJson());
      }
    } catch (e) {
      print('Error syncing room: $e');
    }
  }

  // Helper method to sync an item
  Future<void> _syncItem(Item item) async {
    try {
      if (item.id == null || item.roomId == null) return;
      
      // Check if item exists on server
      final existingItem = await _supabase
          .from('room_items')
          .select('id')
          .eq('inspection_id', item.inspectionId)
          .eq('room_id', item.roomId)
          .eq('item_id', item.id)
          .maybeSingle();
      
      if (existingItem != null) {
        // Update existing item
        await _supabase
            .from('room_items')
            .update(item.toJson())
            .eq('inspection_id', item.inspectionId)
            .eq('room_id', item.roomId)
            .eq('item_id', item.id);
      } else {
        // Insert new item
        await _supabase
            .from('room_items')
            .insert(item.toJson());
      }
    } catch (e) {
      print('Error syncing item: $e');
    }
  }

  // Helper method to sync a detail
  Future<void> _syncDetail(Detail detail) async {
    try {
      if (detail.id == null || detail.roomId == null || detail.itemId == null) return;
      
      // Check if detail exists on server
      final existingDetail = await _supabase
          .from('item_details')
          .select('id')
          .eq('inspection_id', detail.inspectionId)
          .eq('room_id', detail.roomId)
          .eq('room_item_id', detail.itemId)
          .eq('detail_id', detail.id)
          .maybeSingle();
      
      if (existingDetail != null) {
        // Update existing detail
        await _supabase
            .from('item_details')
            .update(detail.toJson())
            .eq('inspection_id', detail.inspectionId)
            .eq('room_id', detail.roomId)
            .eq('room_item_id', detail.itemId)
            .eq('detail_id', detail.id);
      } else {
        // Insert new detail
        await _supabase
            .from('item_details')
            .insert(detail.toJson());
      }
    } catch (e) {
      print('Error syncing detail: $e');
    }
  }

  // Helper method to download media for a detail
  Future<void> _downloadMediaForDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    try {
      // Get media for this detail from Supabase
      final mediaData = await _supabase
          .from('media')
          .select('id, url, type, section')
          .eq('inspection_id', inspectionId)
          .eq('room_id', roomId)
          .eq('room_item_id', itemId)
          .eq('detail_id', detailId);
      
      for (var media in mediaData) {
        final mediaUrl = media['url'];
        final mediaType = media['type'];
        
        // Download media file and save locally
        await _downloadMediaFile(
          inspectionId,
          roomId,
          itemId,
          detailId,
          mediaUrl,
          mediaType,
        );
      }
    } catch (e) {
      print('Error downloading media: $e');
    }
  }

  // Helper method to download a media file
  Future<void> _downloadMediaFile(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    String mediaUrl,
    String mediaType,
  ) async {
    try {
      // Extract filename from URL
      final filename = mediaUrl.split('/').last;
      
      // Get media directory
      final mediaDir = await LocalDatabaseService.getMediaDirectory();
      final localPath = '${mediaDir.path}/$filename';
      
      // Check if file already exists
      final file = File(localPath);
      if (await file.exists()) {
        return;
      }
      
      // Extract bucket and path from URL
      final uri = Uri.parse(mediaUrl);
      final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
      
      // Download file from Supabase Storage
      final response = await _supabase.storage.from('inspection_media').download(path);
      
      // Save to file
      await file.writeAsBytes(response);
      
      // Save reference in local database
      await LocalDatabaseService.saveMedia(
        inspectionId,
        roomId,
        itemId,
        detailId,
        localPath,
      );
    } catch (e) {
      print('Error downloading media file: $e');
    }
  }

  // Helper method to sync media for a detail
  Future<void> _syncMediaForDetail(Detail detail) async {
    try {
      if (detail.id == null || detail.roomId == null || detail.itemId == null) return;
      
      // Get local media paths for this detail
      final mediaPaths = await LocalDatabaseService.getMediaByDetail(
        detail.inspectionId,
        detail.roomId!,
        detail.itemId!,
        detail.id!,
      );
      
      for (var mediaPath in mediaPaths) {
        // Check if file exists
        final file = File(mediaPath);
        if (!await file.exists()) continue;
        
        // Upload file to Supabase Storage
        final filename = mediaPath.split('/').last;
        final storagePath = 'inspections/${detail.inspectionId}/${detail.roomId}/${detail.itemId}/${detail.id}/$filename';
        
        try {
          // Upload file
          final uploadResult = await _supabase.storage
              .from('inspection_media')
              .upload(storagePath, file);
          
          // Get public URL
          final publicUrl = _supabase.storage
              .from('inspection_media')
              .getPublicUrl(uploadResult);
          
          // Check if media already exists in database
          final existingMedia = await _supabase
              .from('media')
              .select('id')
              .eq('inspection_id', detail.inspectionId)
              .eq('room_id', detail.roomId)
              .eq('room_item_id', detail.itemId)
              .eq('detail_id', detail.id)
              .eq('url', publicUrl)
              .maybeSingle();
          
          if (existingMedia == null) {
            // Add new media record
            await _supabase.from('media').insert({
              'inspection_id': detail.inspectionId,
              'room_id': detail.roomId,
              'room_item_id': detail.itemId,
              'detail_id': detail.id,
              'type': mediaPath.toLowerCase().endsWith('.mp4') ? 'video' : 'image',
              'url': publicUrl,
              'section': detail.detailName,
            });
          }
        } catch (e) {
          print('Error uploading media file: $e');
        }
      }
    } catch (e) {
      print('Error syncing media: $e');
    }
  }

  // Download non-conformities for a detail
  Future<void> _downloadNonConformities(int inspectionId, int roomId, int itemId, int detailId) async {
    try {
      // Get non-conformities for this detail from Supabase
      final nonConformities = await _supabase
          .from('non_conformities')
          .select('*')
          .eq('inspection_id', inspectionId)
          .eq('room_id', roomId)
          .eq('item_id', itemId)
          .eq('detail_id', detailId);
      
      for (var nc in nonConformities) {
        // Save to local database
        await LocalDatabaseService.saveNonConformity(nc);
        
        // Download media for this non-conformity
        await _downloadNonConformityMedia(nc['id']);
      }
    } catch (e) {
      print('Error downloading non-conformities: $e');
    }
  }

  // Download media for a non-conformity
  Future<void> _downloadNonConformityMedia(int nonConformityId) async {
    try {
      // Get media for this non-conformity from Supabase
      final mediaData = await _supabase
          .from('non_conformity_media')
          .select('id, url, type')
          .eq('non_conformity_id', nonConformityId);
      
      for (var media in mediaData) {
        final mediaUrl = media['url'];
        final mediaType = media['type'];
        
        // Extract filename from URL
        final filename = mediaUrl.split('/').last;
        
        // Get media directory
        final mediaDir = await LocalDatabaseService.getMediaDirectory();
        final localPath = '${mediaDir.path}/$filename';
        
        // Check if file already exists
        final file = File(localPath);
        if (await file.exists()) {
          continue;
        }
        
        // Extract bucket and path from URL
        final uri = Uri.parse(mediaUrl);
        final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
        
        // Download file from Supabase Storage
        final response = await _supabase.storage.from('non_conformity_media').download(path);
        
        // Save to file
        await file.writeAsBytes(response);
        
        // Save reference in local database
        await LocalDatabaseService.saveNonConformityMedia(
          nonConformityId,
          localPath,
          mediaType,
        );
      }
    } catch (e) {
      print('Error downloading non-conformity media: $e');
    }
  }

  // Sync non-conformities for a detail
  Future<void> _syncNonConformities(int inspectionId, int roomId, int itemId, int detailId) async {
    try {
      // Get local non-conformities for this detail
      final nonConformities = await LocalDatabaseService.getNonConformitiesByDetail(
        inspectionId, roomId, itemId, detailId);
      
      for (var nc in nonConformities) {
        final nonConformityId = nc['id'];
        
        // Check if non-conformity exists on server
        final existingNC = await _supabase
            .from('non_conformities')
            .select('id')
            .eq('id', nonConformityId)
            .maybeSingle();
        
        if (existingNC != null) {
          // Update existing non-conformity
          await _supabase
              .from('non_conformities')
              .update(nc)
              .eq('id', nonConformityId);
        } else {
          // Insert new non-conformity
          final result = await _supabase
              .from('non_conformities')
              .insert(nc)
              .select('id')
              .single();
          
          // Update local ID with server ID
          final newId = result['id'];
          await LocalDatabaseService.updateNonConformityId(nonConformityId, newId);
          
          // Update nonConformityId for syncing media
          nc['id'] = newId;
        }
        
        // Sync media for this non-conformity
        await _syncNonConformityMedia(nc['id']);
      }
    } catch (e) {
      print('Error syncing non-conformities: $e');
    }
  }

  // Sync media for a non-conformity
  Future<void> _syncNonConformityMedia(int nonConformityId) async {
    try {
      // Get local media for this non-conformity
      final mediaItems = await LocalDatabaseService.getNonConformityMedia(nonConformityId);
      
      for (var media in mediaItems) {
        final mediaPath = media['path'];
        final mediaType = media['type'];
        
        // Check if file exists
        final file = File(mediaPath);
        if (!await file.exists()) continue;
        
        // Upload file to Supabase Storage
        final filename = mediaPath.split('/').last;
        final storagePath = 'non_conformities/$nonConformityId/$filename';
        
        try {
          // Upload file
          final uploadResult = await _supabase.storage
              .from('non_conformity_media')
              .upload(storagePath, file);
          
          // Get public URL
          final publicUrl = _supabase.storage
              .from('non_conformity_media')
              .getPublicUrl(uploadResult);
          
          // Check if media already exists in database
          final existingMedia = await _supabase
              .from('non_conformity_media')
              .select('id')
              .eq('non_conformity_id', nonConformityId)
              .eq('url', publicUrl)
              .maybeSingle();
          
          if (existingMedia == null) {
            // Add new media record
            await _supabase.from('non_conformity_media').insert({
              'non_conformity_id': nonConformityId,
              'type': mediaType,
              'url': publicUrl,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          print('Error uploading non-conformity media: $e');
        }
      }
    } catch (e) {
      print('Error syncing non-conformity media: $e');
    }
  }

  // Sync all pending inspections
  Future<void> syncAllPendingInspections() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return;
      }
      
      // Get pending inspections
      final pendingInspections = await LocalDatabaseService.getPendingSyncInspections();
      
      for (var inspection in pendingInspections) {
        await uploadInspection(inspection);
      }
    } catch (e) {
      print('Error syncing pending inspections: $e');
    }
  }
}
// lib/services/sync_service.dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:path/path.dart' as path;

class SyncService {
  final _supabase = Supabase.instance.client;
  
  // Download an inspection with all its related data
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
          if (item.id == null) continue;
          
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
            
            // Skip if detail ID is null
            if (detail.id == null) continue;
            
            // 5. Fetch media for each detail
            final mediaData = await _supabase
                .from('media')
                .select()
                .eq('inspection_id', inspectionId)
                .eq('room_id', room.id!)
                .eq('room_item_id', item.id!)
                .eq('detail_id', detail.id!);
            
            for (var media in mediaData) {
              await _downloadMedia(
                media['url'],
                inspectionId,
                room.id!,
                item.id!,
                detail.id!
              );
            }
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
  
  // Upload an inspection with all its related data
  Future<bool> uploadInspection(Inspection inspection) async {
    try {
      print('Iniciando upload da inspeção ${inspection.id}');
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('Sem conexão. Upload cancelado');
        return false;
      }
      
      // Preparar dados da inspeção para upload, removendo IDs temporários
      final Map<String, dynamic> inspectionData = inspection.toJson();
      
      // 1. Update inspection in Supabase
      print('Atualizando inspeção no Supabase');
      await _supabase
          .from('inspections')
          .update(inspectionData)
          .eq('id', inspection.id);
      
      // 2. Get rooms from local database
      print('Buscando ambientes locais');
      final rooms = await LocalDatabaseService.getRoomsByInspection(inspection.id);
      print('Encontrados ${rooms.length} ambientes');
      
      for (var room in rooms) {
        // Skip if room ID is null
        if (room.id == null) {
          print('Ambiente com ID nulo, pulando');
          continue;
        }
        
        // Preparar dados para upload
        final roomData = room.toJson();
        
        // Verificar se o ID é temporário (positivo, mas não do servidor)
        bool isTemporaryId = room.id! > 0 && room.id! < 1000;
        print('Ambiente ${room.id} (${room.roomName}) - ID temporário: $isTemporaryId');
        
        if (isTemporaryId) {
          // Para IDs temporários, criar novo registro
          print('Inserindo novo ambiente com nome: ${room.roomName}');
          try {
            // Remover o ID para que o servidor gere um novo
            roomData.remove('id');
            
            final result = await _supabase
                .from('rooms')
                .insert(roomData)
                .select('id')
                .single();
            
            // Atualizar ID local com o do servidor
            final newRoomId = result['id'];
            print('Novo ID do servidor para ambiente: $newRoomId');
            
            if (newRoomId != null) {
              await _updateRoomIdLocally(room, newRoomId);
            }
          } catch (e) {
            print('Erro ao inserir ambiente: $e');
            continue;
          }
        } else {
          // Para IDs já existentes no servidor, atualizar
          print('Atualizando ambiente existente: ${room.id}');
          try {
            await _supabase
                .from('rooms')
                .update(roomData)
                .eq('id', room.id!);
          } catch (e) {
            print('Erro ao atualizar ambiente: $e');
            // Se falhar a atualização, tentar inserir
            try {
              roomData.remove('id');
              final result = await _supabase
                  .from('rooms')
                  .insert(roomData)
                  .select('id')
                  .single();
                  
              // Atualizar ID local
              final newRoomId = result['id'];
              if (newRoomId != null) {
                await _updateRoomIdLocally(room, newRoomId);
              }
            } catch (insertError) {
              print('Também falhou ao inserir: $insertError');
            }
          }
        }
      }
      
      // Mark as synced
      await LocalDatabaseService.setSyncStatus(inspection.id, true);
      return true;
    } catch (e) {
      print('Erro ao fazer upload da inspeção: $e');
      return false;
    }
  }
  
  // Método para atualizar ID localmente
  Future<void> _updateRoomIdLocally(Room room, int newId) async {
    // Criar nova room com ID atualizado
    final updatedRoom = room.copyWith(id: newId);
    
    // Salvar localmente
    await LocalDatabaseService.saveRoom(updatedRoom);
  }
  // Sync all pending inspections
  Future<void> syncAllPendingInspections() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return;
      }
      
      // Get all pending inspections
      final pendingInspections = await LocalDatabaseService.getPendingSyncInspections();
      
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
      
      // Download the file
      final response = await _supabase.storage.from('inspection_media').download(url);
      
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
    } catch (e) {
      print('Error downloading media: $e');
    }
  }
  
  // Helper to upload all media for a detail
  Future<void> _uploadMedia(int inspectionId, int roomId, int itemId, int detailId) async {
    try {
      // Get all media for this detail from local database
      final mediaList = await LocalDatabaseService.getMediaByDetail(
        inspectionId,
        roomId,
        itemId,
        detailId
      );
      
      for (var mediaPath in mediaList) {
        // Check if the file exists
        final file = File(mediaPath);
        if (!await file.exists()) continue;
        
        // Create a unique path in storage
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = path.basename(mediaPath);
        final storagePath = 'inspections/$inspectionId/$roomId/$itemId/$detailId/${timestamp}_$filename';
        
        // Upload to storage
        await _supabase.storage.from('inspection_media').upload(
          storagePath,
          file,
        );
        
        // Get the public URL
        final publicUrl = _supabase.storage.from('inspection_media').getPublicUrl(storagePath);
        
        // Check if media already exists in the database
        final existingMedia = await _supabase
            .from('media')
            .select()
            .eq('inspection_id', inspectionId)
            .eq('room_id', roomId)
            .eq('room_item_id', itemId)
            .eq('detail_id', detailId)
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
          // Insert new media
          await _supabase
              .from('media')
              .insert({
                'inspection_id': inspectionId,
                'room_id': roomId,
                'room_item_id': itemId,
                'detail_id': detailId,
                'url': publicUrl,
                'type': _getMediaType(mediaPath),
              });
        }
      }
    } catch (e) {
      print('Error uploading media: $e');
    }
  }
  
  // Helper to check if a record exists
  Future<bool> _checkIfExists(String table, String column, dynamic value) async {
    if (value == null) return false;
    
    try {
      final result = await _supabase
          .from(table)
          .select(column)
          .eq(column, value)
          .maybeSingle();
      
      return result != null;
    } catch (e) {
      return false;
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
}
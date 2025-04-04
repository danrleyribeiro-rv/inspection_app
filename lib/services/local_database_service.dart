// lib/services/local_database_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

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

  static bool _isInitialized() {
    try {
      return Hive.isBoxOpen(inspectionsBoxName) &&
             Hive.isBoxOpen(roomsBoxName) &&
             Hive.isBoxOpen(itemsBoxName) &&
             Hive.isBoxOpen(detailsBoxName);
    } catch (e) {
      print('Erro ao verificar inicialização do Hive: $e');
      return false;
    }
  }

  // Adicionar ao arquivo lib/services/local_database_service.dart

  // Métodos para obter todos os ambientes salvos localmente
  static Future<List<Room>> getAllLocalRooms() async {
    try {
      final box = Hive.box<Room>(roomsBoxName);
      return box.values.toList();
    } catch (e) {
      print('Erro ao obter todos os ambientes: $e');
      return [];
    }
  }
  
  // Obter um ambiente específico pelo ID
  static Future<Room?> getRoomById(int roomId) async {
    try {
      final box = Hive.box<Room>(roomsBoxName);
      // Buscar em todas as chaves que contenham esse roomId
      for (var key in box.keys) {
        final room = box.get(key);
        if (room != null && room.id == roomId) {
          return room;
        }
      }
      return null;
    } catch (e) {
      print('Erro ao obter ambiente por ID: $e');
      return null;
    }
  }
  
  // Métodos para obter todos os itens salvos localmente
  static Future<List<Item>> getAllLocalItems() async {
    try {
      final box = Hive.box<Item>(itemsBoxName);
      return box.values.toList();
    } catch (e) {
      print('Erro ao obter todos os itens: $e');
      return [];
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_isInitialized()) {
      try {
        // Re-inicializar
        await Hive.initFlutter();
        
        // Registrar adapters novamente
        try {
          Hive.registerAdapter(InspectionAdapter());
        } catch (e) {
          print('Adapter de Inspection já registrado');
        }
        
        try {
          Hive.registerAdapter(RoomAdapter());
        } catch (e) {
          print('Adapter de Room já registrado');
        }
        
        try {
          Hive.registerAdapter(ItemAdapter());
        } catch (e) {
          print('Adapter de Item já registrado');
        }
        
        try {
          Hive.registerAdapter(DetailAdapter());
        } catch (e) {
          print('Adapter de Detail já registrado');
        }
        
        // Abrir caixas
        if (!Hive.isBoxOpen(inspectionsBoxName)) {
          await Hive.openBox<Inspection>(inspectionsBoxName);
        }
        
        if (!Hive.isBoxOpen(roomsBoxName)) {
          await Hive.openBox<Room>(roomsBoxName);
        }
        
        if (!Hive.isBoxOpen(itemsBoxName)) {
          await Hive.openBox<Item>(itemsBoxName);
        }
        
        if (!Hive.isBoxOpen(detailsBoxName)) {
          await Hive.openBox<Detail>(detailsBoxName);
        }
        
        if (!Hive.isBoxOpen(mediaBoxName)) {
          await Hive.openBox<String>(mediaBoxName);
        }
        
        if (!Hive.isBoxOpen(syncStatusBoxName)) {
          await Hive.openBox<bool>(syncStatusBoxName);
        }
        
        print('Hive reinicializado com sucesso');
      } catch (e) {
        print('Erro ao reinicializar Hive: $e');
      }
    }
  }
  
  
  // Obter um item específico pelo ID
  static Future<Item?> getItemById(int itemId) async {
    try {
      final box = Hive.box<Item>(itemsBoxName);
      // Buscar em todas as chaves que contenham esse itemId
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null && item.id == itemId) {
          return item;
        }
      }
      return null;
    } catch (e) {
      print('Erro ao obter item por ID: $e');
      return null;
    }
  }
  
  // Métodos para obter todos os detalhes salvos localmente
  static Future<List<Detail>> getAllLocalDetails() async {
    try {
      final box = Hive.box<Detail>(detailsBoxName);
      return box.values.toList();
    } catch (e) {
      print('Erro ao obter todos os detalhes: $e');
      return [];
    }
  }
  
  // Obter um detalhe específico pelo ID
  static Future<Detail?> getDetailById(int detailId) async {
    try {
      final box = Hive.box<Detail>(detailsBoxName);
      // Buscar em todas as chaves que contenham esse detailId
      for (var key in box.keys) {
        final detail = box.get(key);
        if (detail != null && detail.id == detailId) {
          return detail;
        }
      }
      return null;
    } catch (e) {
      print('Erro ao obter detalhe por ID: $e');
      return null;
    }
  }

    static Future<void> saveNonConformity(Map<String, dynamic> nonConformity) async {
    try {
      // Garantir que o banco está inicializado
      await ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      
      // Obter lista atual de não conformidades
      final String? nonConformitiesJson = prefs.getString('local_non_conformities');
      List<Map<String, dynamic>> nonConformities = [];
      
      if (nonConformitiesJson != null) {
        try {
          final List<dynamic> decodedList = jsonDecode(nonConformitiesJson);
          nonConformities = decodedList.cast<Map<String, dynamic>>();
        } catch (e) {
          print('Erro ao decodificar JSON de não conformidades: $e');
        }
      }
      
      // Verificar se esta não conformidade já existe (por ID)
      bool exists = false;
      int existingIndex = -1;
      
      if (nonConformity.containsKey('id')) {
        for (int i = 0; i < nonConformities.length; i++) {
          if (nonConformities[i]['id'] == nonConformity['id']) {
            exists = true;
            existingIndex = i;
            break;
          }
        }
      }
      
      // Adicionar ID local se não existir
      if (!nonConformity.containsKey('id') || nonConformity['id'] == null) {
        nonConformity['id'] = DateTime.now().millisecondsSinceEpoch % 1000; // ID positivo pequeno
      }
      
      // Adicionar timestamp se não existir
      if (!nonConformity.containsKey('created_at') || nonConformity['created_at'] == null) {
        nonConformity['created_at'] = DateTime.now().toIso8601String();
      }
      
      if (exists) {
        // Atualizar existente
        nonConformities[existingIndex] = nonConformity;
        print('Não conformidade ${nonConformity['id']} atualizada');
      } else {
        // Adicionar nova
        nonConformities.add(nonConformity);
        print('Nova não conformidade ${nonConformity['id']} adicionada');
      }
      
      // Salvar de volta
      await prefs.setString('local_non_conformities', jsonEncode(nonConformities));
      
      // Marcar inspeção como não sincronizada, se tiver o ID da inspeção
      if (nonConformity.containsKey('inspection_id')) {
        final inspectionId = nonConformity['inspection_id'];
        await setSyncStatus(inspectionId, false);
        print('Inspeção $inspectionId marcada para sincronização');
      }
    } catch (e) {
      print('Erro ao salvar não conformidade: $e');
    }
  }
  
  // Salvar uma não conformidade no banco de dados local
  static Future<void> saveNonConformityMedia(int nonConformityId, String mediaPath, String mediaType) async {
    try {
      print('Salvando mídia para NC $nonConformityId: $mediaPath (tipo: $mediaType)');
      
      // Garantir que o banco está inicializado
      await ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      
      // Obter mapa de mídia atual
      final String? nonConformityMediaJson = prefs.getString('non_conformity_media');
      Map<String, List<Map<String, dynamic>>> mediaMap = {};
      
      if (nonConformityMediaJson != null) {
        try {
          final Map<String, dynamic> decodedMap = jsonDecode(nonConformityMediaJson);
          
          // Converter para o formato correto
          decodedMap.forEach((key, value) {
            if (value is List) {
              final List<dynamic> mediaList = value;
              mediaMap[key] = mediaList.cast<Map<String, dynamic>>();
            }
          });
        } catch (e) {
          print('Erro ao decodificar JSON de mídia: $e');
        }
      }
      
      // Converter o ID para string para usar como chave
      final String ncIdKey = nonConformityId.toString();
      
      // Inicializar a lista se não existir
      if (!mediaMap.containsKey(ncIdKey)) {
        mediaMap[ncIdKey] = [];
      }
      
      // Verificar duplicatas
      bool isDuplicate = false;
      for (var item in mediaMap[ncIdKey]!) {
        if (item['path'] == mediaPath) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        // Adicionar nova mídia
        mediaMap[ncIdKey]!.add({
          'path': mediaPath,
          'type': mediaType,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Converter para JSON
        final jsonString = jsonEncode(mediaMap);
        
        // Verificar tamanho do JSON
        print('Tamanho do JSON da mídia: ${jsonString.length} bytes');
        
        // Salvar de volta
        await prefs.setString('non_conformity_media', jsonString);
        print('Mídia salva com sucesso para NC $nonConformityId');
      } else {
        print('Mídia já existe para esta NC, ignorando duplicata');
      }
    } catch (e) {
      print('Erro ao salvar mídia da não conformidade: $e');
    }
  }
  
  // Obter todas as não conformidades para uma inspeção
  static Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(int inspectionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obter lista atual de não conformidades
      final String? nonConformitiesJson = prefs.getString('local_non_conformities');
      
      if (nonConformitiesJson != null) {
        final List<dynamic> decodedList = jsonDecode(nonConformitiesJson);
        final List<Map<String, dynamic>> nonConformities = decodedList.cast<Map<String, dynamic>>();
        
        // Filtrar por inspectionId
        return nonConformities.where((nc) => nc['inspection_id'] == inspectionId).toList();
      }
      
      return [];
    } catch (e) {
      print('Erro ao obter não conformidades: $e');
      return [];
    }
  }
  
  // Atualizar status de uma não conformidade
  static Future<void> updateNonConformityStatus(int nonConformityId, String newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obter lista atual de não conformidades
      final String? nonConformitiesJson = prefs.getString('local_non_conformities');
      
      if (nonConformitiesJson != null) {
        final List<dynamic> decodedList = jsonDecode(nonConformitiesJson);
        final List<Map<String, dynamic>> nonConformities = decodedList.cast<Map<String, dynamic>>();
        
        // Encontrar e atualizar
        int inspectionId = -1;
        for (int i = 0; i < nonConformities.length; i++) {
          if (nonConformities[i]['id'] == nonConformityId) {
            nonConformities[i]['status'] = newStatus;
            nonConformities[i]['updated_at'] = DateTime.now().toIso8601String();
            inspectionId = nonConformities[i]['inspection_id'];
            break;
          }
        }
        
        // Salvar de volta
        await prefs.setString('local_non_conformities', jsonEncode(nonConformities));
        
        // Marcar inspeção como não sincronizada, se encontrada
        if (inspectionId != -1) {
          await setSyncStatus(inspectionId, false);
        }
      }
    } catch (e) {
      print('Erro ao atualizar status da não conformidade: $e');
    }
  }
  
  // Obter mídias para uma não conformidade
  static Future<List<Map<String, dynamic>>> getNonConformityMedia(int nonConformityId) async {
    try {
      // Garantir que o banco está inicializado
      await ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      
      // Obter mapa de mídia
      final String? nonConformityMediaJson = prefs.getString('non_conformity_media');
      
      if (nonConformityMediaJson == null) {
        print('Nenhum registro de mídia encontrado');
        return [];
      }
      
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(nonConformityMediaJson);
        
        // Obter lista para este ID de NC
        final String ncIdKey = nonConformityId.toString();
        if (decodedMap.containsKey(ncIdKey)) {
          final List<dynamic> mediaList = decodedMap[ncIdKey] as List<dynamic>;
          
          // Verificar arquivos existentes
          final List<Map<String, dynamic>> validMediaItems = [];
          
          for (var item in mediaList.cast<Map<String, dynamic>>()) {
            if (item.containsKey('path')) {
              // Verificar se o arquivo existe
              final file = File(item['path']);
              if (await file.exists()) {
                validMediaItems.add(item);
              } else {
                print('Arquivo não encontrado: ${item['path']}');
              }
            }
          }
          
          print('Encontradas ${validMediaItems.length} mídias válidas para NC $nonConformityId');
          return validMediaItems;
        } else {
          print('Nenhuma mídia encontrada para NC $nonConformityId');
        }
      } catch (e) {
        print('Erro ao decodificar JSON de mídia: $e');
      }
      
      return [];
    } catch (e) {
      print('Erro ao obter mídia da não conformidade: $e');
      return [];
    }
  }
  
  // Deletar mídia de uma não conformidade
  static Future<void> deleteNonConformityMedia(int nonConformityId, String mediaPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obter mapa de mídia
      final String? nonConformityMediaJson = prefs.getString('non_conformity_media');
      
      if (nonConformityMediaJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(nonConformityMediaJson);
        
        // Obter e modificar lista para este ID de NC
        final String ncIdKey = nonConformityId.toString();
        if (decodedMap.containsKey(ncIdKey)) {
          final List<dynamic> mediaList = decodedMap[ncIdKey] as List<dynamic>;
          final List<Map<String, dynamic>> typedMediaList = mediaList.cast<Map<String, dynamic>>();
          
          // Remover a mídia com este caminho
          typedMediaList.removeWhere((media) => media['path'] == mediaPath);
          
          // Atualizar a lista no mapa
          decodedMap[ncIdKey] = typedMediaList;
          
          // Salvar de volta
          await prefs.setString('non_conformity_media', jsonEncode(decodedMap));
          
          // Tentar deletar o arquivo
          try {
            final file = File(mediaPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (fileError) {
            print('Erro ao deletar arquivo: $fileError');
          }
        }
      }
    } catch (e) {
      print('Erro ao deletar mídia da não conformidade: $e');
    }
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
    await ensureInitialized(); // Garantir que o banco está inicializado
    
    try {
      final box = Hive.box<Inspection>(inspectionsBoxName);
      return box.values.toList();
    } catch (e) {
      print('Erro ao obter todas as inspeções: $e');
      return [];
    }
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
    await ensureInitialized(); // Garantir que o banco está inicializado
    
    try {
      final box = Hive.box<Room>(roomsBoxName);
      return box.values
          .where((room) => room.inspectionId == inspectionId)
          .toList();
    } catch (e) {
      print('Erro ao obter ambientes para inspeção: $e');
      return [];
    }
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
// lib/services/firebase_inspection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseInspectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => FirebaseStorage.instance;

  static final FirebaseInspectionService _instance = FirebaseInspectionService._internal();

  factory FirebaseInspectionService() {
    return _instance;
  }

  FirebaseInspectionService._internal() {
    // Enable Firestore offline persistence
    _enableOfflinePersistence();
  }

  Future<void> _enableOfflinePersistence() async {
  try {
    // Em plataformas móveis, persistência já está habilitada por padrão
    // Portanto, apenas configuramos as Settings
    if (!kIsWeb) {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('Firestore configurado para persistência offline (mobile)');
    } else {
      // Em plataformas web, precisamos chamar enablePersistence explicitamente
      await _firestore.enablePersistence(const PersistenceSettings(
        synchronizeTabs: true,
      ));
      print('Firestore configurado para persistência offline (web)');
    }
  } catch (e) {
    print('Erro ao configurar persistência offline: $e');
    // O erro pode ocorrer se a persistência já estiver habilitada ou em ambientes não suportados
  }
}

  // SECTION: CONNECTIVITY MANAGEMENT
  // ===================================
  
  // Check connectivity
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // SECTION: INSPECTION OPERATIONS
  // ===========================

  // Get inspection
  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      final docSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!docSnapshot.exists) {
        print('Inspection not found: $inspectionId');
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) return null;
      
      // Add the ID to the data map to be included in the conversion
      final inspectionData = {
        ...data,
        'id': inspectionId,
      };
      
      return Inspection.fromJson(inspectionData);
    } catch (e) {
      print('Error getting inspection: $e');
      rethrow;
    }
  }

  // Save inspection
  Future<void> saveInspection(Inspection inspection) async {
    try {
      await _firestore
          .collection('inspections')
          .doc(inspection.id)
          .set(inspection.toJson(), SetOptions(merge: true));
      
      print('Inspection ${inspection.id} saved successfully');
    } catch (e) {
      print('Error saving inspection: $e');
      rethrow;
    }
  }

  // SECTION: ROOM OPERATIONS
  // ========================

  // Get rooms of an inspection
  Future<List<Room>> getRooms(String inspectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('position', descending: false)  // Ordenar por posição
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Room.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      print('Erro ao carregar salas: $e');
      return [];
    }
  }

  // Método para reordenar ambientes
  Future<void> reorderRooms(String inspectionId, List<String> roomIds) async {
    try {
      // Usar uma batch para fazer múltiplas atualizações em uma transação
      final batch = _firestore.batch();
      
      for (int i = 0; i < roomIds.length; i++) {
        final roomRef = _firestore.collection('rooms').doc(roomIds[i]);
        batch.update(roomRef, {'position': i});
      }
      
      await batch.commit();
      print('Salas reordenadas com sucesso');
    } catch (e) {
      print('Erro ao reordenar salas: $e');
      rethrow;
    }
  }

  // Add room
  Future<Room> addRoom(String inspectionId, String name, {String? label, int? position}) async {
    try {
      // Obter próxima posição se não for fornecida
      final nextPosition = position ?? await _getNextRoomPosition(inspectionId);
      
      final roomRef = _firestore.collection('rooms').doc();
      
      final roomData = {
        'inspection_id': inspectionId,
        'room_name': name,
        'room_label': label,
        'position': nextPosition,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await roomRef.set(roomData);
      
      return Room(
        id: roomRef.id,
        inspectionId: inspectionId,
        position: nextPosition,
        roomName: name,
        roomLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar ambiente: $e');
      rethrow;
    }
  }

  // Update room
  Future<void> updateRoom(Room room) async {
    try {
      if (room.id == null) {
        throw Exception('Room ID cannot be null');
      }
      
      await _firestore
          .collection('rooms')
          .doc(room.id)
          .update(room.toJson());
      
      print('Room ${room.id} updated successfully');
    } catch (e) {
      print('Error updating room: $e');
      rethrow;
    }
  }

  // Delete room
  Future<void> deleteRoom(String inspectionId, String roomId) async {
    try {
      // Delete room
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .delete();
      
      // Delete associated items
      final itemsSnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .get();
      
      for (var doc in itemsSnapshot.docs) {
        await doc.reference.delete();
        
        // Delete item details
        final detailsSnapshot = await _firestore
            .collection('item_details')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .where('room_item_id', isEqualTo: doc.id)
            .get();
        
        for (var detailDoc in detailsSnapshot.docs) {
          await detailDoc.reference.delete();
        }
      }
      
      print('Room $roomId and all its items and details deleted successfully');
    } catch (e) {
      print('Error deleting room: $e');
      rethrow;
    }
  }

  // SECTION: ITEM OPERATIONS
  // ========================

  // Get items of a room
  Future<List<Item>> getItems(String inspectionId, String roomId) async {
    try {
      final querySnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Item.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      print('Error getting items: $e');
      return [];
    }
  }

  // Método para reordenar itens
  Future<void> reorderItems(String inspectionId, String roomId, List<String> itemIds) async {
    try {
      final batch = _firestore.batch();
      
      for (int i = 0; i < itemIds.length; i++) {
        final itemRef = _firestore.collection('room_items').doc(itemIds[i]);
        batch.update(itemRef, {'position': i});
      }
      
      await batch.commit();
      print('Itens reordenados com sucesso');
    } catch (e) {
      print('Erro ao reordenar itens: $e');
      rethrow;
    }
  }

  // Add item
  Future<Item> addItem(String inspectionId, String roomId, String name, {String? label, int? position}) async {
    try {
      // Obter próxima posição se não for fornecida
      int nextPosition;
      if (position != null) {
        nextPosition = position;
      } else {
        // Buscar a maior posição existente
        final itemsSnapshot = await _firestore
            .collection('room_items')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .orderBy('position', descending: true)
            .limit(1)
            .get();
        
        if (itemsSnapshot.docs.isEmpty) {
          nextPosition = 0;
        } else {
          final lastPosition = itemsSnapshot.docs.first.data()['position'];
          nextPosition = (lastPosition is int) ? lastPosition + 1 : 0;
        }
      }
      
      final itemRef = _firestore.collection('room_items').doc();
      
      final itemData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'item_name': name,
        'item_label': label,
        'position': nextPosition,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await itemRef.set(itemData);
      
      return Item(
        id: itemRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        position: nextPosition,
        itemName: name,
        itemLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar item: $e');
      rethrow;
    }
  }

  // Update item
  Future<void> updateItem(Item item) async {
    try {
      if (item.id == null) {
        throw Exception('Item ID cannot be null');
      }
      
      await _firestore
          .collection('room_items')
          .doc(item.id)
          .update(item.toJson());
      
      print('Item ${item.id} updated successfully');
    } catch (e) {
      print('Error updating item: $e');
      rethrow;
    }
  }

  // Delete item
  Future<void> deleteItem(String inspectionId, String roomId, String itemId) async {
    try {
      // Delete item
      await _firestore
          .collection('room_items')
          .doc(itemId)
          .delete();
      
      // Delete item details
      final detailsSnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .get();
      
      for (var doc in detailsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      print('Item $itemId and all its details deleted successfully');
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  // SECTION: DETAIL OPERATIONS
  // ===========================

  // Get details of an item
  Future<List<Detail>> getDetails(String inspectionId, String roomId, String itemId) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Detail.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      print('Error getting details: $e');
      return [];
    }
  }

  // Método para reordenar detalhes
  Future<void> reorderDetails(String inspectionId, String roomId, String itemId, List<String> detailIds) async {
    try {
      final batch = _firestore.batch();
      
      for (int i = 0; i < detailIds.length; i++) {
        final detailRef = _firestore.collection('item_details').doc(detailIds[i]);
        batch.update(detailRef, {'position': i});
      }
      
      await batch.commit();
      print('Detalhes reordenados com sucesso');
    } catch (e) {
      print('Erro ao reordenar detalhes: $e');
      rethrow;
    }
  }

  // Add detail
  Future<Detail> addDetail(
      String inspectionId,
      String roomId,
      String itemId,
      String name, {
      String? value,
      String? type,
      List<String>? options,
      int? position
  }) async {
    try {
      // Obter próxima posição se não for fornecida
      int nextPosition;
      if (position != null) {
        nextPosition = position;
      } else {
        // Buscar a maior posição existente
        final detailsSnapshot = await _firestore
            .collection('item_details')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .where('room_item_id', isEqualTo: itemId)
            .orderBy('position', descending: true)
            .limit(1)
            .get();
        
        if (detailsSnapshot.docs.isEmpty) {
          nextPosition = 0;
        } else {
          final lastPosition = detailsSnapshot.docs.first.data()['position'];
          nextPosition = (lastPosition is int) ? lastPosition + 1 : 0;
        }
      }
      
      final detailRef = _firestore.collection('item_details').doc();
      
      final detailData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'room_item_id': itemId,
        'detail_name': name,
        'detail_value': value,
        'position': nextPosition,
        'is_damaged': false,
        'type': type ?? 'text',  // Padrão para 'text' se não especificado
        'options': options,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await detailRef.set(detailData);
      
      return Detail(
        id: detailRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        itemId: itemId,
        position: nextPosition,
        detailName: name,
        detailValue: value,
        isDamaged: false,
        type: type ?? 'text',
        options: options,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar detalhe: $e');
      rethrow;
    }
  }

  // Update detail
  Future<void> updateDetail(Detail detail) async {
    try {
      if (detail.id == null) {
        throw Exception('Detail ID cannot be null');
      }
      
      await _firestore
          .collection('item_details')
          .doc(detail.id)
          .update(detail.toJson());
      
      print('Detail ${detail.id} updated successfully');
    } catch (e) {
      print('Error updating detail: $e');
      rethrow;
    }
  }

  // Delete detail
  Future<void> deleteDetail(String inspectionId, String roomId, String itemId, String detailId) async {
    try {
      await _firestore
          .collection('item_details')
          .doc(detailId)
          .delete();
      
      print('Detail $detailId deleted successfully');
    } catch (e) {
      print('Error deleting detail: $e');
      rethrow;
    }
  }

  // SECTION: TEMPLATE OPERATIONS
  // ===========================

  // Verifica se o template já foi aplicado à inspeção
  Future<bool> isTemplateApplied(String inspectionId) async {
    try {
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      
      if (!inspectionDoc.exists) return false;
      
      final data = inspectionDoc.data();
      return data != null && data['is_templated'] == true;
    } catch (e) {
      print('Error checking if template is applied: $e');
      return false;
    }
  }

  // Marca a inspeção como tendo template aplicado (sem aplicar o template)
  Future<bool> markTemplateAsApplied(String inspectionId) async {
    try {
      await _firestore.collection('inspections').doc(inspectionId).update({
        'is_templated': true,
        'status': 'in_progress',
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking template as applied: $e');
      return false;
    }
  }

  // Aplica template a uma inspeção - MÉTODO MELHORADO
  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    try {
      print('Starting template $templateId application to inspection $inspectionId');
      
      // Check if the inspection already has a template applied
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      final inspectionData = inspectionDoc.data();
      
      if (inspectionData != null && inspectionData['is_templated'] == true) {
        print('This inspection already has a template applied.');
        return true; // Already applied, return success
      }

      // Get cached template data or fetch from server
      final templateDoc = await _firestore.collection('templates').doc(templateId).get();
      if (!templateDoc.exists) {
        print('Template not found: $templateId');
        return false;
      }

      final templateData = templateDoc.data();
      if (templateData == null) {
        print('Template data is null');
        return false;
      }

      print('Template found: ${templateData['title']}');

      // Process template rooms
      final roomsData = templateData['rooms'];
      if (roomsData == null || roomsData is! List) {
        print('Template does not contain valid rooms');
        return false;
      }

      print('Processing ${roomsData.length} rooms from template');
      
      // Batch para acelerar transações
      final batch = _firestore.batch();
      
      // Variable to track if at least one room was created
      bool successfulCreation = false;
      List<Map<String, dynamic>> pendingRooms = [];
      List<Map<String, dynamic>> pendingItems = [];
      List<Map<String, dynamic>> pendingDetails = [];
      
      // First prepare all data structures
      int roomPosition = 0;
      for (var roomData in roomsData) {
        // Extract room name with proper handling for different formats
        String roomName = _extractStringValueFromTemplate(roomData, 'name', defaultValue: 'Unnamed room');
        String? roomDescription = _extractStringValueFromTemplate(roomData, 'description');
        
        print('Preparing room: $roomName');
        
        // Create room document ref
        final roomRef = _firestore.collection('rooms').doc();
        final roomId = roomRef.id;
        
        // Prepare room data
        final newRoomData = {
          'doc_ref': roomRef,
          'data': {
            'inspection_id': inspectionId,
            'room_name': roomName,
            'room_label': roomDescription,
            'position': roomPosition++,
            'is_damaged': false,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }
        };
        
        pendingRooms.add(newRoomData);
        successfulCreation = true;
        
        // Process room items
        List<dynamic> items = _extractArrayFromTemplate(roomData, 'items');
        print('Processing ${items.length} items for room $roomName');
        
        int itemPosition = 0;
        for (var itemData in items) {
          var fields = _extractFieldsFromTemplate(itemData);
          if (fields == null) continue;
          
          // Extract item name and description
          String itemName = _extractStringValueFromTemplate(fields, 'name', defaultValue: 'Unnamed item');
          String? itemDescription = _extractStringValueFromTemplate(fields, 'description');
          
          print('Preparing item: $itemName');
          
          // Create item document ref
          final itemRef = _firestore.collection('room_items').doc();
          final itemId = itemRef.id;
          
          // Prepare item data
          final newItemData = {
            'doc_ref': itemRef,
            'room_id': roomId,
            'data': {
              'inspection_id': inspectionId,
              'room_id': roomId,
              'item_name': itemName,
              'item_label': itemDescription,
              'position': itemPosition++,
              'is_damaged': false,
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            }
          };
          
          pendingItems.add(newItemData);
          
          // Process item details
          List<dynamic> details = _extractArrayFromTemplate(fields, 'details');
          print('Processing ${details.length} details for item $itemName');

          int detailPosition = 0;
          for (var detailData in details) {
            var detailFields = _extractFieldsFromTemplate(detailData);
            if (detailFields == null) continue;
            
            // Extract detail name
            String detailName = _extractStringValueFromTemplate(detailFields, 'name', defaultValue: 'Unnamed detail');
            
            // Extract detail type and options
            String detailType = 'text';  // Default type
            List<String> options = [];
            
            if (detailFields.containsKey('type')) {
              detailType = _extractStringValueFromTemplate(detailFields, 'type', defaultValue: 'text');
            }
            
            if (detailType == 'select' && detailFields.containsKey('options')) {
              // Extract options array
              var optionsArray = _extractArrayFromTemplate(detailFields, 'options');
              
              for (var option in optionsArray) {
                if (option is Map && option.containsKey('stringValue')) {
                  options.add(option['stringValue']);
                } else if (option is String) {
                  options.add(option);
                }
              }
              
              // Check if there's an optionsText field as alternative
              if (options.isEmpty && detailFields.containsKey('optionsText')) {
                String optionsText = _extractStringValueFromTemplate(detailFields, 'optionsText', defaultValue: '');
                if (optionsText.isNotEmpty) {
                  options = optionsText.split(',').map((e) => e.trim()).toList();
                }
              }
            }
            
            // Use the first option as the initial value, if available
            String? initialValue = options.isNotEmpty ? options[0] : null;
            
            print('Preparing detail: $detailName with type: $detailType');
            
            // Create detail document ref
            final detailRef = _firestore.collection('item_details').doc();
            
            // Prepare detail data
            final newDetailData = {
              'doc_ref': detailRef,
              'data': {
                'inspection_id': inspectionId,
                'room_id': roomId,
                'room_item_id': itemId,
                'detail_name': detailName,
                'detail_value': initialValue,
                'position': detailPosition++,
                'is_damaged': false,
                'type': detailType,
                'options': options.isNotEmpty ? options : null,
                'created_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
              }
            };
            
            pendingDetails.add(newDetailData);
          }
        }
      }
      
      // Now execute batches (Firebase Firestore has limit of 500 operations per batch)
      // Process rooms
      for (var roomData in pendingRooms) {
        batch.set(roomData['doc_ref'], roomData['data']);
      }
      
      // Process items
      for (var itemData in pendingItems) {
        batch.set(itemData['doc_ref'], itemData['data']);
      }
      
      // Process details
      for (var detailData in pendingDetails) {
        batch.set(detailData['doc_ref'], detailData['data']);
      }
      
      // Mark inspection as templated
      if (successfulCreation) {
        batch.update(_firestore.collection('inspections').doc(inspectionId), {
          'is_templated': true,
          'status': 'in_progress',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      
      // Commit all operations
      await batch.commit();
      
      print('Template applied successfully to inspection $inspectionId');
      return true;
    } catch (e) {
      print('Error applying template to inspection: $e');
      return false;
    }
  }

  // Auxiliary methods for extracting template data
  
  String _extractStringValueFromTemplate(dynamic data, String key, {String defaultValue = ''}) {
    if (data == null) return defaultValue;
    
    // Case 1: Direct as string
    if (data[key] is String) {
      return data[key];
    }
    
    // Case 2: Firestore format (stringValue)
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }
    
    // Case 3: Value not found
    return defaultValue;
  }
  
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
    
    // Case 3: Value not found
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
    
    // Case 4: Value is not a valid map
    return null;
  }

  // SECTION: NON-CONFORMITY OPERATIONS
  // ====================================

  // Get non-conformities of an inspection
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('non_conformities')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('created_at', descending: true)
          .get();

      final nonConformities = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
      
      // Adicionar informações dos itens relacionados
      for (var nc in nonConformities) {
        if (nc['room_id'] != null) {
          try {
            // Buscar informações da sala
            final roomDoc = await _firestore.collection('rooms').doc(nc['room_id']).get();
if (roomDoc.exists) {
              nc['rooms'] = {
                'id': roomDoc.id,
                'room_name': roomDoc.data()?['room_name'],
                ...roomDoc.data() ?? {}
              };
            }
            
            // Buscar informações do item
            if (nc['item_id'] != null) {
              final itemDoc = await _firestore.collection('room_items').doc(nc['item_id']).get();
              if (itemDoc.exists) {
                nc['room_items'] = {
                  'id': itemDoc.id,
                  'item_name': itemDoc.data()?['item_name'],
                  ...itemDoc.data() ?? {}
                };
              }
            }
            
            // Buscar informações do detalhe
            if (nc['detail_id'] != null) {
              final detailDoc = await _firestore.collection('item_details').doc(nc['detail_id']).get();
              if (detailDoc.exists) {
                nc['item_details'] = {
                  'id': detailDoc.id,
                  'detail_name': detailDoc.data()?['detail_name'],
                  ...detailDoc.data() ?? {}
                };
              }
            }
          } catch (e) {
            print('Erro ao buscar informações relacionadas à não conformidade: $e');
          }
        }
      }
      
      return nonConformities;
    } catch (e) {
      print('Error getting non-conformities: $e');
      return [];
    }
  }

  // Save non-conformity
  Future<void> saveNonConformity(Map<String, dynamic> nonConformity) async {
    try {
      if (nonConformity.containsKey('id') && nonConformity['id'] != null) {
        // Update existing
        final docId = nonConformity['id'];
        
        // Remove related objects that shouldn't be saved
        Map<String, dynamic> dataToSave = Map.from(nonConformity);
        dataToSave.remove('rooms');
        dataToSave.remove('room_items');
        dataToSave.remove('item_details');
        dataToSave.remove('id');
        
        await _firestore
            .collection('non_conformities')
            .doc(docId)
            .update(dataToSave);
      } else {
        // Add new
        // Remove related objects that shouldn't be saved
        Map<String, dynamic> dataToSave = Map.from(nonConformity);
        dataToSave.remove('rooms');
        dataToSave.remove('room_items');
        dataToSave.remove('item_details');
        dataToSave.remove('id');
        
        final docRef = await _firestore
            .collection('non_conformities')
            .add(dataToSave);
        
        nonConformity['id'] = docRef.id;
      }
      
      print('Non-conformity saved successfully');
    } catch (e) {
      print('Error saving non-conformity: $e');
      rethrow;
    }
  }

  // Update non-conformity status
  Future<void> updateNonConformityStatus(String nonConformityId, String newStatus) async {
    try {
      await _firestore
          .collection('non_conformities')
          .doc(nonConformityId)
          .update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Non-conformity status updated to: $newStatus');
    } catch (e) {
      print('Error updating non-conformity status: $e');
      rethrow;
    }
  }

  // Método para atualizar uma não conformidade
Future<void> updateNonConformity(String nonConformityId, Map<String, dynamic> updatedData) async {
  try {
    // Remover campos que não devem ser atualizados
    final Map<String, dynamic> dataToUpdate = {...updatedData};
    dataToUpdate.remove('id');
    dataToUpdate.remove('rooms');
    dataToUpdate.remove('room_items');
    dataToUpdate.remove('item_details');
    dataToUpdate.remove('created_at');
    
    // Adicionar timestamp de atualização
    dataToUpdate['updated_at'] = FieldValue.serverTimestamp();
    
    // Atualizar o documento no Firestore
    await _firestore
        .collection('non_conformities')
        .doc(nonConformityId)
        .update(dataToUpdate);
    
    print('Non-conformity $nonConformityId updated successfully');
  } catch (e) {
    print('Error updating non-conformity: $e');
    rethrow;
  }
}

// Método para excluir uma não conformidade
Future<void> deleteNonConformity(String nonConformityId, String inspectionId) async {
  try {
    // 1. Obter referência às mídias associadas
    final mediaSnapshot = await _firestore
        .collection('non_conformity_media')
        .where('non_conformity_id', isEqualTo: nonConformityId)
        .get();
    
    // 2. Excluir as mídias do Storage
    final batch = _firestore.batch();
    
    for (var doc in mediaSnapshot.docs) {
      final mediaData = doc.data();
      
      // Excluir do Storage se houver URL
      if (mediaData['url'] != null) {
        try {
          final uri = Uri.parse(mediaData['url']);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length > 1) {
            final storagePath = pathSegments.skip(1).join('/');
            await FirebaseStorage.instance.ref(storagePath).delete();
          }
        } catch (e) {
          print('Error deleting media file from storage: $e');
          // Continue mesmo se falhar ao excluir do Storage
        }
      }
      
      // Adicionar à batch para exclusão
      batch.delete(doc.reference);
    }
    
    // 3. Excluir a não conformidade
    batch.delete(_firestore.collection('non_conformities').doc(nonConformityId));
    
    // 4. Executar a batch
    await batch.commit();
    
    print('Non-conformity $nonConformityId and associated media deleted successfully');
  } catch (e) {
    print('Error deleting non-conformity: $e');
    rethrow;
  }
}

  // SECTION: DUPLICATION AND VERIFICATION OPERATIONS
  // =========================================

  // Check if a room with this name already exists in the inspection
  Future<Detail?> isRoomDuplicate(String inspectionId, String roomName) async {
    try {
      // Check if a room with this name exists
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_name', isEqualTo: roomName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // If found existing room, create a copy
        final position = await _getNextRoomPosition(inspectionId);
        final newRoomName = "$roomName (copy)";
        
        // Create new room
        final room = await addRoom(
          inspectionId,
          newRoomName,
          position: position,
        );
        
        // Copy items and details
        if (room.id != null) {
          final existingRoomId = querySnapshot.docs.first.id;
          await _duplicateRoomItems(inspectionId, existingRoomId, room.id!);
        }
        
        return null;
      }
      
      return null;
    } catch (e) {
      print('Error checking duplicate room: $e');
      return null;
    }
  }

  // Duplicate items of a room to another
  Future<void> _duplicateRoomItems(String inspectionId, String sourceRoomId, String targetRoomId) async {
    try {
      // Get items of the original room
      final itemsSnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: sourceRoomId)
          .get();
      
      for (var itemDoc in itemsSnapshot.docs) {
        final itemData = itemDoc.data();
        
        // Create new item in the target room
        final newItemRef = await _firestore.collection('room_items').add({
          ...itemData,
          'room_id': targetRoomId,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Copy item details
        await _duplicateItemDetails(inspectionId, sourceRoomId, itemDoc.id, targetRoomId, newItemRef.id);
      }
    } catch (e) {
      print('Error duplicating room items: $e');
    }
  }

  // Duplicate details of an item to another
  Future<void> _duplicateItemDetails(String inspectionId, String sourceRoomId, String sourceItemId, 
                                    String targetRoomId, String targetItemId) async {
    try {
      // Get details of the original item
      final detailsSnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: sourceRoomId)
          .where('room_item_id', isEqualTo: sourceItemId)
          .get();
      
      for (var detailDoc in detailsSnapshot.docs) {
        final detailData = detailDoc.data();
        
        // Create new detail in the target item
        await _firestore.collection('item_details').add({
          ...detailData,
          'room_id': targetRoomId,
          'room_item_id': targetItemId,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error duplicating item details: $e');
    }
  }

  // Check if an item with this name already exists in this room
  Future<Detail?> isItemDuplicate(String inspectionId, String roomId, String itemName) async {
    try {
      // Check if an item with this name exists
      final querySnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('item_name', isEqualTo: itemName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // If found existing item, create a copy
        final position = await _getNextItemPosition(inspectionId, roomId);
        final newItemName = "$itemName (copy)";
        
        // Create new item
        final item = await addItem(
          inspectionId,
          roomId,
          newItemName,
          position: position,
        );
        
        // Copy details
        if (item.id != null) {
          final existingItemId = querySnapshot.docs.first.id;
          await _duplicateItemDetails(inspectionId, roomId, existingItemId, roomId, item.id!);
        }
        
        return null;
      }
      
      return null;
    } catch (e) {
      print('Error checking duplicate item: $e');
      return null;
    }
  }

  // Check if a detail with this name already exists in this item
  Future<Detail?> isDetailDuplicate(String inspectionId, String roomId, String itemId, String detailName) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .where('detail_name', isEqualTo: detailName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // If found existing detail, create a copy
        final position = await _getNextDetailPosition(inspectionId, roomId, itemId);
        final newDetailName = "$detailName (copy)";
        
        final detail = await addDetail(
          inspectionId,
          roomId,
          itemId,
          newDetailName,
          position: position,
        );
        
        return detail;
      }
      
      return null;
    } catch (e) {
      print('Error checking duplicate detail: $e');
      return null;
    }
  }
  
  Future<int> _getNextRoomPosition(String inspectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('position', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return 0;
      }
      
      final lastPosition = querySnapshot.docs.first.data()['position'] is int
          ? querySnapshot.docs.first.data()['position']
          : 0;
      
      return lastPosition + 1;
    } catch (e) {
      print('Erro ao obter próxima posição de ambiente: $e');
      return 0;
    }
  }

  // Método para obter a próxima posição disponível para um item
  Future<int> _getNextItemPosition(String inspectionId, String roomId) async {
    try {
      final querySnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .orderBy('position', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return 0;
      }
      
      final lastPosition = querySnapshot.docs.first.data()['position'] is int
          ? querySnapshot.docs.first.data()['position']
          : 0;
      
      return lastPosition + 1;
    } catch (e) {
      print('Erro ao obter próxima posição de item: $e');
      return 0;
    }
  }

  // Método para obter a próxima posição disponível para um detalhe
  Future<int> _getNextDetailPosition(String inspectionId, String roomId, String itemId) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .orderBy('position', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return 0;
      }
      
      final lastPosition = querySnapshot.docs.first.data()['position'] is int
          ? querySnapshot.docs.first.data()['position']
          : 0;
      
      return lastPosition + 1;
    } catch (e) {
      print('Erro ao obter próxima posição de detalhe: $e');
      return 0;
    }
  }

  // SECTION: CALCULATIONS AND METRICS
  // =========================

  // Calculate completion percentage of an inspection
  Future<double> calculateCompletionPercentage(String inspectionId) async {
    try {
      // Contadores para total e preenchidos
      int totalDetails = 0;
      int filledDetails = 0;
      
      // Obter todos os detalhes da inspeção diretamente
      final detailsSnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .get();
      
      if (detailsSnapshot.docs.isEmpty) {
        return 0.0; // Se não houver detalhes, progresso é 0
      }
      
      totalDetails = detailsSnapshot.docs.length;
      
      // Contar quantos detalhes estão preenchidos
      for (var doc in detailsSnapshot.docs) {
        final data = doc.data();
        if (data['detail_value'] != null && data['detail_value'].toString().isNotEmpty) {
          filledDetails++;
        }
      }
      
      print('Total de detalhes: $totalDetails, Preenchidos: $filledDetails');
      
      // Calcular a porcentagem
      return totalDetails > 0 ? filledDetails / totalDetails : 0.0;
    } catch (e) {
      print('Erro ao calcular porcentagem de conclusão: $e');
      return 0.0;
    }
  }
}
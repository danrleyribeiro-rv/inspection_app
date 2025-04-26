// lib/services/firebase_inspection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseInspectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      await _firestore.enablePersistence(const PersistenceSettings(
        synchronizeTabs: true,
      ));
      print('Offline persistence enabled successfully');
    } catch (e) {
      print('Error enabling offline persistence: $e');
      // The error may occur if persistence is already enabled or in unsupported environments
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
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Room.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      print('Error getting rooms: $e');
      return [];
    }
  }

  // Add room
  Future<Room> addRoom(String inspectionId, String name, {String? label, int? position}) async {
    try {
      final roomRef = _firestore.collection('rooms').doc();
      
      final roomData = {
        'inspection_id': inspectionId,
        'room_name': name,
        'room_label': label,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await roomRef.set(roomData);
      
      return Room(
        id: roomRef.id,
        inspectionId: inspectionId,
        position: position ?? 0,
        roomName: name,
        roomLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error adding room: $e');
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

  // Add item
  Future<Item> addItem(String inspectionId, String roomId, String name, {String? label, int? position}) async {
    try {
      final itemRef = _firestore.collection('room_items').doc();
      
      final itemData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'item_name': name,
        'item_label': label,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await itemRef.set(itemData);
      
      return Item(
        id: itemRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        position: position ?? 0,
        itemName: name,
        itemLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error adding item: $e');
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

  // Add detail
  Future<Detail> addDetail(String inspectionId, String roomId, String itemId, String name, {String? value, int? position}) async {
    try {
      final detailRef = _firestore.collection('item_details').doc();
      
      final detailData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'room_item_id': itemId,
        'detail_name': name,
        'detail_value': value,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await detailRef.set(detailData);
      
      return Detail(
        id: detailRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        itemId: itemId,
        position: position,
        detailName: name,
        detailValue: value,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error adding detail: $e');
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

  // Apply template to an inspection - IMPROVED METHOD
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
      
      // Get template data
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
      
      // Variable to track if at least one room was created
      bool successfulCreation = false;
      
      // Process template rooms
      for (var roomData in roomsData) {
        // Extract room name with proper handling for different formats
        String roomName = _extractStringValueFromTemplate(roomData, 'name', defaultValue: 'Unnamed room');
        String? roomDescription = _extractStringValueFromTemplate(roomData, 'description');
        
        print('Creating room: $roomName');
        
        try {
          // Create room
          final roomDoc = await _firestore.collection('rooms').add({
            'inspection_id': inspectionId,
            'room_name': roomName,
            'room_label': roomDescription,
            'position': 0,
            'is_damaged': false,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          
          final roomId = roomDoc.id;
          print('Room created with ID: $roomId');
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
            
            print('Creating item: $itemName');
            
            try {
              // Create item
              final itemDoc = await _firestore.collection('room_items').add({
                'inspection_id': inspectionId,
                'room_id': roomId,
                'item_name': itemName,
                'item_label': itemDescription ?? '',
                'position': itemPosition++,
                'is_damaged': false,
                'created_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
              });
              
              final itemId = itemDoc.id;
              print('Item created with ID: $itemId');
              
              // Process item details
              List<dynamic> details = _extractArrayFromTemplate(fields, 'details');
              print('Processing ${details.length} details for item $itemName');
              
              int detailPosition = 0;
              for (var detailData in details) {
                var detailFields = _extractFieldsFromTemplate(detailData);
                if (detailFields == null) continue;
                
                // Extract detail name
                String detailName = _extractStringValueFromTemplate(detailFields, 'name', defaultValue: 'Unnamed detail');
                
                // Extract detail options if they exist
                List<String> options = [];
                var optionsArray = _extractArrayFromTemplate(detailFields, 'options');
                
                for (var option in optionsArray) {
                  if (option is Map && option.containsKey('stringValue')) {
                    options.add(option['stringValue']);
                  } else if (option is String) {
                    options.add(option);
                  }
                }
                
                // Use the first option as the initial value, if available
                String? initialValue = options.isNotEmpty ? options[0] : null;
                
                print('Creating detail: $detailName');
                
                try {
                  await _firestore.collection('item_details').add({
                    'inspection_id': inspectionId,
                    'room_id': roomId,
                    'room_item_id': itemId,
                    'detail_name': detailName,
                    'detail_value': initialValue,
                    'position': detailPosition++,
                    'is_damaged': false,
                    'created_at': FieldValue.serverTimestamp(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } catch (e) {
                  print('Error creating detail $detailName: $e');
                }
              }
            } catch (e) {
              print('Error creating item $itemName: $e');
            }
          }
        } catch (e) {
          print('Error creating room $roomName: $e');
        }
      }
      
      // Mark inspection as templated only if at least one room was created
      if (successfulCreation) {
        await _firestore.collection('inspections').doc(inspectionId).update({
          'is_templated': true,
          'status': 'in_progress',
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        print('Inspection marked as templated successfully');
        return true;
      } else {
        print('No room was created. Template not applied.');
        return false;
      }
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

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
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
        await _firestore
            .collection('non_conformities')
            .doc(nonConformity['id'])
            .update(nonConformity);
      } else {
        // Add new
        final docRef = await _firestore
            .collection('non_conformities')
            .add(nonConformity);
        
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
  
  // Get next position for room
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
      
      final lastPosition = querySnapshot.docs.first.data()['position'] ?? 0;
      return lastPosition + 1;
    } catch (e) {
      print('Error getting next room position: $e');
      return 0;
    }
  }
  
  // Get next position for item
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
      
      final lastPosition = querySnapshot.docs.first.data()['position'] ?? 0;
      return lastPosition + 1;
    } catch (e) {
      print('Error getting next item position: $e');
      return 0;
    }
  }
  
  // Get next position for detail
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
      
      final lastPosition = querySnapshot.docs.first.data()['position'] ?? 0;
      return lastPosition + 1;
    } catch (e) {
      print('Error getting next detail position: $e');
      return 0;
    }
  }

  // SECTION: CALCULATIONS AND METRICS
  // =========================

  // Calculate completion percentage of an inspection
  Future<double> calculateCompletionPercentage(String inspectionId) async {
    try {
      // Get all rooms
      final rooms = await getRooms(inspectionId);
      
      int totalDetails = 0;
      int filledDetails = 0;
      
      for (var room in rooms) {
        if (room.id == null) continue;
        
        // Get all items for this room
        final items = await getItems(inspectionId, room.id!);
        
        for (var item in items) {
          if (item.id == null) continue;
          
          // Get all details for this item
          final details = await getDetails(inspectionId, room.id!, item.id!);
          
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
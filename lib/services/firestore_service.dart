// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'dart:io';
import 'dart:typed_data';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Inspections Collection
  CollectionReference get inspectionsCollection => _firestore.collection('inspections');
  
  // Rooms Collection (subcollection of inspections)
  CollectionReference getRoomsCollection(int inspectionId) => 
      inspectionsCollection.doc(inspectionId.toString()).collection('rooms');
  
  // Items Collection (subcollection of rooms)
  CollectionReference getItemsCollection(int inspectionId, int roomId) => 
      getRoomsCollection(inspectionId).doc(roomId.toString()).collection('items');
  
  // Details Collection (subcollection of items)
  CollectionReference getDetailsCollection(int inspectionId, int roomId, int itemId) => 
      getItemsCollection(inspectionId, roomId).doc(itemId.toString()).collection('details');
  
  // Non-conformities Collection
  CollectionReference get nonConformitiesCollection => _firestore.collection('non_conformities');

  // Create or update inspection
  Future<void> saveInspection(Inspection inspection) async {
    try {
      await inspectionsCollection.doc(inspection.id.toString()).set(
        inspection.toJson(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving inspection: $e');
      rethrow;
    }
  }

  // Get an inspection by ID
  Future<Map<String, dynamic>?> getInspection(int inspectionId) async {
    try {
      final doc = await inspectionsCollection.doc(inspectionId.toString()).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting inspection: $e');
      rethrow;
    }
  }

  // Delete an inspection
  Future<void> deleteInspection(int inspectionId) async {
    try {
      // Delete all subcollections and documents
      await _recursiveDelete(inspectionsCollection.doc(inspectionId.toString()));
    } catch (e) {
      print('Error deleting inspection: $e');
      rethrow;
    }
  }

  // Helper method to recursively delete a document and its subcollections
  Future<void> _recursiveDelete(DocumentReference docRef) async {
    // Get a reference to the Firestore instance
    final firestore = FirebaseFirestore.instance;
    
    // We need to manually list all possible subcollections since listCollections() isn't available
    // For inspections, we know these are the possible subcollections
    if (docRef.path.startsWith('inspections/')) {
      final inspectionId = docRef.id;
      
      // Get rooms subcollection
      final roomsCollection = firestore.collection('inspections/${inspectionId}/rooms');
      final roomsQuery = await roomsCollection.get();
      
      // Delete all rooms and their subcollections
      for (final roomDoc in roomsQuery.docs) {
        final roomId = roomDoc.id;
        
        // Get items subcollection
        final itemsCollection = firestore.collection('inspections/${inspectionId}/rooms/${roomId}/items');
        final itemsQuery = await itemsCollection.get();
        
        // Delete all items and their subcollections
        for (final itemDoc in itemsQuery.docs) {
          final itemId = itemDoc.id;
          
          // Get details subcollection
          final detailsCollection = firestore.collection('inspections/${inspectionId}/rooms/${roomId}/items/${itemId}/details');
          final detailsQuery = await detailsCollection.get();
          
          // Delete all details and their subcollections
          for (final detailDoc in detailsQuery.docs) {
            final detailId = detailDoc.id;
            
            // Get media subcollection
            final mediaCollection = firestore.collection('inspections/${inspectionId}/rooms/${roomId}/items/${itemId}/details/${detailId}/media');
            final mediaQuery = await mediaCollection.get();
            
            // Delete all media documents
            for (final mediaDoc in mediaQuery.docs) {
              await mediaDoc.reference.delete();
            }
            
            // Delete the detail document
            await detailDoc.reference.delete();
          }
          
          // Delete the item document
          await itemDoc.reference.delete();
        }
        
        // Delete the room document
        await roomDoc.reference.delete();
      }
    }
    
    // Finally, delete the main document
    await docRef.delete();
  }


  // Get all inspections for an inspector
  Future<List<Map<String, dynamic>>> getInspectionsByInspector(String inspectorId) async {
    try {
      final snapshot = await inspectionsCollection
          .where('inspectorId', isEqualTo: inspectorId)
          .where('deletedAt', isNull: true)
          .orderBy('scheduledDate', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting inspections by inspector: $e');
      rethrow;
    }
  }

  // Save a room
  Future<void> saveRoom(Room room) async {
    try {
      await getRoomsCollection(room.inspectionId)
          .doc(room.id.toString())
          .set(room.toJson(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving room: $e');
      rethrow;
    }
  }

  // Get all rooms for an inspection
  Future<List<Map<String, dynamic>>> getRoomsByInspection(int inspectionId) async {
    try {
      final snapshot = await getRoomsCollection(inspectionId)
          .orderBy('position', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting rooms by inspection: $e');
      rethrow;
    }
  }

  // Save an item
  Future<void> saveItem(Item item) async {
    try {
      await getItemsCollection(item.inspectionId, item.roomId!)
          .doc(item.id.toString())
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving item: $e');
      rethrow;
    }
  }

  // Get all items for a room
  Future<List<Map<String, dynamic>>> getItemsByRoom(int inspectionId, int roomId) async {
    try {
      final snapshot = await getItemsCollection(inspectionId, roomId)
          .orderBy('position', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting items by room: $e');
      rethrow;
    }
  }

  // Save a detail
  Future<void> saveDetail(Detail detail) async {
    try {
      await getDetailsCollection(detail.inspectionId, detail.roomId!, detail.itemId!)
          .doc(detail.id.toString())
          .set(detail.toJson(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving detail: $e');
      rethrow;
    }
  }

  // Get all details for an item
  Future<List<Map<String, dynamic>>> getDetailsByItem(int inspectionId, int roomId, int itemId) async {
    try {
      final snapshot = await getDetailsCollection(inspectionId, roomId, itemId)
          .orderBy('position', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting details by item: $e');
      rethrow;
    }
  }

  // Upload media file to Firebase Storage
  Future<String> uploadMediaFile(
    File file, 
    int inspectionId, 
    int roomId, 
    int itemId, 
    int detailId,
    String mediaType,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp-${file.path.split('/').last}';
      final filePath = 'inspections/$inspectionId/$roomId/$itemId/$detailId/$fileName';
      
      final storageRef = _storage.ref().child(filePath);
      
      // Upload file
      await storageRef.putFile(file);
      
      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Save reference in Firestore
      await getDetailsCollection(inspectionId, roomId, itemId)
          .doc(detailId.toString())
          .collection('media')
          .add({
            'url': downloadUrl,
            'type': mediaType,
            'fileName': fileName,
            'createdAt': FieldValue.serverTimestamp(),
          });
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading media file: $e');
      rethrow;
    }
  }

  // Get all media for a detail
  Future<List<Map<String, dynamic>>> getMediaByDetail(
    int inspectionId, 
    int roomId, 
    int itemId, 
    int detailId,
  ) async {
    try {
      final snapshot = await getDetailsCollection(inspectionId, roomId, itemId)
          .doc(detailId.toString())
          .collection('media')
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting media by detail: $e');
      rethrow;
    }
  }

  // Save non-conformity
  Future<void> saveNonConformity(Map<String, dynamic> nonConformity) async {
    try {
      final docRef = nonConformity['id'] != null 
          ? nonConformitiesCollection.doc(nonConformity['id'].toString())
          : nonConformitiesCollection.doc();
          
      await docRef.set(nonConformity, SetOptions(merge: true));
      
      // If it's a new document, update the ID in the caller's map
      if (nonConformity['id'] == null) {
        nonConformity['id'] = docRef.id;
      }
    } catch (e) {
      print('Error saving non-conformity: $e');
      rethrow;
    }
  }

  // Get non-conformities by inspection
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(int inspectionId) async {
    try {
      final snapshot = await nonConformitiesCollection
          .where('inspectionId', isEqualTo: inspectionId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      print('Error getting non-conformities by inspection: $e');
      rethrow;
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(String userId, Uint8List imageData) async {
    try {
      final fileName = '$userId-profile.jpg';
      final filePath = 'profile_images/$fileName';
      
      final storageRef = _storage.ref().child(filePath);
      
      // Upload data
      await storageRef.putData(imageData);
      
      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update inspector profile
      await _firestore.collection('inspectors')
          .doc(userId)
          .update({
            'profileImageUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }
}
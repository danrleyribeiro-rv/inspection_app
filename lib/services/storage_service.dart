// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  // Upload a file to Firebase Storage
  Future<String> uploadFile({
    required File file,
    required String path,
    String? contentType,
  }) async {
    try {
      // Create storage reference
      final ref = _storage.ref().child(path);
      
      // Set upload metadata if content type is provided
      SettableMetadata? metadata;
      if (contentType != null) {
        metadata = SettableMetadata(contentType: contentType);
      }
      
      // Upload file
      await ref.putFile(file, metadata);
      
      // Get download URL
      final url = await ref.getDownloadURL();
      
      return url;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  // Upload inspection media file
  Future<String> uploadInspectionMedia({
    required File file,
    required int inspectionId,
    required int roomId,
    required int itemId,
    required int detailId,
    required String type,
  }) async {
    try {
      // Generate a unique filename
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${type}_${roomId}_${itemId}_${detailId}_${timestamp}$fileExt';
      
      // Create the storage path
      final storagePath = 'inspections/$inspectionId/$roomId/$itemId/$detailId/$filename';
      
      // Determine content type
      String? contentType;
      if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
        contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
      } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
        contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
      }
      
      // Upload file
      return await uploadFile(
        file: file,
        path: storagePath,
        contentType: contentType,
      );
    } catch (e) {
      print('Error uploading inspection media: $e');
      rethrow;
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage({
    required File file,
    required String inspectorId,
  }) async {
    try {
      // Generate a unique filename
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'profile_${timestamp}$fileExt';
      
      // Create the storage path
      final storagePath = 'profile_images/$inspectorId/$filename';
      
      // Upload file
      return await uploadFile(
        file: file,
        path: storagePath,
        contentType: 'image/${fileExt.toLowerCase().replaceAll('.', '')}',
      );
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Upload non-conformity media
  Future<String> uploadNonConformityMedia({
    required File file,
    required int inspectionId,
    required int nonConformityId,
    required String type,
  }) async {
    try {
      // Generate a unique filename
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${type}_${_uuid.v4()}$fileExt';
      
      // Create the storage path
      final storagePath = 'inspections/$inspectionId/non_conformities/$nonConformityId/$filename';
      
      // Determine content type
      String? contentType;
      if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
        contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
      } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
        contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
      }
      
      // Upload file
      return await uploadFile(
        file: file,
        path: storagePath,
        contentType: contentType,
      );
    } catch (e) {
      print('Error uploading non-conformity media: $e');
      rethrow;
    }
  }

  // Delete a file from Firebase Storage
  Future<void> deleteFile(String url) async {
    try {
      // Get reference from URL
      final ref = _storage.refFromURL(url);
      
      // Delete file
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  // Get reference from URL
  Reference getRefFromURL(String url) {
    return _storage.refFromURL(url);
  }
}
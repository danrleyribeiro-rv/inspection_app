import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  static final FirebaseStorageService _instance = FirebaseStorageService._internal();

  factory FirebaseStorageService() {
    return _instance;
  }

  FirebaseStorageService._internal();

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
    required String inspectionId,
    required String topicId,
    required String itemId,
    required String detailId,
    required String type,
  }) async {
    try {
      // Generate a unique filename
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${type}_${timestamp}_${_uuid.v4()}$fileExt';

      // Create the storage path
      final storagePath = 'inspections/$inspectionId/$topicId/$itemId/$detailId/$filename';

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
    required String userId,
  }) async {
    try {
      // Generate a unique filename
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'profile_$timestamp$fileExt';

      // Create the storage path
      final storagePath = 'profile_images/$userId/$filename';

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
  Future<String?> uploadNonConformityMedia(
      String localPath, String inspectionId, String topicId, String itemId, 
      String detailId, String nonConformityId) async {
    try {
      // Create file instance from path
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('File not found: $localPath');
      }

      // Determine media type from extension
      final fileExt = path.extension(localPath);
      String type = 'other';

      if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
        type = 'image';
      } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
        type = 'video';
      }

      // Generate a unique filename
      final filename = '${type}_${_uuid.v4()}$fileExt';

      // Create the storage path
      final storagePath = 'inspections/$inspectionId/$topicId/$itemId/$detailId/non_conformities/$nonConformityId/$filename';

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

  // Download a file from Firebase Storage
  Future<List<int>> downloadFile(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      final data = await ref.getData();

      if (data == null) {
        throw Exception('Failed to download file: data is null');
      }

      return data;
    } catch (e) {
      print('Error downloading file: $e');
      rethrow;
    }
  }

  // Extract path from a Firebase Storage URL
  Future<String> extractPathFromUrl(String url) async {
    try {
      // Firebase Storage URLs typically follow this pattern:
      // https://firebasestorage.googleapis.com/v0/b/[bucket]/o/[encoded-path]?[params]
      final uri = Uri.parse(url);
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        // Extract path from Firebase Storage URL format
        final pathSegments = uri.pathSegments;
        if (pathSegments.length > 2 && pathSegments[1] == 'o') {
          // The path is URL encoded in the Firebase Storage URL
          return Uri.decodeComponent(pathSegments[2]);
        }
      }

      // If we can't parse it as a Firebase URL, return the original
      return url;
    } catch (e) {
      print('Error extracting path from URL: $e');
      return url;
    }
  }
}
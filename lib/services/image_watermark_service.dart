import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class ImageWatermarkService {
  final Uuid _uuid = Uuid();

  // Apply watermark to an image
  Future<File?> applyWatermark(String imagePath, String outputPath) async {
    try {
      // Check if image exists
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      // Get current location and timestamp
      final position = await getCurrentLocation();
      final timestamp = DateTime.now();
      
      // Apply watermark based on image type
      if (imagePath.toLowerCase().endsWith('.jpg') || imagePath.toLowerCase().endsWith('.jpeg')) {
        return await addWatermarkToImage(
          imageFile,
          isFromGallery: false,
          timestamp: timestamp,
          location: position,
        );
      } else if (imagePath.toLowerCase().endsWith('.mp4')) {
        return await addWatermarkToVideo(
          imageFile,
          isFromGallery: false,
          timestamp: timestamp,
          location: position,
        );
      } else {
        // If watermarking is not supported for this file type, just copy
        final outputFile = File(outputPath);
        await imageFile.copy(outputPath);
        return outputFile;
      }
    } catch (e) {
      print('Error applying watermark: $e');
      return null;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return null;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return null;
    }

    // Get current position
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Get address from position
  Future<String?> getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        return address;
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return null;
  }

  // Add watermark to image
  Future<File> addWatermarkToImage(
    File imageFile, {
    required bool isFromGallery,
    required DateTime timestamp,
    Position? location,
    String? locationAddress,
  }) async {
    try {
      // For simplicity, just returning the original file (watermark implementation would go here)
      // Actual watermarking would involve loading the image, drawing text on it, and saving it
      
      // Generate output path if not provided
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/${_uuid.v4()}${path.extension(imageFile.path)}';
      
      // Copy the file to output path (in a real implementation, this would be replaced with the watermarked image)
      final outputFile = await imageFile.copy(outputPath);
      
      return outputFile;
    } catch (e) {
      print('Error adding watermark to image: $e');
      rethrow;
    }
  }

  // Add watermark to video
  Future<File> addWatermarkToVideo(
    File videoFile, {
    required bool isFromGallery,
    required DateTime timestamp,
    Position? location,
    String? locationAddress,
  }) async {
    try {
      // For simplicity, just returning the original file (watermark implementation would go here)
      // Actual watermarking would involve using a video editing package
      
      // Generate output path if not provided
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/${_uuid.v4()}${path.extension(videoFile.path)}';
      
      // Copy the file to output path (in a real implementation, this would be replaced with the watermarked video)
      final outputFile = await videoFile.copy(outputPath);
      
      return outputFile;
    } catch (e) {
      print('Error adding watermark to video: $e');
      rethrow;
    }
  }

  // Add metadata to image
  Future<File> addMetadataToImage(
    File imageFile,
    bool isFromGallery,
    DateTime timestamp, {
    Position? location,
    String? locationAddress,
  }) async {
    // In a real implementation, this would add EXIF data to the image
    // For simplicity, just returning the original file
    return imageFile;
  }
}
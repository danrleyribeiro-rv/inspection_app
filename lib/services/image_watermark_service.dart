// lib/services/image_watermark_service.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ImageWatermarkService {
  static final ImageWatermarkService _instance = ImageWatermarkService._internal();
  
  factory ImageWatermarkService() {
    return _instance;
  }
  
  ImageWatermarkService._internal();

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get position with high accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  // Get readable address from coordinates
  Future<String?> getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude
      );
      
      if (placemarks.isEmpty) return null;
      
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.administrativeArea}';
    } catch (e) {
      print('Error getting address from position: $e');
      return null;
    }
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
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final ui.Image image = await decodeImageFromBytes(bytes);
      
      // Create recorder for drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder, 
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
      );
      
      // Draw original image
      canvas.drawImage(image, Offset.zero, Paint());
      
      // Draw watermark
      await _drawWatermark(
        canvas,
        Size(image.width.toDouble(), image.height.toDouble()),
        isFromGallery,
        timestamp,
        location,
        locationAddress,
      );
      
      // Convert to image
      final picture = recorder.endRecording();
      final watermarkedImage = await picture.toImage(image.width, image.height);
      final watermarkedBytes = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);
      
      // Save to file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'watermarked_${timestamp.millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final watermarkedFile = File('${tempDir.path}/$fileName');
      
      await watermarkedFile.writeAsBytes(watermarkedBytes!.buffer.asUint8List());
      
      return watermarkedFile;
    } catch (e) {
      print('Error adding watermark to image: $e');
      return imageFile; // Return original if watermarking fails
    }
  }

  // Add watermark to video (requires FFmpeg or similar)
  Future<File> addWatermarkToVideo(
    File videoFile, {
    required bool isFromGallery,
    required DateTime timestamp,
    Position? location,
    String? locationAddress,
  }) async {
    // FFmpeg functionality removed. Return original file.
    return videoFile;
  }

  Future<void> _drawWatermark(
    Canvas canvas,
    Size size,
    bool isFromGallery,
    DateTime timestamp,
    Position? location,
    String? locationAddress,
  ) async {
    // Format date and time with seconds
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final formattedDateTime = dateTimeFormat.format(timestamp);
    
    // Icon to use based on source
    final iconText = isFromGallery ? '📁' : '📷';
    
    // Calculate position - bottom right corner with some padding
    final bottomPadding = 10.0;
    final rightPadding = 10.0;
    
    // Prepare text style
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.normal,
    );
    
    // Create watermark text with location info if available
    String watermarkText = ' $iconText $formattedDateTime';
    
    // Add location information if provided
    if (location != null) {
      // Add coordinates with 4 decimal precision
      watermarkText += ' | ${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}';
    }
    
    // Add address if provided
    if (locationAddress != null && locationAddress.isNotEmpty) {
      // Using truncated address if too long
      final shortenedAddress = locationAddress.length > 30 
          ? '${locationAddress.substring(0, 27)}...' 
          : locationAddress;
      
      // Append address with separator
      watermarkText += ' | $shortenedAddress';
    }
    
    // Prepare text for measurement
    final textSpan = TextSpan(
      text: watermarkText,
      style: textStyle,
    );
    
    // Create text painter to measure text dimensions
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    
    // Calculate watermark rectangle dimensions with padding
    final double rectWidth = textPainter.width + 10; // add padding
    final double rectHeight = textPainter.height + 4; // add padding
    
    // Calculate position (bottom right)
    final rectLeft = size.width - rectWidth - rightPadding;
    final rectTop = size.height - rectHeight - bottomPadding;
    
    // Draw semi-transparent black background (50% opacity)
    final bgRect = Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(bgRect, bgPaint);
    
    // Draw the text with icon
    textPainter.paint(
      canvas, 
      Offset(rectLeft + 5, rectTop + 2) // apply inner padding
    );
  }

  // Decode image from bytes
  Future<ui.Image> decodeImageFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // Add metadata to image
  Future<File> addMetadataToImage(
    File imageFile,
    bool isFromGallery,
    DateTime timestamp,
    {Position? location, String? locationAddress}
  ) async {
    try {
      // Note: Adding EXIF metadata requires image_editor package
      // For now, we'll just rename the file to include metadata
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final formattedDate = dateFormat.format(timestamp);
      final source = isFromGallery ? 'gallery' : 'camera';
      
      final tempDir = await getTemporaryDirectory();
      final fileName = '${source}_${formattedDate}${path.extension(imageFile.path)}';
      final newFile = File('${tempDir.path}/$fileName');
      
      await imageFile.copy(newFile.path);
      return newFile;
    } catch (e) {
      print('Error adding metadata to image: $e');
      return imageFile;
    }
  }
}
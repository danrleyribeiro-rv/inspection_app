// lib/services/image_watermark_service.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class ImageWatermarkService {
  static final ImageWatermarkService _instance = ImageWatermarkService._internal();
  
  factory ImageWatermarkService() {
    return _instance;
  }
  
  ImageWatermarkService._internal();

  // Add watermark to image
  Future<File> addWatermarkToImage(
    File imageFile, {
    required bool isFromGallery,
    required DateTime timestamp,
  }) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final ui.Image image = await decodeImageFromBytes(bytes);
      
      // Create recorder for drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
      
      // Draw original image
      canvas.drawImage(image, Offset.zero, Paint());
      
      // Draw watermark
      await _drawWatermark(
        canvas,
        Size(image.width.toDouble(), image.height.toDouble()),
        isFromGallery,
        timestamp,
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
  }) async {
    try {
      // Note: Video watermarking requires FFmpeg or similar video processing library
      // For now, we'll return the original video
      // TODO: Implement video watermarking
      print('Video watermarking not implemented yet');
      return videoFile;
    } catch (e) {
      print('Error adding watermark to video: $e');
      return videoFile;
    }
  }

  Future<void> _drawWatermark(
    Canvas canvas,
    Size size,
    bool isFromGallery,
    DateTime timestamp,
  ) async {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Format date and time
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm:ss');
    final dateText = dateFormat.format(timestamp);
    final timeText = timeFormat.format(timestamp);

    // Draw semi-transparent background
    final bgRect = Rect.fromLTWH(
      size.width - 200,
      size.height - 80,
      180,
      60,
    );
    
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      bgPaint,
    );

    // Draw icon (gallery or camera)
    final iconPainter = TextPainter(
      text: TextSpan(
        text: isFromGallery ? '📁' : '📷',
        style: const TextStyle(fontSize: 24),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(size.width - 190, size.height - 75),
    );

    // Draw date
    textPainter.text = TextSpan(
      text: dateText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - 150, size.height - 70),
    );

    // Draw time
    textPainter.text = TextSpan(
      text: timeText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - 150, size.height - 45),
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
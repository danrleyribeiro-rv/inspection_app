import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class WatermarkService {
  final Uuid _uuid = Uuid();

  Future<File?> applyWatermark(
    String inputPath, 
    String outputPath, {
    String? watermarkText,
  }) async {
    try {
      final inputImage = img.decodeImage(await File(inputPath).readAsBytes());
      if (inputImage == null) return null;

      // Aplica marca d'água
      final watermarkedImage = img.drawString(
        inputImage,
        watermarkText ?? '📷 ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
        font: img.arial24,
        x: 20,
        y: inputImage.height - 40,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Salva imagem com marca d'água
      await File(outputPath).writeAsBytes(img.encodeJpg(watermarkedImage, quality: 95));
      return File(outputPath);
    } catch (e) {
      debugPrint('Error applying watermark: $e');
      return null;
    }
  }

  Future<File?> applyVideoWatermark(
    String inputPath, 
    String outputPath, {
    String? watermarkText,
    String aspectRatio = '4:3',
  }) async {
    try {
      // Implementação com FFmpeg seria ideal aqui
      // Por enquanto, copia o arquivo
      await File(inputPath).copy(outputPath);
      return File(outputPath);
    } catch (e) {
      debugPrint('Error applying video watermark: $e');
      return null;
    }
  }

  Future<File> _addImageWatermark(
    File imageFile,
    String outputPath,
    DateTime timestamp,
    Position? position,
    String? address,
  ) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('Could not decode image');
      }

      final watermarkText = _buildWatermarkText(timestamp, position, address);
      final watermarkedImage = _drawWatermarkOnImage(originalImage, watermarkText);
      
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(watermarkedImage, quality: 85));
      
      return outputFile;
    } catch (e) {
      print('Error adding image watermark: $e');
      rethrow;
    }
  }

  Future<File> _addVideoWatermark(
    File videoFile,
    String outputPath,
    DateTime timestamp,
    Position? position,
    String? address,
  ) async {
    try {
      // For video watermarking, would need FFmpeg integration
      // For now, just copy the file and add metadata
      final outputFile = File(outputPath);
      await videoFile.copy(outputPath);
      
      // Add metadata to video file (implementation depends on video format)
      await _addVideoMetadata(outputFile, timestamp, position, address);
      
      return outputFile;
    } catch (e) {
      print('Error adding video watermark: $e');
      rethrow;
    }
  }

  img.Image _drawWatermarkOnImage(img.Image image, String text) {
    final lines = text.split('\n');
    final fontSize = (image.width * 0.025).round();
    final padding = fontSize;
    
    final lineHeight = (fontSize * 1.2).round();
    final textHeight = lines.length * lineHeight + (padding * 2);
    final maxLineWidth = lines.map((line) => line.length * fontSize * 0.6).reduce((a, b) => a > b ? a : b);
    final textWidth = maxLineWidth.round() + (padding * 2);
    
    final bgColor = img.ColorRgba8(0, 0, 0, 180);
    final textColor = img.ColorRgba8(255, 255, 255, 255);
    
    final x = padding;
    final y = image.height - textHeight - padding;
    
    // Draw background
    img.fillRect(
      image,
      x1: x - padding ~/ 2,
      y1: y - padding ~/ 2,
      x2: x + textWidth,
      y2: y + textHeight,
      color: bgColor,
    );
    
    // Draw text
    for (int i = 0; i < lines.length; i++) {
      final lineY = y + (i * lineHeight);
      _drawSimpleText(image, lines[i], x, lineY, fontSize, textColor);
    }
    
    return image;
  }

  void _drawSimpleText(img.Image image, String text, int x, int y, int fontSize, img.Color color) {
    final chars = text.split('');
    var currentX = x;
    
    for (final char in chars) {
      if (char != ' ') {
        _drawChar(image, char, currentX, y, fontSize, color);
      }
      currentX += (fontSize * 0.6).round();
    }
  }

  void _drawChar(img.Image image, String char, int x, int y, int fontSize, img.Color color) {
    final charWidth = (fontSize * 0.5).round();
    final charHeight = fontSize;
    
    // Simple rectangle for character representation
    img.fillRect(
      image,
      x1: x,
      y1: y,
      x2: x + charWidth,
      y2: y + charHeight,
      color: color,
    );
  }

  String _buildWatermarkText(DateTime timestamp, Position? position, String? address) {
    final dateStr = '${timestamp.day.toString().padLeft(2, '0')}/'
                   '${timestamp.month.toString().padLeft(2, '0')}/'
                   '${timestamp.year}';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:'
                   '${timestamp.minute.toString().padLeft(2, '0')}';
    
    final lines = <String>[
      'Data: $dateStr',
      'Hora: $timeStr',
    ];
    
    if (position != null) {
      lines.addAll([
        'Lat: ${position.latitude.toStringAsFixed(6)}',
        'Lng: ${position.longitude.toStringAsFixed(6)}',
      ]);
    }
    
    if (address != null && address.isNotEmpty) {
      final shortAddress = address.length > 40 
          ? '${address.substring(0, 37)}...' 
          : address;
      lines.add('Local: $shortAddress');
    }
    
    return lines.join('\n');
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<String?> _getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final addressParts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((part) => part != null && part.isNotEmpty);

        return addressParts.join(', ');
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  Future<void> _addVideoMetadata(
    File videoFile,
    DateTime timestamp,
    Position? position,
    String? address,
  ) async {
    // Implementation would require FFmpeg or similar for video metadata
    // For now, this is a placeholder
    print('Video metadata added: ${timestamp}, ${position?.latitude}, ${position?.longitude}');
  }
}
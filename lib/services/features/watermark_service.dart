// lib/services/features/watermark_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

class WatermarkService {
  Future<File?> applyWatermark(
    String inputPath, 
    String outputPath, {
    String? watermarkText,
    bool isFromCamera = true,
  }) async {
    try {
      final inputImage = img.decodeImage(await File(inputPath).readAsBytes());
      if (inputImage == null) return null;

      final position = await _getCurrentLocation();

      // Carrega ícone
      final iconPath = isFromCamera 
          ? 'assets/icons/camera_watermark.png'
          : 'assets/icons/galery_watermark.png';
      
      img.Image? watermarkIcon;
      try {
        final iconBytes = await rootBundle.load(iconPath);
        watermarkIcon = img.decodeImage(iconBytes.buffer.asUint8List());
      } catch (e) {
        debugPrint('Could not load watermark icon: $e');
      }

      // Data/hora na marca d'água
      final timestamp = DateTime.now();
      final dateTimeText = DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);
      
      final baseFontSize = (inputImage.width * 0.015).round();
      final padding = 15;
      
      // Desenha fundo
      final textWidth = dateTimeText.length * baseFontSize * 0.6;
      final iconSize = watermarkIcon != null ? (baseFontSize * 1.5).round() : 0;
      final totalWidth = textWidth + iconSize + (iconSize > 0 ? 8 : 0) + (padding * 2);
      
      img.fillRect(
        inputImage,
        x1: 10,
        y1: inputImage.height - 40,
        x2: 10 + totalWidth.round(),
        y2: inputImage.height - 10,
        color: img.ColorRgba8(0, 0, 0, 150),
      );

      // Desenha ícone
      int textStartX = padding + 10;
      if (watermarkIcon != null) {
        final resizedIcon = img.copyResize(watermarkIcon, width: iconSize, height: iconSize);
        img.compositeImage(
          inputImage,
          resizedIcon,
          dstX: padding + 10,
          dstY: inputImage.height - 35,
        );
        textStartX += iconSize + 8;
      }

      // Desenha texto
      final watermarkedImage = img.drawString(
        inputImage,
        dateTimeText,
        font: img.arial14,
        x: textStartX,
        y: inputImage.height - 30,
        color: img.ColorRgb8(255, 255, 255),
      );

      await File(outputPath).writeAsBytes(img.encodeJpg(watermarkedImage, quality: 95));
      
      // Salva metadados em arquivo JSON
      await _saveMetadata(outputPath, timestamp, position, isFromCamera);
      
      return File(outputPath);
    } catch (e) {
      debugPrint('Error applying watermark: $e');
      return null;
    }
  }

  Future<void> _saveMetadata(String imagePath, DateTime timestamp, Position? position, bool isFromCamera) async {
    final metadataPath = '${imagePath}.json';
    final metadata = {
      'timestamp': timestamp.toIso8601String(),
      'source': isFromCamera ? 'camera' : 'gallery',
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'accuracy': position?.accuracy,
    };
    
    await File(metadataPath).writeAsString(jsonEncode(metadata));
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
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<File?> applyVideoWatermark(
    String inputPath, 
    String outputPath, {
    String? watermarkText,
    String aspectRatio = '4:3',
    bool isFromCamera = true,
  }) async {
    try {
      await File(inputPath).copy(outputPath);
      return File(outputPath);
    } catch (e) {
      debugPrint('Error applying video watermark: $e');
      return null;
    }
  }
}
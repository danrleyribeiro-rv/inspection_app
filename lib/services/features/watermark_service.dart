import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

class WatermarkService {
  final Uuid _uuid = Uuid();

  Future<File?> applyWatermark(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final position = await _getCurrentLocation();
      final timestamp = DateTime.now();
      final address = position != null 
          ? await _getAddressFromPosition(position) 
          : null;

      if (imagePath.toLowerCase().endsWith('.jpg') || 
          imagePath.toLowerCase().endsWith('.jpeg') ||
          imagePath.toLowerCase().endsWith('.png')) {
        return await _addImageWatermark(imageFile, timestamp, position, address);
      }

      return imageFile;
    } catch (e) {
      print('Error applying watermark: $e');
      return null;
    }
  }

  Future<File> _addImageWatermark(
    File imageFile,
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
      
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/watermarked_${_uuid.v4()}.jpg';
      final outputFile = File(outputPath);
      
      await outputFile.writeAsBytes(img.encodeJpg(watermarkedImage, quality: 85));
      
      return outputFile;
    } catch (e) {
      print('Error adding image watermark: $e');
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
    
    final bgColor = img.ColorRgba8(0, 0, 0, 128);
    final textColor = img.ColorRgba8(255, 255, 255, 255);
    
    final x = padding;
    final y = image.height - textHeight - padding;
    
    img.fillRect(
      image,
      x1: x - padding ~/ 2,
      y1: y - padding ~/ 2,
      x2: x + textWidth,
      y2: y + textHeight,
      color: bgColor,
    );
    
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
      _drawChar(image, char, currentX, y, fontSize, color);
      currentX += (fontSize * 0.6).round();
    }
  }

  void _drawChar(img.Image image, String char, int x, int y, int fontSize, img.Color color) {
    if (char == ' ') return;
    
    final charWidth = (fontSize * 0.5).round();
    final charHeight = fontSize;
    
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
}
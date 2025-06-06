// lib/services/features/media_service.dart
import 'dart:io';
import 'dart:isolate';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';

class MediaService {
  final FirebaseService _firebase = FirebaseService();
  final InspectionService _inspectionService = InspectionService();
  final Uuid _uuid = Uuid();

  // Processar imagem em background
  static Future<void> _processImageIsolate(Map<String, dynamic> params) async {
    final String inputPath = params['inputPath'];
    final String outputPath = params['outputPath'];
    final SendPort sendPort = params['sendPort'];
    
    try {
      final inputImage = img.decodeImage(await File(inputPath).readAsBytes());
      if (inputImage == null) {
        sendPort.send({'success': false, 'error': 'Failed to decode image'});
        return;
      }

      // Calcular dimensões para 4:3
      int targetWidth, targetHeight;
      
      if (inputImage.width / inputImage.height > 4/3) {
        targetHeight = inputImage.height;
        targetWidth = (targetHeight * 4 / 3).round();
      } else {
        targetWidth = inputImage.width;
        targetHeight = (targetWidth * 3 / 4).round();
      }
      
      // Crop centralizado para 4:3
      final croppedImage = img.copyCrop(
        inputImage,
        x: (inputImage.width - targetWidth) ~/ 2,
        y: (inputImage.height - targetHeight) ~/ 2,
        width: targetWidth,
        height: targetHeight,
      );
      
      await File(outputPath).writeAsBytes(img.encodeJpg(croppedImage, quality: 95));
      sendPort.send({'success': true, 'outputPath': outputPath});
    } catch (e) {
      sendPort.send({'success': false, 'error': e.toString()});
    }
  }

  Future<File?> processImage43(String inputPath, String outputPath) async {
    final ReceivePort receivePort = ReceivePort();
    
    await Isolate.spawn(_processImageIsolate, {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'sendPort': receivePort.sendPort,
    });

    final result = await receivePort.first;
    if (result['success'] == true) {
      return File(result['outputPath']);
    }
    return null;
  }

  Future<Position?> getCurrentLocation() async {
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
      return null;
    }
  }

  Future<String> uploadMedia({
    required File file,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
  }) async {
    final fileExt = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${type}_${timestamp}_${_uuid.v4()}$fileExt';

    String storagePath = 'inspections/$inspectionId/';
    if (topicId != null) storagePath += 'topics/$topicId/';
    if (itemId != null) storagePath += 'items/$itemId/';
    if (detailId != null) storagePath += 'details/$detailId/';
    storagePath += filename;

    String? contentType;
    if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
      contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
    } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
      contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
    }

    final ref = _firebase.storage.ref().child(storagePath);
    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> allMedia = [];

    for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
      final topic = inspection.topics![topicIndex];
      
      // Media do tópico
      final topicMedia = List<Map<String, dynamic>>.from(topic['media'] ?? []);
      for (int mediaIndex = 0; mediaIndex < topicMedia.length; mediaIndex++) {
        allMedia.add({
          ...topicMedia[mediaIndex],
          'id': 'topic_media_${topicIndex}_$mediaIndex',
          'inspection_id': inspectionId,
          'topic_index': topicIndex,
          'topic_id': 'topic_$topicIndex',
          'topic_name': topic['name'],
          'item_index': null,
          'item_id': null,
          'item_name': null,
          'detail_index': null,
          'detail_id': null,
          'detail_name': null,
          'media_index': mediaIndex,
          'is_non_conformity': false,
        });
      }
      
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        
        // Media do item
        final itemMedia = List<Map<String, dynamic>>.from(item['media'] ?? []);
        for (int mediaIndex = 0; mediaIndex < itemMedia.length; mediaIndex++) {
          allMedia.add({
            ...itemMedia[mediaIndex],
            'id': 'item_media_${topicIndex}_${itemIndex}_$mediaIndex',
            'inspection_id': inspectionId,
            'topic_index': topicIndex,
            'topic_id': 'topic_$topicIndex',
            'topic_name': topic['name'],
            'item_index': itemIndex,
            'item_id': 'item_$itemIndex',
            'item_name': item['name'],
            'detail_index': null,
            'detail_id': null,
            'detail_name': null,
            'media_index': mediaIndex,
            'is_non_conformity': false,
          });
        }
        
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];

          // Media regular do detalhe
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          for (int mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
            allMedia.add({
              ...media[mediaIndex],
              'id': 'media_${topicIndex}_${itemIndex}_${detailIndex}_$mediaIndex',
              'inspection_id': inspectionId,
              'topic_index': topicIndex,
              'item_index': itemIndex,
              'detail_index': detailIndex,
              'media_index': mediaIndex,
              'topic_id': 'topic_$topicIndex',
              'topic_item_id': 'item_$itemIndex',
              'detail_id': 'detail_$detailIndex',
              'topic_name': topic['name'],
              'item_name': item['name'],
              'detail_name': detail['name'],
              'is_non_conformity': false,
            });
          }

          // Media de não conformidades
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
            final nc = nonConformities[ncIndex];
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            for (int ncMediaIndex = 0; ncMediaIndex < ncMedia.length; ncMediaIndex++) {
              allMedia.add({
                ...ncMedia[ncMediaIndex],
                'id': 'nc_media_${topicIndex}_${itemIndex}_${detailIndex}_${ncIndex}_$ncMediaIndex',
                'inspection_id': inspectionId,
                'topic_index': topicIndex,
                'item_index': itemIndex,
                'detail_index': detailIndex,
                'nc_index': ncIndex,
                'nc_media_index': ncMediaIndex,
                'topic_id': 'topic_$topicIndex',
                'topic_item_id': 'item_$itemIndex',
                'detail_id': 'detail_$detailIndex',
                'topic_name': topic['name'],
                'item_name': item['name'],
                'detail_name': detail['name'],
                'is_non_conformity': true,
              });
            }
          }
        }
      }
    }

    return allMedia;
  }

  List<Map<String, dynamic>> filterMedia({
    required List<Map<String, dynamic>> allMedia,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    return allMedia.where((media) {
      if (topicId != null && media['topic_id'] != topicId) return false;
      if (itemId != null && media['topic_item_id'] != itemId) return false;
      if (detailId != null && media['detail_id'] != detailId) return false;
      if (isNonConformityOnly == true && media['is_non_conformity'] != true) return false;
      if (mediaType != null && media['type'] != mediaType) return false;
      return true;
    }).toList();
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _firebase.storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

Future<String> uploadProfileImage({
    required File file,
    required String userId,
  }) async {
    final fileExt = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'profile_$timestamp$fileExt';

    final storagePath = 'profile_images/$userId/$filename';

    String? contentType;
    if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
      contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
    }

    final ref = _firebase.storage.ref().child(storagePath);
    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }
}
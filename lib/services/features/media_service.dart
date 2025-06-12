// lib/services/features/media_service.dart
import 'dart:io';
import 'dart:isolate';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

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
      final bytes = await File(inputPath).readAsBytes();
      final inputImage = img.decodeImage(bytes);
      if (inputImage == null) {
        sendPort.send({'success': false, 'error': 'Failed to decode image'});
        return;
      }

      int targetWidth, targetHeight;
      double imageAspectRatio = inputImage.width / inputImage.height;
      const targetAspectRatio = 4.0 / 3.0;

      if (imageAspectRatio > targetAspectRatio) {
        targetHeight = inputImage.height;
        targetWidth = (targetHeight * targetAspectRatio).round();
      } else {
        targetWidth = inputImage.width;
        targetHeight = (targetWidth / targetAspectRatio).round();
      }

      final croppedImage = img.copyCrop(
        inputImage,
        x: (inputImage.width - targetWidth) ~/ 2,
        y: (inputImage.height - targetHeight) ~/ 2,
        width: targetWidth,
        height: targetHeight,
      );

      await File(outputPath)
          .writeAsBytes(img.encodeJpg(croppedImage, quality: 95));
      sendPort.send({'success': true, 'outputPath': outputPath});
    } catch (e) {
      sendPort.send({'success': false, 'error': e.toString()});
    }
  }

  // Processar vídeo em background
  static Future<void> _processVideoIsolate(Map<String, dynamic> params) async {
    final String inputPath = params['inputPath'];
    final String outputPath = params['outputPath'];
    final SendPort sendPort = params['sendPort'];

    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final mediaInfo = session.getMediaInformation();
      if (mediaInfo == null) {
        sendPort.send({'success': false, 'error': 'Could not get video information'});
        return;
      }

      final streams = mediaInfo.getStreams();
      if (streams.isEmpty) {
        sendPort.send({'success': false, 'error': 'Video has no streams'});
        return;
      }

      final StreamInformation? videoStream = streams.firstWhere(
        (s) => s.getType() == 'video',
        orElse: () => streams.first,
      );
      
      if (videoStream == null) {
         sendPort.send({'success': false, 'error': 'No video stream found'});
        return;
      }

      final width = videoStream.getWidth();
      final height = videoStream.getHeight();
      final rotation = videoStream.getTags()?['rotate'];
      
      bool isRotated = rotation == '90' || rotation == '-90' || rotation == '270';
      final effectiveWidth = isRotated ? height : width;
      final effectiveHeight = isRotated ? width : height;

      if (effectiveWidth == null || effectiveHeight == null) {
        sendPort.send({'success': false, 'error': 'Could not determine video dimensions'});
        return;
      }

      String cropFilter;
      const targetAspectRatio = 4.0 / 3.0;
      double currentAspectRatio = effectiveWidth / effectiveHeight;

      if (currentAspectRatio > targetAspectRatio) {
        cropFilter = 'crop=ih*${targetAspectRatio}:ih';
      } else {
        cropFilter = 'crop=iw:iw/${targetAspectRatio}';
      }

      final command = '-i "$inputPath" -vf "$cropFilter" -preset ultrafast -c:a copy "$outputPath"';
      
      final ffmpegSession = await FFmpegKit.execute(command);
      final returnCode = await ffmpegSession.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        sendPort.send({'success': true, 'outputPath': outputPath});
      } else {
        final logs = await ffmpegSession.getAllLogsAsString();
        sendPort.send({'success': false, 'error': 'FFmpeg failed. Logs: $logs'});
      }
    } catch (e) {
      sendPort.send({'success': false, 'error': e.toString()});
    }
  }

  Future<File?> processMedia43(String inputPath, String outputPath, String type) async {
    final ReceivePort receivePort = ReceivePort();
    
    final params = {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'sendPort': receivePort.sendPort,
    };

    if (type == 'image') {
      await Isolate.spawn(_processImageIsolate, params);
    } else if (type == 'video') {
      await Isolate.spawn(_processVideoIsolate, params);
    } else {
      return File(inputPath);
    }

    final result = await receivePort.first;
    if (result['success'] == true) {
      return File(result['outputPath']);
    } else {
      debugPrint("Error processing media: ${result['error']}");
      return null;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Could not get location: $e');
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
    if (topicId != null) {
      storagePath += 'topics/$topicId/';
    }
    if (itemId != null) {
      storagePath += 'items/$itemId/';
    }
    if (detailId != null) {
      storagePath += 'details/$detailId/';
    }
    storagePath += filename;

    String? contentType;
    final lowercasedExt = fileExt.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(lowercasedExt)) {
      contentType = 'image/${lowercasedExt.replaceAll('.', '')}';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(lowercasedExt)) {
      contentType = 'video/${lowercasedExt.replaceAll('.', '')}';
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
      final topicId = topic['id'] ?? 'topic_$topicIndex';

      final topicMedia = List<Map<String, dynamic>>.from(topic['media'] ?? []);
      for (int mediaIndex = 0; mediaIndex < topicMedia.length; mediaIndex++) {
        allMedia.add({
          ...topicMedia[mediaIndex],
          'id': 'topic_media_${topicId}_$mediaIndex',
          'inspection_id': inspectionId,
          'topic_id': topicId,
          'topic_name': topic['name'],
          'item_id': null,
          'detail_id': null,
          'is_non_conformity': false,
        });
      }

      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final itemId = item['id'] ?? 'item_${topicIndex}_$itemIndex';

        final itemMedia = List<Map<String, dynamic>>.from(item['media'] ?? []);
        for (int mediaIndex = 0; mediaIndex < itemMedia.length; mediaIndex++) {
          allMedia.add({
            ...itemMedia[mediaIndex],
            'id': 'item_media_${itemId}_$mediaIndex',
            'inspection_id': inspectionId,
            'topic_id': topicId,
            'item_id': itemId,
            'detail_id': null,
            'topic_name': topic['name'],
            'item_name': item['name'],
            'is_non_conformity': false,
          });
        }

        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];
          final detailId = detail['id'] ?? 'detail_${topicIndex}_${itemIndex}_$detailIndex';
          
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          for (int mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
            allMedia.add({
              ...media[mediaIndex],
              'id': 'media_${detailId}_$mediaIndex',
              'inspection_id': inspectionId,
              'topic_id': topicId, 'item_id': itemId, 'detail_id': detailId,
              'topic_name': topic['name'], 'item_name': item['name'], 'detail_name': detail['name'],
              'is_non_conformity': false,
            });
          }

          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
            final nc = nonConformities[ncIndex];
            final ncId = nc['id'] ?? 'nc_${detailId}_$ncIndex';
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            for (int ncMediaIndex = 0; ncMediaIndex < ncMedia.length; ncMediaIndex++) {
              allMedia.add({
                ...ncMedia[ncMediaIndex],
                'id': 'nc_media_${ncId}_$ncMediaIndex',
                'inspection_id': inspectionId,
                'topic_id': topicId, 'item_id': itemId, 'detail_id': detailId,
                'topic_name': topic['name'], 'item_name': item['name'], 'detail_name': detail['name'],
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
    bool topicOnly = false,
    bool itemOnly = false,
  }) {
    return allMedia.where((media) {
      // 1. Filtro de Hierarquia (sempre aplicado)
      if (topicId != null && media['topic_id'] != topicId) return false;
      if (itemId != null && media['item_id'] != itemId) return false;
      if (detailId != null && media['detail_id'] != detailId) return false;

      // 2. Filtro de Nível Exclusivo (para isolar mídias)
      if (topicOnly) {
        if (media['item_id'] != null || media['detail_id'] != null) return false;
      } else if (itemOnly) {
        if (media['detail_id'] != null) return false;
      }
      
      // 3. Filtro de Não Conformidade
      if (isNonConformityOnly != null) {
        if ((media['is_non_conformity'] ?? false) != isNonConformityOnly) {
          return false;
        }
      }
      
      // 4. Filtro de Tipo de Mídia
      if (mediaType != null && media['type'] != mediaType) return false;
      
      return true;
    }).toList();
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _firebase.storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
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
    final lowercasedExt = fileExt.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(lowercasedExt)) {
      contentType = 'image/${lowercasedExt.replaceAll('.', '')}';
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
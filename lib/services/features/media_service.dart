// lib/services/features/media_service.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

class MediaService {
  static const String _offlineMediaBoxName = 'offline_media';
  static const String _processedMediaDirName = 'processed_media';
  
  final FirebaseService _firebase = FirebaseService();
  final InspectionService _inspectionService = InspectionService();
  final Connectivity _connectivity = Connectivity();
  final Uuid _uuid = Uuid();
  
  Box<OfflineMedia>? _offlineMediaBox;
  Directory? _processedMediaDir;
  
  // Stream para notificar sobre mudanças no status de upload
  final StreamController<OfflineMediaUploadEvent> _uploadEventController = 
      StreamController<OfflineMediaUploadEvent>.broadcast();
  Stream<OfflineMediaUploadEvent> get uploadEventStream => _uploadEventController.stream;
  
  // Inicializar o serviço
  Future<void> initialize() async {
    try {
      // Abrir box do Hive para mídias offline
      if (!Hive.isBoxOpen(_offlineMediaBoxName)) {
        _offlineMediaBox = await Hive.openBox<OfflineMedia>(_offlineMediaBoxName);
      } else {
        _offlineMediaBox = Hive.box<OfflineMedia>(_offlineMediaBoxName);
      }
      
      // Criar diretório para mídias processadas
      final appDir = await getApplicationDocumentsDirectory();
      _processedMediaDir = Directory(path.join(appDir.path, _processedMediaDirName));
      if (!await _processedMediaDir!.exists()) {
        await _processedMediaDir!.create(recursive: true);
      }
      
      // OFFLINE-FIRST: Don't start automatic background upload
      debugPrint('MediaService.initialize: Initialized in offline-first mode');
    } catch (e) {
      debugPrint('Error initializing MediaService: $e');
    }
  }
  
  void dispose() {
    _uploadEventController.close();
  }

  // Processamento rápido de imagem sem FFmpeg (instantâneo)
  Future<File?> processImageFast(String inputPath, String outputPath) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return null;

      // Ler a imagem
      final bytes = await inputFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Garantir aspect ratio 4:3 em modo paisagem (largura > altura)
      int newWidth, newHeight;
      
      // Forçar orientação paisagem: width deve ser maior que height
      // Para 4:3 paisagem: width/height = 4/3, então width = height * 4/3
      
      // Câmera agora captura em 4:3 paisagem, verificar se já está na proporção correta
      final aspectRatio = image.width / image.height;
      final targetRatio = 4.0 / 3.0;
      final tolerance = 0.05; // Tolerância de 5% para considerar já na proporção correta
      
      img.Image processedImage = image;
      
      // Se a imagem já está muito próxima do 4:3, usar como está para evitar perda de qualidade
      if ((aspectRatio - targetRatio).abs() < tolerance) {
        debugPrint('MediaService: Image already in 4:3 ratio (${aspectRatio.toStringAsFixed(2)}), skipping crop');
        newWidth = image.width;
        newHeight = image.height;
      } else {
        // Calcular novo tamanho para forçar 4:3
        if (aspectRatio > targetRatio) {
          // Muito larga - usar altura como base
          newHeight = image.height;
          newWidth = (newHeight * 4 / 3).round();
        } else {
          // Muito alta - usar largura como base
          newWidth = image.width;
          newHeight = (newWidth * 3 / 4).round();
        }
        
        debugPrint('MediaService: Adjusting image from ${image.width}x${image.height} (${aspectRatio.toStringAsFixed(2)}) to ${newWidth}x$newHeight (4:3)');
      }
      
      // Agora fazer crop para 4:3 se necessário
      if (newWidth != processedImage.width || newHeight != processedImage.height) {
        // Crop para 4:3 a partir do centro
        final startX = ((processedImage.width - newWidth) / 2).round().clamp(0, processedImage.width);
        final startY = ((processedImage.height - newHeight) / 2).round().clamp(0, processedImage.height);
        
        // Garantir que as dimensões não excedam a imagem
        final cropWidth = newWidth.clamp(1, processedImage.width - startX);
        final cropHeight = newHeight.clamp(1, processedImage.height - startY);
        
        processedImage = img.copyCrop(processedImage, 
          x: startX, 
          y: startY, 
          width: cropWidth, 
          height: cropHeight
        );
        
        debugPrint('MediaService: Cropped image to ${cropWidth}x$cropHeight from ${processedImage.width}x${processedImage.height}');
      }

      // Redimensionar para tamanho máximo se muito grande
      if (processedImage.width > 1200) {
        final ratio = 1200 / processedImage.width;
        final targetHeight = (processedImage.height * ratio).round();
        processedImage = img.copyResize(processedImage, 
          width: 1200, 
          height: targetHeight
        );
      }

      // Salvar com qualidade otimizada
      final jpegBytes = img.encodeJpg(processedImage, quality: 85);
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpegBytes);
      
      return outputFile;
    } catch (e) {
      debugPrint('Error in fast image processing: $e');
      return null;
    }
  }

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

      final StreamInformation videoStream = streams.firstWhere(
        (s) => s.getType() == 'video',
        orElse: () => streams.first,
      );
      

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
        cropFilter = 'crop=ih*$targetAspectRatio:ih';
      } else {
        cropFilter = 'crop=iw:iw/$targetAspectRatio';
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

  // Capturar/processar múltiplas mídias com fluxo offline-first
  Future<List<OfflineMedia>> captureAndProcessMultipleMedia({
    required List<String> inputPaths,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    Map<String, dynamic>? metadata,
  }) async {
    final results = <OfflineMedia>[];
    
    for (final inputPath in inputPaths) {
      try {
        final media = await captureAndProcessMedia(
          inputPath: inputPath,
          inspectionId: inspectionId,
          type: type,
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
          metadata: metadata,
        );
        results.add(media);
      } catch (e) {
        debugPrint('Error processing media $inputPath: $e');
      }
    }
    
    return results;
  }

  // Capturar/processar mídia com fluxo offline-first
  Future<OfflineMedia> captureAndProcessMedia({
    required String inputPath,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Gerar ID único para a mídia
      final mediaId = _uuid.v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = path.extension(inputPath);
      final fileName = '${type}_${timestamp}_$mediaId$fileExt';
      
      // Criar objeto OfflineMedia
      final offlineMedia = OfflineMedia(
        id: mediaId,
        localPath: inputPath,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        type: type,
        fileName: fileName,
        createdAt: DateTime.now(),
        metadata: metadata ?? {},
        fileSize: await File(inputPath).length(),
      );
      
      // Salvar no cache local
      if (_offlineMediaBox == null) {
        throw Exception('MediaService não foi inicializado corretamente');
      }
      await _offlineMediaBox!.put(mediaId, offlineMedia);
      
      // Processar mídia em background
      _processMediaInBackground(offlineMedia);
      
      return offlineMedia;
    } catch (e) {
      debugPrint('Error capturing media: $e');
      rethrow;
    }
  }
  
  // Processar mídia em background - DEVICE ONLY (sem upload para nuvem)
  Future<void> _processMediaInBackground(OfflineMedia offlineMedia) async {
    try {
      // Determinar caminho de saída permanente no dispositivo
      final outputPath = path.join(
        _processedMediaDir!.path,
        'processed_${offlineMedia.fileName}',
      );
      
      // Processar mídia (conversão 4:3)
      final processedFile = await processMedia43(
        offlineMedia.localPath,
        outputPath,
        offlineMedia.type,
      );
      
      if (processedFile != null) {
        // Atualizar caminho local para o arquivo processado
        offlineMedia.localPath = processedFile.path;
        offlineMedia.fileSize = await processedFile.length();
        offlineMedia.markProcessed();
        
        // DEVICE ONLY: Marcar como "uploaded" para indicar que está pronto para uso
        // (mas armazenado apenas no dispositivo)
        offlineMedia.markUploaded(processedFile.path); // Use local path as "URL"
        
        // Salvar as alterações no Hive
        await _offlineMediaBox!.put(offlineMedia.id, offlineMedia);
        
        // Notificar que o processamento foi concluído
        _uploadEventController.add(OfflineMediaUploadEvent(
          mediaId: offlineMedia.id,
          status: UploadStatus.completed, // Marca como "enviado" mas é só local
          message: 'Mídia processada e armazenada no dispositivo',
        ));
        
        debugPrint('Media ${offlineMedia.id} processed successfully and stored locally at: ${processedFile.path}');
      } else {
        offlineMedia.markError('Falha ao processar mídia');
        _uploadEventController.add(OfflineMediaUploadEvent(
          mediaId: offlineMedia.id,
          status: UploadStatus.error,
          message: 'Falha ao processar mídia',
        ));
      }
    } catch (e) {
      debugPrint('Error processing media in background: $e');
      offlineMedia.markError('Erro no processamento: $e');
      _uploadEventController.add(OfflineMediaUploadEvent(
        mediaId: offlineMedia.id,
        status: UploadStatus.error,
        message: 'Erro no processamento: $e',
      ));
    }
  }
  
  // Removed old disabled _attemptUpload method - using full implementation below
  
  // Removed _startBackgroundUpload - not needed in offline-first mode
  
  // Verificar se está online
  Future<bool> _isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
    } catch (e) {
      return false;
    }
  }
  
  /// OFFLINE-FIRST: Capture and store media locally
  Future<String?> captureMediaOffline({
    required File sourceFile,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    bool isNonConformity = false,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_offlineMediaBox == null || _processedMediaDir == null) {
        throw Exception('MediaService not initialized');
      }
      
      // Generate unique ID for this media
      final mediaId = _uuid.v4();
      final fileExt = path.extension(sourceFile.path);
      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}_$mediaId$fileExt';
      final localPath = path.join(_processedMediaDir!.path, fileName);
      
      // Process the media file (crop to 4:3 for images, etc.)
      File? processedFile;
      if (type == 'image') {
        processedFile = await processImageFast(sourceFile.path, localPath);
      } else {
        // For videos and other types, just copy for now
        processedFile = await sourceFile.copy(localPath);
      }
      
      if (processedFile == null) {
        throw Exception('Failed to process media file');
      }
      
      // Get location if available
      final location = await getCurrentLocation();
      
      // Create offline media record
      final offlineMedia = OfflineMedia(
        id: mediaId,
        type: type,
        localPath: processedFile.path,
        fileName: fileName,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        isProcessed: true,
        isUploaded: false,
        isDownloadedFromCloud: false,
        createdAt: DateTime.now(),
        metadata: {
          ...?metadata,
          'is_non_conformity': isNonConformity,
          'source': 'camera',
          'aspect_ratio': type == 'image' ? '4:3' : null,
          'latitude': location?.latitude,
          'longitude': location?.longitude,
        },
      );
      
      // Save to offline storage
      await _offlineMediaBox!.put(mediaId, offlineMedia);
      
      // Add to inspection document immediately (offline)
      await _addMediaToInspectionOffline(offlineMedia);
      
      debugPrint('MediaService.captureMediaOffline: Captured media $mediaId for inspection $inspectionId');
      return mediaId;
      
    } catch (e) {
      debugPrint('MediaService.captureMediaOffline: Error capturing media: $e');
      return null;
    }
  }
  
  /// Add media to inspection document structure (offline)
  Future<void> _addMediaToInspectionOffline(OfflineMedia offlineMedia) async {
    try {
      final inspection = await _inspectionService.getInspection(offlineMedia.inspectionId);
      if (inspection?.topics == null) {
        debugPrint('MediaService._addMediaToInspectionOffline: Inspection not found');
        return;
      }
      
      // Create media data for inspection document
      final mediaData = {
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'fileName': offlineMedia.fileName,
        'aspect_ratio': offlineMedia.metadata?['aspect_ratio'] ?? '4:3',
        'source': offlineMedia.metadata?['source'] ?? 'camera',
        'is_non_conformity': offlineMedia.metadata?['is_non_conformity'] ?? false,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'status': 'local',
        'metadata': offlineMedia.metadata ?? {},
      };
      
      // Use the coordinator to add media to the appropriate hierarchy level
      if (offlineMedia.detailId != null) {
        if (offlineMedia.metadata?['is_non_conformity'] == true) {
          // Non-conformity media - this would need special handling
          debugPrint('MediaService._addMediaToInspectionOffline: Adding NC media not implemented yet');
        } else {
          // Detail level media - use direct inspection update to avoid circular dependency
          await _addMediaToDetailDirectly(offlineMedia.inspectionId, offlineMedia.topicId!, offlineMedia.itemId!, offlineMedia.detailId!, mediaData);
        }
      } else if (offlineMedia.itemId != null) {
        // Item level media
        await _addMediaToItemDirectly(offlineMedia.inspectionId, offlineMedia.topicId!, offlineMedia.itemId!, mediaData);
      } else if (offlineMedia.topicId != null) {
        // Topic level media
        await _addMediaToTopicDirectly(offlineMedia.inspectionId, offlineMedia.topicId!, mediaData);
      }
      
      debugPrint('MediaService._addMediaToInspectionOffline: Added media ${offlineMedia.id} to inspection structure');
    } catch (e) {
      debugPrint('MediaService._addMediaToInspectionOffline: Error adding media to inspection: $e');
    }
  }
  
  /// Add media directly to topic level (avoiding circular dependency)
  Future<void> _addMediaToTopicDirectly(String inspectionId, String topicId, Map<String, dynamic> mediaData) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection == null) return;

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex != null && topicIndex < topics.length) {
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final mediaList = List<Map<String, dynamic>>.from(topic['media'] ?? []);
      mediaList.add(mediaData);
      topic['media'] = mediaList;
      topics[topicIndex] = topic;

      await _inspectionService.saveInspection(inspection.copyWith(topics: topics));
    }
  }
  
  /// Add media directly to item level (avoiding circular dependency)
  Future<void> _addMediaToItemDirectly(String inspectionId, String topicId, String itemId, Map<String, dynamic> mediaData) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection == null) return;

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex != null && topicIndex < topics.length) {
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      final itemIndexStr = itemId.replaceFirst('item_', '');
      final itemIndex = int.tryParse(itemIndexStr);
      
      if (itemIndex != null && itemIndex < items.length) {
        final item = Map<String, dynamic>.from(items[itemIndex]);
        final mediaList = List<Map<String, dynamic>>.from(item['media'] ?? []);
        mediaList.add(mediaData);
        item['media'] = mediaList;
        items[itemIndex] = item;
        topic['items'] = items;
        topics[topicIndex] = topic;

        await _inspectionService.saveInspection(inspection.copyWith(topics: topics));
      }
    }
  }
  
  /// Add media directly to detail level (avoiding circular dependency)
  Future<void> _addMediaToDetailDirectly(String inspectionId, String topicId, String itemId, String detailId, Map<String, dynamic> mediaData) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection == null) return;

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex != null && topicIndex < topics.length) {
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      final itemIndexStr = itemId.replaceFirst('item_', '');
      final itemIndex = int.tryParse(itemIndexStr);
      
      if (itemIndex != null && itemIndex < items.length) {
        final item = Map<String, dynamic>.from(items[itemIndex]);
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        final detailIndexStr = detailId.replaceFirst('detail_', '');
        final detailIndex = int.tryParse(detailIndexStr);
        
        if (detailIndex != null && detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          mediaList.add(mediaData);
          detail['media'] = mediaList;
          details[detailIndex] = detail;
          item['details'] = details;
          items[itemIndex] = item;
          topic['items'] = items;
          topics[topicIndex] = topic;

          await _inspectionService.saveInspection(inspection.copyWith(topics: topics));
        }
      }
    }
  }
  
  // OFFLINE-FIRST: Manual upload attempt
  Future<void> _attemptUpload(OfflineMedia media) async {
    debugPrint('MediaService._attemptUpload: Attempting to upload ${media.id}');
    try {
      if (!await _isOnline()) {
        throw Exception('No internet connection');
      }
      
      final file = File(media.localPath);
      if (!await file.exists()) {
        throw Exception('Local file not found: ${media.localPath}');
      }
      
      // Upload to Firebase Storage
      final uploadUrl = await uploadCachedMedia(
        localPath: media.localPath,
        inspectionId: media.inspectionId,
        topicId: media.topicId,
        itemId: media.itemId,
        detailId: media.detailId,
      );
      
      // Update offline media record using the markUploaded method
      media.markUploaded(uploadUrl);
      
      // Update inspection document with new URL
      await _updateInspectionMediaUrl(media, uploadUrl);
      
      debugPrint('MediaService._attemptUpload: Successfully uploaded ${media.id}');
    } catch (e) {
      debugPrint('MediaService._attemptUpload: Error uploading ${media.id}: $e');
      media.errorMessage = e.toString();
      await media.save();
      rethrow;
    }
  }
  
  // Obter mídias pendentes de upload
  List<OfflineMedia> getPendingMedia() {
    if (_offlineMediaBox == null) return [];
    return _offlineMediaBox!.values
        .where((media) => media.needsUpload && media.isLocallyCreated)
        .toList();
  }
  
  // Obter mídias pendentes para uma inspeção específica
  List<OfflineMedia> getPendingMediaForInspection(String inspectionId) {
    if (_offlineMediaBox == null) return [];
    return _offlineMediaBox!.values
        .where((media) => media.inspectionId == inspectionId && media.needsUpload && media.isLocallyCreated)
        .toList();
  }
  
  // Upload de mídias pendentes para uma inspeção específica
  Future<void> uploadPendingMediaForInspection(String inspectionId) async {
    try {
      if (!await _isOnline()) {
        throw Exception('Sem conexão com a internet');
      }
      
      final pendingMedia = getPendingMediaForInspection(inspectionId);
          
      if (pendingMedia.isEmpty) {
        return;
      }
      
      int successCount = 0;
      List<String> errors = [];
      
      for (final media in pendingMedia) {
        try {
          debugPrint('MediaService.uploadPendingMediaForInspection: Processing ${media.fileName}, canRetry: ${media.canRetry}, isProcessed: ${media.isProcessed}, isUploaded: ${media.isUploaded}');
          if (media.canRetry) {
            await _attemptUpload(media);
            successCount++;
            debugPrint('MediaService.uploadPendingMediaForInspection: Successfully uploaded ${media.fileName}');
          } else {
            debugPrint('MediaService.uploadPendingMediaForInspection: Skipping ${media.fileName} - cannot retry');
          }
        } catch (e) {
          debugPrint('MediaService.uploadPendingMediaForInspection: Error uploading ${media.fileName}: $e');
          errors.add('Erro no upload de ${media.fileName}: $e');
        }
      }
      
      if (errors.isNotEmpty) {
        throw Exception('${errors.length} uploads falharam: ${errors.join(', ')}');
      }
      
      debugPrint('Upload concluído: $successCount mídias enviadas para a nuvem');
    } catch (e) {
      debugPrint('Error uploading media for inspection $inspectionId: $e');
      rethrow;
    }
  }
  
  // Obter todas as mídias de uma inspeção (online + offline)
  List<OfflineMedia> getAllMediaForInspection(String inspectionId) {
    if (_offlineMediaBox == null) return [];
    return _offlineMediaBox!.values
        .where((media) => media.inspectionId == inspectionId)
        .toList();
  }
  
  // Forçar retry de uma mídia com erro
  Future<void> retryMediaUpload(String mediaId) async {
    final media = _offlineMediaBox?.get(mediaId);
    if (media != null && media.canRetry) {
      media.resetError();
      await _attemptUpload(media);
    }
  }
  
  // Limpar mídias antigas já enviadas
  Future<void> cleanupOldMedia({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final mediaToDelete = _offlineMediaBox?.values
          .where((media) => media.isUploaded && media.createdAt.isBefore(cutoffDate))
          .toList() ?? [];
      
      for (final media in mediaToDelete) {
        // Deletar arquivo local
        final file = File(media.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Remover do cache
        await media.delete();
      }
      
      debugPrint('Cleaned up ${mediaToDelete.length} old media files');
    } catch (e) {
      debugPrint('Error cleaning up old media: $e');
    }
  }
  
  // Obter estatísticas de mídia offline
  Map<String, int> getOfflineMediaStats() {
    if (_offlineMediaBox == null) {
      return {
        'total': 0,
        'pending': 0,
        'uploaded': 0,
        'errors': 0,
        'downloaded': 0,
      };
    }
    
    final allMedia = _offlineMediaBox!.values.toList();
    return {
      'total': allMedia.length,
      'pending': allMedia.where((m) => m.needsUpload && m.isLocallyCreated).length,
      'uploaded': allMedia.where((m) => m.isSynced).length,
      'errors': allMedia.where((m) => m.hasError && m.isLocallyCreated).length,
      'downloaded': allMedia.where((m) => m.isDownloadedFromCloud).length,
    };
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

  // Adicionado para o fluxo de download
  Future<OfflineMedia?> downloadAndCacheMedia({
    required String url,
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_offlineMediaBox == null || _processedMediaDir == null) {
        throw Exception('MediaService not initialized');
      }

      final mediaId = _uuid.v4();
      final fileName = path.basename(url.split('?').first);
      final localPath = path.join(_processedMediaDir!.path, fileName);
      final file = File(localPath);

      // Fazer o download do arquivo
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to download media: ${response.statusCode}');
      }

      final offlineMedia = OfflineMedia(
        id: mediaId,
        localPath: localPath,
        uploadUrl: url,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        type: _getMediaTypeFromUrl(url),
        fileName: fileName,
        createdAt: DateTime.now(),
        isProcessed: true,
        isUploaded: true, // Já está na nuvem
        isDownloadedFromCloud: true,
        metadata: metadata ?? {},
        fileSize: await file.length(),
      );

      await _offlineMediaBox!.put(mediaId, offlineMedia);
      debugPrint('MediaService.downloadAndCacheMedia: Downloaded and cached media $mediaId from $url');
      return offlineMedia;
    } catch (e) {
      debugPrint('MediaService.downloadAndCacheMedia: Error: $e');
      return null;
    }
  }

  String _getMediaTypeFromUrl(String url) {
    if (url.contains('.jpg') || url.contains('.jpeg') || url.contains('.png')) {
      return 'image';
    } else if (url.contains('.mp4') || url.contains('.mov')) {
      return 'video';
    }
    return 'file';
  }

  // Método auxiliar para buscar mídias offline do cache
  Future<List<OfflineMedia>> _getOfflineMediaForInspection(String inspectionId) async {
    try {
      final box = await Hive.openBox<OfflineMedia>('offline_media');
      return box.values.where((media) => media.inspectionId == inspectionId).toList();
    } catch (e) {
      debugPrint('Error getting offline media: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> allMedia = [];

    // Primeiro, buscar mídias offline do cache
    final offlineMediaList = await _getOfflineMediaForInspection(inspectionId);
    
    // Converter OfflineMedia para formato padrão
    debugPrint('MediaService.getAllMedia: Found ${offlineMediaList.length} offline media items');
    for (final offlineMedia in offlineMediaList) {
      final isNonConformity = offlineMedia.metadata?['is_non_conformity'] == true;
      debugPrint('MediaService.getAllMedia: Processing offline media ${offlineMedia.id}, isNC: $isNonConformity');
      
      allMedia.add({
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'url': offlineMedia.uploadUrl,
        'inspection_id': inspectionId,
        'topic_id': offlineMedia.topicId,
        'item_id': offlineMedia.itemId,
        'detail_id': offlineMedia.detailId,
        'topic_name': null, // Será preenchido depois
        'item_name': null,
        'detail_name': null,
        'is_non_conformity': isNonConformity,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'source': 'cache',
        'status': offlineMedia.isUploaded ? 'uploaded' : 
                  offlineMedia.isProcessed ? 'pending' : 'processing',
        'metadata': offlineMedia.metadata,
      });
    }

    for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
      final topic = inspection.topics![topicIndex];
      final topicId = topic['id'] ?? 'topic_$topicIndex';

      final topicMedia = List<Map<String, dynamic>>.from(topic['media'] ?? []);
      for (int mediaIndex = 0; mediaIndex < topicMedia.length; mediaIndex++) {
        final mediaItem = topicMedia[mediaIndex];
        final mediaId = mediaItem['id'] ?? 'topic_media_${topicId}_$mediaIndex';
        
        // Evitar duplicatas com mídias offline
        if (!allMedia.any((m) => m['id'] == mediaId)) {
          allMedia.add({
            ...mediaItem,
            'id': mediaId,
            'inspection_id': inspectionId,
            'topic_id': topicId,
            'topic_name': topic['name'],
            'item_id': null,
            'detail_id': null,
            'is_non_conformity': false,
            'source': 'inspection',
            'status': mediaItem['url'] != null ? 'uploaded' : 'local',
          });
        }
      }

      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final itemId = item['id'] ?? 'item_${topicIndex}_$itemIndex';

        final itemMedia = List<Map<String, dynamic>>.from(item['media'] ?? []);
        for (int mediaIndex = 0; mediaIndex < itemMedia.length; mediaIndex++) {
          final mediaItem = itemMedia[mediaIndex];
          final mediaId = mediaItem['id'] ?? 'item_media_${itemId}_$mediaIndex';
          
          // Evitar duplicatas com mídias offline
          if (!allMedia.any((m) => m['id'] == mediaId)) {
            allMedia.add({
              ...mediaItem,
              'id': mediaId,
              'inspection_id': inspectionId,
              'topic_id': topicId,
              'item_id': itemId,
              'detail_id': null,
              'topic_name': topic['name'],
              'item_name': item['name'],
              'is_non_conformity': false,
              'source': 'inspection',
              'status': mediaItem['url'] != null ? 'uploaded' : 'local',
            });
          }
        }

        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];
          final detailId = detail['id'] ?? 'detail_${topicIndex}_${itemIndex}_$detailIndex';
          
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          for (int mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
            final mediaItem = media[mediaIndex];
            final mediaId = mediaItem['id'] ?? 'media_${detailId}_$mediaIndex';
            
            // Evitar duplicatas com mídias offline
            if (!allMedia.any((m) => m['id'] == mediaId)) {
              allMedia.add({
                ...mediaItem,
                'id': mediaId,
                'inspection_id': inspectionId,
                'topic_id': topicId, 'item_id': itemId, 'detail_id': detailId,
                'topic_name': topic['name'], 'item_name': item['name'], 'detail_name': detail['name'],
                'is_non_conformity': false,
                'source': 'inspection',
                'status': mediaItem['url'] != null ? 'uploaded' : 'local',
              });
            }
          }

          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
            final nc = nonConformities[ncIndex];
            final ncId = nc['id'] ?? 'nc_${detailId}_$ncIndex';
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            for (int ncMediaIndex = 0; ncMediaIndex < ncMedia.length; ncMediaIndex++) {
              final mediaItem = ncMedia[ncMediaIndex];
              final mediaId = mediaItem['id'] ?? 'nc_media_${ncId}_$ncMediaIndex';
              
              // Evitar duplicatas com mídias offline
              if (!allMedia.any((m) => m['id'] == mediaId)) {
                allMedia.add({
                  ...mediaItem,
                  'id': mediaId,
                  'inspection_id': inspectionId,
                  'topic_id': topicId, 'item_id': itemId, 'detail_id': detailId,
                  'topic_name': topic['name'], 'item_name': item['name'], 'detail_name': detail['name'],
                  'is_non_conformity': true,
                  'source': 'inspection',
                  'status': mediaItem['url'] != null ? 'uploaded' : 'local',
                });
              }
            }
          }
        }
      }
    }

    // Preencher nomes das hierarquias para mídias offline
    for (final media in allMedia.where((m) => m['source'] == 'cache')) {
      _populateHierarchyNames(media, inspection);
    }

    return allMedia;
  }

  // Método auxiliar para preencher nomes das hierarquias
  void _populateHierarchyNames(Map<String, dynamic> media, Inspection inspection) {
    final topicId = media['topic_id'];
    final itemId = media['item_id'];
    final detailId = media['detail_id'];

    if (topicId != null && inspection.topics != null) {
      // Procurar tópico por ID real ou por índice
      Map<String, dynamic>? topic;
      for (int i = 0; i < inspection.topics!.length; i++) {
        final t = inspection.topics![i];
        final currentTopicId = t['id'] ?? 'topic_$i';
        if (currentTopicId == topicId) {
          topic = t;
          break;
        }
      }
      
      if (topic != null) {
        media['topic_name'] = topic['name'];

        if (itemId != null) {
          final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
          final item = items.firstWhere(
            (i) => (i['id'] ?? i.hashCode.toString()) == itemId,
            orElse: () => {},
          );
          media['item_name'] = item['name'];

          if (detailId != null) {
            final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
            final detail = details.firstWhere(
              (d) => (d['id'] ?? d.hashCode.toString()) == detailId,
              orElse: () => {},
            );
            media['detail_name'] = detail['name'];
          }
        }
      }
    }
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
    String? statusFilter, // 'uploaded', 'pending', 'local', 'processing'
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
      
      // 5. Filtro de Status
      if (statusFilter != null && media['status'] != statusFilter) return false;
      
      return true;
    }).toList();
  }

  // Método para obter o caminho de exibição da mídia (local ou remoto)
  String? getDisplayPath(Map<String, dynamic> media) {
    final localPath = media['localPath'] as String?;
    final url = media['url'] as String?;
    
    // Priorizar arquivo local se existir
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    
    // Fallback para URL se disponível
    if (url != null && url.isNotEmpty) {
      return url;
    }
    
    return null;
  }

  // Método para verificar se mídia está disponível para exibição
  bool isMediaAvailable(Map<String, dynamic> media) {
    return getDisplayPath(media) != null;
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

  Future<String> uploadCachedMedia({
    required String localPath,
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Cached media file not found at path: $localPath');
    }

    final fileExt = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'cached_${timestamp}_${_uuid.v4()}$fileExt';

    // Build hierarchical storage path following the same pattern as uploadMedia
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

    // Determine content type based on file extension
    String? contentType;
    final lowercasedExt = fileExt.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(lowercasedExt)) {
      contentType = 'image/${lowercasedExt.replaceAll('.', '')}';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(lowercasedExt)) {
      contentType = 'video/${lowercasedExt.replaceAll('.', '')}';
    }

    // Upload file to Firebase Storage
    final ref = _firebase.storage.ref().child(storagePath);
    SettableMetadata? metadata;
    if (contentType != null) {
      metadata = SettableMetadata(contentType: contentType);
    }

    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  // Public method to force update media URL in inspection document
  Future<void> forceUpdateMediaUrl(OfflineMedia offlineMedia) async {
    if (offlineMedia.uploadUrl != null && offlineMedia.uploadUrl!.isNotEmpty) {
      await _updateInspectionMediaUrl(offlineMedia, offlineMedia.uploadUrl!);
    }
  }

  // CRITICAL FIX: Update inspection document with uploaded media URL
  Future<void> _updateInspectionMediaUrl(OfflineMedia offlineMedia, String downloadUrl) async {
    try {
      final inspection = await _inspectionService.getInspection(offlineMedia.inspectionId);
      if (inspection?.topics == null) {
        debugPrint('MediaService._updateInspectionMediaUrl: Inspection not found');
        return;
      }

      debugPrint('MediaService._updateInspectionMediaUrl: Looking for media ${offlineMedia.id} in inspection ${offlineMedia.inspectionId}');
      debugPrint('  topicId: ${offlineMedia.topicId}, itemId: ${offlineMedia.itemId}, detailId: ${offlineMedia.detailId}');

      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      
      // Debug: Print actual inspection structure for the first few topics
      debugPrint('Actual inspection structure:');
      for (int i = 0; i < topics.length && i < 3; i++) {
        final topic = topics[i];
        debugPrint('  Topic $i: id=${topic['id']}, name=${topic['name']}');
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        for (int j = 0; j < items.length && j < 2; j++) {
          final item = items[j];
          debugPrint('    Item $j: id=${item['id']}, name=${item['name']}');
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          for (int k = 0; k < details.length && k < 2; k++) {
            final detail = details[k];
            debugPrint('      Detail $k: id=${detail['id']}, name=${detail['name']}');
          }
        }
      }
      
      bool updated = false;

      // Search for the media in the inspection hierarchy and update its URL
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        
        // Check topic-level media
        if (offlineMedia.topicId != null && topic['id'] == offlineMedia.topicId && 
            offlineMedia.itemId == null && offlineMedia.detailId == null) {
          final mediaList = List<Map<String, dynamic>>.from(topic['media'] ?? []);
          for (int i = 0; i < mediaList.length; i++) {
            if (mediaList[i]['id'] == offlineMedia.id) {
              mediaList[i]['url'] = downloadUrl;
              mediaList[i]['status'] = 'uploaded';
              updated = true;
              break;
            }
          }
          if (updated) {
            topic['media'] = mediaList;
            topics[topicIndex] = topic;
            break;
          }
        }

        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          
          // Check item-level media
          if (offlineMedia.itemId != null && item['id'] == offlineMedia.itemId && 
              offlineMedia.detailId == null) {
            final mediaList = List<Map<String, dynamic>>.from(item['media'] ?? []);
            for (int i = 0; i < mediaList.length; i++) {
              if (mediaList[i]['id'] == offlineMedia.id) {
                mediaList[i]['url'] = downloadUrl;
                mediaList[i]['status'] = 'uploaded';
                updated = true;
                break;
              }
            }
            if (updated) {
              item['media'] = mediaList;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;
              break;
            }
          }

          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            
            // Check detail-level media
            if (offlineMedia.detailId != null && detail['id'] == offlineMedia.detailId) {
              // Regular detail media
              final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
              for (int i = 0; i < mediaList.length; i++) {
                if (mediaList[i]['id'] == offlineMedia.id) {
                  mediaList[i]['url'] = downloadUrl;
                  mediaList[i]['status'] = 'uploaded';
                  updated = true;
                  break;
                }
              }
              if (updated) {
                detail['media'] = mediaList;
                details[detailIndex] = detail;
                item['details'] = details;
                items[itemIndex] = item;
                topic['items'] = items;
                topics[topicIndex] = topic;
                break;
              }

              // Check non-conformity media
              final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
              for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
                final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
                final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
                for (int i = 0; i < ncMedia.length; i++) {
                  if (ncMedia[i]['id'] == offlineMedia.id) {
                    ncMedia[i]['url'] = downloadUrl;
                    ncMedia[i]['status'] = 'uploaded';
                    updated = true;
                    break;
                  }
                }
                if (updated) {
                  nc['media'] = ncMedia;
                  nonConformities[ncIndex] = nc;
                  detail['non_conformities'] = nonConformities;
                  details[detailIndex] = detail;
                  item['details'] = details;
                  items[itemIndex] = item;
                  topic['items'] = items;
                  topics[topicIndex] = topic;
                  break;
                }
              }
              if (updated) break;
            }
          }
          if (updated) break;
        }
        if (updated) break;
      }

      if (updated) {
        final updatedInspection = inspection.copyWith(topics: topics);
        await _inspectionService.saveInspection(updatedInspection);
        debugPrint('MediaService._updateInspectionMediaUrl: Successfully updated inspection with URL for media ${offlineMedia.id}');
      } else {
        // Media not found in inspection - this means it was cached but never properly saved
        // Try to add it to the appropriate hierarchy level
        debugPrint('MediaService._updateInspectionMediaUrl: Media ${offlineMedia.id} not found in inspection hierarchy - attempting to add it');
        await _addMissingMediaToInspection(offlineMedia, downloadUrl, inspection);
      }
    } catch (e) {
      debugPrint('MediaService._updateInspectionMediaUrl: Error updating inspection: $e');
      // Don't rethrow - upload was successful, this is just metadata update
    }
  }

  // Add missing media to inspection document
  Future<void> _addMissingMediaToInspection(OfflineMedia offlineMedia, String downloadUrl, Inspection inspection) async {
    try {
      debugPrint('MediaService._addMissingMediaToInspection: Adding media ${offlineMedia.id} to inspection');
      
      // Create media data object
      final mediaData = {
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'url': downloadUrl,
        'fileName': offlineMedia.fileName,
        'aspect_ratio': '4:3',
        'source': offlineMedia.metadata?['source'] ?? 'camera',
        'is_non_conformity': offlineMedia.metadata?['is_non_conformity'] ?? false,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'status': 'uploaded',
        'metadata': offlineMedia.metadata ?? {},
      };

      final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
      
      // Try to extract index from index-based IDs as fallback
      int? targetTopicIndex, targetItemIndex, targetDetailIndex;
      if (offlineMedia.topicId?.startsWith('topic_') == true) {
        targetTopicIndex = int.tryParse(offlineMedia.topicId!.substring(6));
      }
      if (offlineMedia.itemId?.startsWith('item_') == true) {
        targetItemIndex = int.tryParse(offlineMedia.itemId!.substring(5));
      }
      if (offlineMedia.detailId?.startsWith('detail_') == true) {
        targetDetailIndex = int.tryParse(offlineMedia.detailId!.substring(7));
      }
      
      debugPrint('MediaService._addMissingMediaToInspection: Extracted indices - topic: $targetTopicIndex, item: $targetItemIndex, detail: $targetDetailIndex');

      // Use index-based fallback since ID matching failed
      if (targetDetailIndex != null && targetItemIndex != null && targetTopicIndex != null) {
        // Detail level media (including non-conformity)
        if (targetTopicIndex < topics.length) {
          final topic = Map<String, dynamic>.from(topics[targetTopicIndex]);
          final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
          if (targetItemIndex < items.length) {
            final item = Map<String, dynamic>.from(items[targetItemIndex]);
            final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
            if (targetDetailIndex < details.length) {
              final detail = Map<String, dynamic>.from(details[targetDetailIndex]);
              
              // Check if it's non-conformity media
              if (offlineMedia.metadata?['is_non_conformity'] == true) {
                final ncIndex = offlineMedia.metadata?['nc_index'] as int?;
                if (ncIndex != null) {
                  final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
                  if (ncIndex < nonConformities.length) {
                    final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
                    final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
                    ncMedia.add(mediaData);
                    nc['media'] = ncMedia;
                    nonConformities[ncIndex] = nc;
                    detail['non_conformities'] = nonConformities;
                    debugPrint('MediaService._addMissingMediaToInspection: Added media to NC index $ncIndex');
                  }
                }
              } else {
                // Regular detail media
                final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
                mediaList.add(mediaData);
                detail['media'] = mediaList;
                debugPrint('MediaService._addMissingMediaToInspection: Added media to detail level');
              }
              
              details[targetDetailIndex] = detail;
              item['details'] = details;
              items[targetItemIndex] = item;
              topic['items'] = items;
              topics[targetTopicIndex] = topic;
              
              final updatedInspection = inspection.copyWith(topics: topics);
              await _inspectionService.saveInspection(updatedInspection);
              debugPrint('MediaService._addMissingMediaToInspection: Successfully added media to detail level by index');
              return;
            }
          }
        }
      } else if (targetItemIndex != null && targetTopicIndex != null) {
        // Item level media
        if (targetTopicIndex < topics.length) {
          final topic = Map<String, dynamic>.from(topics[targetTopicIndex]);
          final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
          if (targetItemIndex < items.length) {
            final item = Map<String, dynamic>.from(items[targetItemIndex]);
            final mediaList = List<Map<String, dynamic>>.from(item['media'] ?? []);
            mediaList.add(mediaData);
            item['media'] = mediaList;
            items[targetItemIndex] = item;
            topic['items'] = items;
            topics[targetTopicIndex] = topic;
            
            final updatedInspection = inspection.copyWith(topics: topics);
            await _inspectionService.saveInspection(updatedInspection);
            debugPrint('MediaService._addMissingMediaToInspection: Successfully added media to item level by index');
            return;
          }
        }
      } else if (targetTopicIndex != null) {
        // Topic level media
        if (targetTopicIndex < topics.length) {
          final topic = Map<String, dynamic>.from(topics[targetTopicIndex]);
          final mediaList = List<Map<String, dynamic>>.from(topic['media'] ?? []);
          mediaList.add(mediaData);
          topic['media'] = mediaList;
          topics[targetTopicIndex] = topic;
          
          final updatedInspection = inspection.copyWith(topics: topics);
          await _inspectionService.saveInspection(updatedInspection);
          debugPrint('MediaService._addMissingMediaToInspection: Successfully added media to topic level by index');
          return;
        }
      }
      
      debugPrint('MediaService._addMissingMediaToInspection: Could not find appropriate hierarchy level for media ${offlineMedia.id} - indices out of bounds or invalid');
    } catch (e) {
      debugPrint('MediaService._addMissingMediaToInspection: Error adding media: $e');
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

  // Mover imagem entre tópicos, itens, detalhes ou não conformidades
  Future<bool> moveMedia({
    required String mediaId,
    String? newTopicId,
    String? newItemId,
    String? newDetailId,
    bool isNonConformity = false,
    String? nonConformityId,
  }) async {
    try {
      // Buscar mídia offline
      final offlineMedia = _offlineMediaBox?.get(mediaId);
      if (offlineMedia != null) {
        // Atualizar hierarquia
        offlineMedia.topicId = newTopicId;
        offlineMedia.itemId = newItemId;
        offlineMedia.detailId = newDetailId;
        
        // Atualizar metadata
        offlineMedia.metadata = {
          ...?offlineMedia.metadata,
          'is_non_conformity': isNonConformity,
          'non_conformity_id': nonConformityId,
        };
        
        await offlineMedia.save();
              debugPrint('MediaService.moveOfflineMedia: Moved media $mediaId to topic:${newTopicId ?? 'null'} item:${newItemId ?? 'null'} detail:${newDetailId ?? 'null'} NC:$isNonConformity');
        return true;
      }

      // Se não encontrou offline, buscar online via InspectionService
      final inspectionService = _inspectionService;
      final inspection = await inspectionService.getInspection(offlineMedia?.inspectionId ?? '');
      
      if (inspection?.topics != null) {
        return await _moveOnlineMedia(
          inspection!.topics!,
          mediaId,
          newTopicId,
          newItemId,
          newDetailId,
          isNonConformity,
          nonConformityId,
        );
      }
      
      return false;
    } catch (e) {
      debugPrint('MediaService.moveMedia: Error moving media $mediaId: $e');
      return false;
    }
  }

  // Mover mídia online na estrutura do Firestore
  Future<bool> _moveOnlineMedia(
    List<Map<String, dynamic>> topics,
    String mediaId,
    String? newTopicId,
    String? newItemId,
    String? newDetailId,
    bool isNonConformity,
    String? nonConformityId,
  ) async {
    try {
      Map<String, dynamic>? mediaToMove;
      List<dynamic>? sourceMediaList;
      
      // Procurar a mídia na estrutura hierárquica
      bool found = false;
      for (final topic in topics) {
        if (found) break;
        
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        for (final item in items) {
          if (found) break;
          
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          for (final detail in details) {
            if (found) break;
            
            // Verificar mídia em detalhes
            final detailMedia = List<Map<String, dynamic>>.from(detail['media'] ?? []);
            for (int i = 0; i < detailMedia.length; i++) {
              if (detailMedia[i]['id'] == mediaId) {
                mediaToMove = detailMedia[i];
                sourceMediaList = detailMedia;
                found = true;
                break;
              }
            }
            
            // Verificar mídia em não conformidades
            final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
            for (final nc in nonConformities) {
              final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
              for (int i = 0; i < ncMedia.length; i++) {
                if (ncMedia[i]['id'] == mediaId) {
                  mediaToMove = ncMedia[i];
                  sourceMediaList = ncMedia;
                  found = true;
                  break;
                }
              }
            }
          }
        }
      }
      
      if (mediaToMove == null || sourceMediaList == null) {
        debugPrint('MediaService._moveOnlineMedia: Media $mediaId not found');
        return false;
      }
      
      // Remover da posição original
      sourceMediaList.removeWhere((m) => m['id'] == mediaId);
      
      // Adicionar na nova posição
      return await _addMediaToDestination(
        topics,
        mediaToMove,
        newTopicId,
        newItemId,
        newDetailId,
        isNonConformity,
        nonConformityId,
      );
    } catch (e) {
      debugPrint('MediaService._moveOnlineMedia: Error: $e');
      return false;
    }
  }

  // Adicionar mídia no destino especificado
  Future<bool> _addMediaToDestination(
    List<Map<String, dynamic>> topics,
    Map<String, dynamic> media,
    String? topicId,
    String? itemId,
    String? detailId,
    bool isNonConformity,
    String? nonConformityId,
  ) async {
    try {
      // Encontrar o destino
      for (final topic in topics) {
        final currentTopicId = topic['id'];
        if (topicId == null || currentTopicId == topicId) {
          
          final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
          for (final item in items) {
            final currentItemId = item['id'];
            if (itemId == null || currentItemId == itemId) {
              
              final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
              for (final detail in details) {
                final currentDetailId = detail['id'];
                if (detailId == null || currentDetailId == detailId) {
                  
                  if (isNonConformity) {
                    // Adicionar em não conformidade
                    final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
                    
                    if (nonConformityId != null) {
                      // Mover para não conformidade específica
                      bool found = false;
                      for (final nc in nonConformities) {
                        if (nc['id'] == nonConformityId) {
                          final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
                          ncMedia.add(media);
                          nc['media'] = ncMedia;
                          found = true;
                          break;
                        }
                      }
                      if (!found) {
                        debugPrint('MediaService._addMediaToDestination: Não conformidade $nonConformityId não encontrada');
                        return false;
                      }
                    } else {
                      // Usar primeira não conformidade ou criar nova
                      if (nonConformities.isNotEmpty) {
                        final ncMedia = List<Map<String, dynamic>>.from(nonConformities[0]['media'] ?? []);
                        ncMedia.add(media);
                        nonConformities[0]['media'] = ncMedia;
                      } else {
                        // Criar nova não conformidade se não existir
                        nonConformities.add({
                          'id': 'nc_${DateTime.now().millisecondsSinceEpoch}',
                          'description': 'Não conformidade criada automaticamente',
                          'severity': 'Média',
                          'media': [media],
                          'is_resolved': false,
                        });
                      }
                    }
                    detail['non_conformities'] = nonConformities;
                  } else {
                    // Adicionar em mídia do detalhe
                    final detailMedia = List<Map<String, dynamic>>.from(detail['media'] ?? []);
                    detailMedia.add(media);
                    detail['media'] = detailMedia;
                  }
                  
                  debugPrint('MediaService._addMediaToDestination: Added media to topic:$topicId item:$itemId detail:$detailId NC:$isNonConformity');
                  return true;
                }
              }
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('MediaService._addMediaToDestination: Error: $e');
      return false;
    }
  }

  // Deletar imagem
  Future<bool> deleteMedia(String mediaId) async {
    try {
      // Buscar mídia offline
      final offlineMedia = _offlineMediaBox?.get(mediaId);
      if (offlineMedia != null) {
        // Deletar arquivo local
        final file = File(offlineMedia.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Deletar da nuvem se já foi enviado
        if (offlineMedia.isUploaded && offlineMedia.uploadUrl != null) {
          try {
            final ref = _firebase.storage.refFromURL(offlineMedia.uploadUrl!);
            await ref.delete();
          } catch (e) {
            debugPrint('MediaService.deleteMedia: Error deleting from cloud: $e');
          }
        }
        
        // Remover da estrutura da inspeção se necessário
        await _removeMediaFromInspection(offlineMedia);
        
        // Remover do cache
        await _offlineMediaBox?.delete(mediaId);
        debugPrint('MediaService.deleteMedia: Deleted offline media $mediaId');
        return true;
      }

      // Se não encontrou offline, buscar online na estrutura da inspeção
      return await _deleteOnlineMedia(mediaId);
      
    } catch (e) {
      debugPrint('MediaService.deleteMedia: Error deleting media $mediaId: $e');
      return false;
    }
  }

  // Remover mídia da estrutura da inspeção
  Future<void> _removeMediaFromInspection(OfflineMedia offlineMedia) async {
    try {
      final inspection = await _inspectionService.getInspection(offlineMedia.inspectionId);
      if (inspection?.topics == null) return;

      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      bool updated = false;

      // Procurar e remover a mídia da estrutura hierárquica
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        
        // Check topic-level media
        if (offlineMedia.topicId != null && topic['id'] == offlineMedia.topicId && 
            offlineMedia.itemId == null && offlineMedia.detailId == null) {
          final mediaList = List<Map<String, dynamic>>.from(topic['media'] ?? []);
          final originalLength = mediaList.length;
          mediaList.removeWhere((m) => m['id'] == offlineMedia.id);
          if (mediaList.length < originalLength) {
            topic['media'] = mediaList;
            topics[topicIndex] = topic;
            updated = true;
            break;
          }
        }

        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          
          // Check item-level media
          if (offlineMedia.itemId != null && item['id'] == offlineMedia.itemId && 
              offlineMedia.detailId == null) {
            final mediaList = List<Map<String, dynamic>>.from(item['media'] ?? []);
            final originalLength = mediaList.length;
            mediaList.removeWhere((m) => m['id'] == offlineMedia.id);
            if (mediaList.length < originalLength) {
              item['media'] = mediaList;
              items[itemIndex] = item;
              topic['items'] = items;
              topics[topicIndex] = topic;
              updated = true;
              break;
            }
          }

          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            
            // Check detail-level media
            if (offlineMedia.detailId != null && detail['id'] == offlineMedia.detailId) {
              // Regular detail media
              final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
              final originalLength = mediaList.length;
              mediaList.removeWhere((m) => m['id'] == offlineMedia.id);
              if (mediaList.length < originalLength) {
                detail['media'] = mediaList;
                details[detailIndex] = detail;
                item['details'] = details;
                items[itemIndex] = item;
                topic['items'] = items;
                topics[topicIndex] = topic;
                updated = true;
                break;
              }

              // Check non-conformity media
              final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
              for (int ncIndex = 0; ncIndex < nonConformities.length; ncIndex++) {
                final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
                final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
                final originalLength = ncMedia.length;
                ncMedia.removeWhere((m) => m['id'] == offlineMedia.id);
                if (ncMedia.length < originalLength) {
                  nc['media'] = ncMedia;
                  nonConformities[ncIndex] = nc;
                  detail['non_conformities'] = nonConformities;
                  details[detailIndex] = detail;
                  item['details'] = details;
                  items[itemIndex] = item;
                  topic['items'] = items;
                  topics[topicIndex] = topic;
                  updated = true;
                  break;
                }
              }
              if (updated) break;
            }
          }
          if (updated) break;
        }
        if (updated) break;
      }

      if (updated) {
        final updatedInspection = inspection.copyWith(topics: topics);
        await _inspectionService.saveInspection(updatedInspection);
        debugPrint('MediaService._removeMediaFromInspection: Successfully removed media ${offlineMedia.id} from inspection');
      }
    } catch (e) {
      debugPrint('MediaService._removeMediaFromInspection: Error: $e');
    }
  }

  // Deletar mídia online da estrutura da inspeção
  Future<bool> _deleteOnlineMedia(String mediaId) async {
    try {
      // Buscar em todas as inspeções (isso pode ser otimizado com índices)
      // Por enquanto, vamos buscar na inspeção atual se tivermos o contexto
      debugPrint('MediaService._deleteOnlineMedia: Looking for online media $mediaId');
      
      // Aqui seria necessário ter uma forma de identificar qual inspeção contém a mídia
      // Por enquanto, retornamos false para indicar que não conseguimos deletar
      return false;
      
    } catch (e) {
      debugPrint('MediaService._deleteOnlineMedia: Error: $e');
      return false;
    }
  }
}

  // Classes auxiliares para eventos de upload

class OfflineMediaUploadEvent {
  final String mediaId;
  final UploadStatus status;
  final String message;
  final String? downloadUrl;
  final double? progress;

  OfflineMediaUploadEvent({
    required this.mediaId,
    required this.status,
    required this.message,
    this.downloadUrl,
    this.progress,
  });
}

enum UploadStatus {
  processing,
  processed,
  uploading,
  completed,
  error,
}

// Métodos adicionais para integração completa com OfflineService
extension MediaServiceOfflineExtension on MediaService {
  
  /// Get offline media data as bytes for display
  Future<List<int>?> getOfflineMediaBytes(String mediaId) async {
    try {
      final media = _offlineMediaBox?.get(mediaId);
      if (media == null) return null;
      
      final file = File(media.localPath);
      if (!await file.exists()) return null;
      
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('MediaService.getOfflineMediaBytes: Error reading media $mediaId: $e');
      return null;
    }
  }
  
  /// Delete offline media completely (file + metadata)
  Future<bool> deleteOfflineMediaCompletely(String mediaId) async {
    try {
      final media = _offlineMediaBox?.get(mediaId);
      if (media == null) return false;
      
      // Delete local file
      final file = File(media.localPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from offline box
      await _offlineMediaBox?.delete(mediaId);
      
      // Remove from inspection structure if needed
      await _removeMediaFromInspection(media);
      
      debugPrint('MediaService.deleteOfflineMediaCompletely: Deleted offline media $mediaId completely');
      return true;
    } catch (e) {
      debugPrint('MediaService.deleteOfflineMediaCompletely: Error deleting $mediaId: $e');
      return false;
    }
  }
  
  /// Move offline media to new location
  Future<bool> moveOfflineMedia(String mediaId, String? newTopicId, String? newItemId, String? newDetailId) async {
    try {
      final media = _offlineMediaBox?.get(mediaId);
      if (media == null) return false;
      
      // Update media hierarchy
      media.topicId = newTopicId;
      media.itemId = newItemId;
      media.detailId = newDetailId;
      
      await media.save();
      
      debugPrint('MediaService.moveOfflineMedia: Moved media $mediaId to topic:$newTopicId item:$newItemId detail:$newDetailId');
      return true;
    } catch (e) {
      debugPrint('MediaService.moveOfflineMedia: Error moving $mediaId: $e');
      return false;
    }
  }
  
  /// Get all offline media for inspection with full metadata
  List<Map<String, dynamic>> getOfflineMediaForInspection(String inspectionId) {
    if (_offlineMediaBox == null) return [];
    
    return _offlineMediaBox!.values
        .where((media) => media.inspectionId == inspectionId)
        .map((media) => {
          'id': media.id,
          'type': media.type,
          'localPath': media.localPath,
          'fileName': media.fileName,
          'inspectionId': media.inspectionId,
          'topicId': media.topicId,
          'itemId': media.itemId,
          'detailId': media.detailId,
          'isProcessed': media.isProcessed,
          'isUploaded': media.isUploaded,
          'isDownloadedFromCloud': media.isDownloadedFromCloud,
          'isLocallyCreated': media.isLocallyCreated,
          'needsUpload': media.needsUpload,
          'createdAt': media.createdAt.toIso8601String(),
          'uploadUrl': media.uploadUrl,
          'cloudUrl': media.cloudUrl,
          'metadata': media.metadata,
          'status': media.isUploaded ? 'uploaded' : 
                   media.isProcessed ? 'pending' : 'processing',
        })
        .toList();
  }
  
  /// Check if media file exists locally
  bool isMediaAvailableLocally(String mediaId) {
    final media = _offlineMediaBox?.get(mediaId);
    if (media == null) return false;
    
    return File(media.localPath).existsSync();
  }
  
  /// Get local file path for media
  String? getLocalMediaPath(String mediaId) {
    final media = _offlineMediaBox?.get(mediaId);
    if (media == null) return null;
    
    final file = File(media.localPath);
    return file.existsSync() ? media.localPath : null;
  }
  
  /// Mark media for sync after offline modification
  Future<void> markMediaForSync(String mediaId) async {
    try {
      final media = _offlineMediaBox?.get(mediaId);
      if (media != null && media.isLocallyCreated) {
        // Mark as needing upload (clear any errors)
        media.errorMessage = null;
        await media.save();
        
        // OFFLINE-FIRST: No automatic restart, manual sync only
        debugPrint('MediaService.markMediaForSync: Media marked for sync, use manual sync to upload');
      }
    } catch (e) {
      debugPrint('MediaService.markMediaForSync: Error marking $mediaId for sync: $e');
    }
  }
  
  /// Get offline media statistics for inspection
  Map<String, int> getOfflineMediaStatsForInspection(String inspectionId) {
    if (_offlineMediaBox == null) {
      return {
        'total': 0,
        'downloaded': 0,
        'locallyCreated': 0,
        'uploaded': 0,
        'pending': 0,
        'errors': 0,
      };
    }
    
    final inspectionMedia = _offlineMediaBox!.values
        .where((media) => media.inspectionId == inspectionId)
        .toList();
    
    return {
      'total': inspectionMedia.length,
      'downloaded': inspectionMedia.where((m) => m.isDownloadedFromCloud).length,
      'locallyCreated': inspectionMedia.where((m) => m.isLocallyCreated).length,
      'uploaded': inspectionMedia.where((m) => m.isUploaded).length,
      'pending': inspectionMedia.where((m) => m.needsUpload).length,
      'errors': inspectionMedia.where((m) => m.hasError).length,
    };
  }
}
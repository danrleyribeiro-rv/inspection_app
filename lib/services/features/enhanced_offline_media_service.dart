import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/repositories/media_repository.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/services/media_counter_notifier.dart';

class EnhancedOfflineMediaService {
  static EnhancedOfflineMediaService? _instance;
  static EnhancedOfflineMediaService get instance =>
      _instance ??= EnhancedOfflineMediaService._();

  EnhancedOfflineMediaService._();

  late final MediaRepository _mediaRepository;
  late final FirestoreSyncService _syncService;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _mediaRepository = MediaRepository();
    _syncService = FirestoreSyncService.instance;

    _isInitialized = true;
    debugPrint('EnhancedOfflineMediaService: Initialized');
  }

  // ===============================
  // DIRETÓRIOS E ARMAZENAMENTO
  // ===============================

  Future<Directory> get _mediaDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'media'));

    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
      debugPrint('EnhancedOfflineMediaService: Created media directory: ${mediaDir.path}');
    }

    return mediaDir;
  }

  Future<Directory> get _thumbnailDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory(path.join(appDir.path, 'thumbnails'));

    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    return thumbnailDir;
  }

  // ===============================
  // CAPTURA DE MÍDIA
  // ===============================

  Future<OfflineMedia> capturePhoto({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    required XFile imageFile,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('EnhancedOfflineMediaService: capturePhoto called with:');
      debugPrint('  inspectionId: $inspectionId');
      debugPrint('  topicId: $topicId');
      debugPrint('  itemId: $itemId');
      debugPrint('  detailId: $detailId');
      debugPrint('  nonConformityId: $nonConformityId');
      
      final mediaDir = await _mediaDirectory;
      final filename = '${const Uuid().v4()}.jpg';
      final localPath = path.join(mediaDir.path, filename);

      // Copiar o arquivo para o diretório de mídia
      final file = File(imageFile.path);
      await file.copy(localPath);

      // Obter informações do arquivo
      final fileSize = await file.length();
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);

      // Pular GPS para salvamento instantâneo (será obtido de forma assíncrona)
      
      // Preparar metadata com localização
      final processedMetadata = <String, dynamic>{
        'source': metadata?['source'] ?? 'camera',
        'captured_at': DateTime.now().toIso8601String(),
        'location_status': 'processing', // GPS será capturado de forma assíncrona
        ...?metadata,
      };
      
      // GPS será capturado de forma assíncrona
      debugPrint('EnhancedOfflineMediaService: GPS location will be captured asynchronously');

      // Gerar thumbnail de forma assíncrona para não bloquear o salvamento
      String? thumbnailPath;
      
      // Salvar mídia primeiro, criar thumbnail depois
      debugPrint('EnhancedOfflineMediaService: Skipping thumbnail creation for immediate save');

      // Determinar source e isResolutionMedia
      final sourceValue = metadata?['source'] as String? ?? 'camera';
      final isResolutionMedia = sourceValue.contains('resolution');
      
      // Criar o objeto OfflineMedia com todos os dados
      final now = DateTime.now();
      final media = OfflineMedia(
        id: const Uuid().v4(),
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        type: 'image',
        localPath: localPath,
        filename: filename,
        fileSize: fileSize,
        mimeType: 'image/jpeg',
        width: image?.width,
        height: image?.height,
        thumbnailPath: thumbnailPath,
        isProcessed: true,
        isUploaded: false,
        needsSync: true,
        createdAt: now,
        updatedAt: now,
        capturedAt: now, // Set capturedAt for proper date/time display
        source: sourceValue,
        isResolutionMedia: isResolutionMedia, // Derivado automaticamente do source
        metadata: processedMetadata,
      );

      // Salvar no banco de dados IMEDIATAMENTE
      await _mediaRepository.insert(media);
      debugPrint('EnhancedOfflineMediaService: Media saved to database immediately');

      // Criar thumbnail E obter GPS de forma assíncrona (não bloqueia o retorno)
      Future.microtask(() async {
        try {
          // Thumbnail assíncrono
          debugPrint('EnhancedOfflineMediaService: Starting async thumbnail creation');
          final asyncThumbnailPath = await _createImageThumbnail(localPath);
          
          // GPS assíncrono
          debugPrint('EnhancedOfflineMediaService: ========== STARTING ASYNC GPS CAPTURE ==========');
          debugPrint('EnhancedOfflineMediaService: Media ID: ${media.id}');
          debugPrint('EnhancedOfflineMediaService: Media filename: ${media.filename}');
          
          final asyncPosition = await getCurrentLocation();
          
          // Preparar metadata atualizada
          Map<String, dynamic> updatedMetadata = Map.from(processedMetadata);
          if (asyncPosition != null) {
            final latitude = asyncPosition['latitude'];
            final longitude = asyncPosition['longitude'];
            final accuracy = asyncPosition['accuracy'] ?? 0.0;
            final capturedAt = DateTime.now().toIso8601String();
            
            updatedMetadata['location'] = {
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'captured_at': capturedAt,
            };
            updatedMetadata['location_status'] = 'captured';
            
            debugPrint('EnhancedOfflineMediaService: ========== GPS LOCATION SUCCESSFULLY CAPTURED ==========');
            debugPrint('EnhancedOfflineMediaService: Media ID: ${media.id}');
            debugPrint('EnhancedOfflineMediaService: Latitude: $latitude');
            debugPrint('EnhancedOfflineMediaService: Longitude: $longitude');
            debugPrint('EnhancedOfflineMediaService: Accuracy: ${accuracy}m');
            debugPrint('EnhancedOfflineMediaService: Captured at: $capturedAt');
            debugPrint('EnhancedOfflineMediaService: Location will be included in cloud upload metadata');
            debugPrint('EnhancedOfflineMediaService: ========== GPS CAPTURE COMPLETE ==========');
          } else {
            updatedMetadata['location_status'] = 'unavailable';
            debugPrint('EnhancedOfflineMediaService: ========== GPS LOCATION NOT AVAILABLE ==========');
            debugPrint('EnhancedOfflineMediaService: Media ID: ${media.id}');
            debugPrint('EnhancedOfflineMediaService: Reason: getCurrentLocation() returned null');
            debugPrint('EnhancedOfflineMediaService: Check permissions and device location settings');
            debugPrint('EnhancedOfflineMediaService: ========== GPS CAPTURE FAILED ==========');
          }
          
          // Atualizar mídia com thumbnail e GPS
          if (asyncThumbnailPath != null || asyncPosition != null) {
            final updatedMedia = media.copyWith(
              thumbnailPath: asyncThumbnailPath,
              metadata: updatedMetadata,
            );
            
            await _mediaRepository.update(updatedMedia);
          }
        } catch (e) {
          debugPrint('EnhancedOfflineMediaService: Error in async processing: $e');
        }
      });

      // Notificar contadores sobre nova mídia IMEDIATAMENTE
      MediaCounterNotifier.instance.notifyMediaAdded(
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
      );

      // Force extra notification after brief delay to ensure UI catches it
      Future.delayed(const Duration(milliseconds: 50), () {
        MediaCounterNotifier.instance.notifyMediaAdded(
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
        );
      });

      debugPrint('EnhancedOfflineMediaService: Captured photo ${media.id} successfully - thumbnail will be created async');

      return media;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error capturing photo: $e');
      rethrow;
    }
  }

  Future<OfflineMedia> captureVideo({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    required XFile videoFile,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final mediaDir = await _mediaDirectory;
      final filename = '${const Uuid().v4()}.mp4';
      final localPath = path.join(mediaDir.path, filename);

      // Copiar o arquivo para o diretório de mídia
      final file = File(videoFile.path);
      await file.copy(localPath);

      // Obter informações do arquivo
      final fileSize = await file.length();

      // Criar o objeto OfflineMedia
      final media = OfflineMedia.create(
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        type: 'video',
        localPath: localPath,
        filename: filename,
        fileSize: fileSize,
        mimeType: 'video/mp4',
        source: metadata?['source'] as String? ?? 'camera',
        metadata: metadata,
      );

      // Salvar no banco de dados
      await _mediaRepository.insert(media);

      debugPrint('EnhancedOfflineMediaService: Captured video ${media.id}');

      return media;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error capturing video: $e');
      rethrow;
    }
  }

  // ===============================
  // MÉTODOS AUXILIARES
  // ===============================

  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      debugPrint('EnhancedOfflineMediaService: ========== GPS LOCATION CAPTURE STARTED ==========');
      
      // Verificar se o serviço de localização está habilitado
      debugPrint('EnhancedOfflineMediaService: Checking if location service is enabled...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('EnhancedOfflineMediaService: ❌ Location service is disabled');
        debugPrint('EnhancedOfflineMediaService: Please enable location services in device settings');
        return null;
      }
      debugPrint('EnhancedOfflineMediaService: ✅ Location service is enabled');

      // Verificar permissões
      debugPrint('EnhancedOfflineMediaService: Checking location permissions...');
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('EnhancedOfflineMediaService: Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('EnhancedOfflineMediaService: Location permission denied, requesting permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('EnhancedOfflineMediaService: Permission request result: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('EnhancedOfflineMediaService: ❌ Location permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('EnhancedOfflineMediaService: ❌ Location permission permanently denied');
        debugPrint('EnhancedOfflineMediaService: Please enable location permission in app settings');
        return null;
      }

      debugPrint('EnhancedOfflineMediaService: ✅ Location permission granted: $permission');
      
      // Obter localização
      debugPrint('EnhancedOfflineMediaService: Getting current GPS position...');
      debugPrint('EnhancedOfflineMediaService: Using LocationAccuracy.best with 10 second timeout');
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      final latitude = position.latitude;
      final longitude = position.longitude;
      final accuracy = position.accuracy;
      final timestamp = position.timestamp;
      
      debugPrint('EnhancedOfflineMediaService: ========== GPS POSITION OBTAINED SUCCESSFULLY ==========');
      debugPrint('EnhancedOfflineMediaService: ✅ Latitude: $latitude');
      debugPrint('EnhancedOfflineMediaService: ✅ Longitude: $longitude');
      debugPrint('EnhancedOfflineMediaService: ✅ Accuracy: ${accuracy}m');
      debugPrint('EnhancedOfflineMediaService: ✅ Timestamp: $timestamp');
      debugPrint('EnhancedOfflineMediaService: GPS coordinates ready for metadata storage');
      debugPrint('EnhancedOfflineMediaService: ========== GPS CAPTURE SUCCESS ==========');
      
      return {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      };
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: ========== GPS CAPTURE ERROR ==========');
      debugPrint('EnhancedOfflineMediaService: ❌ Error getting location: $e');
      debugPrint('EnhancedOfflineMediaService: Error type: ${e.runtimeType}');
      debugPrint('EnhancedOfflineMediaService: This could be due to:');
      debugPrint('EnhancedOfflineMediaService: - Timeout (10 seconds)');
      debugPrint('EnhancedOfflineMediaService: - GPS signal not available');
      debugPrint('EnhancedOfflineMediaService: - Device location turned off');
      debugPrint('EnhancedOfflineMediaService: ========== GPS CAPTURE FAILED ==========');
      return null;
    }
  }

  Future<OfflineMedia> captureAndProcessMedia({
    required String inputPath,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    Map<String, dynamic>? metadata,
  }) async {
    final xFile = XFile(inputPath);

    if (type == 'image') {
      return await capturePhoto(
        imageFile: xFile,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        metadata: metadata,
      );
    } else {
      return await captureVideo(
        videoFile: xFile,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        metadata: metadata,
      );
    }
  }

  Future<OfflineMedia> importMedia({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    required String filePath,
    required String type,
    String source = 'gallery',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('EnhancedOfflineMediaService: importMedia called with:');
      debugPrint('  inspectionId: $inspectionId');
      debugPrint('  topicId: $topicId');
      debugPrint('  itemId: $itemId');
      debugPrint('  detailId: $detailId');
      debugPrint('  nonConformityId: $nonConformityId');
      debugPrint('  type: $type');
      debugPrint('  source: $source');
      
      final mediaDir = await _mediaDirectory;
      final originalFile = File(filePath);
      final extension = path.extension(filePath);
      final filename = '${const Uuid().v4()}$extension';
      final localPath = path.join(mediaDir.path, filename);

      // Copiar o arquivo para o diretório de mídia
      await originalFile.copy(localPath);

      // Obter informações do arquivo
      final fileSize = await originalFile.length();
      String mimeType = 'application/octet-stream';
      int? width, height, duration;

      // Obter localização GPS
      final position = await getCurrentLocation();
      
      // Preparar metadata com localização
      final processedMetadata = <String, dynamic>{
        'source': source,
        'imported_at': DateTime.now().toIso8601String(),
        ...?metadata,
      };
      
      if (position != null) {
        processedMetadata['location'] = {
          'latitude': position['latitude'],
          'longitude': position['longitude'],
          'accuracy': position['accuracy'] ?? 0.0,
          'captured_at': DateTime.now().toIso8601String(),
        };
        debugPrint('EnhancedOfflineMediaService: GPS location captured: ${position['latitude']}, ${position['longitude']}');
      } else {
        debugPrint('EnhancedOfflineMediaService: GPS location not available');
        processedMetadata['location_status'] = 'unavailable';
      }

      String? thumbnailPath;
      
      if (type == 'image') {
        mimeType = 'image/jpeg';
        try {
          final imageBytes = await originalFile.readAsBytes();
          final image = img.decodeImage(imageBytes);
          width = image?.width;
          height = image?.height;
          
          // Gerar thumbnail para imagem
          thumbnailPath = await _createImageThumbnail(localPath);
          debugPrint('EnhancedOfflineMediaService: Thumbnail created: $thumbnailPath');
        } catch (e) {
          debugPrint('Error decoding image: $e');
        }
      } else if (type == 'video') {
        mimeType = 'video/mp4';
        // Duration will be set later by processing
      }

      // Criar o objeto OfflineMedia com todos os dados
      final now = DateTime.now();
      final media = OfflineMedia(
        id: const Uuid().v4(),
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        type: type,
        localPath: localPath,
        filename: filename,
        fileSize: fileSize,
        mimeType: mimeType,
        width: width,
        height: height,
        duration: duration,
        thumbnailPath: thumbnailPath,
        isProcessed: true,
        isUploaded: false,
        needsSync: true,
        createdAt: now,
        updatedAt: now,
        capturedAt: now, // Set capturedAt for proper date/time display
        source: source,
        metadata: processedMetadata,
      );

      // Salvar no banco de dados
      await _mediaRepository.insert(media);

      // Notificar contadores sobre nova mídia IMEDIATAMENTE
      MediaCounterNotifier.instance.notifyMediaAdded(
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
      );

      // Force extra notification after brief delay to ensure UI catches it
      Future.delayed(const Duration(milliseconds: 50), () {
        MediaCounterNotifier.instance.notifyMediaAdded(
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
        );
      });

      debugPrint('EnhancedOfflineMediaService: Imported $type ${media.id} successfully with thumbnail: ${thumbnailPath != null ? 'YES' : 'NO'}');

      return media;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error importing media: $e');
      rethrow;
    }
  }

  // Método completo para captura e processamento de mídia
  Future<OfflineMedia> captureAndProcessMediaSimple({
    required String inputPath,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    String source = 'camera',
  }) async {
    try {
      await initialize();
      
      debugPrint('EnhancedOfflineMediaService: ========== STARTING MEDIA CAPTURE ==========');
      debugPrint('EnhancedOfflineMediaService: Input path: $inputPath');
      debugPrint('EnhancedOfflineMediaService: Type: $type');
      debugPrint('EnhancedOfflineMediaService: Source RECEIVED: $source');
      debugPrint('EnhancedOfflineMediaService: TopicId: $topicId');
      debugPrint('EnhancedOfflineMediaService: ItemId: $itemId');
      debugPrint('EnhancedOfflineMediaService: DetailId: $detailId');
      debugPrint('EnhancedOfflineMediaService: NonConformityId: $nonConformityId');
      
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Arquivo de entrada não encontrado: $inputPath');
      }

      final mediaDir = await _mediaDirectory;
      final mediaId = const Uuid().v4();
      final extension = path.extension(inputPath);
      final filename = '$mediaId$extension';
      final localPath = path.join(mediaDir.path, filename);

      debugPrint('EnhancedOfflineMediaService: Copying file to: $localPath');
      
      // Copiar arquivo para o diretório de mídia
      await inputFile.copy(localPath);
      
      // Verificar se o arquivo foi copiado corretamente
      final copiedFile = File(localPath);
      if (!await copiedFile.exists()) {
        throw Exception('Falha ao copiar arquivo para: $localPath');
      }

      // Obter informações do arquivo
      final fileSize = await copiedFile.length();
      int? width, height;
      String? thumbnailPath;
      
      debugPrint('EnhancedOfflineMediaService: File copied successfully, size: $fileSize bytes');

      // Processar imagem para obter dimensões e gerar thumbnail
      if (type == 'image') {
        try {
          debugPrint('EnhancedOfflineMediaService: Processing image for dimensions and thumbnail');
          final imageBytes = await copiedFile.readAsBytes();
          final image = img.decodeImage(imageBytes);
          
          if (image != null) {
            width = image.width;
            height = image.height;
            debugPrint('EnhancedOfflineMediaService: Image dimensions extracted: ${width}x$height');
            
            // Pular criação de thumbnail para salvamento rápido
            debugPrint('EnhancedOfflineMediaService: Skipping thumbnail for fast save');
          } else {
            debugPrint('EnhancedOfflineMediaService: Warning: Could not decode image');
          }
        } catch (e) {
          debugPrint('EnhancedOfflineMediaService: Error processing image: $e');
          // Continue without dimensions/thumbnail rather than failing completely
        }
      }

      // Pular GPS para salvamento instantâneo (será obtido de forma assíncrona)
      debugPrint('EnhancedOfflineMediaService: Skipping GPS for instant save');
      Map<String, dynamic> processedMetadata = {
        'source': source,
        'captured_at': DateTime.now().toIso8601String(),
        'processed_at': DateTime.now().toIso8601String(),
        'location_status': 'processing', // GPS será capturado de forma assíncrona
      };
      
      // GPS será capturado de forma assíncrona
      debugPrint('EnhancedOfflineMediaService: GPS location will be captured asynchronously for captureAndProcessMediaSimple');

      // Determinar automaticamente se é mídia de resolução baseado no source
      final isResolutionMedia = source.contains('resolution');
      
      debugPrint('EnhancedOfflineMediaService: ========== SOURCE ANALYSIS ==========');
      debugPrint('EnhancedOfflineMediaService: Original source: $source');
      debugPrint('EnhancedOfflineMediaService: Contains "resolution": ${source.contains('resolution')}');
      debugPrint('EnhancedOfflineMediaService: isResolutionMedia will be: $isResolutionMedia');
      debugPrint('EnhancedOfflineMediaService: Source being saved to metadata: ${processedMetadata['source']}');
      
      // Criar registro de mídia com dados completos
      final now = DateTime.now();
      final media = OfflineMedia(
        id: mediaId,
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        type: type,
        localPath: localPath,
        filename: filename,
        fileSize: fileSize,
        mimeType: type == 'image' ? 'image/jpeg' : 'video/mp4',
        width: width,
        height: height,
        thumbnailPath: thumbnailPath,
        isProcessed: true,
        isUploaded: false,
        needsSync: true,
        createdAt: now,
        updatedAt: now,
        capturedAt: now, // Set capturedAt for proper date/time display
        source: source,
        isResolutionMedia: isResolutionMedia, // Derivado automaticamente do source
        metadata: processedMetadata,
      );

      // Salvar no repositório IMEDIATAMENTE
      await _mediaRepository.insert(media);
      debugPrint('EnhancedOfflineMediaService: ========== MEDIA SAVED TO DATABASE ==========');
      debugPrint('EnhancedOfflineMediaService: Media ID: ${media.id}');
      debugPrint('EnhancedOfflineMediaService: Source saved: ${media.source}');
      debugPrint('EnhancedOfflineMediaService: isResolutionMedia saved: ${media.isResolutionMedia}');
      debugPrint('EnhancedOfflineMediaService: Type: ${media.type}');
      debugPrint('EnhancedOfflineMediaService: Filename: ${media.filename}');
      debugPrint('EnhancedOfflineMediaService: ========== SAVE COMPLETE ==========');
      
      // Criar thumbnail de forma assíncrona (não bloqueia o retorno)
      Future.microtask(() async {
        try {
          final asyncThumbnailPath = await _createImageThumbnail(localPath);
          if (asyncThumbnailPath != null) {
            // Atualizar mídia com thumbnail
            final updatedMedia = media.copyWith(thumbnailPath: asyncThumbnailPath);
            await _mediaRepository.update(updatedMedia);
            
            // Segunda notificação para atualizar UI com thumbnail
            MediaCounterNotifier.instance.notifyMediaAdded(
              inspectionId: inspectionId,
              topicId: topicId,
              itemId: itemId,
              detailId: detailId,
            );
          }
        } catch (e) {
          debugPrint('EnhancedOfflineMediaService: Error in async thumbnail creation: $e');
        }
      });
      
      // Notificar contadores sobre nova mídia IMEDIATAMENTE
      MediaCounterNotifier.instance.notifyMediaAdded(
        inspectionId: inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
      );

      // Force extra notification after brief delay to ensure UI catches it
      Future.delayed(const Duration(milliseconds: 50), () {
        MediaCounterNotifier.instance.notifyMediaAdded(
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailId: detailId,
        );
      });
      
      debugPrint('EnhancedOfflineMediaService: ===== MEDIA SAVED SUCCESSFULLY =====');
      debugPrint('  MediaId: $mediaId');
      debugPrint('  LocalPath: $localPath');
      debugPrint('  FileSize: $fileSize bytes');
      debugPrint('  Dimensions: ${width ?? 'null'}x${height ?? 'null'}');
      debugPrint('  ThumbnailPath: ${thumbnailPath ?? 'null'}');
      debugPrint('  Source: $source');
      debugPrint('  GPS Location: Will be captured asynchronously');
      debugPrint('  Metadata keys: ${processedMetadata.keys.join(', ')}');
      debugPrint('==================================================');

      return media;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: ERROR in captureAndProcessMediaSimple: $e');
      debugPrint('EnhancedOfflineMediaService: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<String> uploadProfileImage(String imagePath, String userId) async {
    try {
      final file = File(imagePath);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint(
          'EnhancedOfflineMediaService: Error uploading profile image: $e');
      rethrow;
    }
  }


  // ===============================
  // GERENCIAMENTO DE MÍDIA
  // ===============================

  Future<List<OfflineMedia>> getMediaByInspection(String inspectionId) async {
    return await _mediaRepository.findByInspectionId(inspectionId);
  }

  Future<List<OfflineMedia>> getMediaByContext({
    String? inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
  }) async {
    if (nonConformityId != null) {
      return await _mediaRepository.findByNonConformityId(nonConformityId);
    } else if (detailId != null) {
      return await _mediaRepository.findByDetailId(detailId);
    } else if (itemId != null) {
      return await _mediaRepository.findByItemId(itemId);
    } else if (topicId != null) {
      return await _mediaRepository.findByTopicId(topicId);
    } else if (inspectionId != null) {
      return await _mediaRepository.findByInspectionId(inspectionId);
    }

    return [];
  }

  Future<OfflineMedia?> getMedia(String mediaId) async {
    return await _mediaRepository.findById(mediaId);
  }

  Future<void> deleteMedia(String mediaId) async {
    final media = await _mediaRepository.findById(mediaId);
    if (media != null) {
      // Deletar arquivos físicos
      final file = File(media.localPath);
      if (await file.exists()) {
        await file.delete();
      }

      if (media.thumbnailPath != null) {
        final thumbnailFile = File(media.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }

      // Deletar do banco de dados (soft delete)
      await _mediaRepository.delete(mediaId);

      // Notificar contadores sobre mídia removida
      MediaCounterNotifier.instance.notifyMediaRemoved(
        inspectionId: media.inspectionId,
        topicId: media.topicId,
        itemId: media.itemId,
        detailId: media.detailId,
      );

      // Verify deletion
      final deletedMedia = await _mediaRepository.findById(mediaId);
      if (deletedMedia == null) {
        debugPrint('EnhancedOfflineMediaService: Verified - media $mediaId no longer found in active records');
      } else {
        debugPrint('EnhancedOfflineMediaService: Warning - media $mediaId still found after deletion');
      }

      debugPrint('EnhancedOfflineMediaService: Deleted media $mediaId');
    } else {
      debugPrint('EnhancedOfflineMediaService: Media $mediaId not found for deletion');
    }
  }

  Future<File?> getMediaFile(String mediaId) async {
    final media = await _mediaRepository.findById(mediaId);
    if (media != null) {
      final file = File(media.localPath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Future<File?> getThumbnailFile(String mediaId) async {
    final media = await _mediaRepository.findById(mediaId);
    if (media != null && media.thumbnailPath != null) {
      final file = File(media.thumbnailPath!);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Future<List<OfflineMedia>> getProcessedMedia() async {
    return await _mediaRepository.findProcessed();
  }

  Future<List<OfflineMedia>> getUnprocessedMedia() async {
    return await _mediaRepository.findUnprocessed();
  }

  Future<List<OfflineMedia>> getMediaPendingUpload() async {
    return await _mediaRepository.findPendingUpload();
  }

  Future<List<OfflineMedia>> getUploadedMedia() async {
    return await _mediaRepository.findUploaded();
  }

  // ===============================
  // FILTROS E BUSCA
  // ===============================

  Future<List<OfflineMedia>> getImagesByInspection(String inspectionId) async {
    return await _mediaRepository.findByInspectionIdAndType(
        inspectionId, 'image');
  }

  Future<List<OfflineMedia>> getVideosByInspection(String inspectionId) async {
    return await _mediaRepository.findByInspectionIdAndType(
        inspectionId, 'video');
  }

  Future<List<OfflineMedia>> searchMedia(String query) async {
    return await _mediaRepository.searchByFilename(query);
  }

  Future<List<OfflineMedia>> getMediaPaginated(
      String inspectionId, int page, int pageSize) async {
    final offset = page * pageSize;
    return await _mediaRepository.findByInspectionIdPaginated(
        inspectionId, pageSize, offset);
  }

  // ===============================
  // ESTATÍSTICAS
  // ===============================

  Future<Map<String, int>> getMediaStats(String inspectionId) async {
    return await _mediaRepository.getMediaStatsByInspectionId(inspectionId);
  }

  Future<double> getTotalMediaSize(String inspectionId) async {
    return await _mediaRepository.getTotalFileSizeByInspectionId(inspectionId);
  }

  Future<int> getMediaCount(String inspectionId) async {
    return await _mediaRepository.countByInspectionId(inspectionId);
  }

  Future<Map<String, dynamic>> getGlobalMediaStats() async {
    final allMedia = await _mediaRepository.findAll();
    final processed = await _mediaRepository.findProcessed();
    final uploaded = await _mediaRepository.findUploaded();
    final pendingUpload = await _mediaRepository.findPendingUpload();

    double totalSize = 0;
    for (final media in allMedia) {
      totalSize += media.fileSize?.toDouble() ?? 0;
    }

    return {
      'total': allMedia.length,
      'processed': processed.length,
      'uploaded': uploaded.length,
      'pending_upload': pendingUpload.length,
      'total_size': totalSize,
    };
  }

  // ===============================
  // SINCRONIZAÇÃO
  // ===============================

  Future<void> syncMedia() async {
    try {
      debugPrint('EnhancedOfflineMediaService: Starting media sync');

      if (await _syncService.isConnected()) {
        await _syncService.uploadLocalChangesToCloud();
        debugPrint('EnhancedOfflineMediaService: Media sync completed');
      } else {
        debugPrint(
            'EnhancedOfflineMediaService: No internet connection for sync');
      }
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error during media sync: $e');
    }
  }

  Future<void> syncMediaForInspection(String inspectionId) async {
    try {
      debugPrint(
          'EnhancedOfflineMediaService: Starting media sync for inspection $inspectionId');

      if (await _syncService.isConnected()) {
        // Obter mídias que precisam ser sincronizadas
        final mediaList =
            await _mediaRepository.findByInspectionId(inspectionId);
        final pendingSync = mediaList.where((m) => m.needsSync).toList();

        for (final media in pendingSync) {
          if (media.isProcessed && !media.isUploaded) {
            // Fazer upload da mídia
            // Este processo seria integrado com o FirestoreSyncService
            await _mediaRepository.markSynced(media.id);
          }
        }

        debugPrint(
            'EnhancedOfflineMediaService: Media sync completed for inspection $inspectionId');
      } else {
        debugPrint(
            'EnhancedOfflineMediaService: No internet connection for sync');
      }
    } catch (e) {
      debugPrint(
          'EnhancedOfflineMediaService: Error during media sync for inspection $inspectionId: $e');
    }
  }

  // ===============================
  // UTILITÁRIOS
  // ===============================

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool isImageFile(String filename) {
    final extension = path.extension(filename).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(extension);
  }

  bool isVideoFile(String filename) {
    final extension = path.extension(filename).toLowerCase();
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv']
        .contains(extension);
  }

  // ===============================
  // MOVER MÍDIA
  // ===============================

  Future<bool> moveMedia({
    required String mediaId,
    required String inspectionId,
    String? newTopicId,
    String? newItemId,
    String? newDetailId,
    String? newNonConformityId,
  }) async {
    try {
      final media = await _mediaRepository.findById(mediaId);
      if (media == null) {
        debugPrint('EnhancedOfflineMediaService: Media not found: $mediaId');
        return false;
      }

      // Notificar remoção da localização anterior
      MediaCounterNotifier.instance.notifyMediaRemoved(
        inspectionId: media.inspectionId,
        topicId: media.topicId,
        itemId: media.itemId,
        detailId: media.detailId,
      );

      // Determinar se a mídia deve manter o status isResolutionMedia
      bool shouldKeepResolutionStatus = media.isResolutionMedia;
      
      // Create updated media with new location
      // IMPORTANT: We need to explicitly handle null values for moving to higher levels
      final updatedMedia = OfflineMedia(
        id: media.id,
        inspectionId: media.inspectionId,
        topicId: newTopicId ?? media.topicId,
        itemId: newItemId, // This can be null for topic-level moves
        detailId: newDetailId, // This can be null for topic/item-level moves
        nonConformityId: newNonConformityId,
        type: media.type,
        localPath: media.localPath,
        cloudUrl: media.cloudUrl,
        filename: media.filename,
        fileSize: media.fileSize,
        mimeType: media.mimeType,
        thumbnailPath: media.thumbnailPath,
        duration: media.duration,
        width: media.width,
        height: media.height,
        isProcessed: media.isProcessed,
        isUploaded: media.isUploaded,
        uploadProgress: media.uploadProgress,
        createdAt: media.createdAt,
        updatedAt: DateTime.now(),
        needsSync: true,
        isDeleted: media.isDeleted,
        source: media.source,
        isResolutionMedia: shouldKeepResolutionStatus,
        metadata: media.metadata,
        capturedAt: media.capturedAt,
        latitude: media.latitude,
        longitude: media.longitude,
      );

      // Debug: Log the final media object
      debugPrint('EnhancedOfflineMediaService: Updated media object - topic=${updatedMedia.topicId}, item=${updatedMedia.itemId}, detail=${updatedMedia.detailId}');

      // Update in database
      await _mediaRepository.update(updatedMedia);

      // DEBUG: Verify the move was successful by re-querying the database
      final verifyMedia = await _mediaRepository.findById(mediaId);
      if (verifyMedia != null) {
        debugPrint('EnhancedOfflineMediaService: Verification - media after update: topic=${verifyMedia.topicId}, item=${verifyMedia.itemId}, detail=${verifyMedia.detailId}');
      } else {
        debugPrint('EnhancedOfflineMediaService: ERROR - Media not found after update!');
      }

      // Notificar adição na nova localização
      debugPrint('EnhancedOfflineMediaService: Notifying media addition to: topic=$newTopicId, item=$newItemId, detail=$newDetailId');
      MediaCounterNotifier.instance.notifyMediaAdded(
        inspectionId: inspectionId,
        topicId: newTopicId,
        itemId: newItemId,
        detailId: newDetailId,
      );

      debugPrint(
          'EnhancedOfflineMediaService: Media moved successfully: $mediaId');
      return true;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error moving media: $e');
      return false;
    }
  }

  // ===============================
  // GERAÇÃO DE THUMBNAILS
  // ===============================


  Future<String?> _createImageThumbnail(String imagePath) async {
    try {
      debugPrint('EnhancedOfflineMediaService: Starting thumbnail creation for: $imagePath');
      
      final thumbnailDir = await _thumbnailDirectory;
      final file = File(imagePath);
      
      if (!await file.exists()) {
        debugPrint('EnhancedOfflineMediaService: Source image file not found: $imagePath');
        return null;
      }
      
      debugPrint('EnhancedOfflineMediaService: Reading image bytes for thumbnail');
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image != null) {
        debugPrint('EnhancedOfflineMediaService: Image decoded successfully, original size: ${image.width}x${image.height}');
        
        // Criar thumbnail 200x150 (proporção 4:3) para consistência
        final thumbnail = img.copyResize(
          image, 
          width: 200, 
          height: 150,
          interpolation: img.Interpolation.linear,
        );
        
        debugPrint('EnhancedOfflineMediaService: Thumbnail resized to: ${thumbnail.width}x${thumbnail.height}');
        
        final thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);
        
        // Usar UUID para nome único do thumbnail
        final uuid = const Uuid().v4();
        final thumbnailName = '${uuid}_thumb.jpg';
        final thumbnailPath = path.join(thumbnailDir.path, thumbnailName);
        
        debugPrint('EnhancedOfflineMediaService: Writing thumbnail to: $thumbnailPath');
        await File(thumbnailPath).writeAsBytes(thumbnailBytes);
        
        // Verify thumbnail was created successfully
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          final thumbnailSize = await thumbnailFile.length();
          debugPrint('EnhancedOfflineMediaService: Thumbnail created successfully: $thumbnailPath ($thumbnailSize bytes)');
          return thumbnailPath;
        } else {
          debugPrint('EnhancedOfflineMediaService: Thumbnail file was not created at: $thumbnailPath');
          return null;
        }
      } else {
        debugPrint('EnhancedOfflineMediaService: Failed to decode image for thumbnail creation');
      }
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error creating thumbnail: $e');
      debugPrint('EnhancedOfflineMediaService: Thumbnail error stack trace: ${StackTrace.current}');
    }
    return null;
  }

  Future<Directory> getMediaDirectory() async {
    return await _mediaDirectory;
  }

  Future<Directory> getThumbnailDirectory() async {
    return await _thumbnailDirectory;
  }
}

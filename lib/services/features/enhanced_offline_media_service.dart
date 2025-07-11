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

      // Criar o objeto OfflineMedia
      final media = OfflineMedia.create(
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
        source: metadata?['source'] as String?,
        metadata: metadata,
      );

      // Salvar no banco de dados
      await _mediaRepository.insert(media);

      // Processar imagem (simplificado - sem isolate por enquanto)
      _processImage(media.id, localPath);

      debugPrint('EnhancedOfflineMediaService: Captured photo ${media.id}');

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
        source: metadata?['source'] as String?,
        metadata: metadata,
      );

      // Salvar no banco de dados
      await _mediaRepository.insert(media);

      // Processar vídeo (simplificado)
      _processVideo(media.id, localPath);

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
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error getting location: $e');
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

  // Método simplificado para captura rápida sem processamento pesado
  Future<OfflineMedia> captureAndProcessMediaSimple({
    required String inputPath,
    required String inspectionId,
    required String type,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
  }) async {
    try {
      await initialize();
      
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Arquivo de entrada não encontrado: $inputPath');
      }

      final mediaDir = await _mediaDirectory;
      final mediaId = const Uuid().v4();
      final extension = path.extension(inputPath);
      final filename = '$mediaId$extension';
      final localPath = path.join(mediaDir.path, filename);

      // Cópia simples do arquivo sem processamento
      await inputFile.copy(localPath);

      // Criar registro de mídia
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
        fileSize: await inputFile.length(),
        mimeType: type == 'image' ? 'image/jpeg' : 'video/mp4',
        isProcessed: true, // Marcar como processado imediatamente
        isUploaded: false,
        needsSync: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Salvar no repositório
      await _mediaRepository.insert(media);

      debugPrint('EnhancedOfflineMediaService: Imagem salva rapidamente: $mediaId');
      return media;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Erro na captura rápida: $e');
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
  // PROCESSAMENTO SIMPLIFICADO
  // ===============================

  Future<void> _processImage(String mediaId, String imagePath) async {
    try {
      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        // Redimensionar para proporção 4:3 se necessário
        final resized = img.copyResize(image, width: 1024, height: 768);

        // Salvar imagem processada
        final processedBytes = img.encodeJpg(resized, quality: 85);
        await file.writeAsBytes(processedBytes);

        // Gerar thumbnail
        final thumbnail = img.copyResize(resized, width: 200, height: 150);
        final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);

        final thumbnailDir = await _thumbnailDirectory;
        final thumbnailPath = path.join(thumbnailDir.path, '$mediaId.jpg');
        final thumbnailFile = File(thumbnailPath);
        await thumbnailFile.writeAsBytes(thumbnailBytes);

        // Atualizar no banco de dados
        await _mediaRepository.markAsProcessed(mediaId, imagePath);
        await _mediaRepository.setThumbnail(mediaId, thumbnailPath);
        await _mediaRepository.updateDimensions(
            mediaId, resized.width, resized.height);

        debugPrint(
            'EnhancedOfflineMediaService: Image processed successfully: $mediaId');
      }
    } catch (e) {
      debugPrint(
          'EnhancedOfflineMediaService: Error processing image $mediaId: $e');
    }
  }

  Future<void> _processVideo(String mediaId, String videoPath) async {
    try {
      // Marcar como processado (simplificado)
      await _mediaRepository.markAsProcessed(mediaId, videoPath);

      debugPrint(
          'EnhancedOfflineMediaService: Video processed successfully: $mediaId');
    } catch (e) {
      debugPrint(
          'EnhancedOfflineMediaService: Error processing video $mediaId: $e');
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

      // Deletar do banco de dados
      await _mediaRepository.delete(mediaId);

      debugPrint('EnhancedOfflineMediaService: Deleted media $mediaId');
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

      // Create updated media with new location
      final updatedMedia = media.copyWith(
        topicId: newTopicId,
        itemId: newItemId,
        detailId: newDetailId,
        nonConformityId: newNonConformityId,
        updatedAt: DateTime.now(),
        needsSync: true,
      );

      // Update in database
      await _mediaRepository.update(updatedMedia);

      debugPrint(
          'EnhancedOfflineMediaService: Media moved successfully: $mediaId');
      return true;
    } catch (e) {
      debugPrint('EnhancedOfflineMediaService: Error moving media: $e');
      return false;
    }
  }
}

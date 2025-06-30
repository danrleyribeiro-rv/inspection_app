import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/models/cached_inspection.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
class CacheService {
  static const String _inspectionsBoxName = 'inspections';
  static const String _offlineMediaBoxName = 'offline_media';
  final InspectionService _inspectionService = InspectionService();
  final Connectivity _connectivity = Connectivity();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CachedInspectionAdapter());
    Hive.registerAdapter(OfflineMediaAdapter());
    await Hive.openBox<CachedInspection>(_inspectionsBoxName);
    await Hive.openBox<OfflineMedia>(_offlineMediaBoxName);
  }

  Box<CachedInspection> get _inspectionsBox =>
      Hive.box<CachedInspection>(_inspectionsBoxName);
      
  Box<OfflineMedia> get _offlineMediaBox =>
      Hive.box<OfflineMedia>(_offlineMediaBoxName);

  Future<void> cacheInspection(String id, Map<String, dynamic> data) async {
    final cached = CachedInspection(
      id: id,
      data: data,
      lastUpdated: DateTime.now(),
      needsSync: false,
    );
    await _inspectionsBox.put(id, cached);
  }

  CachedInspection? getCachedInspection(String id) {
    return _inspectionsBox.get(id);
  }

  Future<void> markForSync(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = true;
      await cached.save();
    }
  }

  List<CachedInspection> getInspectionsNeedingSync() {
    return _inspectionsBox.values
        .where((inspection) => inspection.needsSync)
        .toList();
  }

  Future<void> markSynced(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> clearCache() async {
    await _inspectionsBox.clear();
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
  }

  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      if (await _isOnline()) {
        final inspection = await _inspectionService.getInspection(inspectionId);
        if (inspection != null) {
          await cacheInspection(inspectionId, inspection.toMap());
          return inspection;
        }
      }
      final cached = getCachedInspection(inspectionId);
      if (cached != null) {
        final inspectionData = Map<String, dynamic>.from(cached.data);
        return Inspection.fromMap({'id': cached.id, ...inspectionData});
      }

      return null;
    } catch (e) {
      debugPrint('Error getting inspection: $e');
      return null;
    }
  }

  Future<void> saveInspection(Inspection inspection) async {
    try {
      await cacheInspection(inspection.id, inspection.toMap());
      await markForSync(inspection.id);
      if (await _isOnline()) {
        try {
          await _inspectionService.saveInspection(inspection);
          await markSynced(inspection.id);
        } catch (e) {
          debugPrint('Error saving to Firebase: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving inspection: $e');
      rethrow;
    }
  }

  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      final inspection = await _inspectionService.getInspection(inspectionId);
      if (inspection?.topics != null) {
        return inspection!.topics!.asMap().entries.map((entry) {
          final index = entry.key;
          final topic = entry.value;
          return Topic(
            id: 'topic_$index',
            inspectionId: inspectionId,
            position: index,
            topicName: topic['name'] ?? 'Tópico ${index + 1}',
            topicLabel: topic['description'] ?? '',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting topics: $e');
      return [];
    }
  }

  // TODO: Refactor to use direct service calls instead of coordinator
  // This method should be called through InspectionCoordinator to avoid circular dependencies

  // TODO: Refactor to use direct service calls instead of coordinator
  // This method should be called through InspectionCoordinator to avoid circular dependencies

  // TODO: Refactor to use direct service calls instead of coordinator
  // This method should be called through InspectionCoordinator to avoid circular dependencies

  // TODO: Refactor to use direct service calls instead of coordinator
  // This method should be called through InspectionCoordinator to avoid circular dependencies

  // Métodos para gerenciamento de mídia offline
  Future<List<Map<String, dynamic>>> getPendingMediaForInspection(String inspectionId) async {
    try {
      final pendingMedia = _offlineMediaBox.values
          .where((media) => media.inspectionId == inspectionId && media.needsUpload)
          .toList();
      
      return pendingMedia.map((media) => {
        'id': media.id,
        'localPath': media.localPath,
        'inspectionId': media.inspectionId,
        'topicId': media.topicId,
        'itemId': media.itemId,
        'detailId': media.detailId,
        'type': media.type,
        'fileName': media.fileName,
        'createdAt': media.createdAt.toIso8601String(),
      }).toList();
    } catch (e) {
      debugPrint('Error getting pending media: $e');
      return [];
    }
  }

  Future<void> markMediaSynced(String mediaId) async {
    try {
      final media = _offlineMediaBox.get(mediaId);
      if (media != null) {
        media.isUploaded = true;
        await media.save();
      }
    } catch (e) {
      debugPrint('Error marking media as synced: $e');
    }
  }
  
  // Novos métodos para gerenciamento de mídia offline
  Future<void> addOfflineMedia(OfflineMedia media) async {
    try {
      await _offlineMediaBox.put(media.id, media);
    } catch (e) {
      debugPrint('Error adding offline media: $e');
    }
  }
  
  OfflineMedia? getOfflineMedia(String mediaId) {
    try {
      return _offlineMediaBox.get(mediaId);
    } catch (e) {
      debugPrint('Error getting offline media: $e');
      return null;
    }
  }
  
  List<OfflineMedia> getAllOfflineMediaForInspection(String inspectionId) {
    try {
      return _offlineMediaBox.values
          .where((media) => media.inspectionId == inspectionId)
          .toList();
    } catch (e) {
      debugPrint('Error getting offline media for inspection: $e');
      return [];
    }
  }
  
  List<OfflineMedia> getPendingOfflineMedia() {
    try {
      return _offlineMediaBox.values
          .where((media) => media.needsUpload)
          .toList();
    } catch (e) {
      debugPrint('Error getting pending offline media: $e');
      return [];
    }
  }
  
  Future<void> removeOfflineMedia(String mediaId) async {
    try {
      await _offlineMediaBox.delete(mediaId);
    } catch (e) {
      debugPrint('Error removing offline media: $e');
    }
  }
  
  Future<void> clearOfflineMedia() async {
    try {
      await _offlineMediaBox.clear();
    } catch (e) {
      debugPrint('Error clearing offline media: $e');
    }
  }

  // Método para verificar se uma inspeção específica está sincronizada
  bool isInspectionSynced(String inspectionId) {
    final cached = getCachedInspection(inspectionId);
    // Se não existe no cache, consideramos como sincronizado (não há mudanças locais)
    // Se existe no cache, verificamos se precisa sync
    return cached == null || cached.needsSync == false;
  }
  
  // Método para verificar se uma inspeção tem dados que precisam ser sincronizados
  bool hasUnsyncedData(String inspectionId) {
    final cached = getCachedInspection(inspectionId);
    return cached != null && cached.needsSync == true;
  }
  
  // Método para verificar se há dados mais recentes na nuvem
  Future<bool> hasNewerDataInCloud(String inspectionId) async {
    try {
      if (!(await _isOnline())) {
        return false; // Se offline, não há como verificar
      }
      
      final cached = getCachedInspection(inspectionId);
      if (cached == null) {
        return true; // Se não há cache local, pode haver dados na nuvem
      }
      
      // Busca dados básicos da nuvem (apenas metadados, não dados completos)
      final cloudInspection = await _inspectionService.getInspection(inspectionId);
      if (cloudInspection == null) {
        return false; // Não existe na nuvem
      }
      
      // Compara timestamps
      final cachedTime = cached.lastUpdated;
      final cloudTime = cloudInspection.updatedAt;
      
      // Retorna true se a nuvem tem dados mais recentes
      return cloudTime.isAfter(cachedTime);
    } catch (e) {
      debugPrint('Error checking cloud data: $e');
      return false;
    }
  }
  
  // Método para verificar se uma inspeção está disponível localmente
  bool isAvailableOffline(String inspectionId) {
    final cached = getCachedInspection(inspectionId);
    return cached != null;
  }
  
  // Método para obter o status de sincronização completo
  Future<SyncStatus> getSyncStatus(String inspectionId) async {
    final hasUnsynced = hasUnsyncedData(inspectionId);
    final hasNewer = await hasNewerDataInCloud(inspectionId);
    final isOffline = isAvailableOffline(inspectionId);
    final isOnline = await _isOnline();
    
    return SyncStatus(
      needsUpload: hasUnsynced,
      needsDownload: hasNewer,
      isAvailableOffline: isOffline,
      isOnline: isOnline,
    );
  }
}

// Classe para representar o status de sincronização
class SyncStatus {
  final bool needsUpload;
  final bool needsDownload;
  final bool isAvailableOffline;
  final bool isOnline;
  
  const SyncStatus({
    required this.needsUpload,
    required this.needsDownload,
    required this.isAvailableOffline,
    required this.isOnline,
  });
  
  bool get isSynced => !needsUpload && !needsDownload;
  bool get hasConflict => needsUpload && needsDownload;
}
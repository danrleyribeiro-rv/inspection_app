import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/cached_inspection.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
class CacheService {
  static const String _inspectionsBoxName = 'inspections';
  static const String _offlineMediaBoxName = 'offline_media';
  static const String _templatesBoxName = 'templates';
  final Connectivity _connectivity = Connectivity();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CachedInspectionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(OfflineMediaAdapter());
    }
    
    await Hive.openBox<CachedInspection>(_inspectionsBoxName);
    await Hive.openBox<OfflineMedia>(_offlineMediaBoxName);
    await Hive.openBox<Map>(_templatesBoxName);
  }

  Box<CachedInspection> get _inspectionsBox =>
      Hive.box<CachedInspection>(_inspectionsBoxName);
      
  Box<OfflineMedia> get _offlineMediaBox =>
      Hive.box<OfflineMedia>(_offlineMediaBoxName);
      
  Box<Map> get _templatesBox =>
      Hive.box<Map>(_templatesBoxName);

  Future<void> cacheInspection(String id, Map<String, dynamic> data, {bool isFromCloud = false}) async {
    final convertedData = _convertTimestampsToDateTimes(data);
    final safeData = ensureStringDynamicMap(convertedData);
    
    // Set appropriate local status based on context
    String localStatus = 'cloud_only';
    if (isFromCloud) {
      localStatus = 'downloaded'; // Downloaded for offline use
    }
    
    final cached = CachedInspection(
      id: id,
      data: safeData,
      lastUpdated: DateTime.now(),
      localStatus: localStatus,
      needsSync: false, // Downloaded from cloud or already synced
    );
    await _inspectionsBox.put(id, cached);
    
    if (isFromCloud) {
      debugPrint('CacheService.cacheInspection: Cached inspection $id from cloud for offline use (status: downloaded)');
    }
  }

  // Helper to convert Firestore Timestamps to Dart DateTimes for Hive storage
  Map<String, dynamic> _convertTimestampsToDateTimes(Map<String, dynamic> data) {
    final Map<String, dynamic> newData = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        newData[key] = value.toDate();
      } else if (value is Map) {
        newData[key] = _convertTimestampsToDateTimes(Map<String, dynamic>.from(value));
      } else if (value is List) {
        newData[key] = value.map((item) {
          if (item is Map) {
            return _convertTimestampsToDateTimes(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        newData[key] = value;
      }
    });
    return newData;
  }

  CachedInspection? getCachedInspection(String id) {
    return _inspectionsBox.get(id);
  }

  Future<void> markForSync(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = true;
      cached.lastUpdated = DateTime.now(); // Update timestamp for local modifications
      await cached.save();
      debugPrint('CacheService.markForSync: Marked inspection $id as needing sync (locally modified)');
    }
  }
  
  Future<void> markAsLocallyModified(String id, Map<String, dynamic> data) async {
    final cached = getCachedInspection(id);
    if (cached != null) {
      cached.data = ensureStringDynamicMap(data);
      cached.lastUpdated = DateTime.now();
      cached.localStatus = 'modified';
      cached.needsSync = true;
      await cached.save();
    } else {
      await cacheInspection(id, data, isFromCloud: false);
      await markForSync(id);
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
    try {
      final result = await _connectivity.checkConnectivity();
      final hasConnection = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
      
      if (!hasConnection) {
        return false;
      }
      
      // Double-check with a quick network test if we think we're online
      // This helps detect cases where device shows connectivity but can't reach internet
      try {
        final testResult = await _connectivity.checkConnectivity();
        return testResult.contains(ConnectivityResult.wifi) ||
            testResult.contains(ConnectivityResult.mobile);
      } catch (e) {
        debugPrint('CacheService._isOnline: Network test failed, assuming offline: $e');
        return false;
      }
    } catch (e) {
      debugPrint('CacheService._isOnline: Error checking connectivity, assuming offline: $e');
      return false;
    }
  }

  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      final cached = getCachedInspection(inspectionId);

      if (cached != null) {
        debugPrint('CacheService.getInspection: Returning cached inspection $inspectionId');
        try {
          final inspectionData = ensureStringDynamicMap(cached.data);
          final fullInspectionData = {'id': cached.id, ...inspectionData};
          return Inspection.fromMap(fullInspectionData);
        } catch (e) {
          debugPrint('CacheService.getInspection: Error converting cached data: $e');
          return null;
        }
      }

      debugPrint('CacheService.getInspection: No cached inspection found for $inspectionId');
      return null;
    } catch (e) {
      debugPrint('CacheService.getInspection: Error getting inspection $inspectionId: $e');
      return null;
    }
  }

  // Helper method to ensure Map<String, dynamic> type safety
  Map<String, dynamic> ensureStringDynamicMap(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        return data;
      } else if (data is Map) {
        // Handle CastMap and other Map types by iterating through entries
        final Map<String, dynamic> result = {};
        data.forEach((key, value) {
          final String stringKey = key.toString();
          dynamic convertedValue = value;
          
          // Recursively convert nested maps
          if (value is Map && value is! Map<String, dynamic>) {
            convertedValue = ensureStringDynamicMap(value);
          } else if (value is List) {
            // Handle lists that might contain maps
            convertedValue = value.map((item) {
              if (item is Map && item is! Map<String, dynamic>) {
                return ensureStringDynamicMap(item);
              }
              return item;
            }).toList();
          }
          
          result[stringKey] = convertedValue;
        });
        return result;
      } else {
        debugPrint('CacheService.ensureStringDynamicMap: Data is not a Map: ${data.runtimeType}');
        throw ArgumentError('Data is not a Map: ${data.runtimeType}');
      }
    } catch (e) {
      debugPrint('CacheService.ensureStringDynamicMap: Error converting data: $e');
      debugPrint('CacheService.ensureStringDynamicMap: Data type: ${data.runtimeType}');
      debugPrint('CacheService.ensureStringDynamicMap: Data content: $data');
      rethrow;
    }
  }


  // Removed _safeMapConversion - using _ensureStringDynamicMap instead

  Future<void> saveInspection(Inspection inspection) async {
    try {
      // OFFLINE-FIRST: Always save locally, never attempt cloud sync
      final cached = getCachedInspection(inspection.id);
      if (cached != null) {
        // Update existing cached inspection
        cached.data = ensureStringDynamicMap(inspection.toMap());
        cached.lastUpdated = DateTime.now();
        cached.localStatus = 'modified'; // Mark as modified for sync
        cached.needsSync = true;
        await cached.save();
        debugPrint('CacheService.saveInspection: Updated cached inspection ${inspection.id} (offline-first)');
      } else {
        // Create new cached inspection (shouldn't happen in normal flow)
        await cacheInspection(inspection.id, inspection.toMap(), isFromCloud: false);
        await markForSync(inspection.id);
        debugPrint('CacheService.saveInspection: Created new cached inspection ${inspection.id} (offline-first)');
      }
    } catch (e) {
      debugPrint('CacheService.saveInspection: Error saving inspection: $e');
      rethrow;
    }
  }

  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      final inspection = await getInspection(inspectionId);
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

  // Métodos para gerenciamento de mídia offline
  Future<List<Map<String, dynamic>>> getPendingMediaForInspection(String inspectionId) async {
    try {
      final pendingMedia = _offlineMediaBox.values
          .where((media) => media.inspectionId == inspectionId && media.needsUpload && media.isLocallyCreated)
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
          .where((media) => media.needsUpload && media.isLocallyCreated)
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
      final cloudInspection = await getInspection(inspectionId);
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
  
  // Método para obter todas as inspeções em cache
  List<CachedInspection> getAllCachedInspections() {
    try {
      return _inspectionsBox.values.toList();
    } catch (e) {
      debugPrint('Error getting all cached inspections: $e');
      return [];
    }
  }

  // Método para obter apenas as inspeções em cache do vistoriador logado
  List<CachedInspection> getCachedInspectionsForCurrentUser(String? currentUserId) {
    try {
      if (currentUserId == null) {
        debugPrint('CacheService.getCachedInspectionsForCurrentUser: No user ID provided');
        return [];
      }

      final allCached = _inspectionsBox.values.toList();
      final filteredInspections = allCached.where((cachedInspection) {
        try {
          // Ensure safe map conversion before accessing data
          final safeData = ensureStringDynamicMap(cachedInspection.data);
          final inspectorId = safeData['inspector_id'];
          return inspectorId == currentUserId;
        } catch (e) {
          debugPrint('CacheService.getCachedInspectionsForCurrentUser: Error checking inspector_id for ${cachedInspection.id}: $e');
          return false;
        }
      }).toList();

      debugPrint('CacheService.getCachedInspectionsForCurrentUser: Found ${filteredInspections.length} cached inspections for user $currentUserId');
      return filteredInspections;
    } catch (e) {
      debugPrint('CacheService.getCachedInspectionsForCurrentUser: Error: $e');
      return [];
    }
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

  Future<void> cacheTemplate(String templateId, Map<String, dynamic> templateData) async {
    try {
      final convertedData = _convertTimestampsToDateTimes(templateData);
      await _templatesBox.put(templateId, convertedData);
      debugPrint('CacheService.cacheTemplate: Cached template $templateId');
    } catch (e) {
      debugPrint('CacheService.cacheTemplate: Error caching template $templateId: $e');
    }
  }

  Map<String, dynamic>? getCachedTemplate(String templateId) {
    try {
      final cached = _templatesBox.get(templateId);
      if (cached != null) {
        return Map<String, dynamic>.from(cached);
      }
    } catch (e) {
      debugPrint('CacheService.getCachedTemplate: Error getting cached template $templateId: $e');
    }
    return null;
  }

  List<Map<String, dynamic>> getAllCachedTemplates() {
    try {
      return _templatesBox.values
          .map((template) => Map<String, dynamic>.from(template))
          .toList();
    } catch (e) {
      debugPrint('CacheService.getAllCachedTemplates: Error getting templates: $e');
      return [];
    }
  }

  Future<void> clearTemplateCache() async {
    try {
      await _templatesBox.clear();
      debugPrint('CacheService.clearTemplateCache: Template cache cleared');
    } catch (e) {
      debugPrint('CacheService.clearTemplateCache: Error clearing template cache: $e');
    }
  }

  bool hasTemplatesCached() {
    try {
      return _templatesBox.isNotEmpty;
    } catch (e) {
      debugPrint('CacheService.hasTemplatesCached: Error checking templates: $e');
      return false;
    }
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
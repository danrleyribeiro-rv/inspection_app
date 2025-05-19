import 'package:inspection_app/services/cache_service.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineInspectionService {
  final CacheService _cacheService = CacheService();
  final FirebaseInspectionService _firebaseService =
      FirebaseInspectionService();
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();

  // Initialize the service
  void initialize() {
    _syncService.initialize();
  }

  void dispose() {
    _syncService.dispose();
  }

  // Check if we're online
  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
  }

  // ======= INSPECTION METHODS =======

  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      // Try to get from Firebase first if online
      if (await _isOnline()) {
        final inspection = await _firebaseService.getInspection(inspectionId);
        if (inspection != null) {
          await _cacheService.cacheInspection(inspection);
          return inspection;
        }
      }

      // Fallback to cache
      final cached = _cacheService.getCachedInspection(inspectionId);
      if (cached != null) {
        return Inspection.fromMap({
          'id': cached.id,
          ...cached.data ?? {},
        });
      }

      return null;
    } catch (e) {
      print('Error getting inspection: $e');
      return null;
    }
  }

  // ======= TOPIC METHODS =======

  Future<List<Topic>> getTopics(String inspectionId) async {
    try {
      // Try to get from Firebase first if online
      if (await _isOnline()) {
        try {
          final topics = await _firebaseService.getTopics(inspectionId);

          // Cache the topics
          for (final topic in topics) {
            if (topic.id != null) {
              await _cacheService.cacheTopic(topic);
            }
          }

          return topics;
        } catch (e) {
          print('Error getting topics from Firebase: $e');
        }
      }

      // Fallback to cache
      final cachedTopics = _cacheService.getCachedTopics(inspectionId);
      return cachedTopics
          .map((cached) => _cacheService.cachedTopicToTopic(cached))
          .toList();
    } catch (e) {
      print('Error getting topics: $e');
      return [];
    }
  }

  Future<Topic> addTopic(
    String inspectionId,
    String topicName, {
    String? label,
    int? position,
    String? observation,
  }) async {
    try {
      // Create topic object
      final topic = Topic(
        id: null,
        inspectionId: inspectionId,
        topicName: topicName,
        topicLabel: label,
        position: position ?? 0,
        observation: observation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Try to save to Firebase if online
      if (await _isOnline()) {
        try {
          final firebaseTopic = await _firebaseService.addTopic(
            inspectionId,
            topicName,
            label: label,
            position: position,
            observation: observation,
          );

          // Cache with Firebase ID
          await _cacheService.cacheTopic(firebaseTopic);
          return firebaseTopic;
        } catch (e) {
          print('Error adding topic to Firebase: $e');
        }
      }

      // Save to cache (will be synced later)
      final cachedId = await _cacheService.cacheTopic(topic);
      return topic.copyWith(id: cachedId);
    } catch (e) {
      print('Error adding topic: $e');
      rethrow;
    }
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    try {
      // Try to update in Firebase if online
      if (await _isOnline() && updatedTopic.id != null) {
        try {
          await _firebaseService.updateTopic(updatedTopic);
        } catch (e) {
          print('Error updating topic in Firebase: $e');
        }
      }

      // Update in cache
      if (updatedTopic.id != null) {
        await _cacheService.updateCachedTopic(updatedTopic.id!, updatedTopic);
      }
    } catch (e) {
      print('Error updating topic: $e');
      rethrow;
    }
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    try {
      // Try to delete from Firebase if online
      if (await _isOnline()) {
        try {
          await _firebaseService.deleteTopic(inspectionId, topicId);
        } catch (e) {
          print('Error deleting topic from Firebase: $e');
        }
      }

      // Delete from cache
      await _cacheService.deleteCachedTopic(topicId);
    } catch (e) {
      print('Error deleting topic: $e');
      rethrow;
    }
  }

  // ======= ITEM METHODS =======

  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    try {
      // Try to get from Firebase first if online
      if (await _isOnline()) {
        try {
          final items = await _firebaseService.getItems(inspectionId, topicId);

          // Cache the items
          for (final item in items) {
            if (item.id != null) {
              await _cacheService.cacheItem(item);
            }
          }

          return items;
        } catch (e) {
          print('Error getting items from Firebase: $e');
        }
      }

      // Fallback to cache
      final cachedItems = _cacheService.getCachedItems(topicId);
      return cachedItems
          .map((cached) => _cacheService.cachedItemToItem(cached))
          .toList();
    } catch (e) {
      print('Error getting items: $e');
      return [];
    }
  }

  Future<Item> addItem(
    String inspectionId,
    String topicId,
    String itemName, {
    String? label,
    String? observation,
  }) async {
    try {
      // Get existing items to determine position
      final existingItems = await getItems(inspectionId, topicId);
      final newPosition =
          existingItems.isEmpty ? 0 : existingItems.last.position + 1;

      // Create item object
      final item = Item(
        id: null,
        topicId: topicId,
        inspectionId: inspectionId,
        itemName: itemName,
        itemLabel: label,
        observation: observation,
        position: newPosition,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Try to save to Firebase if online
      if (await _isOnline()) {
        try {
          final firebaseItem = await _firebaseService.addItem(
            inspectionId,
            topicId,
            itemName,
            label: label,
            observation: observation,
          );

          // Cache with Firebase ID
          await _cacheService.cacheItem(firebaseItem);
          return firebaseItem;
        } catch (e) {
          print('Error adding item to Firebase: $e');
        }
      }

      // Save to cache (will be synced later)
      final cachedId = await _cacheService.cacheItem(item);
      return item.copyWith(id: cachedId);
    } catch (e) {
      print('Error adding item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(Item updatedItem) async {
    try {
      // Try to update in Firebase if online
      if (await _isOnline() && updatedItem.id != null) {
        try {
          await _firebaseService.updateItem(updatedItem);
        } catch (e) {
          print('Error updating item in Firebase: $e');
        }
      }

      // Update in cache
      if (updatedItem.id != null) {
        await _cacheService.updateCachedItem(updatedItem.id!, updatedItem);
      }
    } catch (e) {
      print('Error updating item: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(
      String inspectionId, String topicId, String itemId) async {
    try {
      // Try to delete from Firebase if online
      if (await _isOnline()) {
        try {
          await _firebaseService.deleteItem(inspectionId, topicId, itemId);
        } catch (e) {
          print('Error deleting item from Firebase: $e');
        }
      }

      // Delete from cache
      await _cacheService.deleteCachedItem(itemId);
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  // ======= DETAIL METHODS =======

  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    try {
      // Try to get from Firebase first if online
      if (await _isOnline()) {
        try {
          final details =
              await _firebaseService.getDetails(inspectionId, topicId, itemId);

          // Cache the details
          for (final detail in details) {
            if (detail.id != null) {
              await _cacheService.cacheDetail(detail);
            }
          }

          return details;
        } catch (e) {
          print('Error getting details from Firebase: $e');
        }
      }

      // Fallback to cache
      final cachedDetails = _cacheService.getCachedDetails(itemId);
      return cachedDetails
          .map((cached) => _cacheService.cachedDetailToDetail(cached))
          .toList();
    } catch (e) {
      print('Error getting details: $e');
      return [];
    }
  }

  Future<Detail> addDetail(
    String inspectionId,
    String topicId,
    String itemId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
  }) async {
    try {
      // Get existing details to determine position
      final existingDetails = await getDetails(inspectionId, topicId, itemId);
      final newPosition = existingDetails.isEmpty
          ? 0
          : (existingDetails.last.position ?? 0) + 1;

      // Create detail object
      final detail = Detail(
        id: null,
        topicId: topicId,
        itemId: itemId,
        inspectionId: inspectionId,
        detailName: detailName,
        type: type ?? 'text',
        options: options,
        detailValue: detailValue,
        observation: observation,
        isDamaged: isDamaged ?? false,
        position: newPosition,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Try to save to Firebase if online
      if (await _isOnline()) {
        try {
          final firebaseDetail = await _firebaseService.addDetail(
            inspectionId,
            topicId,
            itemId,
            detailName,
            type: type,
            options: options,
            detailValue: detailValue,
            observation: observation,
            isDamaged: isDamaged,
          );

          // Cache with Firebase ID
          await _cacheService.cacheDetail(firebaseDetail);
          return firebaseDetail;
        } catch (e) {
          print('Error adding detail to Firebase: $e');
        }
      }

      // Save to cache (will be synced later)
      final cachedId = await _cacheService.cacheDetail(detail);
      return detail.copyWith(id: cachedId);
    } catch (e) {
      print('Error adding detail: $e');
      rethrow;
    }
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    try {
      // Try to update in Firebase if online
      if (await _isOnline() && updatedDetail.id != null) {
        try {
          await _firebaseService.updateDetail(updatedDetail);
        } catch (e) {
          print('Error updating detail in Firebase: $e');
        }
      }

      // Update in cache
      if (updatedDetail.id != null) {
        await _cacheService.updateCachedDetail(
            updatedDetail.id!, updatedDetail);
      }
    } catch (e) {
      print('Error updating detail: $e');
      rethrow;
    }
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId,
      String detailId) async {
    try {
      // Try to delete from Firebase if online
      if (await _isOnline()) {
        try {
          await _firebaseService.deleteDetail(
              inspectionId, topicId, itemId, detailId);
        } catch (e) {
          print('Error deleting detail from Firebase: $e');
        }
      }

      // Delete from cache
      await _cacheService.deleteCachedDetail(detailId);
    } catch (e) {
      print('Error deleting detail: $e');
      rethrow;
    }
  }

  // ======= MEDIA METHODS =======

  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    try {
      // Try to save to Firebase if online
      if (await _isOnline()) {
        try {
          await _firebaseService.saveMedia(mediaData);
        } catch (e) {
          print('Error saving media to Firebase: $e');
        }
      }

      // Save to cache (will be synced later)
      await _cacheService.cacheMedia(mediaData);
    } catch (e) {
      print('Error saving media: $e');
      rethrow;
    }
  }

  // ======= NON-CONFORMITY METHODS =======

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    try {
      // Try to save to Firebase if online
      if (await _isOnline()) {
        try {
          await _firebaseService.saveNonConformity(nonConformityData);
        } catch (e) {
          print('Error saving non-conformity to Firebase: $e');
        }
      }

      // Save to cache (will be synced later)
      await _cacheService.cacheNonConformity(nonConformityData);
    } catch (e) {
      print('Error saving non-conformity: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    // This method would need to be implemented to get from cache and Firebase
    // For now, delegate to Firebase service
    return await _firebaseService.getNonConformitiesByInspection(inspectionId);
  }

  // ======= DUPLICATE CHECK METHODS =======
  Future<Topic> isTopicDuplicate(String inspectionId, String topicName) async {
    if (await _isOnline()) {
      return await _firebaseService.isTopicDuplicate(inspectionId, topicName);
    }
    throw UnimplementedError(
        'Duplicate check not implemented for offline mode');
  }

  Future<Item> isItemDuplicate(
      String inspectionId, String topicId, String itemName) async {
    if (await _isOnline()) {
      return await _firebaseService.isItemDuplicate(
          inspectionId, topicId, itemName);
    }
    throw UnimplementedError(
        'Duplicate check not implemented for offline mode');
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId,
      String itemId, String detailName) async {
    if (await _isOnline()) {
      return await _firebaseService.isDetailDuplicate(
          inspectionId, topicId, itemId, detailName);
    }
    throw UnimplementedError(
        'Duplicate check not implemented for offline mode');
  }

  // ======= TEMPLATE METHODS =======
  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    if (await _isOnline()) {
      return await _firebaseService.isTemplateAlreadyApplied(inspectionId);
    }
    throw UnimplementedError('Template check not implemented for offline mode');
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    if (await _isOnline()) {
      return await _firebaseService.applyTemplateToInspectionSafe(
          inspectionId, templateId);
    }
    throw UnimplementedError(
        'Template application not implemented for offline mode');
  }

  Future<void> saveInspection(Inspection inspection) async {
    if (await _isOnline()) {
      await _firebaseService.saveInspection(inspection);
    }
    // Optionally, cache locally if needed
  }

  // ======= UTILITY METHODS =======

  Future<void> forceSyncAll() async {
    await _syncService.forceSyncAll();
  }

  bool hasPendingSync() {
    return _syncService.hasPendingSync();
  }
}

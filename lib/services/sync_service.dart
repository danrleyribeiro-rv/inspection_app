import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/cache_service.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncService {
  final CacheService _cacheService = CacheService();
  final FirebaseInspectionService _firebaseService = FirebaseInspectionService();
  final Connectivity _connectivity = Connectivity();
  
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result.contains(ConnectivityResult.wifi) || 
                      result.contains(ConnectivityResult.mobile);
      if (isOnline && !_isSyncing) {
        _syncAll();
      }
    });
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.contains(ConnectivityResult.wifi) || 
                      connectivityResult.contains(ConnectivityResult.mobile);

      if (!isOnline) {
        _isSyncing = false;
        return;
      }

      // Sync in order: topics -> items -> details -> media -> non-conformities
      await _syncTopics();
      await _syncItems();
      await _syncDetails();
      await _syncMedia();
      await _syncNonConformities();

    } catch (e) {
      print('Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTopics() async {
    final topicsToSync = _cacheService.getTopicsNeedingSync();
    
    for (final cachedTopic in topicsToSync) {
      try {
        final topic = _cacheService.cachedTopicToTopic(cachedTopic);
        
        // Check if topic already exists in Firebase
        final existingTopics = await _firebaseService.getTopics(topic.inspectionId);
        final existingTopic = existingTopics.firstWhere(
          (t) => t.topicName == topic.topicName && t.position == topic.position,
          orElse: () => Topic(
            id: null,
            inspectionId: topic.inspectionId,
            topicName: '',
            position: -1,
          ),
        );

        if (existingTopic.topicName.isNotEmpty) {
          // Topic already exists, update cache with Firebase ID and mark as synced
          cachedTopic.id = existingTopic.id!;
          await cachedTopic.save();
          await _cacheService.markTopicSynced(cachedTopic.id);
        } else {
          // Create new topic in Firebase
          final newTopic = await _firebaseService.addTopic(
            topic.inspectionId,
            topic.topicName,
            label: topic.topicLabel,
            position: topic.position,
            observation: topic.observation,
          );
          
          // Update cache with Firebase ID
          cachedTopic.id = newTopic.id!;
          await cachedTopic.save();
          await _cacheService.markTopicSynced(cachedTopic.id);
        }
      } catch (e) {
        print('Error syncing topic ${cachedTopic.id}: $e');
      }
    }
  }

  Future<void> _syncItems() async {
    final itemsToSync = _cacheService.getItemsNeedingSync();
    
    for (final cachedItem in itemsToSync) {
      try {
        final item = _cacheService.cachedItemToItem(cachedItem);
        
        // Check if item already exists in Firebase
        final existingItems = await _firebaseService.getItems(
          item.inspectionId, 
          item.topicId!
        );
        final existingItem = existingItems.firstWhere(
          (i) => i.itemName == item.itemName && i.position == item.position,
          orElse: () => Item(
            id: null,
            topicId: item.topicId,
            inspectionId: item.inspectionId,
            itemName: '',
            position: -1,
          ),
        );

        if (existingItem.itemName.isNotEmpty) {
          // Item already exists, update cache with Firebase ID and mark as synced
          cachedItem.id = existingItem.id!;
          await cachedItem.save();
          await _cacheService.markItemSynced(cachedItem.id);
        } else {
          // Create new item in Firebase
          final newItem = await _firebaseService.addItem(
            item.inspectionId,
            item.topicId!,
            item.itemName,
            label: item.itemLabel,
            observation: item.observation,
          );
          
          // Update cache with Firebase ID
          cachedItem.id = newItem.id!;
          await cachedItem.save();
          await _cacheService.markItemSynced(cachedItem.id);
        }
      } catch (e) {
        print('Error syncing item ${cachedItem.id}: $e');
      }
    }
  }

  Future<void> _syncDetails() async {
    final detailsToSync = _cacheService.getDetailsNeedingSync();
    
    for (final cachedDetail in detailsToSync) {
      try {
        final detail = _cacheService.cachedDetailToDetail(cachedDetail);
        
        // Check if detail already exists in Firebase
        final existingDetails = await _firebaseService.getDetails(
          detail.inspectionId,
          detail.topicId!,
          detail.itemId!,
        );
        final existingDetail = existingDetails.firstWhere(
          (d) => d.detailName == detail.detailName && 
                 (d.position ?? 0) == (detail.position ?? 0),
          orElse: () => Detail(
            id: null,
            itemId: detail.itemId,
            topicId: detail.topicId,
            inspectionId: detail.inspectionId,
            detailName: '',
            position: -1,
          ),
        );

        if (existingDetail.detailName.isNotEmpty) {
          // Detail already exists, update cache with Firebase ID and mark as synced
          cachedDetail.id = existingDetail.id!;
          await cachedDetail.save();
          await _cacheService.markDetailSynced(cachedDetail.id);
        } else {
          // Create new detail in Firebase
          final newDetail = await _firebaseService.addDetail(
            detail.inspectionId,
            detail.topicId!,
            detail.itemId!,
            detail.detailName,
            type: detail.type,
            options: detail.options,
            detailValue: detail.detailValue,
            observation: detail.observation,
            isDamaged: detail.isDamaged,
          );
          
          // Update cache with Firebase ID
          cachedDetail.id = newDetail.id!;
          await cachedDetail.save();
          await _cacheService.markDetailSynced(cachedDetail.id);
        }
      } catch (e) {
        print('Error syncing detail ${cachedDetail.id}: $e');
      }
    }
  }

  Future<void> _syncMedia() async {
    final mediaToSync = _cacheService.getMediaNeedingSync();
    
    for (final cachedMedia in mediaToSync) {
      try {
        final mediaData = {
          'id': cachedMedia.id,
          'type': cachedMedia.type,
          'localPath': cachedMedia.localPath,
          'url': cachedMedia.url,
          'is_non_conformity': cachedMedia.isNonConformity,
          'observation': cachedMedia.observation,
          'non_conformity_id': cachedMedia.nonConformityId,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        await _firebaseService.saveMedia({
          'inspection_id': cachedMedia.inspectionId,
          'topic_id': cachedMedia.topicId,
          'topic_item_id': cachedMedia.itemId,
          'detail_id': cachedMedia.detailId,
          ...mediaData,
        });
        
        await _cacheService.markMediaSynced(cachedMedia.id);
      } catch (e) {
        print('Error syncing media ${cachedMedia.id}: $e');
      }
    }
  }

  Future<void> _syncNonConformities() async {
    final nonConformitiesToSync = _cacheService.getNonConformitiesNeedingSync();
    
    for (final cachedNC in nonConformitiesToSync) {
      try {
        final ncData = {
          'inspection_id': cachedNC.inspectionId,
          'topic_id': cachedNC.topicId,
          'item_id': cachedNC.itemId,
          'detail_id': cachedNC.detailId,
          'description': cachedNC.description,
          'severity': cachedNC.severity,
          'corrective_action': cachedNC.correctiveAction,
          'deadline': cachedNC.deadline,
          'status': cachedNC.status,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        await _firebaseService.saveNonConformity(ncData);
        await _cacheService.markNonConformitySynced(cachedNC.id);
      } catch (e) {
        print('Error syncing non-conformity ${cachedNC.id}: $e');
      }
    }
  }

  // Force sync all pending items
  Future<void> forceSyncAll() async {
    await _syncAll();
  }

  // Check if there are items pending sync
  bool hasPendingSync() {
    return _cacheService.getTopicsNeedingSync().isNotEmpty ||
           _cacheService.getItemsNeedingSync().isNotEmpty ||
           _cacheService.getDetailsNeedingSync().isNotEmpty ||
           _cacheService.getMediaNeedingSync().isNotEmpty ||
           _cacheService.getNonConformitiesNeedingSync().isNotEmpty;
  }
}
// lib/services/coordinator/inspection_coordinator.dart
import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/data/topic_service.dart';
import 'package:inspection_app/services/data/item_service.dart';
import 'package:inspection_app/services/data/detail_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/features/template_service.dart';
import 'package:inspection_app/services/data/non_conformity_service.dart';
import 'package:inspection_app/services/download_service.dart';
import 'package:inspection_app/services/manual_sync_service.dart';

class InspectionCoordinator {
  final InspectionService _inspectionService = InspectionService();
  final TopicService _topicService = TopicService();
  final ItemService _itemService = ItemService();
  final DetailService _detailService = DetailService();
  final NonConformityService _nonConformityService = NonConformityService();
  final MediaService _mediaService = MediaService();
  final TemplateService _templateService = TemplateService();
  final DownloadService _downloadService = DownloadService();
  final ManualSyncService _syncService = ManualSyncService();

  // INSPECTION OPERATIONS
  Future<Inspection?> getInspection(String inspectionId) async {
    return await _inspectionService.getInspection(inspectionId);
  }

  Future<void> saveInspection(Inspection inspection) async {
    await _inspectionService.saveInspection(inspection);
  }

  // OFFLINE-FIRST OPERATIONS
  
  /// Baixa uma inspeção do servidor para edição offline
  Future<bool> downloadInspectionForOfflineEditing(String inspectionId, {Function(double)? onProgress}) async {
    debugPrint('InspectionCoordinator.downloadInspectionForOfflineEditing: Downloading inspection $inspectionId');
    final success = await _downloadService.downloadInspection(inspectionId, onProgress: onProgress);
    if (success) {
      debugPrint('InspectionCoordinator.downloadInspectionForOfflineEditing: Successfully downloaded inspection $inspectionId');
    } else {
      debugPrint('InspectionCoordinator.downloadInspectionForOfflineEditing: Failed to download inspection $inspectionId');
    }
    return success;
  }

  /// Sincroniza mudanças locais com a nuvem
  Future<bool> syncInspectionToCloud(String inspectionId, {Function(double)? onProgress}) async {
    debugPrint('InspectionCoordinator.syncInspectionToCloud: Syncing inspection $inspectionId to cloud');
    final success = await _syncService.syncInspection(inspectionId, onProgress: onProgress);
    if (success) {
      debugPrint('InspectionCoordinator.syncInspectionToCloud: Successfully synced inspection $inspectionId');
    } else {
      debugPrint('InspectionCoordinator.syncInspectionToCloud: Failed to sync inspection $inspectionId');
    }
    return success;
  }

  /// Verifica se uma inspeção está disponível para edição offline
  bool isInspectionAvailableOffline(String inspectionId) {
    return _inspectionService.isInspectionAvailable(inspectionId);
  }

  /// Verifica se uma inspeção precisa ser sincronizada
  bool doesInspectionNeedSync(String inspectionId) {
    return _inspectionService.needsSync(inspectionId);
  }

  /// Obtém o status de uma inspeção (local/cloud/synced)
  String? getInspectionStatus(String inspectionId) {
    return _inspectionService.getInspectionStatus(inspectionId);
  }

  /// Verifica conectividade para sincronização
  Future<bool> canSyncToCloud() async {
    return await _syncService.canSync();
  }

  /// Force refresh inspection data from Firestore (DEPRECATED)
  @Deprecated('Use downloadInspectionForOfflineEditing() instead')
  Future<void> refreshInspectionFromFirestore(String inspectionId) async {
    debugPrint('InspectionCoordinator.refreshInspectionFromFirestore: Method deprecated - use downloadInspectionForOfflineEditing instead');
    await downloadInspectionForOfflineEditing(inspectionId);
  }

  // TOPIC OPERATIONS
  Future<List<Topic>> getTopics(String inspectionId) async {
    return await _topicService.getTopics(inspectionId);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    return await _topicService.addTopic(inspectionId, topicName,
        label: label, position: position, observation: observation);
  }

  Future<Topic> addTopicFromTemplate(
      String inspectionId, Map<String, dynamic> templateData) async {
    return await _topicService.addTopicFromTemplate(inspectionId, templateData);
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    await _topicService.updateTopic(updatedTopic);
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    await _topicService.deleteTopic(inspectionId, topicId);
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    await _topicService.reorderTopics(inspectionId, topicIds);
  }

  Future<Topic> duplicateTopic(String inspectionId, Topic sourceTopic) async {
    return await _topicService.duplicateTopic(inspectionId, sourceTopic);
  }

  Future<double> getTopicProgress(String inspectionId, String topicId) async {
    return await _topicService.getTopicProgress(inspectionId, topicId);
  }

  // ITEM OPERATIONS
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    return await _itemService.getItems(inspectionId, topicId);
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? description, String? observation}) async {
    return await _itemService.addItem(inspectionId, topicId, itemName,
        description: description, observation: observation);
  }

  Future<void> updateItem(Item updatedItem) async {
    await _itemService.updateItem(updatedItem);
  }

  Future<void> deleteItem(
      String inspectionId, String topicId, String itemId) async {
    await _itemService.deleteItem(inspectionId, topicId, itemId);
  }

  Future<Item> duplicateItem(
      String inspectionId, String topicId, Item sourceItem) async {
    return await _itemService.duplicateItem(inspectionId, topicId, sourceItem);
  }

  Future<void> reorderItems(
      String inspectionId, String topicId, int oldIndex, int newIndex) async {
    await _itemService.reorderItems(inspectionId, topicId, oldIndex, newIndex);
  }

  Future<double> getItemProgress(
      String inspectionId, String topicId, String itemId) async {
    return await _itemService.getItemProgress(inspectionId, topicId, itemId);
  }

  // DETAIL OPERATIONS
  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    return await _detailService.getDetails(inspectionId, topicId, itemId);
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
    return await _detailService.addDetail(
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
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId,
      String detailId) async {
    await _detailService.deleteDetail(inspectionId, topicId, itemId, detailId);
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    await _detailService.updateDetail(updatedDetail);
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId,
      String itemId, String detailName) async {
    return await _detailService.isDetailDuplicate(
        inspectionId, topicId, itemId, detailName);
  }

  Future<Detail> duplicateDetail(String inspectionId, String topicId,
      String itemId, Detail sourceDetail) async {
    return await _detailService.duplicateDetail(
        inspectionId, topicId, itemId, sourceDetail);
  }

  Future<void> reorderDetails(String inspectionId, String topicId,
      String itemId, int oldIndex, int newIndex) async {
    await _detailService.reorderDetails(
        inspectionId, topicId, itemId, oldIndex, newIndex);
  }

  // NON-CONFORMITY OPERATIONS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    return await _nonConformityService
        .getNonConformitiesByInspection(inspectionId);
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    await _nonConformityService.saveNonConformity(nonConformityData);
  }

  Future<void> updateNonConformityStatus(
      String nonConformityId, String newStatus) async {
    await _nonConformityService.updateNonConformityStatus(
        nonConformityId, newStatus);
  }

  Future<void> updateNonConformity(
      String nonConformityId, Map<String, dynamic> updatedData) async {
    await _nonConformityService.updateNonConformity(
        nonConformityId, updatedData);
  }

  Future<void> deleteNonConformity(
      String nonConformityId, String inspectionId) async {
    await _nonConformityService.deleteNonConformity(
        nonConformityId, inspectionId);
  }

  Future<String> addNonConformityToTopic(String inspectionId, String topicId, Map<String, dynamic> ncData) async {
    return await _nonConformityService.addNonConformityToTopic(inspectionId, topicId, ncData);
  }

  Future<String> addNonConformityToItem(String inspectionId, String topicId, String itemId, Map<String, dynamic> ncData) async {
    return await _nonConformityService.addNonConformityToItem(inspectionId, topicId, itemId, ncData);
  }

  // MEDIA OPERATIONS
  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    return await _mediaService.getAllMedia(inspectionId);
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
    return _mediaService.filterMedia(
      allMedia: allMedia,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      isNonConformityOnly: isNonConformityOnly,
      mediaType: mediaType,
      topicOnly: topicOnly,
      itemOnly: itemOnly,
    );
  }

  // THE FIX: Métodos adicionados à classe correta
  Future<void> addMediaToTopic(String inspectionId, String topicId, Map<String, dynamic> mediaData) async {
    final inspection = await getInspection(inspectionId);
    if (inspection == null) return;

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    // Parse topic index from topicId format "topic_X"
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex == null || topicIndex >= topics.length) {
      debugPrint('InspectionCoordinator.addMediaToTopic: Invalid topic index $topicIndex for topicId $topicId');
      return;
    }

    final topic = Map<String, dynamic>.from(topics[topicIndex]);
    final mediaList = List<Map<String, dynamic>>.from(topic['media'] ?? []);
    mediaList.add(mediaData);
    topic['media'] = mediaList;
    topics[topicIndex] = topic;

    await saveInspection(inspection.copyWith(topics: topics));
  }

  Future<void> addMediaToItem(String inspectionId, String topicId, String itemId, Map<String, dynamic> mediaData) async {
    final inspection = await getInspection(inspectionId);
    if (inspection == null) return;

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    // Parse topic index from topicId format "topic_X"
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex == null || topicIndex >= topics.length) {
      debugPrint('InspectionCoordinator.addMediaToItem: Invalid topic index $topicIndex for topicId $topicId');
      return;
    }

    final topic = Map<String, dynamic>.from(topics[topicIndex]);
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
    // Parse item index from itemId format "item_X"
    final itemIndexStr = itemId.replaceFirst('item_', '');
    final itemIndex = int.tryParse(itemIndexStr);
    
    if (itemIndex == null || itemIndex >= items.length) {
      debugPrint('InspectionCoordinator.addMediaToItem: Invalid item index $itemIndex for itemId $itemId');
      return;
    }

    final item = Map<String, dynamic>.from(items[itemIndex]);
    final mediaList = List<Map<String, dynamic>>.from(item['media'] ?? []);
    mediaList.add(mediaData);
    item['media'] = mediaList;
    items[itemIndex] = item;
    topic['items'] = items;
    topics[topicIndex] = topic;

    await saveInspection(inspection.copyWith(topics: topics));
  }

  Future<void> addMediaToDetail(String inspectionId, String topicId, String itemId, String detailId, Map<String, dynamic> mediaData) async {
    debugPrint('InspectionCoordinator.addMediaToDetail: Adding media ${mediaData['id']} to detail $detailId');
    final inspection = await getInspection(inspectionId);
    if (inspection == null) {
      debugPrint('InspectionCoordinator.addMediaToDetail: Inspection not found');
      return;
    }

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    // Parse topic index from topicId format "topic_X"
    final topicIndexStr = topicId.replaceFirst('topic_', '');
    final topicIndex = int.tryParse(topicIndexStr);
    
    if (topicIndex == null || topicIndex >= topics.length) {
      debugPrint('InspectionCoordinator.addMediaToDetail: Invalid topic index $topicIndex for topicId $topicId, topics count: ${topics.length}');
      return;
    }

    final topic = Map<String, dynamic>.from(topics[topicIndex]);
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
    // Parse item index from itemId format "item_X"
    final itemIndexStr = itemId.replaceFirst('item_', '');
    final itemIndex = int.tryParse(itemIndexStr);
    
    if (itemIndex == null || itemIndex >= items.length) {
      debugPrint('InspectionCoordinator.addMediaToDetail: Invalid item index $itemIndex for itemId $itemId, items count: ${items.length}');
      return;
    }

    final item = Map<String, dynamic>.from(items[itemIndex]);
    final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
    // Parse detail index from detailId format "detail_X"
    final detailIndexStr = detailId.replaceFirst('detail_', '');
    final detailIndex = int.tryParse(detailIndexStr);
    
    if (detailIndex == null || detailIndex >= details.length) {
      debugPrint('InspectionCoordinator.addMediaToDetail: Invalid detail index $detailIndex for detailId $detailId, details count: ${details.length}');
      return;
    }

    final detail = Map<String, dynamic>.from(details[detailIndex]);
    final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
    mediaList.add(mediaData);
    detail['media'] = mediaList;
    details[detailIndex] = detail;
    item['details'] = details;
    items[itemIndex] = item;
    topic['items'] = items;
    topics[topicIndex] = topic;

    debugPrint('InspectionCoordinator.addMediaToDetail: Saving inspection with ${mediaList.length} media items');
    await saveInspection(inspection.copyWith(topics: topics));
    debugPrint('InspectionCoordinator.addMediaToDetail: Inspection saved successfully');
  }

  // TEMPLATE OPERATIONS
  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    return await _templateService.isTemplateAlreadyApplied(inspectionId);
  }

  Future<bool> applyTemplateToInspectionSafe(
      String inspectionId, String templateId) async {
    return await _templateService.applyTemplateToInspectionSafe(
        inspectionId, templateId);
  }

  Future<bool> applyTemplateToInspection(
      String inspectionId, String templateId) async {
    return await _templateService.applyTemplateToInspection(
        inspectionId, templateId);
  }

  // OFFLINE TEMPLATE SUPPORT
  Future<List<Map<String, dynamic>>> getAvailableTemplates() async {
    return await _templateService.getAvailableTemplates();
  }

  Future<List<Map<String, dynamic>>> getAvailableTopicsFromTemplates() async {
    return await _templateService.getAvailableTopicsFromTemplates();
  }

  Future<bool> applyTemplateToInspectionOfflineSafe(
      String inspectionId, String templateId) async {
    return await _templateService.applyTemplateToInspectionOfflineSafe(
        inspectionId, templateId);
  }

  // OFFLINE TOPIC TEMPLATE SUPPORT
  Future<List<Map<String, dynamic>>> getAvailableTemplateTopics() async {
    return await _topicService.getAvailableTemplateTopics();
  }

  Future<Topic> addTopicFromTemplateOffline(String inspectionId, Map<String, dynamic> topicTemplate) async {
    return await _topicService.addTopicFromTemplateOffline(inspectionId, topicTemplate);
  }

  // Get topics from a specific template
  Future<List<Map<String, dynamic>>> getTopicsFromSpecificTemplate(String templateId) async {
    return await _topicService.getTopicsFromSpecificTemplate(templateId);
  }

}
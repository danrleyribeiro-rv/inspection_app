import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:inspection_app/services/data/topic_data_service.dart';
import 'package:inspection_app/services/data/item_data_service.dart';
import 'package:inspection_app/services/data/detail_data_service.dart';
import 'package:inspection_app/services/data/media_data_service.dart';
import 'package:inspection_app/services/data/non_conformity_data_service.dart';
import 'package:inspection_app/services/data/template_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class InspectionServiceCoordinator {
  final InspectionDataService _inspectionService = InspectionDataService();
  final TopicDataService _topicService = TopicDataService();
  final ItemDataService _itemService = ItemDataService();
  final DetailDataService _detailService = DetailDataService();
  final MediaDataService _mediaService = MediaDataService();
  final NonConformityDataService _nonConformityService = NonConformityDataService();
  final TemplateService _templateService = TemplateService();

  // INSPECTION OPERATIONS
  Future<Inspection?> getInspection(String inspectionId) async {
    return await _inspectionService.getInspection(inspectionId);
  }

  Future<void> saveInspection(Inspection inspection) async {
    await _inspectionService.saveInspection(inspection);
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

  Future<void> updateTopic(Topic updatedTopic) async {
    await _topicService.updateTopic(updatedTopic);
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    await _topicService.deleteTopic(inspectionId, topicId);
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    await _topicService.reorderTopics(inspectionId, topicIds);
  }

  Future<Topic> duplicateTopic(String inspectionId, String topicName) async {
    return await _topicService.isTopicDuplicate(inspectionId, topicName);
  }

  // ITEM OPERATIONS
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    return await _itemService.getItems(inspectionId, topicId);
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    return await _itemService.addItem(inspectionId, topicId, itemName,
        label: label, observation: observation);
  }

  Future<void> updateItem(Item updatedItem) async {
    await _itemService.updateItem(updatedItem);
  }

  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    await _itemService.deleteItem(inspectionId, topicId, itemId);
  }

  Future<Item> duplicateItem(String inspectionId, String topicId, String itemName) async {
    return await _itemService.isItemDuplicate(inspectionId, topicId, itemName);
  }

  // DETAIL OPERATIONS
  Future<List<Detail>> getDetails(String inspectionId, String topicId, String itemId) async {
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

  Future<void> updateDetail(Detail updatedDetail) async {
    await _detailService.updateDetail(updatedDetail);
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
    await _detailService.deleteDetail(inspectionId, topicId, itemId, detailId);
  }

  Future<Detail?> duplicateDetail(String inspectionId, String topicId, String itemId, String detailName) async {
    return await _detailService.isDetailDuplicate(inspectionId, topicId, itemId, detailName);
  }

  // MEDIA OPERATIONS
  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId,
      {String? topicId, String? itemId, String? detailId, bool? isNonConformityOnly, String? mediaType}) async {
    return await _mediaService.getAllMedia(inspectionId,
        topicId: topicId, itemId: itemId, detailId: detailId,
        isNonConformityOnly: isNonConformityOnly, mediaType: mediaType);
  }

  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    await _mediaService.saveMedia(mediaData);
  }

  Future<void> updateMedia(String mediaId, Map<String, dynamic> originalData, Map<String, dynamic> updateData) async {
    await _mediaService.updateMedia(mediaId, originalData, updateData);
  }

  Future<void> deleteMedia(Map<String, dynamic> mediaData) async {
    await _mediaService.deleteMedia(mediaData);
  }

  List<Map<String, dynamic>> filterMedia({
    required List<Map<String, dynamic>> allMedia,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    return _mediaService.filterMedia(
      allMedia: allMedia,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      isNonConformityOnly: isNonConformityOnly,
      mediaType: mediaType,
    );
  }

  // NON-CONFORMITY OPERATIONS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    return await _nonConformityService.getNonConformitiesByInspection(inspectionId);
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    await _nonConformityService.saveNonConformity(nonConformityData);
  }

  Future<void> updateNonConformityStatus(String nonConformityId, String newStatus) async {
    await _nonConformityService.updateNonConformityStatus(nonConformityId, newStatus);
  }

  Future<void> updateNonConformity(String nonConformityId, Map<String, dynamic> updatedData) async {
    await _nonConformityService.updateNonConformity(nonConformityId, updatedData);
  }

  Future<void> deleteNonConformity(String nonConformityId, String inspectionId) async {
    await _nonConformityService.deleteNonConformity(nonConformityId, inspectionId);
  }

  // TEMPLATE OPERATIONS
  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    return await _templateService.isTemplateAlreadyApplied(inspectionId);
  }

  Future<bool> applyTemplateToInspectionSafe(String inspectionId, String templateId) async {
    return await _templateService.applyTemplateToInspectionSafe(inspectionId, templateId);
  }

  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    return await _templateService.applyTemplateToInspection(inspectionId, templateId);
  }
}
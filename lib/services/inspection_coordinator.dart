import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/inspection_checkpoint.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/data/inspection_service.dart';
import 'package:inspection_app/services/data/topic_service.dart';
import 'package:inspection_app/services/data/item_service.dart';
import 'package:inspection_app/services/data/detail_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/features/template_service.dart';
import 'package:inspection_app/services/features/checkpoint_service.dart';
import 'package:inspection_app/services/data/non_conformity_service.dart';


class InspectionCoordinator {
  final InspectionService _inspectionService = InspectionService();
  final TopicService _topicService = TopicService();
  final ItemService _itemService = ItemService();
  final DetailService _detailService = DetailService();
  final NonConformityService _nonConformityService = NonConformityService();
  final MediaService _mediaService = MediaService();
  final TemplateService _templateService = TemplateService();
  final CheckpointService _checkpointService = CheckpointService();

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
    return await _topicService.duplicateTopic(inspectionId, topicName);
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

  Future<Item?> isItemDuplicate(String inspectionId, String topicId, String itemName) async {
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

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
    await _detailService.deleteDetail(inspectionId, topicId, itemId, detailId);
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    await _detailService.updateDetail(updatedDetail);
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId, String itemId, String detailName) async {
    return await _detailService.isDetailDuplicate(inspectionId, topicId, itemId, detailName);
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

  // CHECKPOINT OPERATIONS
  Future<InspectionCheckpoint> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    return await _checkpointService.createCheckpoint(
      inspectionId: inspectionId,
      message: message,
    );
  }

  Future<List<InspectionCheckpoint>> getCheckpoints(String inspectionId) async {
    return await _checkpointService.getCheckpoints(inspectionId);
  }

  Future<bool> restoreCheckpoint(String inspectionId, String checkpointId) async {
    return await _checkpointService.restoreCheckpoint(inspectionId, checkpointId);
  }

  Future<Map<String, dynamic>> compareWithCheckpoint(String inspectionId, String checkpointId) async {
  return await _checkpointService.compareWithCheckpoint(inspectionId, checkpointId);
}
}
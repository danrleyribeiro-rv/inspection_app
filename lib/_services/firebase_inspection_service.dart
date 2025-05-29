import 'package:inspection_app/services/inspection_service_coordinator.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';

/// Legacy service that delegates to InspectionServiceCoordinator
class FirebaseInspectionService {
  final InspectionServiceCoordinator _coordinator = InspectionServiceCoordinator();

  // INSPECTION METHODS
  Future<Inspection?> getInspection(String inspectionId) async {
    return await _coordinator.getInspection(inspectionId);
  }

  Future<void> saveInspection(Inspection inspection) async {
    await _coordinator.saveInspection(inspection);
  }

  // TOPICS METHODS
  Future<List<Topic>> getTopics(String inspectionId) async {
    return await _coordinator.getTopics(inspectionId);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    return await _coordinator.addTopic(inspectionId, topicName,
        label: label, position: position, observation: observation);
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    await _coordinator.updateTopic(updatedTopic);
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    await _coordinator.deleteTopic(inspectionId, topicId);
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    await _coordinator.reorderTopics(inspectionId, topicIds);
  }

  Future<Topic> isTopicDuplicate(String inspectionId, String topicName) async {
    return await _coordinator.duplicateTopic(inspectionId, topicName);
  }

  // ITEMS METHODS
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    return await _coordinator.getItems(inspectionId, topicId);
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    return await _coordinator.addItem(inspectionId, topicId, itemName,
        label: label, observation: observation);
  }

  Future<void> updateItem(Item updatedItem) async {
    await _coordinator.updateItem(updatedItem);
  }

  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    await _coordinator.deleteItem(inspectionId, topicId, itemId);
  }

  Future<Item> isItemDuplicate(String inspectionId, String topicId, String itemName) async {
    return await _coordinator.duplicateItem(inspectionId, topicId, itemName);
  }

  // DETAILS METHODS
  Future<List<Detail>> getDetails(String inspectionId, String topicId, String itemId) async {
    return await _coordinator.getDetails(inspectionId, topicId, itemId);
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
    return await _coordinator.addDetail(
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
    await _coordinator.updateDetail(updatedDetail);
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
    await _coordinator.deleteDetail(inspectionId, topicId, itemId, detailId);
  }



  // NON-CONFORMITY METHODS
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    return await _coordinator.getNonConformitiesByInspection(inspectionId);
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    await _coordinator.saveNonConformity(nonConformityData);
  }

  Future<void> updateNonConformityStatus(String nonConformityId, String newStatus) async {
    await _coordinator.updateNonConformityStatus(nonConformityId, newStatus);
  }

  Future<void> updateNonConformity(String nonConformityId, Map<String, dynamic> updatedData) async {
    await _coordinator.updateNonConformity(nonConformityId, updatedData);
  }

  Future<void> deleteNonConformity(String nonConformityId, String inspectionId) async {
    await _coordinator.deleteNonConformity(nonConformityId, inspectionId);
  }

  // MEDIA METHODS
  Future<void> saveMedia(Map<String, dynamic> mediaData) async {
    await _coordinator.saveMedia(mediaData);
  }

  Future<void> deleteMedia(String mediaId, Map<String, dynamic> mediaData) async {
    await _coordinator.deleteMedia(mediaData);
  }

  Future<void> updateMedia(String mediaId, Map<String, dynamic> mediaData, Map<String, dynamic> updatedData) async {
    await _coordinator.updateMedia(mediaId, mediaData, updatedData);
  }

  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    return await _coordinator.getAllMedia(inspectionId);
  }

  // TEMPLATE APPLICATION
  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    return await _coordinator.applyTemplateToInspection(inspectionId, templateId);
  }

  Future<bool> isTemplateAlreadyApplied(String inspectionId) async {
    return await _coordinator.isTemplateAlreadyApplied(inspectionId);
  }

  Future<bool> applyTemplateToInspectionSafe(String inspectionId, String templateId) async {
    return await _coordinator.applyTemplateToInspectionSafe(inspectionId, templateId);
  }
}
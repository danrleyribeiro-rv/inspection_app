import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:inspection_app/services/data/media_data_service.dart';
import 'package:inspection_app/services/data/non_conformity_data_service.dart';
import 'package:inspection_app/services/data/template_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';

class InspectionServiceCoordinator {
 final InspectionDataService _inspectionService = InspectionDataService();
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
   return await _inspectionService.getTopics(inspectionId);
 }

 Future<Topic> addTopic(String inspectionId, String topicName,
     {String? label, int? position, String? observation}) async {
   return await _inspectionService.addTopic(inspectionId, topicName,
       label: label, position: position, observation: observation);
 }

 Future<void> updateTopic(Topic updatedTopic) async {
   await _inspectionService.updateTopic(updatedTopic);
 }

 Future<void> deleteTopic(String inspectionId, String topicId) async {
   await _inspectionService.deleteTopic(inspectionId, topicId);
 }

 Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
   await _inspectionService.reorderTopics(inspectionId, topicIds);
 }

 Future<Topic> duplicateTopic(String inspectionId, String topicName) async {
   return await _inspectionService.duplicateTopic(inspectionId, topicName);
 }

 // ITEM OPERATIONS
 Future<List<Item>> getItems(String inspectionId, String topicId) async {
   return await _inspectionService.getItems(inspectionId, topicId);
 }

 Future<Item> addItem(String inspectionId, String topicId, String itemName,
     {String? label, String? observation}) async {
   return await _inspectionService.addItem(inspectionId, topicId, itemName,
       label: label, observation: observation);
 }

 Future<void> updateItem(Item updatedItem) async {
   await _inspectionService.updateItem(updatedItem);
 }

 Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
   await _inspectionService.deleteItem(inspectionId, topicId, itemId);
 }

 Future<Item> duplicateItem(String inspectionId, String topicId, String itemName) async {
   return await _inspectionService.duplicateItem(inspectionId, topicId, itemName);
 }

 // DETAIL OPERATIONS
 Future<List<Detail>> getDetails(String inspectionId, String topicId, String itemId) async {
   return await _inspectionService.getDetails(inspectionId, topicId, itemId);
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
   return await _inspectionService.addDetail(
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
   await _inspectionService.updateDetail(updatedDetail);
 }

 Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
   await _inspectionService.deleteDetail(inspectionId, topicId, itemId, detailId);
 }

 Future<Detail?> duplicateDetail(String inspectionId, String topicId, String itemId, String detailName) async {
   return await _inspectionService.duplicateDetail(inspectionId, topicId, itemId, detailName);
 }

 // MEDIA OPERATIONS
 Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
   return await _mediaService.getAllMedia(inspectionId);
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
   return allMedia.where((media) {
     if (topicId != null && media['topic_id'] != topicId) return false;
     if (itemId != null && media['topic_item_id'] != itemId) return false;
     if (detailId != null && media['detail_id'] != detailId) return false;
     if (isNonConformityOnly == true && media['is_non_conformity'] != true) return false;
     if (mediaType != null && media['type'] != mediaType) return false;
     return true;
   }).toList();
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
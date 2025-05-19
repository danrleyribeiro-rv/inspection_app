import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';

class DetailDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final InspectionDataService _inspectionService = InspectionDataService();

  Future<List<Detail>> getDetails(String inspectionId, String topicId, String itemId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    
    if (inspection?.topics != null && topicIndex != null && itemIndex != null 
        && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final itemData = items[itemIndex];
        return _inspectionService.extractDetails(inspectionId, topicId, itemId, itemData);
      }
    }
    
    return [];
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
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    
    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }
    
    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition = existingDetails.length;

    final newDetailData = {
      'name': detailName,
      'type': type ?? 'text',
      'options': options,
      'value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged ?? false,
      'required': false,
      'media': <Map<String, dynamic>>[],
      'non_conformities': <Map<String, dynamic>>[],
    };

    await _inspectionService.addDetail(inspectionId, topicIndex, itemIndex, newDetailData);

    return Detail(
      id: 'detail_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
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
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    final topicIndex = int.tryParse(updatedDetail.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex = int.tryParse(updatedDetail.itemId?.replaceFirst('item_', '') ?? '');
    final detailIndex = int.tryParse(updatedDetail.id?.replaceFirst('detail_', '') ?? '');
    
    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      final inspection = await _inspectionService.getInspection(updatedDetail.inspectionId);
      if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = items[itemIndex];
          final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            final currentDetailData = Map<String, dynamic>.from(details[detailIndex]);
            currentDetailData['name'] = updatedDetail.detailName;
            currentDetailData['value'] = updatedDetail.detailValue;
            currentDetailData['observation'] = updatedDetail.observation;
            currentDetailData['is_damaged'] = updatedDetail.isDamaged ?? false;
            
            await _inspectionService.updateDetail(updatedDetail.inspectionId, topicIndex, itemIndex, detailIndex, currentDetailData);
          }
        }
      }
    }
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId, String detailId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));
    
    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      await _inspectionService.deleteDetail(inspectionId, topicIndex, itemIndex, detailIndex);
    }
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId, String itemId, String detailName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    
    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }
    
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        
        // Find the source detail
        Map<String, dynamic>? sourceDetailData;
        for (final detail in details) {
          if (detail['name'] == detailName) {
            sourceDetailData = Map<String, dynamic>.from(detail);
            break;
          }
        }
        
        if (sourceDetailData == null) {
          throw Exception('Source detail not found');
        }
        
        // Create duplicate
        final duplicateDetailData = Map<String, dynamic>.from(sourceDetailData);
        duplicateDetailData['name'] = '$detailName (copy)';
        duplicateDetailData['media'] = <Map<String, dynamic>>[];
        duplicateDetailData['non_conformities'] = <Map<String, dynamic>>[];
        
        await _inspectionService.addDetail(inspectionId, topicIndex, itemIndex, duplicateDetailData);
        
        List<String>? options;
        if (duplicateDetailData['options'] is List) {
          options = List<String>.from(duplicateDetailData['options']);
        }
        
        return Detail(
          id: 'detail_${details.length}',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: '$detailName (copy)',
          type: duplicateDetailData['type'] ?? 'text',
          options: options,
          detailValue: duplicateDetailData['value'],
          observation: duplicateDetailData['observation'],
          isDamaged: duplicateDetailData['is_damaged'] ?? false,
          position: details.length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }
    
    throw Exception('Item not found');
  }
}
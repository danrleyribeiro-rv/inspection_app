import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:inspection_app/services/data/media_data_service.dart';
import 'package:inspection_app/services/data/non_conformity_data_service.dart';
import 'package:inspection_app/services/data/template_service.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // TOPIC OPERATIONS (trabalham com estrutura aninhada)
  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    return _inspectionService.extractTopics(inspectionId, inspection?.topics);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final newTopicData = {
      'name': topicName,
      'description': label,
      'observation': observation,
      'items': <Map<String, dynamic>>[],
    };
    
    await _inspectionService.addTopic(inspectionId, newTopicData);
    
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topics = inspection?.topics ?? [];
    final newPosition = topics.length - 1;
    
    return Topic(
      id: 'topic_$newPosition',
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    final topicIndex = int.tryParse(updatedTopic.id?.replaceFirst('topic_', '') ?? '');
    if (topicIndex != null) {
      final inspection = await _inspectionService.getInspection(updatedTopic.inspectionId);
      if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
        final currentTopicData = Map<String, dynamic>.from(inspection.topics![topicIndex]);
        currentTopicData['name'] = updatedTopic.topicName;
        currentTopicData['description'] = updatedTopic.topicLabel;
        currentTopicData['observation'] = updatedTopic.observation;
        
        await _inspectionService.updateTopic(updatedTopic.inspectionId, topicIndex, currentTopicData);
      }
    }
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex != null) {
      await _inspectionService.deleteTopic(inspectionId, topicIndex);
    }
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection!.topics!);
      final reorderedTopics = <Map<String, dynamic>>[];
      
      for (final topicId in topicIds) {
        final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
        if (topicIndex != null && topicIndex < topics.length) {
          reorderedTopics.add(topics[topicIndex]);
        }
      }
      
      await _inspectionService.firestore.collection('inspections').doc(inspectionId).update({
        'topics': reorderedTopics,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Topic> duplicateTopic(String inspectionId, String topicName) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topics = inspection?.topics ?? [];
    
    Map<String, dynamic>? sourceTopicData;
    for (final topic in topics) {
      if (topic['name'] == topicName) {
        sourceTopicData = Map<String, dynamic>.from(topic);
        break;
      }
    }
    
    if (sourceTopicData == null) {
      throw Exception('Source topic not found');
    }
    
    final duplicateTopicData = Map<String, dynamic>.from(sourceTopicData);
    duplicateTopicData['name'] = '$topicName (copy)';
    
    await _inspectionService.addTopic(inspectionId, duplicateTopicData);
    
    return Topic(
      id: 'topic_${topics.length}',
      inspectionId: inspectionId,
      topicName: '$topicName (copy)',
      topicLabel: duplicateTopicData['description'],
      position: topics.length,
      observation: duplicateTopicData['observation'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ITEM OPERATIONS
  Future<List<Item>> getItems(String inspectionId, String topicId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    
    if (inspection?.topics != null && topicIndex != null && topicIndex < inspection!.topics!.length) {
      final topicData = inspection.topics![topicIndex];
      return _inspectionService.extractItems(inspectionId, topicId, topicData);
    }
    
    return [];
  }

  Future<Item> addItem(String inspectionId, String topicId, String itemName,
      {String? label, String? observation}) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');
    
    final existingItems = await getItems(inspectionId, topicId);
    final newPosition = existingItems.length;

    final newItemData = {
      'name': itemName,
      'description': label,
      'observation': observation,
      'details': <Map<String, dynamic>>[],
    };

    await _inspectionService.addItem(inspectionId, topicIndex, newItemData);

    return Item(
      id: 'item_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemName: itemName,
      itemLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateItem(Item updatedItem) async {
    final topicIndex = int.tryParse(updatedItem.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex = int.tryParse(updatedItem.id?.replaceFirst('item_', '') ?? '');
    
    if (topicIndex != null && itemIndex != null) {
      final inspection = await _inspectionService.getInspection(updatedItem.inspectionId);
      if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final currentItemData = Map<String, dynamic>.from(items[itemIndex]);
          currentItemData['name'] = updatedItem.itemName;
          currentItemData['description'] = updatedItem.itemLabel;
          currentItemData['observation'] = updatedItem.observation;
          
          await _inspectionService.updateItem(updatedItem.inspectionId, topicIndex, itemIndex, currentItemData);
        }
      }
    }
  }

  Future<void> deleteItem(String inspectionId, String topicId, String itemId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    
    if (topicIndex != null && itemIndex != null) {
      await _inspectionService.deleteItem(inspectionId, topicIndex, itemIndex);
    }
  }

  Future<Item> duplicateItem(String inspectionId, String topicId, String itemName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null) throw Exception('Invalid topic ID');
    
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      Map<String, dynamic>? sourceItemData;
      for (final item in items) {
        if (item['name'] == itemName) {
          sourceItemData = Map<String, dynamic>.from(item);
          break;
        }
      }
      
      if (sourceItemData == null) {
        throw Exception('Source item not found');
      }
      
      final duplicateItemData = Map<String, dynamic>.from(sourceItemData);
      duplicateItemData['name'] = '$itemName (copy)';
      
      await _inspectionService.addItem(inspectionId, topicIndex, duplicateItemData);
      
      return Item(
        id: 'item_${items.length}',
        inspectionId: inspectionId,
        topicId: topicId,
        itemName: '$itemName (copy)',
        itemLabel: duplicateItemData['description'],
        position: items.length,
        observation: duplicateItemData['observation'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    throw Exception('Topic not found');
  }

  // DETAIL OPERATIONS
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

  Future<Detail?> duplicateDetail(String inspectionId, String topicId, String itemId, String detailName) async {
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

  // MEDIA OPERATIONS
  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId,
      {String? topicId, String? itemId, String? detailId, bool? isNonConformityOnly, String? mediaType}) async {
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
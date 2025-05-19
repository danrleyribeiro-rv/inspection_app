import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';
import 'package:uuid/uuid.dart';

class NonConformityDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final InspectionDataService _inspectionService = InspectionDataService();
  final Uuid _uuid = Uuid();

  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics == null) return [];
    
    List<Map<String, dynamic>> nonConformities = [];
    
    for (int topicIndex = 0; topicIndex < inspection!.topics!.length; topicIndex++) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        
        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];
          final ncList = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          
          for (int ncIndex = 0; ncIndex < ncList.length; ncIndex++) {
            final nc = ncList[ncIndex];
            
            nonConformities.add({
              ...nc,
              'id': 'nc_$ncIndex',
              'inspection_id': inspectionId,
              'topic_id': 'topic_$topicIndex',
              'item_id': 'item_$itemIndex',
              'detail_id': 'detail_$detailIndex',
              'topics': {
                'topic_name': topic['name'],
                'id': 'topic_$topicIndex',
              },
              'topic_items': {
                'item_name': item['name'],
                'id': 'item_$itemIndex',
              },
              'item_details': {
                'detail_name': detail['name'],
                'id': 'detail_$detailIndex',
              },
            });
          }
        }
      }
    }
    
    return nonConformities;
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    final inspectionId = nonConformityData['inspection_id'];
    final topicId = nonConformityData['topic_id'];
    final itemId = nonConformityData['item_id'];
    final detailId = nonConformityData['detail_id'];

    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));

    if (topicIndex == null || itemIndex == null || detailIndex == null) {
      throw Exception('Invalid topic, item, or detail ID');
    }

    final nonConformityToSave = {
      'id': _uuid.v4(),
      'description': nonConformityData['description'],
      'severity': nonConformityData['severity'] ?? 'Média',
      'corrective_action': nonConformityData['corrective_action'],
      'deadline': nonConformityData['deadline'],
      'status': nonConformityData['status'] ?? 'pendente',
      'media': <Map<String, dynamic>>[],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await _inspectionService.addNonConformity(inspectionId, topicIndex, itemIndex, detailIndex, nonConformityToSave);
  }

  Future<void> updateNonConformityStatus(String nonConformityId, String newStatus) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null || itemIndex == null || detailIndex == null || ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        
        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          
          if (ncIndex < nonConformities.length) {
            final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
            nc['status'] = newStatus;
            nc['updated_at'] = FieldValue.serverTimestamp();
            
            nonConformities[ncIndex] = nc;
            detail['non_conformities'] = nonConformities;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;
            
            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  Future<void> updateNonConformity(String nonConformityId, Map<String, dynamic> updatedData) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null || itemIndex == null || detailIndex == null || ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        
        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          
          if (ncIndex < nonConformities.length) {
            final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
            
            // Update allowed fields
            if (updatedData.containsKey('description')) nc['description'] = updatedData['description'];
            if (updatedData.containsKey('severity')) nc['severity'] = updatedData['severity'];
            if (updatedData.containsKey('corrective_action')) nc['corrective_action'] = updatedData['corrective_action'];
            if (updatedData.containsKey('deadline')) nc['deadline'] = updatedData['deadline'];
            if (updatedData.containsKey('status')) nc['status'] = updatedData['status'];
            nc['updated_at'] = FieldValue.serverTimestamp();
            
            nonConformities[ncIndex] = nc;
            detail['non_conformities'] = nonConformities;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;
            
            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  Future<void> deleteNonConformity(String nonConformityId, String inspectionId) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null || itemIndex == null || detailIndex == null || ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = topics[topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        
        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          
          if (ncIndex < nonConformities.length) {
            nonConformities.removeAt(ncIndex);
            detail['non_conformities'] = nonConformities;
            
            // Update is_damaged status based on remaining non-conformities
            detail['is_damaged'] = nonConformities.isNotEmpty;
            
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;
            
            await firestore.collection('inspections').doc(inspectionId).update({
              'topics': topics,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }
}
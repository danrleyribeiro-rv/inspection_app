import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/data/inspection_data_service.dart';

class TopicDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final InspectionDataService _inspectionService = InspectionDataService();

  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    return _inspectionService.extractTopics(inspectionId, inspection?.topics);
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final existingTopics = inspection?.topics ?? [];
    final newPosition = position ?? existingTopics.length;

    final newTopicData = {
      'name': topicName,
      'description': label,
      'observation': observation,
      'items': <Map<String, dynamic>>[],
    };

    await _inspectionService.addTopic(inspectionId, newTopicData);

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
    final inspection = await _inspectionService.getInspection(updatedTopic.inspectionId);
    if (inspection?.topics != null) {
      final topicIndex = int.tryParse(updatedTopic.id?.replaceFirst('topic_', '') ?? '');
      if (topicIndex != null && topicIndex < inspection!.topics!.length) {
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
      
      await firestore.collection('inspections').doc(inspectionId).update({
        'topics': reorderedTopics,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Topic> isTopicDuplicate(String inspectionId, String topicName) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topics = inspection?.topics ?? [];
    
    // Find the source topic
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
    
    // Create duplicate
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
}
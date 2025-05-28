import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/data/inspection_service.dart';

class TopicService {
  final InspectionService _inspectionService = InspectionService();

  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    return _extractTopics(inspectionId, inspection?.topics);
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

    await _addTopicToInspection(inspectionId, newTopicData);

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

        await _updateTopicAtIndex(updatedTopic.inspectionId, topicIndex, currentTopicData);
      }
    }
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex != null) {
      await _deleteTopicAtIndex(inspectionId, topicIndex);
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

      await _inspectionService.saveInspection(inspection.copyWith(topics: reorderedTopics));
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

    await _addTopicToInspection(inspectionId, duplicateTopicData);

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

  List<Topic> _extractTopics(String inspectionId, List<dynamic>? topicsData) {
    if (topicsData == null) return [];

    List<Topic> topics = [];
    for (int i = 0; i < topicsData.length; i++) {
      final topicData = topicsData[i];
      if (topicData is Map<String, dynamic>) {
        topics.add(Topic(
          id: 'topic_$i',
          inspectionId: inspectionId,
          topicName: topicData['name'] ?? 'Tópico ${i + 1}',
          topicLabel: topicData['description'],
          position: i,
          observation: topicData['observation'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return topics;
  }

  Future<void> _addTopicToInspection(String inspectionId, Map<String, dynamic> newTopic) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    final topics = inspection?.topics != null
        ? List<Map<String, dynamic>>.from(inspection!.topics!)
        : <Map<String, dynamic>>[];

    topics.add(newTopic);
    await _inspectionService.saveInspection(inspection!.copyWith(topics: topics));
  }

  Future<void> _updateTopicAtIndex(String inspectionId, int topicIndex,
      Map<String, dynamic> updatedTopic) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics[topicIndex] = updatedTopic;
        await _inspectionService.saveInspection(inspection.copyWith(topics: topics));
      }
    }
  }

  Future<void> _deleteTopicAtIndex(String inspectionId, int topicIndex) async {
    final inspection = await _inspectionService.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        topics.removeAt(topicIndex);
        await _inspectionService.saveInspection(inspection.copyWith(topics: topics));
      }
    }
  }
}
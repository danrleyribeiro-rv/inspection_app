import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';

class TopicDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<List<Topic>> getTopics(String inspectionId) async {
    final topicsSnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .orderBy('position')
        .get();

    if (topicsSnapshot.docs.isEmpty) {
      return [];
    }

    List<Topic> topics = [];
    for (var doc in topicsSnapshot.docs) {
      final data = doc.data();
      topics.add(Topic.fromMap({
        ...data,
        'id': doc.id,
        'inspection_id': inspectionId,
      }));
    }

    return topics;
  }

  Future<Topic> addTopic(String inspectionId, String topicName,
      {String? label, int? position, String? observation}) async {
    final existingTopics = await getTopics(inspectionId);
    final newPosition = position ??
        (existingTopics.isEmpty ? 0 : existingTopics.last.position + 1);

    final topic = Topic(
      id: null,
      inspectionId: inspectionId,
      topicName: topicName,
      topicLabel: label,
      position: newPosition,
      observation: observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .add(topic.toMap()
          ..remove('inspection_id')
          ..remove('id'));

    return topic.copyWith(id: docRef.id);
  }

  Future<void> updateTopic(Topic updatedTopic) async {
    final inspectionId = updatedTopic.inspectionId;
    final topicId = updatedTopic.id;

    if (topicId == null) {
      throw Exception('Topic ID is required for updates');
    }

    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .update(updatedTopic.toMap()
          ..remove('inspection_id')
          ..remove('id'));
  }

  Future<void> deleteTopic(String inspectionId, String topicId) async {
    await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .delete();
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    WriteBatch batch = firestore.batch();

    for (int i = 0; i < topicIds.length; i++) {
      final topicRef = firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .doc(topicIds[i]);

      batch.update(topicRef, {'position': i});
    }

    await batch.commit();
  }

  Future<Topic> isTopicDuplicate(String inspectionId, String topicName) async {
    final querySnapshot = await firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .where('topic_name', isEqualTo: topicName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Source topic not found');
    }

    final sourceTopicDoc = querySnapshot.docs.first;
    final sourceTopicData = sourceTopicDoc.data();

    final existingTopics = await getTopics(inspectionId);
    final newPosition =
        existingTopics.isEmpty ? 0 : existingTopics.last.position + 1;
    final newTopicName = '$topicName (copy)';

    return await addTopic(
      inspectionId,
      newTopicName,
      label: sourceTopicData['topic_label'],
      position: newPosition,
      observation: sourceTopicData['observation'],
    );
  }
}

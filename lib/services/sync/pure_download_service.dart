import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';

/// Serviço para download puro de inspeções preservando estrutura original
class PureDownloadService {
  final FirebaseService _firebaseService;
  final EnhancedOfflineDataService _offlineService;

  PureDownloadService({
    required FirebaseService firebaseService,
    required EnhancedOfflineDataService offlineService,
  })  : _firebaseService = firebaseService,
        _offlineService = offlineService;

  /// Download puro de inspeções preservando estrutura original do Firebase
  Future<void> downloadInspectionsPreservingStructure() async {
    try {
      debugPrint('PureDownloadService: Starting pure download preserving structure');

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        debugPrint('PureDownloadService: No user logged in');
        return;
      }

      final QuerySnapshot querySnapshot = await _firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: currentUser.uid)
          .where('deleted_at', isNull: true)
          .get();

      for (final doc in querySnapshot.docs) {
        final rawData = doc.data() as Map<String, dynamic>;
        rawData['id'] = doc.id;

        // Convert Firestore timestamps but preserve all other data
        final preservedData = _convertFirestoreTimestampsOnly(rawData);

        try {
          // Create inspection WITHOUT nested data for database storage
          final inspectionDataForDb = Map<String, dynamic>.from(preservedData);
          inspectionDataForDb.remove('topics'); // Remove nested topics for DB storage
          
          final inspection = Inspection.fromMap(inspectionDataForDb);
          
          // Save inspection without nested structure
          await _offlineService.insertOrUpdateInspectionFromCloud(inspection);
          await _offlineService.markInspectionSynced(doc.id);
          
          // Process nested structure preserving evaluable, direct_details, etc.
          await _processNestedStructurePreservingOriginal(doc.id, preservedData);
          
          debugPrint('PureDownloadService: Downloaded inspection ${doc.id} preserving structure');
        } catch (e) {
          debugPrint('PureDownloadService: Error downloading inspection ${doc.id}: $e');
        }
      }

      debugPrint('PureDownloadService: Finished pure download preserving structure');
    } catch (e) {
      debugPrint('PureDownloadService: Error in pure download: $e');
      rethrow;
    }
  }

  /// Converte apenas timestamps do Firestore, preservando toda estrutura original
  Map<String, dynamic> _convertFirestoreTimestampsOnly(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map && (key == 'scheduled_date' || key == 'created_at' || key == 'updated_at')) {
        // Convert Firestore timestamp objects
        final map = Map<String, dynamic>.from(value);
        if (map.containsKey('_seconds') && map.containsKey('_nanoseconds')) {
          final seconds = map['_seconds'] as int;
          final nanoseconds = map['_nanoseconds'] as int;
          converted[key] = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          );
        } else {
          converted[key] = value;
        }
      } else {
        // Preserve everything else exactly as is
        converted[key] = value;
      }
    });

    return converted;
  }

  /// Processa estrutura nested preservando campos originais (evaluable, direct_details, etc.)
  Future<void> _processNestedStructurePreservingOriginal(
      String inspectionId, Map<String, dynamic> inspectionData) async {
    try {
      final topics = inspectionData['topics'] as List<dynamic>? ?? [];
      debugPrint('PureDownloadService: Processing ${topics.length} topics preserving original structure');

      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topicData = Map<String, dynamic>.from(topics[topicIndex]);
        
        // Create topic preserving direct_details field
        final topic = Topic(
          id: '${inspectionId}_topic_$topicIndex',
          inspectionId: inspectionId,
          position: topicIndex,
          orderIndex: topicIndex,
          topicName: topicData['name'] ?? 'Tópico ${topicIndex + 1}',
          topicLabel: topicData['description'],
          observation: topicData['observation'],
          directDetails: topicData['direct_details'] as bool?, // PRESERVE direct_details
          isDamaged: false,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _offlineService.insertOrUpdateTopicFromCloud(topic);
        debugPrint('PureDownloadService: Created topic ${topic.id} with direct_details: ${topic.directDetails}');

        // Process based on topic structure - check for both direct_details and presence of details array
        if (topic.directDetails == true || (topicData.containsKey('details') && topicData['details'] is List)) {
          // Process direct details
          await _processTopicDirectDetailsPreservingOriginal(topic, topicData);
        } else {
          // Process items
          await _processTopicItemsPreservingOriginal(topic, topicData);
        }
      }
    } catch (e) {
      debugPrint('PureDownloadService: Error processing nested structure: $e');
    }
  }

  /// Processa detalhes diretos do tópico preservando estrutura original
  Future<void> _processTopicDirectDetailsPreservingOriginal(
      Topic topic, Map<String, dynamic> topicData) async {
    try {
      final detailsData = topicData['details'] as List<dynamic>? ?? [];
      debugPrint('PureDownloadService: Processing ${detailsData.length} direct details for topic ${topic.id}');

      for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
        final detailData = Map<String, dynamic>.from(detailsData[detailIndex]);
        
        final detail = Detail(
          id: '${topic.inspectionId}_topic_${topic.position}_detail_$detailIndex',
          inspectionId: topic.inspectionId,
          topicId: topic.id,
          itemId: null, // Direct details have no item
          detailId: null,
          position: detailIndex,
          orderIndex: detailIndex,
          detailName: detailData['name'] ?? 'Detalhe ${detailIndex + 1}',
          detailValue: detailData['value']?.toString(),
          observation: detailData['observation'],
          isDamaged: detailData['is_damaged'] == true,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          type: detailData['type'] ?? 'text',
          options: detailData['options'] != null
              ? List<String>.from(detailData['options'])
              : null,
          status: 'pending',
          isRequired: detailData['required'] == true,
        );

        await _offlineService.insertOrUpdateDetailFromCloud(detail);
        debugPrint('PureDownloadService: Created direct detail ${detail.id}');
      }
    } catch (e) {
      debugPrint('PureDownloadService: Error processing direct details: $e');
    }
  }

  /// Processa itens do tópico preservando campos evaluable e evaluation_options
  Future<void> _processTopicItemsPreservingOriginal(
      Topic topic, Map<String, dynamic> topicData) async {
    try {
      final itemsData = topicData['items'] as List<dynamic>? ?? [];
      debugPrint('PureDownloadService: Processing ${itemsData.length} items for topic ${topic.id}');

      for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
        final itemData = Map<String, dynamic>.from(itemsData[itemIndex]);
        
        // Create item preserving evaluable fields
        final item = Item(
          id: '${topic.inspectionId}_topic_${topic.position}_item_$itemIndex',
          inspectionId: topic.inspectionId,
          topicId: topic.id,
          itemId: null,
          position: itemIndex,
          orderIndex: itemIndex,
          itemName: itemData['name'] ?? 'Item ${itemIndex + 1}',
          itemLabel: itemData['description'],
          observation: itemData['observation'],
          evaluable: itemData['evaluable'] as bool?, // PRESERVE evaluable
          evaluationOptions: itemData['evaluation_options'] != null
              ? List<String>.from(itemData['evaluation_options'])
              : null, // PRESERVE evaluation_options
          evaluationValue: itemData['evaluation_value']?.toString(), // PRESERVE evaluation_value
          evaluation: null,
          isDamaged: false,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _offlineService.insertOrUpdateItemFromCloud(item);
        debugPrint('PureDownloadService: Created item ${item.id} with evaluable: ${item.evaluable}');

        // Process item details
        await _processItemDetailsPreservingOriginal(item, itemData);
      }
    } catch (e) {
      debugPrint('PureDownloadService: Error processing items: $e');
    }
  }

  /// Processa detalhes dos itens preservando estrutura original
  Future<void> _processItemDetailsPreservingOriginal(
      Item item, Map<String, dynamic> itemData) async {
    try {
      final detailsData = itemData['details'] as List<dynamic>? ?? [];
      debugPrint('PureDownloadService: Processing ${detailsData.length} details for item ${item.id}');

      for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
        final detailData = Map<String, dynamic>.from(detailsData[detailIndex]);
        
        final detail = Detail(
          id: '${item.inspectionId}_topic_${item.position}_item_${item.position}_detail_$detailIndex',
          inspectionId: item.inspectionId,
          topicId: item.topicId,
          itemId: item.id,
          detailId: null,
          position: detailIndex,
          orderIndex: detailIndex,
          detailName: detailData['name'] ?? 'Detalhe ${detailIndex + 1}',
          detailValue: detailData['value']?.toString(),
          observation: detailData['observation'],
          isDamaged: detailData['is_damaged'] == true,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          type: detailData['type'] ?? 'text',
          options: detailData['options'] != null
              ? List<String>.from(detailData['options'])
              : null,
          status: 'pending',
          isRequired: detailData['required'] == true,
        );

        await _offlineService.insertOrUpdateDetailFromCloud(detail);
        debugPrint('PureDownloadService: Created detail ${detail.id}');
      }
    } catch (e) {
      debugPrint('PureDownloadService: Error processing details: $e');
    }
  }
}
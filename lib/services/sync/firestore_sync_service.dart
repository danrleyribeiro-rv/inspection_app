import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';

class FirestoreSyncService {
  final FirebaseService _firebaseService;
  final EnhancedOfflineDataService _offlineService;
  bool _isSyncing = false;

  // Singleton pattern
  static FirestoreSyncService? _instance;
  static FirestoreSyncService get instance {
    if (_instance == null) {
      throw Exception(
          'FirestoreSyncService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  FirestoreSyncService({
    required FirebaseService firebaseService,
    required EnhancedOfflineDataService offlineService,
  })  : _firebaseService = firebaseService,
        _offlineService = offlineService;

  static void initialize({
    required FirebaseService firebaseService,
    required EnhancedOfflineDataService offlineService,
  }) {
    _instance = FirestoreSyncService(
      firebaseService: firebaseService,
      offlineService: offlineService,
    );
  }

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ===============================
  // SINCRONIZAÇÃO COMPLETA
  // ===============================

  Future<void> performFullSync() async {
    if (_isSyncing) {
      debugPrint('FirestoreSyncService: Sync already in progress');
      return;
    }

    if (!await isConnected()) {
      debugPrint('FirestoreSyncService: No internet connection');
      return;
    }

    try {
      _isSyncing = true;
      debugPrint('FirestoreSyncService: Starting full sync');

      // Primeiro: baixar inspeções da nuvem
      await downloadInspectionsFromCloud();

      // Segundo: fazer upload de alterações locais
      await uploadLocalChangesToCloud();

      debugPrint('FirestoreSyncService: Full sync completed successfully');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error during full sync: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // ===============================
  // DOWNLOAD DA NUVEM
  // ===============================

  Future<void> downloadInspectionsFromCloud() async {
    try {
      debugPrint('FirestoreSyncService: Downloading inspections from cloud');

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        debugPrint('FirestoreSyncService: No user logged in');
        return;
      }

      final QuerySnapshot querySnapshot = await _firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: currentUser.uid)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Converter timestamps do Firestore
        final convertedData = _convertFirestoreTimestamps(data);

        try {
          final cloudInspection = Inspection.fromMap(convertedData);
          final localInspection = await _offlineService.getInspection(doc.id);

          // Verificar se precisa atualizar
          if (localInspection == null ||
              cloudInspection.updatedAt.isAfter(localInspection.updatedAt)) {
            await _offlineService.saveInspection(cloudInspection);
            await _offlineService.markInspectionSynced(doc.id);

            // Baixar dados relacionados
            await _downloadInspectionRelatedData(doc.id);
            
            // Baixar template da inspeção se necessário
            await _downloadInspectionTemplate(cloudInspection);

            debugPrint('FirestoreSyncService: Downloaded inspection ${doc.id}');
          }
        } catch (e) {
          debugPrint(
              'FirestoreSyncService: Error processing inspection ${doc.id}: $e');
        }
      }

      debugPrint('FirestoreSyncService: Finished downloading inspections');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading inspections: $e');
    }
  }

  Future<void> _downloadInspectionRelatedData(String inspectionId) async {
    try {
      debugPrint(
          'FirestoreSyncService: Processing nested structure for inspection $inspectionId');

      // Buscar diretamente do Firestore para pegar os topics
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final topics = data['topics'] as List<dynamic>?;

        if (topics != null && topics.isNotEmpty) {
          debugPrint(
              'FirestoreSyncService: Processing ${topics.length} nested topics from Firestore');
          final topicsData =
              topics.map((topic) => Map<String, dynamic>.from(topic)).toList();
          await _processNestedTopicsStructure(inspectionId, topicsData);
        } else {
          debugPrint(
              'FirestoreSyncService: No nested topics found, creating default structure');
          await _createDefaultInspectionStructure(inspectionId);
        }
      } else {
        debugPrint(
            'FirestoreSyncService: No nested topics found, creating default structure');
        await _createDefaultInspectionStructure(inspectionId);
      }
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error downloading related data for $inspectionId: $e');
    }
  }

  Future<void> _createDefaultInspectionStructure(String inspectionId) async {
    try {
      debugPrint(
          'FirestoreSyncService: Creating default structure for inspection $inspectionId');

      // Criar tópico padrão
      final defaultTopic = Topic(
        id: '${inspectionId}_default_topic',
        inspectionId: inspectionId,
        position: 0,
        orderIndex: 0,
        topicName: 'Inspeção Geral',
        topicLabel: 'Tópico padrão para inspeção',
        observation: null,
        isDamaged: false,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _offlineService.saveTopic(defaultTopic);

      // Criar item padrão
      final defaultItem = Item(
        id: '${inspectionId}_default_item',
        inspectionId: inspectionId,
        topicId: defaultTopic.id,
        itemId: null,
        position: 0,
        orderIndex: 0,
        itemName: 'Item de Inspeção',
        itemLabel: 'Item padrão para inspeção',
        evaluation: null,
        observation: null,
        isDamaged: false,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _offlineService.saveItem(defaultItem);

      // Criar detalhe padrão
      final defaultDetail = Detail(
        id: '${inspectionId}_default_detail',
        inspectionId: inspectionId,
        topicId: defaultTopic.id,
        itemId: defaultItem.id,
        detailId: null,
        position: 0,
        orderIndex: 0,
        detailName: 'Verificação',
        detailValue: null,
        observation: null,
        isDamaged: false,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: 'text',
        options: null,
        status: 'pending',
        isRequired: false,
      );

      await _offlineService.saveDetail(defaultDetail);

      debugPrint(
          'FirestoreSyncService: Created default structure for inspection $inspectionId');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error creating default structure for $inspectionId: $e');
    }
  }

  Future<void> _processNestedTopicsStructure(
      String inspectionId, List<Map<String, dynamic>> topicsData) async {
    try {
      debugPrint(
          'FirestoreSyncService: Processing ${topicsData.length} topics from nested structure');

      for (int topicIndex = 0; topicIndex < topicsData.length; topicIndex++) {
        final topicData = topicsData[topicIndex];

        // Criar tópico
        final topic = Topic(
          id: '${inspectionId}_topic_$topicIndex',
          inspectionId: inspectionId,
          position: topicIndex,
          orderIndex: topicIndex,
          topicName: topicData['name'] ?? 'Tópico ${topicIndex + 1}',
          topicLabel: topicData['description'],
          observation: topicData['observation'],
          isDamaged: false,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _offlineService.saveTopic(topic);
        debugPrint(
            'FirestoreSyncService: Created topic ${topic.id}: ${topic.topicName}');

        // Processar itens do tópico
        final itemsData = topicData['items'] as List<dynamic>? ?? [];
        debugPrint(
            'FirestoreSyncService: Processing ${itemsData.length} items for topic ${topic.id}');

        for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
          final itemData = itemsData[itemIndex];

          // Criar item
          final item = Item(
            id: '${inspectionId}_topic_${topicIndex}_item_$itemIndex',
            inspectionId: inspectionId,
            topicId: topic.id,
            itemId: null,
            position: itemIndex,
            orderIndex: itemIndex,
            itemName: itemData['name'] ?? 'Item ${itemIndex + 1}',
            itemLabel: itemData['description'],
            evaluation: null,
            observation: itemData['observation'],
            isDamaged: false,
            tags: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineService.saveItem(item);
          debugPrint(
              'FirestoreSyncService: Created item ${item.id}: ${item.itemName}');

          // Processar detalhes do item
          final detailsData = itemData['details'] as List<dynamic>? ?? [];
          debugPrint(
              'FirestoreSyncService: Processing ${detailsData.length} details for item ${item.id}');

          for (int detailIndex = 0;
              detailIndex < detailsData.length;
              detailIndex++) {
            final detailData = detailsData[detailIndex];

            // Criar detalhe
            final detail = Detail(
              id: '${inspectionId}_topic_${topicIndex}_item_${itemIndex}_detail_$detailIndex',
              inspectionId: inspectionId,
              topicId: topic.id,
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

            await _offlineService.saveDetail(detail);
            debugPrint(
                'FirestoreSyncService: Created detail ${detail.id}: ${detail.detailName}');
          }
        }
      }

      debugPrint(
          'FirestoreSyncService: Successfully processed nested topics structure');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error processing nested topics structure: $e');
    }
  }

  // ===============================
  // UPLOAD PARA A NUVEM
  // ===============================

  Future<void> uploadLocalChangesToCloud() async {
    try {
      debugPrint('FirestoreSyncService: Uploading local changes to cloud');

      await _uploadInspectionsWithNestedStructure();

      debugPrint('FirestoreSyncService: Finished uploading local changes');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading local changes: $e');
    }
  }

  Future<void> _uploadInspectionsWithNestedStructure() async {
    try {
      final inspections = await _offlineService.getInspectionsNeedingSync();

      for (final inspection in inspections) {
        try {
          // Build the complete nested structure for Firestore
          final inspectionData = await _buildNestedInspectionData(inspection);

          await _firebaseService.firestore
              .collection('inspections')
              .doc(inspection.id)
              .set(inspectionData, SetOptions(merge: true));

          // Mark all related entities as synced
          await _markInspectionAndChildrenSynced(inspection.id);

          debugPrint(
              'FirestoreSyncService: Uploaded inspection with nested structure ${inspection.id}');
        } catch (e) {
          debugPrint(
              'FirestoreSyncService: Error uploading inspection ${inspection.id}: $e');
        }
      }
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading inspections with nested structure: $e');
    }
  }

  Future<Map<String, dynamic>> _buildNestedInspectionData(
      Inspection inspection) async {
    // Start with basic inspection data
    final data = inspection.toMap();
    data.remove('id');
    data.remove('needs_sync');
    data.remove('is_deleted');

    // Convert integer booleans back to booleans for Firestore
    if (data['is_templated'] is int) {
      data['is_templated'] = data['is_templated'] == 1;
    }
    if (data['is_synced'] is int) {
      data['is_synced'] = data['is_synced'] == 1;
    }
    if (data['has_local_changes'] is int) {
      data['has_local_changes'] = data['has_local_changes'] == 1;
    }

    // Get all topics for this inspection
    final topics = await _offlineService.getTopics(inspection.id);
    final topicsData = <Map<String, dynamic>>[];

    for (final topic in topics) {
      final topicData = <String, dynamic>{
        'name': topic.topicName,
        'description': topic.topicLabel,
        'observation': topic.observation,
        'non_conformities': <Map<String, dynamic>>[], // Will be populated later
        'items': <Map<String, dynamic>>[],
      };

      // Get all items for this topic
      final items = await _offlineService.getItems(topic.id ?? '');
      final itemsData = <Map<String, dynamic>>[];

      for (final item in items) {
        final itemData = <String, dynamic>{
          'name': item.itemName,
          'description': item.itemLabel,
          'observation': item.observation,
          'non_conformities':
              <Map<String, dynamic>>[], // Will be populated later
          'details': <Map<String, dynamic>>[],
        };

        // Get all details for this item
        final details = await _offlineService.getDetails(item.id ?? '');
        final detailsData = <Map<String, dynamic>>[];

        for (final detail in details) {
          final detailData = <String, dynamic>{
            'name': detail.detailName,
            'type': detail.type ?? 'text',
            'options': detail.options ?? [],
            'value': detail.detailValue,
            'observation': detail.observation,
            'required': detail.isRequired == true,
            'is_damaged': detail.isDamaged == true,
            'media': <Map<String, dynamic>>[], // Will be populated later
            'non_conformities':
                <Map<String, dynamic>>[], // Will be populated later
          };

          detailsData.add(detailData);
        }

        itemData['details'] = detailsData;
        itemsData.add(itemData);
      }

      topicData['items'] = itemsData;
      topicsData.add(topicData);
    }

    // Add topics to the main data
    data['topics'] = topicsData;

    return data;
  }

  Future<void> _markInspectionAndChildrenSynced(String inspectionId) async {
    // Mark inspection as synced
    await _offlineService.markInspectionSynced(inspectionId);

    // Mark all topics as synced
    final topics = await _offlineService.getTopics(inspectionId);
    for (final topic in topics) {
      await _offlineService.markTopicSynced(topic.id ?? '');

      // Mark all items as synced
      final items = await _offlineService.getItems(topic.id ?? '');
      for (final item in items) {
        await _offlineService.markItemSynced(item.id ?? '');

        // Mark all details as synced
        final details = await _offlineService.getDetails(item.id ?? '');
        for (final detail in details) {
          await _offlineService.markDetailSynced(detail.id ?? '');
        }
      }
    }
  }

  Future<void> _downloadInspectionTemplate(Inspection inspection) async {
    try {
      if (inspection.templateId == null || inspection.templateId!.isEmpty) {
        debugPrint('FirestoreSyncService: No template associated with inspection ${inspection.id}');
        return;
      }

      debugPrint('FirestoreSyncService: Downloading template ${inspection.templateId} for inspection ${inspection.id}');
      
      // Tentar baixar o template usando o template service via service factory
      try {
        final serviceFactory = EnhancedOfflineServiceFactory.instance;
        final templateService = serviceFactory.templateService;
        final success = await templateService.downloadTemplateForOffline(inspection.templateId!);
        
        if (success) {
          debugPrint('FirestoreSyncService: Successfully downloaded template ${inspection.templateId}');
        } else {
          debugPrint('FirestoreSyncService: Failed to download template ${inspection.templateId}');
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Error downloading template ${inspection.templateId}: $e');
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error in _downloadInspectionTemplate: $e');
    }
  }

  // ===============================
  // UTILITÁRIOS
  // ===============================

  Map<String, dynamic> _convertFirestoreTimestamps(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map) {
        converted[key] =
            _convertFirestoreTimestamps(Map<String, dynamic>.from(value));
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Map) {
            return _convertFirestoreTimestamps(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });

    return converted;
  }

  // ===============================
  // SINCRONIZAÇÃO DE INSPEÇÃO ESPECÍFICA
  // ===============================

  Future<void> syncInspection(String inspectionId) async {
    if (!await isConnected()) {
      debugPrint(
          'FirestoreSyncService: No internet connection for inspection sync');
      return;
    }

    try {
      debugPrint('FirestoreSyncService: Syncing inspection $inspectionId');

      // Download da nuvem
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        data['id'] = inspectionId;

        final convertedData = _convertFirestoreTimestamps(data);
        final cloudInspection = Inspection.fromMap(convertedData);

        await _offlineService.saveInspection(cloudInspection);
        await _offlineService.markInspectionSynced(inspectionId);

        // Baixar dados relacionados
        await _downloadInspectionRelatedData(inspectionId);
        
        // Baixar template da inspeção se necessário
        await _downloadInspectionTemplate(cloudInspection);
      }

      // Upload de alterações locais
      final localInspection = await _offlineService.getInspection(inspectionId);
      if (localInspection != null) {
        // Upload da inspeção se necessário
        final inspectionsNeedingSync =
            await _offlineService.getInspectionsNeedingSync();
        final inspectionNeedsSync =
            inspectionsNeedingSync.any((i) => i.id == inspectionId);

        if (inspectionNeedsSync) {
          await _uploadInspectionsWithNestedStructure();
        }
      }

      debugPrint(
          'FirestoreSyncService: Finished syncing inspection $inspectionId');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error syncing inspection $inspectionId: $e');
      rethrow;
    }
  }

  // ===============================
  // STATUS DE SINCRONIZAÇÃO
  // ===============================

  bool get isSyncing => _isSyncing;

  Future<Map<String, int>> getSyncStatus() async {
    final inspections = await _offlineService.getInspectionsNeedingSync();
    final topics = await _offlineService.getTopicsNeedingSync();
    final items = await _offlineService.getItemsNeedingSync();
    final details = await _offlineService.getDetailsNeedingSync();
    final nonConformities =
        await _offlineService.getNonConformitiesNeedingSync();

    return {
      'inspections': inspections.length,
      'topics': topics.length,
      'items': items.length,
      'details': details.length,
      'non_conformities': nonConformities.length,
    };
  }

  Future<bool> hasUnsyncedData() async {
    final status = await getSyncStatus();
    return status.values.any((pendingCount) => pendingCount > 0);
  }

  // Alias for performFullSync for backward compatibility
  Future<void> fullSync() async {
    await performFullSync();
  }
}

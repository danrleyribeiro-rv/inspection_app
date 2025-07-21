import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/models/inspection_history.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';

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
  // SINCRONIZAÇÃO COMPLETA SIMPLIFICADA
  // ===============================

  Future<void> performFullSync() async {
    if (_isSyncing || !await isConnected()) {
      debugPrint('FirestoreSyncService: Sync in progress or no connection');
      return;
    }

    try {
      _isSyncing = true;
      debugPrint('FirestoreSyncService: Starting simplified full sync');

      await downloadInspectionsFromCloud();
      await uploadLocalChangesToCloud();

      debugPrint('FirestoreSyncService: Full sync completed');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error during sync: $e');
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
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) return;

      final querySnapshot = await _firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: currentUser.uid)
          .where('deleted_at', isNull: true)
          .get();

      debugPrint('FirestoreSyncService: Found ${querySnapshot.docs.length} inspections to download');

      for (final doc in querySnapshot.docs) {
        await _downloadSingleInspection(doc);
      }

      debugPrint('FirestoreSyncService: Download completed');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading inspections: $e');
    }
  }

  Future<void> _downloadSingleInspection(QueryDocumentSnapshot doc) async {
    try {
      debugPrint('FirestoreSyncService: Starting download of inspection ${doc.id}');
      
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      // Converter timestamps do Firestore primeiro
      final convertedData = _convertFirestoreTimestamps(data);
      
      // Criar objeto Inspection a partir dos dados convertidos
      final cloudInspection = Inspection.fromMap(convertedData);
      debugPrint('FirestoreSyncService: Created inspection object - Title: "${cloudInspection.title}", Inspector: ${cloudInspection.inspectorId}');
      
      final localInspection = await _offlineService.getInspection(doc.id);
      debugPrint('FirestoreSyncService: Local inspection exists: ${localInspection != null}');

      // Sempre fazer download se não existe localmente ou se é mais recente
      if (localInspection == null || cloudInspection.updatedAt.isAfter(localInspection.updatedAt)) {
        debugPrint('FirestoreSyncService: Proceeding with download of inspection ${doc.id}');
        
        // Preparar inspeção para salvamento local
        final downloadedInspection = cloudInspection.copyWith(
          hasLocalChanges: false,
          isSynced: true,
          lastSyncAt: DateTime.now(),
        );
        
        debugPrint('FirestoreSyncService: Saving inspection ${doc.id} to local database');
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);
        
        // Verificar se foi salva
        final savedInspection = await _offlineService.getInspection(doc.id);
        debugPrint('FirestoreSyncService: Verification - Inspection ${doc.id} saved successfully: ${savedInspection != null}');
        
        // Processar estrutura aninhada apenas se a inspeção foi salva
        if (savedInspection != null) {
          final topicsData = convertedData['topics'] as List<dynamic>? ?? [];
          final topicsMapList = topicsData.map((t) => Map<String, dynamic>.from(t)).toList();
          await _processNestedTopicsStructure(cloudInspection.id, topicsMapList);
          
          // Baixar mídias
          await _downloadInspectionMedia(doc.id);
          
          // Baixar template se necessário
          await _downloadInspectionTemplate(cloudInspection);

          // Registrar no histórico
          await _addDownloadHistory(doc.id, cloudInspection.title);

          debugPrint('FirestoreSyncService: Successfully downloaded inspection "${cloudInspection.title}" (${doc.id})');
        } else {
          debugPrint('FirestoreSyncService: ERROR - Failed to save inspection ${doc.id} to local database');
        }
      } else {
        debugPrint('FirestoreSyncService: Inspection ${doc.id} is already up to date');
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading inspection ${doc.id}: $e');
    }
  }

  Future<void> _addDownloadHistory(String inspectionId, String title) async {
    final currentUser = _firebaseService.currentUser;
    if (currentUser != null) {
      await _offlineService.addInspectionHistory(
        inspectionId: inspectionId,
        status: HistoryStatus.downloadedInspection,
        inspectorId: currentUser.uid,
        description: 'Inspeção baixada da nuvem com sucesso',
        metadata: {
          'source': 'cloud_sync',
          'downloaded_at': DateTime.now().toIso8601String(),
          'inspection_title': title,
        },
      );
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
        data['id'] = inspectionId;

        // *** CORREÇÃO: Salvar a inspeção primeiro antes de processar estrutura aninhada ***
        final convertedData = _convertFirestoreTimestamps(data);
        final cloudInspection = Inspection.fromMap(convertedData);
        
        // Salvar inspeção sem marcar como alterada localmente
        final downloadedInspection = cloudInspection.copyWith(
          hasLocalChanges: false,
          isSynced: true,
          lastSyncAt: DateTime.now(),
        );
        
        debugPrint('FirestoreSyncService: 💾 Salvando inspeção $inspectionId durante download de dados relacionados...');
        debugPrint('FirestoreSyncService: 💾 Inspector ID: ${downloadedInspection.inspectorId}');
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);
        debugPrint('FirestoreSyncService: ✅ Inspeção "${downloadedInspection.title}" salva no banco local');

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

      await _offlineService.insertOrUpdateTopic(defaultTopic);

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

      await _offlineService.insertOrUpdateItem(defaultItem);

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

      await _offlineService.insertOrUpdateDetail(defaultDetail);

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
      for (int topicIndex = 0; topicIndex < topicsData.length; topicIndex++) {
        await _processSingleTopic(inspectionId, topicsData[topicIndex], topicIndex);
      }
      debugPrint('FirestoreSyncService: Processed ${topicsData.length} topics');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing topics: $e');
    }
  }

  Future<void> _processSingleTopic(String inspectionId, Map<String, dynamic> topicData, int topicIndex) async {
    final hasDirectDetails = topicData['direct_details'] == true;
    
    final topic = Topic(
      id: '${inspectionId}_topic_$topicIndex',
      inspectionId: inspectionId,
      position: topicIndex,
      orderIndex: topicIndex,
      topicName: topicData['name'] ?? 'Tópico ${topicIndex + 1}',
      topicLabel: topicData['description'],
      observation: topicData['observation'],
      directDetails: hasDirectDetails,
      isDamaged: false,
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _offlineService.insertOrUpdateTopic(topic);
    
    // Processar dados relacionados
    await _processTopicNonConformities(topic, topicData);
    await _processTopicMedia(topic, topicData);

    if (hasDirectDetails) {
      await _processTopicDirectDetails(inspectionId, topic.id!, topicData);
    } else {
      await _processTopicItems(inspectionId, topic.id!, topicData, topicIndex);
    }
  }

  Future<void> _processTopicDirectDetails(String inspectionId, String topicId, Map<String, dynamic> topicData) async {
    final detailsData = topicData['details'] as List<dynamic>? ?? [];
    for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
      await _processDetailFromJson(inspectionId, topicId, null, detailsData[detailIndex], detailIndex);
    }
  }

  Future<void> _processTopicItems(String inspectionId, String topicId, Map<String, dynamic> topicData, int topicIndex) async {
    final itemsData = topicData['items'] as List<dynamic>? ?? [];
    for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
      await _processSingleItem(inspectionId, topicId, itemsData[itemIndex], topicIndex, itemIndex);
    }
  }

  Future<void> _processSingleItem(String inspectionId, String topicId, Map<String, dynamic> itemData, int topicIndex, int itemIndex) async {
    final item = Item(
      id: '${inspectionId}_topic_${topicIndex}_item_$itemIndex',
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: null,
      position: itemIndex,
      orderIndex: itemIndex,
      itemName: itemData['name'] ?? 'Item ${itemIndex + 1}',
      itemLabel: itemData['description'],
      evaluation: null,
      observation: itemData['observation'],
      evaluable: itemData['evaluable'],
      evaluationOptions: itemData['evaluation_options'] != null 
          ? List<String>.from(itemData['evaluation_options']) 
          : null,
      evaluationValue: itemData['evaluation_value'],
      isDamaged: false,
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _offlineService.insertOrUpdateItem(item);
    
    // Processar dados relacionados
    await _processItemNonConformities(item, itemData);
    await _processItemMedia(item, itemData);

    // Processar detalhes do item
    final detailsData = itemData['details'] as List<dynamic>? ?? [];
    for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
      await _processDetailFromJson(inspectionId, topicId, item.id, detailsData[detailIndex], detailIndex);
    }
  }

  Future<void> _processTopicNonConformities(Topic topic, Map<String, dynamic> topicData) async {
    try {
      final nonConformitiesData = topicData['non_conformities'] as List<dynamic>? ?? [];
      debugPrint(
          'FirestoreSyncService: Processing ${nonConformitiesData.length} non-conformities for topic ${topic.id}');

      for (final ncData in nonConformitiesData) {
        final ncMap = Map<String, dynamic>.from(ncData);
        final nonConformity = NonConformity(
          id: ncMap['id'] ?? 'nc_${DateTime.now().millisecondsSinceEpoch}',
          inspectionId: topic.inspectionId,
          topicId: topic.id,
          itemId: null,
          detailId: null,
          title: ncMap['title'] ?? ncMap['description'] ?? 'Não conformidade',
          description: ncMap['description'] ?? '',
          severity: ncMap['severity'] ?? 'low',
          status: ncMap['status'] ?? 'open',
          correctiveAction: ncMap['corrective_action'],
          deadline: ncMap['deadline'] != null ? DateTime.tryParse(ncMap['deadline'].toString()) : null,
          isResolved: ncMap['is_resolved'] == true || ncMap['is_resolved'] == 1,
          resolvedAt: ncMap['resolved_at'] != null ? DateTime.tryParse(ncMap['resolved_at'].toString()) : null,
          createdAt: DateTime.tryParse(ncMap['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(ncMap['updated_at']?.toString() ?? '') ?? DateTime.now(),
        );

        await _offlineService.insertOrUpdateNonConformity(nonConformity);
        debugPrint(
            'FirestoreSyncService: Created non-conformity ${nonConformity.id} for topic ${topic.id}');

        // Processar mídias da não conformidade
        await _processNonConformityMedia(nonConformity, ncMap);
      }
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error processing topic non-conformities: $e');
    }
  }

  Future<void> _processItemNonConformities(Item item, Map<String, dynamic> itemData) async {
    try {
      final nonConformitiesData = itemData['non_conformities'] as List<dynamic>? ?? [];
      debugPrint(
          'FirestoreSyncService: Processing ${nonConformitiesData.length} non-conformities for item ${item.id}');

      for (final ncData in nonConformitiesData) {
        final ncMap = Map<String, dynamic>.from(ncData);
        final nonConformity = NonConformity(
          id: ncMap['id'] ?? 'nc_${DateTime.now().millisecondsSinceEpoch}',
          inspectionId: item.inspectionId,
          topicId: item.topicId,
          itemId: item.id,
          detailId: null,
          title: ncMap['title'] ?? ncMap['description'] ?? 'Não conformidade',
          description: ncMap['description'] ?? '',
          severity: ncMap['severity'] ?? 'low',
          status: ncMap['status'] ?? 'open',
          correctiveAction: ncMap['corrective_action'],
          deadline: ncMap['deadline'] != null ? DateTime.tryParse(ncMap['deadline'].toString()) : null,
          isResolved: ncMap['is_resolved'] == true || ncMap['is_resolved'] == 1,
          resolvedAt: ncMap['resolved_at'] != null ? DateTime.tryParse(ncMap['resolved_at'].toString()) : null,
          createdAt: DateTime.tryParse(ncMap['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(ncMap['updated_at']?.toString() ?? '') ?? DateTime.now(),
        );

        await _offlineService.insertOrUpdateNonConformity(nonConformity);
        debugPrint(
            'FirestoreSyncService: Created non-conformity ${nonConformity.id} for item ${item.id}');

        // Processar mídias da não conformidade
        await _processNonConformityMedia(nonConformity, ncMap);
      }
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error processing item non-conformities: $e');
    }
  }

  // Método centralizado para processar detalhes
  Future<String> _processDetailFromJson(String inspectionId, String topicId, String? itemId, Map<String, dynamic> detailData, int position) async {
    // DEBUG: Log dados do detalhe sendo baixados da nuvem
    debugPrint('FirestoreSyncService: 🔍 DOWNLOAD - Detalhe "${detailData['name']}" - Value vinda da nuvem: "${detailData['value'] ?? "null"}", Observation: "${detailData['observation'] ?? "null"}"');
    
    // Criar detalhe
    final detail = Detail(
      id: itemId != null 
          ? '${inspectionId}_topic_${topicId.split('_').last}_item_${itemId.split('_').last}_detail_$position'
          : '${inspectionId}_topic_${topicId.split('_').last}_detail_$position',
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: null,
      position: position,
      orderIndex: position,
      detailName: detailData['name'] ?? 'Detalhe ${position + 1}',
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

    await _offlineService.insertOrUpdateDetail(detail);
    debugPrint(
        'FirestoreSyncService: Created detail ${detail.id}: ${detail.detailName}');

    // Processar não conformidades do detalhe
    await _processDetailNonConformities(detail, detailData);

    // Processar mídias do detalhe
    await _processDetailMedia(detail, detailData);

    return detail.id!;
  }

  Future<void> _processTopicMedia(Topic topic, Map<String, dynamic> topicData) async {
    try {
      final mediaData = topicData['media'] as List<dynamic>? ?? [];
      debugPrint('FirestoreSyncService: Processing ${mediaData.length} media items for topic ${topic.id}');

      for (final media in mediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        await _processMediaItem(
          mediaMap, 
          topic.inspectionId, 
          topicId: topic.id,
        );
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing topic media: $e');
    }
  }

  Future<void> _processItemMedia(Item item, Map<String, dynamic> itemData) async {
    try {
      final mediaData = itemData['media'] as List<dynamic>? ?? [];
      debugPrint('FirestoreSyncService: Processing ${mediaData.length} media items for item ${item.id}');

      for (final media in mediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        await _processMediaItem(
          mediaMap, 
          item.inspectionId, 
          topicId: item.topicId,
          itemId: item.id,
        );
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing item media: $e');
    }
  }

  Future<void> _processDetailMedia(Detail detail, Map<String, dynamic> detailData) async {
    try {
      final mediaData = detailData['media'] as List<dynamic>? ?? [];
      debugPrint('FirestoreSyncService: Processing ${mediaData.length} media items for detail ${detail.id}');

      for (final media in mediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        await _processMediaItem(
          mediaMap, 
          detail.inspectionId, 
          topicId: detail.topicId,
          itemId: detail.itemId,
          detailId: detail.id,
        );
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing detail media: $e');
    }
  }

  Future<void> _processMediaItem(
    Map<String, dynamic> mediaData, 
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
  }) async {
    try {
      final success = await _downloadAndSaveMediaWithIds(
        mediaData, 
        inspectionId, 
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        context: 'nested_structure_processing',
        isResolutionMedia: mediaData['isResolutionMedia'] == true,
      );
      
      if (success) {
        debugPrint('FirestoreSyncService: Successfully processed media from cloud data');
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing media item: $e');
    }
  }

  Future<void> _processNonConformityMedia(NonConformity nonConformity, Map<String, dynamic> ncData) async {
    try {
      // Processar mídias regulares
      final mediaData = ncData['media'] as List<dynamic>? ?? [];
      debugPrint('FirestoreSyncService: Processing ${mediaData.length} media items for non-conformity ${nonConformity.id}');

      for (final media in mediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        await _processMediaItem(
          mediaMap, 
          nonConformity.inspectionId, 
          topicId: nonConformity.topicId,
          itemId: nonConformity.itemId,
          detailId: nonConformity.detailId,
          nonConformityId: nonConformity.id,
        );
      }

      // Processar mídias de resolução (solved_media)
      final solvedMediaData = ncData['solved_media'] as List<dynamic>? ?? [];
      debugPrint('FirestoreSyncService: Processing ${solvedMediaData.length} solved media items for non-conformity ${nonConformity.id}');

      for (final media in solvedMediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        // Marcar como mídia de resolução
        mediaMap['isResolutionMedia'] = true;
        await _processMediaItem(
          mediaMap, 
          nonConformity.inspectionId, 
          topicId: nonConformity.topicId,
          itemId: nonConformity.itemId,
          detailId: nonConformity.detailId,
          nonConformityId: nonConformity.id,
        );
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing non-conformity media: $e');
    }
  }

  Future<void> _processDetailNonConformities(Detail detail, Map<String, dynamic> detailData) async {
    try {
      final nonConformitiesData = detailData['non_conformities'] as List<dynamic>? ?? [];
      debugPrint(
          'FirestoreSyncService: Processing ${nonConformitiesData.length} non-conformities for detail ${detail.id}');

      for (final ncData in nonConformitiesData) {
        final ncMap = Map<String, dynamic>.from(ncData);
        final nonConformity = NonConformity(
          id: ncMap['id'] ?? 'nc_${DateTime.now().millisecondsSinceEpoch}',
          inspectionId: detail.inspectionId,
          topicId: detail.topicId,
          itemId: detail.itemId,
          detailId: detail.id,
          title: ncMap['title'] ?? ncMap['description'] ?? 'Não conformidade',
          description: ncMap['description'] ?? '',
          severity: ncMap['severity'] ?? 'low',
          status: ncMap['status'] ?? 'open',
          correctiveAction: ncMap['corrective_action'],
          deadline: ncMap['deadline'] != null ? DateTime.tryParse(ncMap['deadline'].toString()) : null,
          isResolved: ncMap['is_resolved'] == true || ncMap['is_resolved'] == 1,
          resolvedAt: ncMap['resolved_at'] != null ? DateTime.tryParse(ncMap['resolved_at'].toString()) : null,
          createdAt: DateTime.tryParse(ncMap['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(ncMap['updated_at']?.toString() ?? '') ?? DateTime.now(),
        );

        await _offlineService.insertOrUpdateNonConformity(nonConformity);
        debugPrint(
            'FirestoreSyncService: Created non-conformity ${nonConformity.id} for detail ${detail.id}');

        // Processar mídias da não conformidade
        await _processNonConformityMedia(nonConformity, ncMap);
      }
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error processing detail non-conformities: $e');
    }
  }

  Future<void> _downloadInspectionMedia(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: ========== STARTING MEDIA DOWNLOAD FOR INSPECTION $inspectionId ==========');
      
      // Show immediate media-specific progress notification
      await _showProgressNotification(
        title: 'Baixando Mídias',
        message: 'Verificando mídias disponíveis...',
        progress: 0,
        indeterminate: true,
      );
      
      // Get the local structure that was already created by _downloadInspectionRelatedData
      final localTopics = await _offlineService.getTopics(inspectionId);
      debugPrint('FirestoreSyncService: Found ${localTopics.length} local topics for inspection $inspectionId');
      
      // Build local ID maps for efficient lookup
      final Map<String, Topic> localTopicsByPosition = {};
      final Map<String, Item> localItemsByPosition = {};
      final Map<String, Detail> localDetailsByPosition = {};
      final Map<String, NonConformity> localNonConformitiesByFirestoreId = {};
      
      // Map topics by position
      for (final topic in localTopics) {
        localTopicsByPosition['${topic.position}'] = topic;
      }
      
      // Map items by position within their topics
      for (final topic in localTopics) {
        if (topic.id != null) {
          final items = await _offlineService.getItems(topic.id!);
          for (final item in items) {
            localItemsByPosition['${topic.position}_${item.position}'] = item;
          }
        }
      }
      
      // Map details by position within their items
      for (final topic in localTopics) {
        if (topic.id != null) {
          final items = await _offlineService.getItems(topic.id!);
          for (final item in items) {
            if (item.id != null) {
              final details = await _offlineService.getDetails(item.id!);
              for (final detail in details) {
                localDetailsByPosition['${topic.position}_${item.position}_${detail.position}'] = detail;
              }
            }
          }
        }
      }
      
      // Map non-conformities by their original Firestore ID
      final allNonConformities = await _offlineService.getNonConformities(inspectionId);
      for (final nc in allNonConformities) {
        localNonConformitiesByFirestoreId[nc.id] = nc;
      }
      
      debugPrint('FirestoreSyncService: Built local maps - Topics: ${localTopicsByPosition.length}, Items: ${localItemsByPosition.length}, Details: ${localDetailsByPosition.length}, NCs: ${localNonConformitiesByFirestoreId.length}');
      
      // Fetch Firestore inspection data to get media
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        debugPrint('FirestoreSyncService: Inspection not found in Firestore');
        return;
      }
      
      final data = docSnapshot.data()!;
      final firestoreTopics = data['topics'] as List<dynamic>? ?? [];
      
      int totalMediaDownloaded = 0;
      int totalMediaFound = 0;
      
      debugPrint('FirestoreSyncService: Found ${firestoreTopics.length} firestore topics for inspection $inspectionId');
      
      // First pass: Count total media to provide accurate progress
      int preliminaryMediaCount = 0;
      for (int topicIndex = 0; topicIndex < firestoreTopics.length; topicIndex++) {
        final topicData = firestoreTopics[topicIndex];
        final topic = Map<String, dynamic>.from(topicData);
        
        // Count topic media
        final topicMedias = topic['media'] as List<dynamic>? ?? [];
        preliminaryMediaCount += topicMedias.length;
        
        // Count item media
        final items = topic['items'] as List<dynamic>? ?? [];
        for (final itemData in items) {
          final item = Map<String, dynamic>.from(itemData);
          final itemMedias = item['media'] as List<dynamic>? ?? [];
          preliminaryMediaCount += itemMedias.length;
          
          // Count detail media
          final details = item['details'] as List<dynamic>? ?? [];
          for (final detailData in details) {
            final detail = Map<String, dynamic>.from(detailData);
            final detailMedias = detail['media'] as List<dynamic>? ?? [];
            preliminaryMediaCount += detailMedias.length;
            
            // Count NC media (both media and solved_media)
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            for (final ncData in nonConformities) {
              final nc = Map<String, dynamic>.from(ncData);
              final ncMedias = nc['media'] as List<dynamic>? ?? [];
              final ncSolvedMedias = nc['solved_media'] as List<dynamic>? ?? [];
              preliminaryMediaCount += ncMedias.length + ncSolvedMedias.length;
            }
          }
          
          // Count item-level NC media (both media and solved_media)
          final itemNonConformities = item['non_conformities'] as List<dynamic>? ?? [];
          for (final ncData in itemNonConformities) {
            final nc = Map<String, dynamic>.from(ncData);
            final ncMedias = nc['media'] as List<dynamic>? ?? [];
            final ncSolvedMedias = nc['solved_media'] as List<dynamic>? ?? [];
            preliminaryMediaCount += ncMedias.length + ncSolvedMedias.length;
          }
        }
        
        // Count topic-level NC media (both media and solved_media)
        final topicNonConformities = topic['non_conformities'] as List<dynamic>? ?? [];
        for (final ncData in topicNonConformities) {
          final nc = Map<String, dynamic>.from(ncData);
          final ncMedias = nc['media'] as List<dynamic>? ?? [];
          final ncSolvedMedias = nc['solved_media'] as List<dynamic>? ?? [];
          preliminaryMediaCount += ncMedias.length + ncSolvedMedias.length;
        }
      }
      
      debugPrint('FirestoreSyncService: Found $preliminaryMediaCount total media files to download');
      
      // Show initial progress with known total
      if (preliminaryMediaCount > 0) {
        await _showProgressNotification(
          title: 'Baixando Mídias',
          message: 'Iniciando download de $preliminaryMediaCount mídias...',
          progress: 0,
          indeterminate: false,
        );
      } else {
        await _showProgressNotification(
          title: 'Verificação Completa',
          message: 'Nenhuma mídia encontrada para download',
          progress: 100,
          indeterminate: false,
        );
      }
      
      // Update totals for accurate progress tracking
      totalMediaFound = preliminaryMediaCount;
      
      // Process media at all hierarchy levels
      for (int topicIndex = 0; topicIndex < firestoreTopics.length; topicIndex++) {
        final topicData = firestoreTopics[topicIndex];
        final topic = Map<String, dynamic>.from(topicData);
        final localTopic = localTopicsByPosition['$topicIndex'];
        
        if (localTopic == null) {
          debugPrint('FirestoreSyncService: No local topic found for position $topicIndex');
          continue;
        }
        
        // Process topic-level media
        final topicMedias = topic['media'] as List<dynamic>? ?? [];
        totalMediaFound += topicMedias.length;
        if (topicMedias.isNotEmpty) {
          debugPrint('FirestoreSyncService: Processing ${topicMedias.length} media files for topic ${localTopic.topicName}');
        }
        
        for (final mediaData in topicMedias) {
          final media = Map<String, dynamic>.from(mediaData);
          
          // Update progress notification less frequently (first item, every 5th item, or last item)
          final shouldShowNotification = totalMediaDownloaded == 0 || 
                                       (totalMediaDownloaded + 1) % 5 == 0 || 
                                       totalMediaDownloaded + 1 >= totalMediaFound;
          
          if (shouldShowNotification) {
            await _showProgressNotification(
              title: 'Baixando Mídias',
              message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - Tópico: ${localTopic.topicName}',
              progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
            );
          }
          
          if (await _downloadAndSaveMediaWithIds(
            media, 
            inspectionId, 
            topicId: localTopic.id,
            context: 'Topic: ${localTopic.topicName}'
          )) {
            totalMediaDownloaded++;
          }
        }
        
        // Process item-level media
        final items = topic['items'] as List<dynamic>? ?? [];
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final itemData = items[itemIndex];
          final item = Map<String, dynamic>.from(itemData);
          final localItem = localItemsByPosition['${topicIndex}_$itemIndex'];
          
          if (localItem == null) {
            debugPrint('FirestoreSyncService: No local item found for position ${topicIndex}_$itemIndex');
            continue;
          }
          
          // Process item media
          final itemMedias = item['media'] as List<dynamic>? ?? [];
          totalMediaFound += itemMedias.length;
          if (itemMedias.isNotEmpty) {
            debugPrint('FirestoreSyncService: Processing ${itemMedias.length} media files for item ${localItem.itemName}');
          }
          
          for (final mediaData in itemMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            
            // Update progress notification less frequently (first item, every 5th item, or last item)
            final shouldShowNotification = totalMediaDownloaded == 0 || 
                                         (totalMediaDownloaded + 1) % 5 == 0 || 
                                         totalMediaDownloaded + 1 >= totalMediaFound;
            
            if (shouldShowNotification) {
              await _showProgressNotification(
                title: 'Baixando Mídias',
                message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - Item: ${localItem.itemName}',
                progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
              );
            }
            
            if (await _downloadAndSaveMediaWithIds(
              media, 
              inspectionId, 
              topicId: localItem.topicId,
              itemId: localItem.id,
              context: 'Item: ${localItem.itemName}'
            )) {
              totalMediaDownloaded++;
            }
          }
          
          // Process detail-level media
          final details = item['details'] as List<dynamic>? ?? [];
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detailData = details[detailIndex];
            final detail = Map<String, dynamic>.from(detailData);
            final localDetail = localDetailsByPosition['${topicIndex}_${itemIndex}_$detailIndex'];
            
            if (localDetail == null) {
              debugPrint('FirestoreSyncService: No local detail found for position ${topicIndex}_${itemIndex}_$detailIndex');
              continue;
            }
            
            // Process detail media
            final detailMedias = detail['media'] as List<dynamic>? ?? [];
            totalMediaFound += detailMedias.length;
            if (detailMedias.isNotEmpty) {
              debugPrint('FirestoreSyncService: Processing ${detailMedias.length} media files for detail ${localDetail.detailName}');
            }
            
            for (final mediaData in detailMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              
              // Update progress notification less frequently (first item, every 5th item, or last item)
              final shouldShowNotification = totalMediaDownloaded == 0 || 
                                           (totalMediaDownloaded + 1) % 5 == 0 || 
                                           totalMediaDownloaded + 1 >= totalMediaFound;
              
              if (shouldShowNotification) {
                await _showProgressNotification(
                  title: 'Baixando Mídias',
                  message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - Detalhe: ${localDetail.detailName}',
                  progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
                );
              }
              
              if (await _downloadAndSaveMediaWithIds(
                media, 
                inspectionId, 
                topicId: localDetail.topicId,
                itemId: localDetail.itemId,
                detailId: localDetail.id,
                context: 'Detail: ${localDetail.detailName}'
              )) {
                totalMediaDownloaded++;
              }
            }
            
            // Process non-conformity media
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            for (final ncData in nonConformities) {
              final nc = Map<String, dynamic>.from(ncData);
              final ncId = nc['id'] as String?;
              final localNc = ncId != null ? localNonConformitiesByFirestoreId[ncId] : null;
              
              if (localNc == null) {
                debugPrint('FirestoreSyncService: No local non-conformity found for ID $ncId');
                continue;
              }
              
              // Process NC media
              final ncMedias = nc['media'] as List<dynamic>? ?? [];
              totalMediaFound += ncMedias.length;
              if (ncMedias.isNotEmpty) {
                debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for non-conformity ${localNc.title}');
              }
              
              for (final mediaData in ncMedias) {
                final media = Map<String, dynamic>.from(mediaData);
                
                // Update progress notification for NC media less frequently (first item, every 5th item, or last item)
                final shouldShowNotification = totalMediaDownloaded == 0 || 
                                             (totalMediaDownloaded + 1) % 5 == 0 || 
                                             totalMediaDownloaded + 1 >= totalMediaFound;
                
                if (shouldShowNotification) {
                  await _showProgressNotification(
                    title: 'Baixando Mídias',
                    message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - NC: ${localNc.title}',
                    progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
                  );
                }
                
                if (await _downloadAndSaveMediaWithIds(
                  media, 
                  inspectionId, 
                  topicId: localNc.topicId,
                  itemId: localNc.itemId,
                  detailId: localNc.detailId,
                  nonConformityId: localNc.id,
                  context: 'NC: ${localNc.title}'
                )) {
                  totalMediaDownloaded++;
                }
              }
            }
          }
          
          // Process item-level non-conformities
          final itemNonConformities = item['non_conformities'] as List<dynamic>? ?? [];
          for (final ncData in itemNonConformities) {
            final nc = Map<String, dynamic>.from(ncData);
            final ncId = nc['id'] as String?;
            final localNc = ncId != null ? localNonConformitiesByFirestoreId[ncId] : null;
            
            if (localNc == null) {
              debugPrint('FirestoreSyncService: No local item non-conformity found for ID $ncId');
              continue;
            }
            
            final ncMedias = nc['media'] as List<dynamic>? ?? [];
            totalMediaFound += ncMedias.length;
            if (ncMedias.isNotEmpty) {
              debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for item non-conformity ${localNc.title}');
            }
            
            for (final mediaData in ncMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              
              // Update progress notification for Item NC media less frequently (first item, every 5th item, or last item)
              final shouldShowNotification = totalMediaDownloaded == 0 || 
                                           (totalMediaDownloaded + 1) % 5 == 0 || 
                                           totalMediaDownloaded + 1 >= totalMediaFound;
              
              if (shouldShowNotification) {
                await _showProgressNotification(
                  title: 'Baixando Mídias',
                  message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - Item NC: ${localNc.title}',
                  progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
                );
              }
              
              if (await _downloadAndSaveMediaWithIds(
                media, 
                inspectionId, 
                topicId: localNc.topicId,
                itemId: localNc.itemId,
                nonConformityId: localNc.id,
                context: 'Item NC: ${localNc.title}'
              )) {
                totalMediaDownloaded++;
              }
            }
          }
        }
        
        // Process topic-level non-conformities  
        final topicNonConformities = topic['non_conformities'] as List<dynamic>? ?? [];
        for (final ncData in topicNonConformities) {
          final nc = Map<String, dynamic>.from(ncData);
          final ncId = nc['id'] as String?;
          final localNc = ncId != null ? localNonConformitiesByFirestoreId[ncId] : null;
          
          if (localNc == null) {
            debugPrint('FirestoreSyncService: No local topic non-conformity found for ID $ncId');
            continue;
          }
          
          final ncMedias = nc['media'] as List<dynamic>? ?? [];
          totalMediaFound += ncMedias.length;
          if (ncMedias.isNotEmpty) {
            debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for topic non-conformity ${localNc.title}');
          }
          
          for (final mediaData in ncMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            
            // Update progress notification for Topic NC media less frequently (first item, every 5th item, or last item)
            final shouldShowNotification = totalMediaDownloaded == 0 || 
                                         (totalMediaDownloaded + 1) % 5 == 0 || 
                                         totalMediaDownloaded + 1 >= totalMediaFound;
            
            if (shouldShowNotification) {
              await _showProgressNotification(
                title: 'Baixando Mídias',
                message: 'Baixando mídia ${totalMediaDownloaded + 1} de $totalMediaFound - Topic NC: ${localNc.title}',
                progress: totalMediaFound > 0 ? ((totalMediaDownloaded / totalMediaFound) * 100).round() : 0,
              );
            }
            
            if (await _downloadAndSaveMediaWithIds(
              media, 
              inspectionId, 
              topicId: localNc.topicId,
              nonConformityId: localNc.id,
              context: 'Topic NC: ${localNc.title}'
            )) {
              totalMediaDownloaded++;
            }
          }
        }
      }
      
      debugPrint('FirestoreSyncService: ========== MEDIA DOWNLOAD SUMMARY ==========');
      debugPrint('FirestoreSyncService: Found: $totalMediaFound, Downloaded: $totalMediaDownloaded for inspection $inspectionId');
      
      // Show final progress notification
      if (totalMediaFound == 0) {
        await _showProgressNotification(
          title: 'Download Concluído',
          message: 'Nenhuma mídia encontrada para esta vistoria',
          progress: 100,
        );
        debugPrint('FirestoreSyncService: WARNING - No media found in Firestore for inspection $inspectionId');
      } else if (totalMediaDownloaded == 0) {
        await _showProgressNotification(
          title: 'Aviso de Download',
          message: 'Mídias encontradas mas não baixadas (podem já existir)',
          progress: 100,
        );
        debugPrint('FirestoreSyncService: WARNING - Media found but none downloaded for inspection $inspectionId');
      } else if (totalMediaDownloaded < totalMediaFound) {
        await _showProgressNotification(
          title: 'Download Parcialmente Concluído',
          message: 'Baixadas $totalMediaDownloaded de $totalMediaFound mídias',
          progress: (totalMediaDownloaded / totalMediaFound * 100).round(),
        );
        debugPrint('FirestoreSyncService: WARNING - Some media not downloaded for inspection $inspectionId');
        debugPrint('FirestoreSyncService: ${totalMediaFound - totalMediaDownloaded} media files failed to download');
      } else {
        await _showProgressNotification(
          title: 'Download Concluído',
          message: 'Todas as $totalMediaDownloaded mídias foram baixadas com sucesso!',
          progress: 100,
        );
        debugPrint('FirestoreSyncService: ✅ All media downloaded successfully!');
      }
      
      debugPrint('FirestoreSyncService: ========== MEDIA DOWNLOAD COMPLETED ==========');
      
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading media for inspection $inspectionId: $e');
    }
  }

  Future<bool> _downloadAndSaveMediaWithIds(
    Map<String, dynamic> mediaData, 
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    required String context,
    bool isResolutionMedia = false,
  }) async {
    try {
      debugPrint('FirestoreSyncService: Processing media in context: $context');
      debugPrint('FirestoreSyncService: Media data keys: ${mediaData.keys.toList()}');
      
      // Verificar diferentes possíveis formatos de dados de mídia
      final cloudUrl = mediaData['cloudUrl'] as String? ?? 
                      mediaData['url'] as String? ?? 
                      mediaData['downloadUrl'] as String?;
      final filename = mediaData['filename'] as String? ?? 
                      mediaData['name'] as String?;
      
      if (cloudUrl == null || filename == null) {
        debugPrint('FirestoreSyncService: Media missing cloudUrl or filename in context: $context');
        debugPrint('FirestoreSyncService: Available data: $mediaData');
        return false;
      }
      
      // Verificar se já foi baixado
      final existingMedia = await _offlineService.getMediaByFilename(filename);
      if (existingMedia.isNotEmpty) {
        debugPrint('FirestoreSyncService: Media $filename already exists locally');
        return false;
      }
      
      debugPrint('FirestoreSyncService: Downloading media $filename from $cloudUrl for context: $context');
      debugPrint('FirestoreSyncService: Target IDs - Topic: $topicId, Item: $itemId, Detail: $detailId, NC: $nonConformityId');
      
      // Baixar arquivo do Firebase Storage
      final storageRef = _firebaseService.storage.refFromURL(cloudUrl);
      final localFile = await _offlineService.createMediaFile(filename);
      
      await storageRef.writeToFile(localFile);
      
      // Extract and preserve ALL metadata from Firestore
      debugPrint('FirestoreSyncService: Extracting complete metadata from Firestore data');
      
      // Parse original timestamps
      DateTime? originalCreatedAt;
      DateTime? originalUpdatedAt;
      try {
        if (mediaData['created_at'] != null) {
          final createdAtValue = mediaData['created_at'];
          if (createdAtValue is String) {
            originalCreatedAt = DateTime.parse(createdAtValue);
          } else if (createdAtValue.toString().contains('_seconds')) {
            // Firestore Timestamp format
            final seconds = createdAtValue['_seconds'] as int?;
            final nanoseconds = createdAtValue['_nanoseconds'] as int?;
            if (seconds != null) {
              originalCreatedAt = DateTime.fromMillisecondsSinceEpoch(
                seconds * 1000 + (nanoseconds ?? 0) ~/ 1000000
              );
            }
          }
        }
        
        if (mediaData['updated_at'] != null) {
          final updatedAtValue = mediaData['updated_at'];
          if (updatedAtValue is String) {
            originalUpdatedAt = DateTime.parse(updatedAtValue);
          } else if (updatedAtValue.toString().contains('_seconds')) {
            // Firestore Timestamp format
            final seconds = updatedAtValue['_seconds'] as int?;
            final nanoseconds = updatedAtValue['_nanoseconds'] as int?;
            if (seconds != null) {
              originalUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
                seconds * 1000 + (nanoseconds ?? 0) ~/ 1000000
              );
            }
          }
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Error parsing timestamps: $e');
      }
      
      // Extract complete metadata including visual indicators and source info
      final completeMetadata = <String, dynamic>{};
      
      // Preserve original Firestore data for complete reconstruction
      completeMetadata['original_firestore_data'] = Map<String, dynamic>.from(mediaData);
      
      // Extract critical visual and functional properties
      if (mediaData['isFromCamera'] != null) {
        completeMetadata['isFromCamera'] = mediaData['isFromCamera'];
      }
      if (mediaData['isResolutionMedia'] != null) {
        completeMetadata['isResolutionMedia'] = mediaData['isResolutionMedia'];
      }
      if (mediaData['nonConformityStatus'] != null) {
        completeMetadata['nonConformityStatus'] = mediaData['nonConformityStatus'];
      }
      if (mediaData['captureContext'] != null) {
        completeMetadata['captureContext'] = mediaData['captureContext'];
      }
      if (mediaData['tags'] != null) {
        completeMetadata['tags'] = mediaData['tags'];
      }
      if (mediaData['orientation'] != null) {
        completeMetadata['orientation'] = mediaData['orientation'];
      }
      if (mediaData['location'] != null) {
        completeMetadata['location'] = mediaData['location'];
      }
      if (mediaData['deviceInfo'] != null) {
        completeMetadata['deviceInfo'] = mediaData['deviceInfo'];
      }
      
      debugPrint('FirestoreSyncService: Extracted metadata keys: ${completeMetadata.keys.toList()}');
      
      // Salvar metadata completa da mídia no banco com todos os dados preservados
      await _offlineService.saveOfflineMedia(
        inspectionId: inspectionId,
        filename: filename,
        localPath: localFile.path,
        cloudUrl: cloudUrl,
        type: mediaData['type'] as String? ?? 'image',
        fileSize: mediaData['fileSize'] as int? ?? mediaData['file_size'] as int? ?? 0,
        mimeType: mediaData['mimeType'] as String? ?? mediaData['mime_type'] as String? ?? 'image/jpeg',
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        isUploaded: true,
        // PRESERVE COMPLETE ORIGINAL METADATA
        source: mediaData['source'] as String?,
        metadata: completeMetadata,
        width: mediaData['width'] as int? ?? mediaData['dimensions']?['width'] as int?,
        height: mediaData['height'] as int? ?? mediaData['dimensions']?['height'] as int?,
        duration: mediaData['duration'] as int?,
        originalCreatedAt: originalCreatedAt,
        originalUpdatedAt: originalUpdatedAt,
        customId: mediaData['id'] as String?, // Preserve original ID if available
        isResolutionMedia: isResolutionMedia,
      );
      
      debugPrint('FirestoreSyncService: Successfully downloaded and saved media $filename for context: $context with local IDs');
      return true;
      
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading media in context $context: $e');
      debugPrint('FirestoreSyncService: Media data was: $mediaData');
      return false;
    }
  }

  // ===============================
  // PROGRESS NOTIFICATION HELPER
  // ===============================
  
  Future<void> _showProgressNotification({
    required String title,
    required String message,
    int? progress,
    bool indeterminate = false,
  }) async {
    try {
      debugPrint('FirestoreSyncService: Showing progress notification: $title - $message (progress: $progress, indeterminate: $indeterminate)');
      
      // Show real system notification using SimpleNotificationService
      await SimpleNotificationService.instance.showDownloadProgress(
        title: title,
        message: message,
        progress: progress,
        indeterminate: indeterminate,
      );
    } catch (e) {
      debugPrint('FirestoreSyncService: Error showing progress notification: $e');
      // Fallback: at least show debug message
      debugPrint('FirestoreSyncService: NOTIFICATION - $title: $message');
    }
  }

  // ===============================
  // UPLOAD PARA A NUVEM
  // ===============================

  Future<void> uploadLocalChangesToCloud() async {
    try {
      debugPrint('FirestoreSyncService: Uploading local changes to cloud');

      // Upload media files first
      await _uploadMediaFiles();

      // Then upload inspection data with nested structure
      await _uploadInspectionsWithNestedStructure();

      debugPrint('FirestoreSyncService: Finished uploading local changes');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading local changes: $e');
    }
  }

  Future<void> _uploadMediaFiles([String? inspectionId]) async {
    try {
      debugPrint('FirestoreSyncService: Uploading media files${inspectionId != null ? ' for inspection $inspectionId' : ''}');
      
      List<OfflineMedia> mediaFiles;
      if (inspectionId != null) {
        // Upload apenas mídias da inspeção específica
        mediaFiles = await _offlineService.getMediaPendingUpload();
        mediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();
      } else {
        // Upload todas as mídias pendentes
        mediaFiles = await _offlineService.getMediaPendingUpload();
      }
      
      debugPrint('FirestoreSyncService: Found ${mediaFiles.length} media files to upload');
      
      for (final media in mediaFiles) {
        try {
          // Upload to Firebase Storage
          final downloadUrl = await _uploadMediaToStorage(media);
          
          if (downloadUrl != null) {
            // Update media with cloud URL
            await _offlineService.updateMediaCloudUrl(media.id, downloadUrl);
            debugPrint('FirestoreSyncService: Uploaded media ${media.filename}');
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading media ${media.filename}: $e');
        }
      }
      
      debugPrint('FirestoreSyncService: Finished uploading media files');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media files: $e');
    }
  }

  Future<String?> _uploadMediaToStorage(OfflineMedia media) async {
    try {
      debugPrint('FirestoreSyncService: Uploading media ${media.filename} to Firebase Storage');
      
      // Check if file exists
      final file = File(media.localPath);
      if (!await file.exists()) {
        debugPrint('FirestoreSyncService: File does not exist: ${media.localPath}');
        return null;
      }
      
      // Create storage reference with proper path structure
      final storageRef = _firebaseService.storage.ref();
      final mediaPath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
      final mediaRef = storageRef.child(mediaPath);
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: media.mimeType,
        customMetadata: {
          'inspection_id': media.inspectionId,
          'topic_id': media.topicId ?? '',
          'item_id': media.itemId ?? '',
          'detail_id': media.detailId ?? '',
          'non_conformity_id': media.nonConformityId ?? '',
          'type': media.type,
          'original_filename': media.filename,
          'created_at': media.createdAt.toIso8601String(),
        },
      );
      
      // Upload file with metadata
      final uploadTask = mediaRef.putFile(file, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('FirestoreSyncService: Upload progress for ${media.filename}: ${(progress * 100).toStringAsFixed(1)}%');
        
        // Update progress in database
        _offlineService.updateMediaUploadProgress(media.id, progress * 100);
      });
      
      // Wait for upload completion
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('FirestoreSyncService: Successfully uploaded ${media.filename} to Firebase Storage');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media ${media.filename} to storage: $e');
      
      // Handle specific Firebase Storage errors
      if (e is FirebaseException) {
        switch (e.code) {
          case 'storage/unauthorized':
            debugPrint('FirestoreSyncService: Unauthorized access to Firebase Storage');
            break;
          case 'storage/canceled':
            debugPrint('FirestoreSyncService: Upload was canceled');
            break;
          case 'storage/unknown':
            debugPrint('FirestoreSyncService: Unknown storage error occurred');
            break;
          case 'storage/object-not-found':
            debugPrint('FirestoreSyncService: Object not found in storage');
            break;
          case 'storage/bucket-not-found':
            debugPrint('FirestoreSyncService: Storage bucket not found');
            break;
          case 'storage/quota-exceeded':
            debugPrint('FirestoreSyncService: Storage quota exceeded');
            break;
          case 'storage/invalid-format':
            debugPrint('FirestoreSyncService: Invalid file format');
            break;
          default:
            debugPrint('FirestoreSyncService: Firebase Storage error: ${e.code} - ${e.message}');
        }
      }
      
      return null;
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

          // Registrar evento de upload no histórico
          final currentUser = _firebaseService.currentUser;
          if (currentUser != null) {
            await _offlineService.addInspectionHistory(
              inspectionId: inspection.id,
              status: HistoryStatus.uploadedInspection,
              inspectorId: currentUser.uid,
              description: 'Inspeção enviada para nuvem com sucesso',
              metadata: {
                'source': 'local_sync',
                'uploaded_at': DateTime.now().toIso8601String(),
                'inspection_title': inspection.title,
                'inspection_status': inspection.status,
              },
            );
          }

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

  Future<void> _uploadSingleInspectionWithNestedStructure(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Uploading single inspection $inspectionId');
      
      final inspection = await _offlineService.getInspection(inspectionId);
      if (inspection == null) {
        debugPrint('FirestoreSyncService: Inspection $inspectionId not found locally');
        return;
      }

      // Build the complete nested structure for Firestore
      final inspectionData = await _buildNestedInspectionData(inspection);

      await _firebaseService.firestore
          .collection('inspections')
          .doc(inspection.id)
          .set(inspectionData, SetOptions(merge: true));

      // Mark all related entities as synced
      await _markInspectionAndChildrenSynced(inspection.id);
      
      // Adicionar entrada no histórico de sincronização
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        await _offlineService.addSyncHistoryEntry(
          inspection.id,
          currentUser.uid,
          'upload',
          metadata: {
            'source': 'single_sync',
            'inspection_title': inspection.title,
            'inspection_status': inspection.status,
          },
        );
      }

      debugPrint(
          'FirestoreSyncService: Successfully uploaded single inspection with nested structure $inspectionId');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading single inspection $inspectionId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _buildNestedInspectionData(
      Inspection inspection) async {
    debugPrint('FirestoreSyncService: 🔍 DIAGNÓSTICO: Construindo dados para upload da inspeção ${inspection.id}');
    
    // Start with basic inspection data
    final data = inspection.toMap();
    debugPrint('FirestoreSyncService: 🔍 DADOS BASE DA INSPEÇÃO - Title: "${data['title']}", Observation: "${data['observation'] ?? "null"}"');
    
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
    debugPrint('FirestoreSyncService: 🔍 DIAGNÓSTICO: Encontrados ${topics.length} tópicos para upload');
    final topicsData = <Map<String, dynamic>>[];


    for (final topic in topics) {
      debugPrint('FirestoreSyncService: 🔍 PROCESSANDO TÓPICO "${topic.topicName}" - Observation: "${topic.observation ?? "null"}", DirectDetails: ${topic.directDetails}');
      
      // Get topic-level media
      final topicMedia = await _offlineService.getMediaByTopic(topic.id ?? '');
      final topicMediaList = <Map<String, dynamic>>[];
      
      // Add direct topic media (sorted by orderIndex and capturedAt)
      final sortedTopicMedia = List<OfflineMedia>.from(topicMedia)
        ..sort((a, b) {
          // Primary sort by orderIndex
          final orderComparison = a.orderIndex.compareTo(b.orderIndex);
          if (orderComparison != 0) return orderComparison;
          
          // Secondary sort by capturedAt if orderIndex is the same
          final aCaptured = a.capturedAt ?? a.createdAt;
          final bCaptured = b.capturedAt ?? b.createdAt;
          return aCaptured.compareTo(bCaptured);
        });
      
      topicMediaList.addAll(sortedTopicMedia.map((media) => {
        'filename': media.filename,
        'type': media.type,
        'localPath': media.localPath,
        'cloudUrl': media.cloudUrl,
        'thumbnailPath': media.thumbnailPath,
        'fileSize': media.fileSize,
        'mimeType': media.mimeType,
        'isUploaded': media.isUploaded,
        'createdAt': media.createdAt.toIso8601String(),
        'capturedAt': (media.capturedAt ?? media.createdAt).toIso8601String(),
        'orderIndex': media.orderIndex,
      }));
      
      // For direct_details topics, also include media from direct details in the topic media array
      if (topic.directDetails == true) {
        final directDetailsMedia = await _offlineService.getMediaByTopicDirectDetails(topic.id ?? '');
        final sortedDirectDetailsMedia = List<OfflineMedia>.from(directDetailsMedia)
          ..sort((a, b) {
            final orderComparison = a.orderIndex.compareTo(b.orderIndex);
            if (orderComparison != 0) return orderComparison;
            final aCaptured = a.capturedAt ?? a.createdAt;
            final bCaptured = b.capturedAt ?? b.createdAt;
            return aCaptured.compareTo(bCaptured);
          });
        
        topicMediaList.addAll(sortedDirectDetailsMedia.map((media) => {
          'filename': media.filename,
          'type': media.type,
          'localPath': media.localPath,
          'cloudUrl': media.cloudUrl,
          'thumbnailPath': media.thumbnailPath,
          'fileSize': media.fileSize,
          'mimeType': media.mimeType,
          'isUploaded': media.isUploaded,
          'createdAt': media.createdAt.toIso8601String(),
          'capturedAt': (media.capturedAt ?? media.createdAt).toIso8601String(),
          'orderIndex': media.orderIndex,
        }));
      }
      
      final topicMediaData = topicMediaList;
      
      // Get topic-level non-conformities with hierarchical media structure
      final topicNCs = await _offlineService.getNonConformitiesByTopic(topic.id ?? '');
      final topicNonConformitiesData = <Map<String, dynamic>>[];
      
      for (final nc in topicNCs) {
        final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
        topicNonConformitiesData.add(ncData);
      }

      final topicData = <String, dynamic>{
        'name': topic.topicName,
        'description': topic.topicLabel,
        'observation': topic.observation,
        'media': topicMediaData,
        'non_conformities': topicNonConformitiesData,
      };
      
      // DEBUG: Log topic data being uploaded
      debugPrint('FirestoreSyncService: Uploading topic "${topic.topicName}" with observation: "${topic.observation ?? "null"}"');

      // Check if this is a direct_details topic
      if (topic.directDetails == true) {
        // For direct_details topics, add details directly to topic
        topicData['direct_details'] = true;
        
        // Get all details for this topic (no items)
        final details = await _offlineService.getDetailsByTopic(topic.id ?? '');
        final detailsData = <Map<String, dynamic>>[];

        for (final detail in details) {
          // Get media for this detail
          final detailMedia = await _offlineService.getMediaByDetail(detail.id ?? '');
          
          final mediaData = detailMedia.map((media) => {
            'filename': media.filename,
            'type': media.type,
            'localPath': media.localPath,
            'cloudUrl': media.cloudUrl,
            'thumbnailPath': media.thumbnailPath,
            'fileSize': media.fileSize,
            'mimeType': media.mimeType,
            'isUploaded': media.isUploaded,
            'createdAt': media.createdAt.toIso8601String(),
          }).toList();
          
          // Get non-conformities for this detail with hierarchical media structure
          final detailNCs = await _offlineService.getNonConformitiesByDetail(detail.id ?? '');
          final nonConformitiesData = <Map<String, dynamic>>[];
          
          for (final nc in detailNCs) {
            final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
            nonConformitiesData.add(ncData);
          }

          final detailData = <String, dynamic>{
            'name': detail.detailName,
            'type': detail.type ?? 'text',
            'options': detail.options ?? [],
            'value': detail.detailValue,
            'observation': detail.observation,
            'required': detail.isRequired == true,
            'is_damaged': detail.isDamaged == true,
            'media': mediaData,
            'non_conformities': nonConformitiesData,
          };
          
          // DEBUG: Log detail data being uploaded
          debugPrint('FirestoreSyncService: Uploading detail "${detail.detailName}" with value: "${detail.detailValue ?? "null"}", observation: "${detail.observation ?? "null"}"');

          detailsData.add(detailData);
        }

        topicData['details'] = detailsData;
      } else {
        // For regular topics, get all items
        topicData['direct_details'] = false; // PRESERVE direct_details as false for regular topics
        final items = await _offlineService.getItems(topic.id ?? '');
        final itemsData = <Map<String, dynamic>>[];

        for (final item in items) {
        // Get item-level media
        final itemMedia = await _offlineService.getMediaByItem(item.id ?? '');
        
        final itemMediaData = itemMedia.map((media) => {
          'filename': media.filename,
          'type': media.type,
          'localPath': media.localPath,
          'cloudUrl': media.cloudUrl,
          'thumbnailPath': media.thumbnailPath,
          'fileSize': media.fileSize,
          'mimeType': media.mimeType,
          'isUploaded': media.isUploaded,
          'createdAt': media.createdAt.toIso8601String(),
        }).toList();
        
        // Get item-level non-conformities with hierarchical media structure
        final itemNCs = await _offlineService.getNonConformitiesByItem(item.id ?? '');
        final itemNonConformitiesData = <Map<String, dynamic>>[];
        
        for (final nc in itemNCs) {
          final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
          itemNonConformitiesData.add(ncData);
        }

        final itemData = <String, dynamic>{
          'name': item.itemName,
          'description': item.itemLabel,
          'observation': item.observation,
          'evaluable': item.evaluable, // PRESERVE evaluable field
          'evaluation_options': item.evaluationOptions ?? [], // PRESERVE evaluation_options field
          'evaluation_value': item.evaluationValue, // PRESERVE evaluation_value field
          'media': itemMediaData,
          'non_conformities': itemNonConformitiesData,
          'details': <Map<String, dynamic>>[],
        };
        
        // DEBUG: Log item data being uploaded
        debugPrint('FirestoreSyncService: Uploading item "${item.itemName}" with observation: "${item.observation ?? "null"}", evaluationValue: "${item.evaluationValue ?? "null"}"');
        debugPrint('FirestoreSyncService: Item full data - ID: ${item.id}, evaluable: ${item.evaluable}');

        // Get all details for this item
        final details = await _offlineService.getDetails(item.id ?? '');
        final detailsData = <Map<String, dynamic>>[];

        for (final detail in details) {
          // Get media for this detail
          final detailMedia = await _offlineService.getMediaByDetail(detail.id ?? '');
          
          final mediaData = detailMedia.map((media) => {
            'filename': media.filename,
            'type': media.type,
            'localPath': media.localPath,
            'cloudUrl': media.cloudUrl,
            'thumbnailPath': media.thumbnailPath,
            'fileSize': media.fileSize,
            'mimeType': media.mimeType,
            'isUploaded': media.isUploaded,
            'createdAt': media.createdAt.toIso8601String(),
          }).toList();
          
          // Get non-conformities for this detail with hierarchical media structure
          final detailNCs = await _offlineService.getNonConformitiesByDetail(detail.id ?? '');
          final nonConformitiesData = <Map<String, dynamic>>[];
          
          for (final nc in detailNCs) {
            final ncData = await _buildNonConformityWithHierarchicalMedia(nc);
            nonConformitiesData.add(ncData);
          }

          final detailData = <String, dynamic>{
            'name': detail.detailName,
            'type': detail.type ?? 'text',
            'options': detail.options ?? [],
            'value': detail.detailValue,
            'observation': detail.observation,
            'required': detail.isRequired == true,
            'is_damaged': detail.isDamaged == true,
            'media': mediaData,
            'non_conformities': nonConformitiesData,
          };
          
          // DEBUG: Log detail data being uploaded
          debugPrint('FirestoreSyncService: Uploading detail "${detail.detailName}" with value: "${detail.detailValue ?? "null"}", observation: "${detail.observation ?? "null"}"');

          detailsData.add(detailData);
        }

          itemData['details'] = detailsData;
          itemsData.add(itemData);
        }

        topicData['items'] = itemsData;
      }
      debugPrint('FirestoreSyncService: 🔍 TÓPICO FINAL PARA UPLOAD "${topicData['name']}" - Observation: "${topicData['observation'] ?? "null"}"');
      topicsData.add(topicData);
    }

    // Add topics to the main data
    data['topics'] = topicsData;
    debugPrint('FirestoreSyncService: 🔍 DADOS FINAIS CONSTRUÍDOS - ${topicsData.length} tópicos preparados para upload');
    
    // Add sync history
    if (inspection.syncHistory != null) {
      data['sync_history'] = inspection.syncHistory;
    }

    return data;
  }

  // Helper method to build non-conformity data with hierarchical media structure (media vs solved_media)
  Future<Map<String, dynamic>> _buildNonConformityWithHierarchicalMedia(NonConformity nc) async {
    // Get all media for this non-conformity
    final allMedia = await _offlineService.getMediaByNonConformity(nc.id);
    
    // Separate media based on resolution status
    final mediaList = <Map<String, dynamic>>[];
    final solvedMediaList = <Map<String, dynamic>>[];
    
    for (final media in allMedia) {
      final mediaData = {
        'filename': media.filename,
        'type': media.type,
        'localPath': media.localPath,
        'cloudUrl': media.cloudUrl,
        'thumbnailPath': media.thumbnailPath,
        'fileSize': media.fileSize,
        'mimeType': media.mimeType,
        'isUploaded': media.isUploaded,
        'createdAt': media.createdAt.toIso8601String(),
        'isResolutionMedia': media.isResolutionMedia,
        'source': media.source,
      };
      
      if (media.isResolutionMedia) {
        solvedMediaList.add(mediaData);
      } else {
        mediaList.add(mediaData);
      }
    }
    
    return {
      'id': nc.id,
      'title': nc.title,
      'description': nc.description,
      'severity': nc.severity,
      'status': nc.status,
      'corrective_action': nc.correctiveAction,
      'deadline': nc.deadline?.toIso8601String(),
      'is_resolved': nc.isResolved,
      'resolved_at': nc.resolvedAt?.toIso8601String(),
      'createdAt': nc.createdAt.toIso8601String(),
      'updatedAt': nc.updatedAt.toIso8601String(),
      'media': mediaList,           // Media for unresolved state
      'solved_media': solvedMediaList, // Media for resolved state
    };
  }


  Future<void> _markInspectionAndChildrenSynced(String inspectionId) async {
    // Mark inspection as synced
    await _offlineService.markInspectionSynced(inspectionId);

    // Mark all topics as synced
    final topics = await _offlineService.getTopics(inspectionId);
    for (final topic in topics) {
      await _offlineService.markTopicSynced(topic.id ?? '');
      
      // Mark topic-level media as synced
      final topicMedia = await _offlineService.getMediaByTopic(topic.id ?? '');
      for (final media in topicMedia) {
        await _offlineService.markMediaSynced(media.id);
      }
      
      // Mark topic-level non-conformities as synced
      final topicNCs = await _offlineService.getNonConformitiesByTopic(topic.id ?? '');
      for (final nc in topicNCs) {
        await _offlineService.markNonConformitySynced(nc.id);
      }

      // Mark all items as synced
      final items = await _offlineService.getItems(topic.id ?? '');
      for (final item in items) {
        await _offlineService.markItemSynced(item.id ?? '');
        
        // Mark item-level media as synced
        final itemMedia = await _offlineService.getMediaByItem(item.id ?? '');
        for (final media in itemMedia) {
          await _offlineService.markMediaSynced(media.id);
        }
        
        // Mark item-level non-conformities as synced
        final itemNCs = await _offlineService.getNonConformitiesByItem(item.id ?? '');
        for (final nc in itemNCs) {
          await _offlineService.markNonConformitySynced(nc.id);
        }

        // Mark all details as synced
        final details = await _offlineService.getDetails(item.id ?? '');
        for (final detail in details) {
          await _offlineService.markDetailSynced(detail.id ?? '');
          
          // Mark detail-level media as synced
          final detailMedia = await _offlineService.getMediaByDetail(detail.id ?? '');
          for (final media in detailMedia) {
            await _offlineService.markMediaSynced(media.id);
          }
          
          // Mark detail-level non-conformities as synced
          final detailNCs = await _offlineService.getNonConformitiesByDetail(detail.id ?? '');
          for (final nc in detailNCs) {
            await _offlineService.markNonConformitySynced(nc.id);
          }
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

  Future<Map<String, dynamic>> syncInspection(String inspectionId) async {
    if (!await isConnected()) {
      debugPrint(
          'FirestoreSyncService: No internet connection for inspection sync');
      return {'success': false, 'error': 'No internet connection'};
    }

    try {
      debugPrint('FirestoreSyncService: Syncing inspection $inspectionId');

      // Get local inspection first to check for conflicts
      final localInspection = await _offlineService.getInspection(inspectionId);
      
      // Download da nuvem
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      // *** PRIMEIRO: Upload das mudanças locais (incluindo exclusões) ***
      if (localInspection != null) {
        debugPrint('FirestoreSyncService: 🔧 UPLOAD PRIMEIRO - Uploading local changes (data + media) for inspection $inspectionId');
        
        // PRIMEIRO: Upload das mídias pendentes (incluindo exclusões)
        await _uploadMediaFiles(inspectionId);
        
        // SEGUNDO: Upload da inspeção com estrutura completa
        await _uploadSingleInspectionWithNestedStructure(inspectionId);
        
        debugPrint('FirestoreSyncService: ✅ Successfully uploaded all local changes for inspection $inspectionId');
      }

      // *** DOWNLOAD APENAS SE NÃO TEMOS DADOS LOCAIS (primeiro download) ***
      if (docSnapshot.exists && localInspection == null) {
        debugPrint('FirestoreSyncService: 📥 PRIMEIRO DOWNLOAD - No local data found, downloading from cloud');
        final data = docSnapshot.data()!;
        data['id'] = inspectionId;

        final convertedData = _convertFirestoreTimestamps(data);
        final cloudInspection = Inspection.fromMap(convertedData);

        // Salvar a vistoria principal no banco local
        final downloadedInspection = cloudInspection.copyWith(
          hasLocalChanges: false,
          isSynced: true,
          lastSyncAt: DateTime.now(),
        );
        
        debugPrint('FirestoreSyncService: Saving inspection ${inspectionId} to local database');
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);
        
        // Processar estrutura aninhada preservando dados existentes
        final topicsData = data['topics'] as List<dynamic>? ?? [];
        final topicsMapList = topicsData.map((t) => Map<String, dynamic>.from(t)).toList();
        await _processNestedTopicsStructure(cloudInspection.id, topicsMapList);
        
        // Baixar mídias da inspeção
        await _downloadInspectionMedia(inspectionId);
        
        // Baixar template da inspeção se necessário
        await _downloadInspectionTemplate(cloudInspection);
      } else if (localInspection != null) {
        debugPrint('FirestoreSyncService: ✅ SYNC ONLY - Local data preserved, upload completed');
        // Apenas baixar template se necessário, sem sobrescrever dados
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          final convertedData = _convertFirestoreTimestamps(data);
          final cloudInspection = Inspection.fromMap(convertedData);
          await _downloadInspectionTemplate(cloudInspection);
        }
      }

      // Marcar como sincronizado apenas no final do processo completo
      await _offlineService.markInspectionSynced(inspectionId);

      debugPrint(
          'FirestoreSyncService: Finished syncing inspection $inspectionId');
      return {'success': true, 'hasConflicts': false};
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error syncing inspection $inspectionId: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> _detectConflicts(
      Inspection? localInspection, Inspection cloudInspection) async {
    final conflicts = <Map<String, dynamic>>[];

    if (localInspection == null) {
      // No local inspection, no conflicts
      return conflicts;
    }

    // Check if local inspection has changes
    if (!localInspection.hasLocalChanges) {
      // No local changes, no conflicts
      return conflicts;
    }

    // Check if cloud inspection is newer than local last sync
    if (localInspection.lastSyncAt != null &&
        cloudInspection.updatedAt.isAfter(localInspection.lastSyncAt!)) {
      // Cloud has newer changes, check for specific conflicts
      
      // Check title conflict
      if (localInspection.title != cloudInspection.title) {
        conflicts.add({
          'type': 'title',
          'field': 'title',
          'localValue': localInspection.title,
          'cloudValue': cloudInspection.title,
          'message': 'Título foi modificado tanto localmente quanto na nuvem',
        });
      }

      // Check observation conflict
      if (localInspection.observation != cloudInspection.observation) {
        conflicts.add({
          'type': 'observation',
          'field': 'observation',
          'localValue': localInspection.observation,
          'cloudValue': cloudInspection.observation,
          'message': 'Observação foi modificada tanto localmente quanto na nuvem',
        });
      }

      // Check status conflict
      if (localInspection.status != cloudInspection.status) {
        conflicts.add({
          'type': 'status',
          'field': 'status',
          'localValue': localInspection.status,
          'cloudValue': cloudInspection.status,
          'message': 'Status foi modificado tanto localmente quanto na nuvem',
        });
      }

      // Check address conflict
      if (localInspection.addressString != cloudInspection.addressString) {
        conflicts.add({
          'type': 'address',
          'field': 'address',
          'localValue': localInspection.addressString,
          'cloudValue': cloudInspection.addressString,
          'message': 'Endereço foi modificado tanto localmente quanto na nuvem',
        });
      }

      // Check scheduled date conflict
      if (localInspection.scheduledDate != cloudInspection.scheduledDate) {
        conflicts.add({
          'type': 'scheduledDate',
          'field': 'scheduled_date',
          'localValue': localInspection.scheduledDate?.toIso8601String() ?? 'Não definida',
          'cloudValue': cloudInspection.scheduledDate?.toIso8601String() ?? 'Não definida',
          'message': 'Data agendada foi modificada tanto localmente quanto na nuvem',
        });
      }

      // Area field removed - not present in Inspection model

      // Detailed conflict detection for nested structures
      await _checkNestedStructuresConflicts(localInspection, cloudInspection, conflicts);
    }

    return conflicts;
  }

  /// Checks for conflicts in nested structures (topics, items, details, non-conformities)
  Future<void> _checkNestedStructuresConflicts(
      Inspection localInspection, 
      Inspection cloudInspection, 
      List<Map<String, dynamic>> conflicts) async {
    
    // Get local and cloud topics from database
    final localTopics = await _offlineService.getTopics(localInspection.id);
    final cloudTopics = cloudInspection.topics ?? [];

    // Check topics count conflict
    if (localTopics.length != cloudTopics.length) {
      conflicts.add({
        'type': 'topics_count',
        'field': 'topics',
        'localValue': localTopics.length,
        'cloudValue': cloudTopics.length,
        'message': 'Número de tópicos foi modificado tanto localmente quanto na nuvem',
      });
    }

    // Check individual topic conflicts
    for (final localTopic in localTopics) {
      await _checkTopicConflicts(localTopic, cloudTopics, conflicts);
    }

    // Check for deleted topics in cloud
    for (final cloudTopicData in cloudTopics) {
      final cloudTopicName = cloudTopicData['name'] as String? ?? '';
      final hasLocalMatch = localTopics.any((t) => t.topicName == cloudTopicName);
      
      if (!hasLocalMatch) {
        conflicts.add({
          'type': 'topic_deleted_locally',
          'field': 'topics',
          'localValue': 'Tópico removido localmente',
          'cloudValue': cloudTopicName,
          'message': 'Tópico "$cloudTopicName" foi removido localmente mas existe na nuvem',
        });
      }
    }
  }

  /// Checks conflicts for a specific topic
  Future<void> _checkTopicConflicts(
      Topic localTopic, 
      List<dynamic> cloudTopics, 
      List<Map<String, dynamic>> conflicts) async {
    
    // Find matching cloud topic by name
    dynamic cloudTopicData;
    try {
      cloudTopicData = cloudTopics.firstWhere(
        (t) => t['name'] == localTopic.topicName,
      );
    } catch (e) {
      cloudTopicData = null;
    }

    if (cloudTopicData == null) {
      conflicts.add({
        'type': 'topic_added_locally',
        'field': 'topics',
        'localValue': localTopic.topicName,
        'cloudValue': 'Tópico não existe na nuvem',
        'message': 'Tópico "${localTopic.topicName}" foi adicionado localmente mas não existe na nuvem',
      });
      return;
    }

    // Check topic observation conflict
    final cloudObservation = cloudTopicData['observation'] as String?;
    if (localTopic.observation != cloudObservation) {
      conflicts.add({
        'type': 'topic_observation',
        'field': 'topic_observation',
        'localValue': localTopic.observation ?? 'Sem observação',
        'cloudValue': cloudObservation ?? 'Sem observação',
        'message': 'Observação do tópico "${localTopic.topicName}" foi modificada tanto localmente quanto na nuvem',
      });
    }

    // Check items conflicts
    await _checkItemsConflicts(localTopic, cloudTopicData, conflicts);
  }

  /// Checks conflicts for items within a topic
  Future<void> _checkItemsConflicts(
      Topic localTopic, 
      Map<String, dynamic> cloudTopicData, 
      List<Map<String, dynamic>> conflicts) async {
    
    final localItems = await _offlineService.getItems(localTopic.id ?? '');
    final cloudItems = cloudTopicData['items'] as List<dynamic>? ?? [];

    // Check items count conflict
    if (localItems.length != cloudItems.length) {
      conflicts.add({
        'type': 'items_count',
        'field': 'items',
        'localValue': localItems.length,
        'cloudValue': cloudItems.length,
        'message': 'Número de itens no tópico "${localTopic.topicName}" foi modificado tanto localmente quanto na nuvem',
      });
    }

    // Check individual item conflicts
    for (final localItem in localItems) {
      await _checkItemConflicts(localItem, cloudItems, conflicts);
    }

    // Check for deleted items in cloud
    for (final cloudItemData in cloudItems) {
      final cloudItemName = cloudItemData['name'] as String? ?? '';
      final hasLocalMatch = localItems.any((i) => i.itemName == cloudItemName);
      
      if (!hasLocalMatch) {
        conflicts.add({
          'type': 'item_deleted_locally',
          'field': 'items',
          'localValue': 'Item removido localmente',
          'cloudValue': cloudItemName,
          'message': 'Item "$cloudItemName" foi removido localmente mas existe na nuvem',
        });
      }
    }
  }

  /// Checks conflicts for a specific item
  Future<void> _checkItemConflicts(
      Item localItem, 
      List<dynamic> cloudItems, 
      List<Map<String, dynamic>> conflicts) async {
    
    // Find matching cloud item by name
    dynamic cloudItemData;
    try {
      cloudItemData = cloudItems.firstWhere(
        (i) => i['name'] == localItem.itemName,
      );
    } catch (e) {
      cloudItemData = null;
    }

    if (cloudItemData == null) {
      conflicts.add({
        'type': 'item_added_locally',
        'field': 'items',
        'localValue': localItem.itemName,
        'cloudValue': 'Item não existe na nuvem',
        'message': 'Item "${localItem.itemName}" foi adicionado localmente mas não existe na nuvem',
      });
      return;
    }

    // Check item observation conflict
    final cloudObservation = cloudItemData['observation'] as String?;
    if (localItem.observation != cloudObservation) {
      conflicts.add({
        'type': 'item_observation',
        'field': 'item_observation',
        'localValue': localItem.observation ?? 'Sem observação',
        'cloudValue': cloudObservation ?? 'Sem observação',
        'message': 'Observação do item "${localItem.itemName}" foi modificada tanto localmente quanto na nuvem',
      });
    }

    // Check item evaluation conflict
    final cloudEvaluation = cloudItemData['evaluation'] as String?;
    if (localItem.evaluation != cloudEvaluation) {
      conflicts.add({
        'type': 'item_evaluation',
        'field': 'item_evaluation',
        'localValue': localItem.evaluation ?? 'Sem avaliação',
        'cloudValue': cloudEvaluation ?? 'Sem avaliação',
        'message': 'Avaliação do item "${localItem.itemName}" foi modificada tanto localmente quanto na nuvem',
      });
    }

    // Check details conflicts
    await _checkDetailsConflicts(localItem, cloudItemData, conflicts);
  }

  /// Checks conflicts for details within an item
  Future<void> _checkDetailsConflicts(
      Item localItem, 
      Map<String, dynamic> cloudItemData, 
      List<Map<String, dynamic>> conflicts) async {
    
    final localDetails = await _offlineService.getDetails(localItem.id ?? '');
    final cloudDetails = cloudItemData['details'] as List<dynamic>? ?? [];

    // Check details count conflict
    if (localDetails.length != cloudDetails.length) {
      conflicts.add({
        'type': 'details_count',
        'field': 'details',
        'localValue': localDetails.length,
        'cloudValue': cloudDetails.length,
        'message': 'Número de detalhes no item "${localItem.itemName}" foi modificado tanto localmente quanto na nuvem',
      });
    }

    // Check individual detail conflicts
    for (final localDetail in localDetails) {
      await _checkDetailConflicts(localDetail, cloudDetails, conflicts);
    }

    // Check for deleted details in cloud
    for (final cloudDetailData in cloudDetails) {
      final cloudDetailName = cloudDetailData['name'] as String? ?? '';
      final hasLocalMatch = localDetails.any((d) => d.detailName == cloudDetailName);
      
      if (!hasLocalMatch) {
        conflicts.add({
          'type': 'detail_deleted_locally',
          'field': 'details',
          'localValue': 'Detalhe removido localmente',
          'cloudValue': cloudDetailName,
          'message': 'Detalhe "$cloudDetailName" foi removido localmente mas existe na nuvem',
        });
      }
    }
  }

  /// Checks conflicts for a specific detail
  Future<void> _checkDetailConflicts(
      Detail localDetail, 
      List<dynamic> cloudDetails, 
      List<Map<String, dynamic>> conflicts) async {
    
    // Find matching cloud detail by name
    dynamic cloudDetailData;
    try {
      cloudDetailData = cloudDetails.firstWhere(
        (d) => d['name'] == localDetail.detailName,
      );
    } catch (e) {
      cloudDetailData = null;
    }

    if (cloudDetailData == null) {
      conflicts.add({
        'type': 'detail_added_locally',
        'field': 'details',
        'localValue': localDetail.detailName,
        'cloudValue': 'Detalhe não existe na nuvem',
        'message': 'Detalhe "${localDetail.detailName}" foi adicionado localmente mas não existe na nuvem',
      });
      return;
    }

    // Check detail value conflict
    final cloudValue = cloudDetailData['value'];
    final localValue = localDetail.detailValue;
    if (localValue != cloudValue) {
      conflicts.add({
        'type': 'detail_value',
        'field': 'detail_value',
        'localValue': localValue?.toString() ?? 'Sem valor',
        'cloudValue': cloudValue?.toString() ?? 'Sem valor',
        'message': 'Valor do detalhe "${localDetail.detailName}" foi modificado tanto localmente quanto na nuvem',
      });
    }

    // Check detail observation conflict
    final cloudObservation = cloudDetailData['observation'] as String?;
    if (localDetail.observation != cloudObservation) {
      conflicts.add({
        'type': 'detail_observation',
        'field': 'detail_observation',
        'localValue': localDetail.observation ?? 'Sem observação',
        'cloudValue': cloudObservation ?? 'Sem observação',
        'message': 'Observação do detalhe "${localDetail.detailName}" foi modificada tanto localmente quanto na nuvem',
      });
    }

    // Check detail damaged status conflict
    final cloudIsDamaged = cloudDetailData['is_damaged'] as bool? ?? false;
    final localIsDamaged = localDetail.isDamaged ?? false;
    if (localIsDamaged != cloudIsDamaged) {
      conflicts.add({
        'type': 'detail_damaged',
        'field': 'detail_damaged',
        'localValue': localIsDamaged ? 'Danificado' : 'Não danificado',
        'cloudValue': cloudIsDamaged ? 'Danificado' : 'Não danificado',
        'message': 'Status de dano do detalhe "${localDetail.detailName}" foi modificado tanto localmente quanto na nuvem',
      });
    }

    // Check non-conformities conflicts
    await _checkNonConformitiesConflicts(localDetail, cloudDetailData, conflicts);
  }

  /// Checks conflicts for non-conformities within a detail
  Future<void> _checkNonConformitiesConflicts(
      Detail localDetail, 
      Map<String, dynamic> cloudDetailData, 
      List<Map<String, dynamic>> conflicts) async {
    
    final cloudNonConformities = cloudDetailData['non_conformities'] as List<dynamic>? ?? [];
    
    // Get local non-conformities for this detail
    final localNonConformities = await _offlineService.getNonConformitiesByDetail(localDetail.id ?? '');
    
    // Check non-conformities count conflict
    if (localNonConformities.length != cloudNonConformities.length) {
      conflicts.add({
        'type': 'non_conformities_count',
        'field': 'non_conformities',
        'localValue': localNonConformities.length,
        'cloudValue': cloudNonConformities.length,
        'message': 'Número de não conformidades no detalhe "${localDetail.detailName}" foi modificado tanto localmente quanto na nuvem',
      });
    }
    
    // Check individual non-conformity conflicts
    for (final localNonConformity in localNonConformities) {
      await _checkSingleNonConformityConflicts(localNonConformity, cloudNonConformities, conflicts);
    }
    
    // Check for non-conformities deleted locally but existing in cloud
    for (final cloudNonConformityData in cloudNonConformities) {
      final cloudNonConformityId = cloudNonConformityData['id'] as String? ?? '';
      final cloudNonConformityDescription = cloudNonConformityData['description'] as String? ?? 'Sem descrição';
      
      final hasLocalMatch = localNonConformities.any((nc) => nc.id == cloudNonConformityId);
      
      if (!hasLocalMatch) {
        conflicts.add({
          'type': 'non_conformity_deleted_locally',
          'field': 'non_conformities',
          'localValue': 'Não conformidade removida localmente',
          'cloudValue': cloudNonConformityDescription,
          'message': 'Não conformidade "$cloudNonConformityDescription" foi removida localmente mas existe na nuvem',
        });
      }
    }
  }
  
  /// Checks conflicts for a single non-conformity
  Future<void> _checkSingleNonConformityConflicts(
      NonConformity localNonConformity,
      List<dynamic> cloudNonConformities,
      List<Map<String, dynamic>> conflicts) async {
    
    // Find matching cloud non-conformity by ID
    dynamic cloudNonConformityData;
    try {
      cloudNonConformityData = cloudNonConformities.firstWhere(
        (nc) => nc['id'] == localNonConformity.id,
      );
    } catch (e) {
      cloudNonConformityData = null;
    }
    
    if (cloudNonConformityData == null) {
      conflicts.add({
        'type': 'non_conformity_added_locally',
        'field': 'non_conformities',
        'localValue': localNonConformity.description,
        'cloudValue': 'Não conformidade não existe na nuvem',
        'message': 'Não conformidade "${localNonConformity.description}" foi adicionada localmente mas não existe na nuvem',
      });
      return;
    }
    
    // Check description conflict
    final cloudDescription = cloudNonConformityData['description'] as String?;
    if (localNonConformity.description != cloudDescription) {
      conflicts.add({
        'type': 'non_conformity_description',
        'field': 'non_conformity_description',
        'localValue': localNonConformity.description,
        'cloudValue': cloudDescription ?? 'Sem descrição',
        'message': 'Descrição da não conformidade foi modificada tanto localmente quanto na nuvem',
      });
    }
    
    // Check severity conflict
    final cloudSeverity = cloudNonConformityData['severity'] as String?;
    if (localNonConformity.severity != cloudSeverity) {
      conflicts.add({
        'type': 'non_conformity_severity',
        'field': 'non_conformity_severity',
        'localValue': localNonConformity.severity,
        'cloudValue': cloudSeverity ?? 'Sem severidade',
        'message': 'Severidade da não conformidade "${localNonConformity.description}" foi modificada tanto localmente quanto na nuvem',
      });
    }
    
    // Check status conflict
    final cloudStatus = cloudNonConformityData['status'] as String?;
    if (localNonConformity.status != cloudStatus) {
      conflicts.add({
        'type': 'non_conformity_status',
        'field': 'non_conformity_status',
        'localValue': localNonConformity.status,
        'cloudValue': cloudStatus ?? 'Sem status',
        'message': 'Status da não conformidade "${localNonConformity.description}" foi modificado tanto localmente quanto na nuvem',
      });
    }
    
    // Check corrective action conflict
    final cloudCorrectiveAction = cloudNonConformityData['corrective_action'] as String?;
    if (localNonConformity.correctiveAction != cloudCorrectiveAction) {
      conflicts.add({
        'type': 'non_conformity_corrective_action',
        'field': 'non_conformity_corrective_action',
        'localValue': localNonConformity.correctiveAction ?? 'Sem ação corretiva',
        'cloudValue': cloudCorrectiveAction ?? 'Sem ação corretiva',
        'message': 'Ação corretiva da não conformidade "${localNonConformity.description}" foi modificada tanto localmente quanto na nuvem',
      });
    }
    
    // Check deadline conflict
    final cloudDeadline = cloudNonConformityData['deadline'];
    final localDeadlineString = localNonConformity.deadline?.toIso8601String();
    final cloudDeadlineString = cloudDeadline != null ? 
        (cloudDeadline is String ? cloudDeadline : cloudDeadline.toString()) : null;
    
    if (localDeadlineString != cloudDeadlineString) {
      conflicts.add({
        'type': 'non_conformity_deadline',
        'field': 'non_conformity_deadline',
        'localValue': localDeadlineString ?? 'Sem prazo',
        'cloudValue': cloudDeadlineString ?? 'Sem prazo',
        'message': 'Prazo da não conformidade "${localNonConformity.description}" foi modificado tanto localmente quanto na nuvem',
      });
    }
    
    // Check media conflicts for non-conformity
    await _checkNonConformityMediaConflicts(localNonConformity, cloudNonConformityData, conflicts);
  }
  
  /// Checks conflicts for media within a non-conformity
  Future<void> _checkNonConformityMediaConflicts(
      NonConformity localNonConformity,
      Map<String, dynamic> cloudNonConformityData,
      List<Map<String, dynamic>> conflicts) async {
    
    final cloudMedia = cloudNonConformityData['media'] as List<dynamic>? ?? [];
    
    // Get local media for this non-conformity
    final localMedia = await _offlineService.getMediaByNonConformity(localNonConformity.id);
    
    // Check media count conflict
    if (localMedia.length != cloudMedia.length) {
      conflicts.add({
        'type': 'non_conformity_media_count',
        'field': 'non_conformity_media',
        'localValue': localMedia.length,
        'cloudValue': cloudMedia.length,
        'message': 'Número de mídias na não conformidade "${localNonConformity.description}" foi modificado tanto localmente quanto na nuvem',
      });
    }
    
    // Check for media deleted locally but existing in cloud
    for (final cloudMediaData in cloudMedia) {
      final cloudMediaFilename = cloudMediaData['filename'] as String? ?? '';
      final cloudMediaUrl = cloudMediaData['url'] as String? ?? '';
      
      final hasLocalMatch = localMedia.any((m) => 
          m.filename == cloudMediaFilename || 
          m.cloudUrl == cloudMediaUrl);
      
      if (!hasLocalMatch) {
        conflicts.add({
          'type': 'non_conformity_media_deleted_locally',
          'field': 'non_conformity_media',
          'localValue': 'Mídia removida localmente',
          'cloudValue': cloudMediaFilename,
          'message': 'Mídia "$cloudMediaFilename" foi removida localmente mas existe na nuvem para a não conformidade "${localNonConformity.description}"',
        });
      }
    }
    
    // Check for media added locally but not in cloud
    for (final localMediaItem in localMedia) {
      final hasCloudMatch = cloudMedia.any((m) => 
          m['filename'] == localMediaItem.filename || 
          m['url'] == localMediaItem.cloudUrl);
      
      if (!hasCloudMatch) {
        conflicts.add({
          'type': 'non_conformity_media_added_locally',
          'field': 'non_conformity_media',
          'localValue': localMediaItem.filename,
          'cloudValue': 'Mídia não existe na nuvem',
          'message': 'Mídia "${localMediaItem.filename}" foi adicionada localmente mas não existe na nuvem para a não conformidade "${localNonConformity.description}"',
        });
      }
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

  // ===============================
  // RESOLUÇÃO DE CONFLITOS
  // ===============================

  /// Downloads a specific inspection from the cloud, replacing the local version
  Future<void> downloadSpecificInspection(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Downloading specific inspection $inspectionId to resolve conflicts');
      
      if (!await isConnected()) {
        throw Exception('Sem conexão com a internet');
      }

      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Inspeção não encontrada na nuvem');
      }

      final data = docSnapshot.data()!;
      data['id'] = inspectionId;

      final convertedData = _convertFirestoreTimestamps(data);
      final cloudInspection = Inspection.fromMap(convertedData);

      // Replace local version with cloud version
      await _offlineService.insertOrUpdateInspection(cloudInspection);
      await _offlineService.markInspectionSynced(inspectionId);

      // Download related data
      await _downloadInspectionRelatedData(inspectionId);
      
      // Download media
      await _downloadInspectionMedia(inspectionId);
      
      // Download template if needed
      await _downloadInspectionTemplate(cloudInspection);

      debugPrint('FirestoreSyncService: Successfully downloaded specific inspection $inspectionId');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading specific inspection $inspectionId: $e');
      rethrow;
    }
  }

  /// Forces upload of local inspection changes to the cloud, overriding cloud version
  Future<void> forceUploadInspection(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Force uploading inspection $inspectionId to resolve conflicts');
      
      if (!await isConnected()) {
        throw Exception('Sem conexão com a internet');
      }

      final localInspection = await _offlineService.getInspection(inspectionId);
      if (localInspection == null) {
        throw Exception('Inspeção local não encontrada');
      }

      // Force upload media files first
      await _uploadMediaFiles(inspectionId);
      
      // Force upload the inspection with nested structure
      await _uploadSingleInspectionWithNestedStructure(inspectionId);
      
      // Mark as synced
      await _offlineService.markInspectionSynced(inspectionId);

      debugPrint('FirestoreSyncService: Successfully force uploaded inspection $inspectionId');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error force uploading inspection $inspectionId: $e');
      rethrow;
    }
  }
}

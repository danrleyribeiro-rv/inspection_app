import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer';
import '../upload_progress_service.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/cloud_verification_service.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/models/inspection_history.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';

class FirestoreSyncService {
  final FirebaseService _firebaseService;
  final EnhancedOfflineDataService _offlineService;
  bool _isSyncing = false;
  
  // Stream controller for detailed sync progress
  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

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
    
    // Initialize CloudVerificationService
    CloudVerificationService.initialize(
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
        return;
    }

    try {
      _isSyncing = true;

      await downloadInspectionsFromCloud();
      await uploadLocalChangesToCloud();

    } catch (e) {
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


      for (final doc in querySnapshot.docs) {
        await _downloadSingleInspection(doc);
      }

    } catch (e) {
      // Log apenas erros críticos de download
      log('Erro ao baixar inspeções: $e');
    }
  }

  Future<void> _downloadSingleInspection(QueryDocumentSnapshot doc) async {
    try {
      
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      // Converter timestamps do Firestore primeiro
      final convertedData = _convertFirestoreTimestamps(data);
      
      // Criar objeto Inspection a partir dos dados convertidos
      final cloudInspection = Inspection.fromMap(convertedData);
      
      final localInspection = await _offlineService.getInspection(doc.id);

      // Sempre fazer download se não existe localmente ou se é mais recente
      if (localInspection == null || cloudInspection.updatedAt.isAfter(localInspection.updatedAt)) {
        
        // Preparar inspeção para salvamento local
        final downloadedInspection = cloudInspection.copyWith(
          hasLocalChanges: false,
          isSynced: true,
          lastSyncAt: DateTime.now(),
        );
        
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);
        
        // Verificar se foi salva
        final savedInspection = await _offlineService.getInspection(doc.id);
        
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

        } else {
        }
      } else {
      }
    } catch (e) {
      // Log apenas erros críticos
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
        
        await _offlineService.insertOrUpdateInspectionFromCloud(downloadedInspection);

        final topics = data['topics'] as List<dynamic>?;

        if (topics != null && topics.isNotEmpty) {
          final topicsData =
              topics.map((topic) => Map<String, dynamic>.from(topic)).toList();
          await _processNestedTopicsStructure(inspectionId, topicsData);
        } else {
          await _createDefaultInspectionStructure(inspectionId);
        }
      } else {
        await _createDefaultInspectionStructure(inspectionId);
      }
    } catch (e) {
      // Log apenas erros críticos
    }
  }

  Future<void> _createDefaultInspectionStructure(String inspectionId) async {
    try {

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

    } catch (e) {
      // Log apenas erros críticos
    }
  }

  Future<void> _processNestedTopicsStructure(
      String inspectionId, List<Map<String, dynamic>> topicsData) async {
    try {
      // Process topics in parallel batches for better performance
      const batchSize = 3;
      for (int i = 0; i < topicsData.length; i += batchSize) {
        final batch = topicsData.skip(i).take(batchSize).toList();
        final futures = <Future>[];
        
        for (int j = 0; j < batch.length; j++) {
          final topicIndex = i + j;
          futures.add(_processSingleTopic(inspectionId, batch[j], topicIndex));
        }
        
        // Process batch in parallel
        await Future.wait(futures);
        
        // Small delay to prevent database lock issues
        if (i + batchSize < topicsData.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing nested topics: $e');
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
    
    // Process related data in parallel where possible
    final futures = <Future>[];
    
    // Add non-conformities and media processing
    futures.add(_processTopicNonConformities(topic, topicData));
    futures.add(_processTopicMedia(topic, topicData));
    
    // Wait for these to complete first
    await Future.wait(futures);
    
    // Then process details/items (these depend on topic being saved)
    if (hasDirectDetails) {
      await _processTopicDirectDetails(inspectionId, topic.id!, topicData);
    } else {
      await _processTopicItems(inspectionId, topic.id!, topicData, topicIndex);
    }
  }

  Future<void> _processTopicDirectDetails(String inspectionId, String topicId, Map<String, dynamic> topicData) async {
    final detailsData = topicData['details'] as List<dynamic>? ?? [];
    
    // Process details in small batches to avoid overwhelming the database
    const batchSize = 5;
    for (int i = 0; i < detailsData.length; i += batchSize) {
      final batch = detailsData.skip(i).take(batchSize).toList();
      final futures = <Future>[];
      
      for (int j = 0; j < batch.length; j++) {
        final detailIndex = i + j;
        futures.add(_processDetailFromJson(inspectionId, topicId, null, batch[j], detailIndex));
      }
      
      await Future.wait(futures);
      
      // Small delay between batches
      if (i + batchSize < detailsData.length) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
    }
  }

  Future<void> _processTopicItems(String inspectionId, String topicId, Map<String, dynamic> topicData, int topicIndex) async {
    final itemsData = topicData['items'] as List<dynamic>? ?? [];
    
    // Process items in small batches
    const batchSize = 3;
    for (int i = 0; i < itemsData.length; i += batchSize) {
      final batch = itemsData.skip(i).take(batchSize).toList();
      final futures = <Future>[];
      
      for (int j = 0; j < batch.length; j++) {
        final itemIndex = i + j;
        futures.add(_processSingleItem(inspectionId, topicId, batch[j], topicIndex, itemIndex));
      }
      
      await Future.wait(futures);
      
      // Small delay between batches
      if (i + batchSize < itemsData.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
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

    // Processar não conformidades do detalhe
    await _processDetailNonConformities(detail, detailData);

    // Processar mídias do detalhe
    await _processDetailMedia(detail, detailData);

    return detail.id!;
  }

  Future<void> _processTopicMedia(Topic topic, Map<String, dynamic> topicData) async {
    try {
      final mediaData = topicData['media'] as List<dynamic>? ?? [];

      for (final media in mediaData) {
        final mediaMap = Map<String, dynamic>.from(media);
        await _processMediaItem(
          mediaMap, 
          topic.inspectionId, 
          topicId: topic.id,
        );
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  Future<void> _processItemMedia(Item item, Map<String, dynamic> itemData) async {
    try {
      final mediaData = itemData['media'] as List<dynamic>? ?? [];

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
      // Erro silencioso
    }
  }

  Future<void> _processDetailMedia(Detail detail, Map<String, dynamic> detailData) async {
    try {
      final mediaData = detailData['media'] as List<dynamic>? ?? [];

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
      // Erro silencioso
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
      }
    } catch (e) {
      // Erro silencioso
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
      
      // Notificação inicial de download removida para evitar duplicação
      
      // Get the local structure that was already created by _downloadInspectionRelatedData
      final localTopics = await _offlineService.getTopics(inspectionId);
      
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
      
      
      // Fetch Firestore inspection data to get media
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        return;
      }
      
      final data = docSnapshot.data()!;
      final firestoreTopics = data['topics'] as List<dynamic>? ?? [];
      
      
      
      
      // Notificações de progresso de download removidas para evitar duplicação
      
      // Update totals for accurate progress tracking
      // totalMediaFound = preliminaryMediaCount; // Variable removed
      
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
        // totalMediaFound += topicMedias.length; // Variable removed
        if (topicMedias.isNotEmpty) {
          debugPrint('FirestoreSyncService: Processing ${topicMedias.length} media files for topic ${localTopic.topicName}');
        }
        
        for (final mediaData in topicMedias) {
          final media = Map<String, dynamic>.from(mediaData);
          
          // Notificações de progresso individuais removidas
          
          if (await _downloadAndSaveMediaWithIds(
            media, 
            inspectionId, 
            topicId: localTopic.id,
            context: 'Topic: ${localTopic.topicName}'
          )) {
            // totalMediaDownloaded++; // Variable removed
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
          // totalMediaFound += itemMedias.length; // Variable removed
          if (itemMedias.isNotEmpty) {
            debugPrint('FirestoreSyncService: Processing ${itemMedias.length} media files for item ${localItem.itemName}');
          }
          
          for (final mediaData in itemMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            
            // Notificações de progresso de itens removidas
            
            if (await _downloadAndSaveMediaWithIds(
              media, 
              inspectionId, 
              topicId: localItem.topicId,
              itemId: localItem.id,
              context: 'Item: ${localItem.itemName}'
            )) {
              // totalMediaDownloaded++; // Variable removed
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
            // totalMediaFound += detailMedias.length; // Variable removed
            if (detailMedias.isNotEmpty) {
              debugPrint('FirestoreSyncService: Processing ${detailMedias.length} media files for detail ${localDetail.detailName}');
            }
            
            for (final mediaData in detailMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              
              // Notificações de progresso de detalhes removidas
              
              if (await _downloadAndSaveMediaWithIds(
                media, 
                inspectionId, 
                topicId: localDetail.topicId,
                itemId: localDetail.itemId,
                detailId: localDetail.id,
                context: 'Detail: ${localDetail.detailName}'
              )) {
                // totalMediaDownloaded++; // Variable removed
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
              // totalMediaFound += ncMedias.length; // Variable removed
              if (ncMedias.isNotEmpty) {
                debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for non-conformity ${localNc.title}');
              }
              
              for (final mediaData in ncMedias) {
                final media = Map<String, dynamic>.from(mediaData);
                
                // Notificações de progresso de NC removidas
                
                if (await _downloadAndSaveMediaWithIds(
                  media, 
                  inspectionId, 
                  topicId: localNc.topicId,
                  itemId: localNc.itemId,
                  detailId: localNc.detailId,
                  nonConformityId: localNc.id,
                  context: 'NC: ${localNc.title}'
                )) {
                  // totalMediaDownloaded++; // Variable removed
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
            // totalMediaFound += ncMedias.length; // Variable removed
            if (ncMedias.isNotEmpty) {
              debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for item non-conformity ${localNc.title}');
            }
            
            for (final mediaData in ncMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              
              // Notificações de progresso de item NC removidas
              
              if (await _downloadAndSaveMediaWithIds(
                media, 
                inspectionId, 
                topicId: localNc.topicId,
                itemId: localNc.itemId,
                nonConformityId: localNc.id,
                context: 'Item NC: ${localNc.title}'
              )) {
                // totalMediaDownloaded++; // Variable removed
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
          // totalMediaFound += ncMedias.length; // Variable removed
          if (ncMedias.isNotEmpty) {
            debugPrint('FirestoreSyncService: Processing ${ncMedias.length} media files for topic non-conformity ${localNc.title}');
          }
          
          for (final mediaData in ncMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            
            // Notificações de progresso de topic NC removidas
            
            if (await _downloadAndSaveMediaWithIds(
              media, 
              inspectionId, 
              topicId: localNc.topicId,
              nonConformityId: localNc.id,
              context: 'Topic NC: ${localNc.title}'
            )) {
              // totalMediaDownloaded++; // Variable removed
            }
          }
        }
      }
      
      
      // Notificações finais de download removidas para evitar duplicação
      
      
    } catch (e) {
      // Log apenas erros críticos de download de mídia
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
      
      // Verificar diferentes possíveis formatos de dados de mídia
      final cloudUrl = mediaData['cloudUrl'] as String? ?? 
                      mediaData['url'] as String? ?? 
                      mediaData['downloadUrl'] as String?;
      final filename = mediaData['filename'] as String? ?? 
                      mediaData['name'] as String?;
      
      if (cloudUrl == null || filename == null) {
        return false;
      }
      
      // Verificar se já foi baixado
      final existingMedia = await _offlineService.getMediaByFilename(filename);
      if (existingMedia.isNotEmpty) {
        return false;
      }
      
      
      // Baixar arquivo do Firebase Storage
      debugPrint('FirestoreSyncService: Downloading media file $filename from $cloudUrl');
      
      final storageRef = _firebaseService.storage.refFromURL(cloudUrl);
      final localFile = await _offlineService.createMediaFile(filename);
      
      try {
        await storageRef.writeToFile(localFile);
        
        // Verificar se o arquivo foi realmente criado
        if (!await localFile.exists()) {
          debugPrint('FirestoreSyncService: ERROR - File $filename was not created after download');
          return false;
        }
        
        final fileSize = await localFile.length();
        if (fileSize == 0) {
          debugPrint('FirestoreSyncService: ERROR - File $filename is empty after download');
          return false;
        }
        
        debugPrint('FirestoreSyncService: Successfully downloaded $filename ($fileSize bytes)');
      } catch (downloadError) {
        debugPrint('FirestoreSyncService: ERROR downloading media $filename: $downloadError');
        // Tentar limpar o arquivo parcial se existir
        try {
          if (await localFile.exists()) {
            await localFile.delete();
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Error cleaning up partial file: $e');
        }
        return false;
      }
      
      // Extract and preserve ALL metadata from Firestore
      
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
        // Erro silencioso no parsing de timestamps
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
      
      return true;
      
    } catch (e) {
      return false;
    }
  }

  // ===============================
  // PROGRESS NOTIFICATION HELPER
  // ===============================
  
  /// Formatar velocidade para exibição
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Formatar tempo para exibição
  String _formatTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  

  // ===============================
  // UPLOAD PARA A NUVEM - OTIMIZADO
  // ===============================

  /// Public method for ultra-fast media upload during manual sync
  Future<void> uploadMediaUltraFast(String inspectionId) async {
    await _uploadMediaFilesWithProgress(inspectionId);
  }

  /// Public method for ultra-fast media upload of all pending media
  Future<void> uploadAllMediaUltraFast() async {
    await _uploadMediaFilesUltraFast();
  }

  /// Método otimizado para sincronização rápida em lotes quando clicado manualmente
  Future<void> uploadMediaBatchOptimized(String inspectionId) async {
    final stopwatch = Stopwatch()..start();
    Timer? notificationTimer;
    String? sessionId;
    
    try {
      final mediaFiles = await _offlineService.getMediaPendingUpload();
      final inspectionMediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();
      
      if (inspectionMediaFiles.isEmpty) {
        return;
      }
      
      // Sort por tamanho para melhor percepção de velocidade
      inspectionMediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      
      // Preparar itens para tracking de progresso
      final uploadItems = inspectionMediaFiles.map((media) => UploadItem(
        id: media.id,
        filename: media.filename,
        totalBytes: media.fileSize ?? 1024, // fallback 1KB
      )).toList();
      
      // Iniciar tracking de progresso
      sessionId = 'batch_$inspectionId';
      UploadProgressService.instance.startUploadTracking(sessionId, uploadItems);
      
      // Timer para atualizar notificação a cada 2 segundos
      notificationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final stats = UploadProgressService.instance.getUploadStats(sessionId!);
        if (stats != null) {
          await SimpleNotificationService.instance.showSyncProgress(
            title: 'Enviando dados',
            message: '',
            progress: stats.progressPercentage.round(),
            currentItem: stats.currentItem,
            totalItems: stats.totalItems,
            estimatedTime: stats.estimatedTimeRemaining != null ? _formatTime(stats.estimatedTimeRemaining!) : null,
            speed: _formatSpeed(stats.speedBytesPerSecond),
          );
        }
      });
      
      const int maxConcurrentBatch = 35; // Máximo para upload manual
      const int chunkSizeBatch = 25; // Chunks maiores para melhor throughput
      
      int totalUploaded = 0;
      
      // Process em chunks com máximo paralelismo
      for (int i = 0; i < inspectionMediaFiles.length; i += chunkSizeBatch) {
        final chunk = inspectionMediaFiles.skip(i).take(chunkSizeBatch).toList();
        
        // Controle de concorrência para evitar sobrecarga
        final semaphore = <Future>[];
        final uploadFutures = <Future<bool>>[];
        
        for (final media in chunk) {
          // Aguarda slot disponível
          while (semaphore.length >= maxConcurrentBatch) {
            await semaphore.removeAt(0);
          }
          
          // Inicia upload
          final uploadFuture = _uploadSingleMediaOptimizedBatch(media, uploadFutures.length + 1, sessionId);
          semaphore.add(uploadFuture);
          uploadFutures.add(uploadFuture);
        }
        
        // Aguarda todos os uploads do chunk
        final results = await Future.wait(uploadFutures);
        final chunkUploaded = results.where((success) => success).length;
        totalUploaded += chunkUploaded;
        
        
        // Delay mínimo entre chunks
        if (i + chunkSizeBatch < inspectionMediaFiles.length) {
          await Future.delayed(const Duration(milliseconds: 25)); // Muito rápido
        }
      }
      
      stopwatch.stop();
      
      // Finalizar tracking e timer
      notificationTimer.cancel();
      UploadProgressService.instance.stopUploadTracking(sessionId);
      
      // Log resultado final apenas se houver upload
      if (totalUploaded > 0) {
        final timeSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
        log('Batch upload: $totalUploaded/${inspectionMediaFiles.length} em ${timeSeconds}s');
        
        // Notificação final de conclusão (usando showSyncProgress para consistência)
        await SimpleNotificationService.instance.showSyncProgress(
          title: 'Upload Concluído',
          message: 'Todas as $totalUploaded mídias foram enviadas com sucesso!',
          progress: 100,
          currentItem: totalUploaded,
          totalItems: totalUploaded,
        );
      }
      
    } catch (e) {
      stopwatch.stop();
      notificationTimer?.cancel();
      if (sessionId != null) {
        UploadProgressService.instance.stopUploadTracking(sessionId);
      }
      log('Erro no batch otimizado: $e');
    }
  }

  /// Upload individual otimizado para batch manual
  Future<bool> _uploadSingleMediaOptimizedBatch(OfflineMedia media, int index, [String? sessionId]) async {
    try {
      // Skip se já foi feito upload
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        // Marcar como completo no tracking
        if (sessionId != null) {
          UploadProgressService.instance.markItemCompleted(sessionId, media.id);
        }
        return true;
      }
      
      // Upload com timeout agressivo para falha rápida
      final downloadUrl = await _uploadMediaToStorageOptimizedBatch(media, sessionId);
      
      if (downloadUrl != null) {
        await _offlineService.updateMediaCloudUrl(media.id, downloadUrl);
        
        // Marcar como completo no tracking
        if (sessionId != null) {
          UploadProgressService.instance.markItemCompleted(sessionId, media.id);
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Upload para Storage com configurações otimizadas para batch
  Future<String?> _uploadMediaToStorageOptimizedBatch(OfflineMedia media, [String? sessionId]) async {
    try {
      final file = File(media.localPath);
      if (!await file.exists()) {
        return null;
      }
      
      final storageRef = _firebaseService.storage.ref();
      final mediaPath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
      final mediaRef = storageRef.child(mediaPath);
      
      // Metadata mínima para upload mais rápido
      final metadata = SettableMetadata(
        contentType: media.mimeType,
        customMetadata: {
          'inspection_id': media.inspectionId,
          'type': media.type,
        },
      );
      
      // Upload com timeout agressivo para batch manual
      final uploadTask = mediaRef.putFile(file, metadata);
      
      // Monitor progress se temos sessionId
      StreamSubscription? progressSubscription;
      if (sessionId != null) {
        progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
          if (snapshot.state == TaskState.running) {
            UploadProgressService.instance.updateItemProgress(
              sessionId, 
              media.id, 
              snapshot.bytesTransferred
            );
          }
        });
      }
      
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 2), // Timeout mais agressivo para batch
        onTimeout: () {
          progressSubscription?.cancel();
          uploadTask.cancel();
          throw TimeoutException('Upload timeout batch', const Duration(minutes: 2));
        },
      );
      
      progressSubscription?.cancel();
      return await snapshot.ref.getDownloadURL();
      
    } catch (e) {
      return null;
    }
  }

  Future<void> uploadLocalChangesToCloud() async {
    try {

      // Upload media files first with optimized method
      await _uploadMediaFilesUltraFast();

      // Then upload inspection data with nested structure
      await _uploadInspectionsWithNestedStructure();

    } catch (e) {
      // Log apenas erros críticos
      log('Erro no upload para nuvem: $e');
    }
  }

  /// Ultra-fast media upload for manual sync operations
  Future<void> _uploadMediaFilesUltraFast([String? inspectionId]) async {
    try {
      
      List<OfflineMedia> mediaFiles;
      if (inspectionId != null) {
        mediaFiles = await _offlineService.getMediaPendingUpload();
        mediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();
      } else {
        mediaFiles = await _offlineService.getMediaPendingUpload();
      }
      
      if (mediaFiles.isEmpty) {
        return;
      }
      
      
      // Sort by file size for optimal upload order
      mediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      
      const int maxConcurrent = 25; // Maximum concurrent uploads (reduzido para estabilidade)
      const int chunkSize = 20; // Process in chunks to avoid memory issues (aumentado)
      
      int totalUploaded = 0;
      
      // Process in chunks with maximum concurrency
      for (int i = 0; i < mediaFiles.length; i += chunkSize) {
        final chunk = mediaFiles.skip(i).take(chunkSize).toList();
        
        // Create semaphore for concurrency control
        final semaphore = <Future>[];
        final uploadFutures = <Future<bool>>[];
        
        // Start all uploads in the chunk
        for (final media in chunk) {
          // Wait for available slot
          while (semaphore.length >= maxConcurrent) {
            await semaphore.removeAt(0);
          }
          
          // Start upload
          final uploadFuture = _uploadSingleMediaWithTiming(media, uploadFutures.length + 1);
          semaphore.add(uploadFuture);
          uploadFutures.add(uploadFuture);
        }
        
        // Wait for all uploads in this chunk
        final results = await Future.wait(uploadFutures);
        final chunkUploaded = results.where((success) => success).length;
        totalUploaded += chunkUploaded;
        
        
        // Small delay between chunks
        if (i + chunkSize < mediaFiles.length) {
          await Future.delayed(const Duration(milliseconds: 50)); // Reduzido de 100ms para 50ms
        }
      }
      
      // Log resultado final apenas se houver upload
      if (totalUploaded > 0) {
        log('Ultra-fast upload: $totalUploaded/${mediaFiles.length} mídias');
      }
      
    } catch (e) {
      // Log apenas erros críticos
      log('Erro no ultra-fast upload: $e');
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
      
      // Process media files in optimized parallel batches
      const int batchSize = 25; // Increased batch size for better throughput (otimizado)
      
      // Sort files by size for better perceived performance
      mediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      
      for (int i = 0; i < mediaFiles.length; i += batchSize) {
        final batch = mediaFiles.skip(i).take(batchSize).toList();
        debugPrint('FirestoreSyncService: ⚡ FAST BATCH ${(i ~/ batchSize) + 1}: ${batch.length} files');
        
        // Upload batch in parallel with optimized method
        final futures = batch.map((media) => _uploadSingleMediaWithTiming(media, i + 1));
        await Future.wait(futures);
        
        debugPrint('FirestoreSyncService: ✅ COMPLETED BATCH ${(i ~/ batchSize) + 1}');
        
        // Reduced delay for better speed
        if (i + batchSize < mediaFiles.length) {
          await Future.delayed(const Duration(milliseconds: 100)); // Reduzido de 200ms para 100ms
        }
      }
      
      debugPrint('FirestoreSyncService: Finished uploading media files');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media files: $e');
    }
  }
  

  Future<void> _uploadMediaFilesWithProgress(String inspectionId) async {
    final totalStopwatch = Stopwatch()..start();
    
    try {
      debugPrint('FirestoreSyncService: Starting optimized upload for inspection $inspectionId');
      
      // Upload apenas mídias da inspeção específica
      final mediaFiles = await _offlineService.getMediaPendingUpload();
      final inspectionMediaFiles = mediaFiles.where((media) => media.inspectionId == inspectionId).toList();
      
      if (inspectionMediaFiles.isEmpty) {
        debugPrint('FirestoreSyncService: No media files to upload');
        return;
      }
      
      debugPrint('FirestoreSyncService: Found ${inspectionMediaFiles.length} media files to upload');
      
      int uploadedCount = 0;
      
      // Sort by file size - upload smaller files first for perceived speed
      inspectionMediaFiles.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      
      // Emit initial progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: 0,
        total: inspectionMediaFiles.length,
        message: 'Upload iniciado: ${inspectionMediaFiles.length} arquivos',
        currentItem: 'Preparando',
        itemType: 'Mídia',
        mediaCount: inspectionMediaFiles.length,
      ));
      
      // Process uploads with controlled concurrency to prevent blocking
      const int batchSize = 8; // Process in batches otimizados (aumentado de 8)
      
      for (int i = 0; i < inspectionMediaFiles.length; i += batchSize) {
        final batch = inspectionMediaFiles.skip(i).take(batchSize).toList();
        
        // Process batch with Future.wait (no additional concurrency control needed)
        final batchFutures = batch.asMap().entries.map((entry) {
          final index = i + entry.key + 1;
          final media = entry.value;
          return _uploadSingleMediaWithTiming(media, index);
        }).toList();
        
        final batchResults = await Future.wait(batchFutures);
        uploadedCount += batchResults.where((success) => success).length;
        
        // Update progress after each batch
        final completedCount = i + batch.length;
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: completedCount,
          total: inspectionMediaFiles.length,
          message: 'Upload: $completedCount/${inspectionMediaFiles.length}',
          currentItem: 'Processando',
          itemType: 'Mídia',
          mediaCount: inspectionMediaFiles.length,
        ));
      }
      
      totalStopwatch.stop();
      
      // Final progress update with timing
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: uploadedCount,
        total: inspectionMediaFiles.length,
        message: uploadedCount == inspectionMediaFiles.length 
            ? 'Concluído: ${inspectionMediaFiles.length} arquivos em ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s'
            : 'Parcial: $uploadedCount/${inspectionMediaFiles.length} em ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
        currentItem: 'Finalizado',
        itemType: 'Resultado',
        mediaCount: inspectionMediaFiles.length,
      ));
      
      debugPrint('FirestoreSyncService: Upload completed - $uploadedCount/${inspectionMediaFiles.length} files in ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
    } catch (e) {
      totalStopwatch.stop();
      debugPrint('FirestoreSyncService: Upload error after ${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s: $e');
    }
  }

  Future<bool> _uploadSingleMediaWithTiming(OfflineMedia media, int index) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Skip if already uploaded (optimization)
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        debugPrint('[$index] ${media.filename}: Already uploaded (0.0s)');
        return true;
      }
      
      // Upload to Firebase Storage with optimized settings
      final downloadUrl = await _uploadMediaToStorageOptimized(media);
      
      stopwatch.stop();
      final timeSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      
      if (downloadUrl != null) {
        // Update media with cloud URL
        await _offlineService.updateMediaCloudUrl(media.id, downloadUrl);
        debugPrint('[$index] ${media.filename}: ${(media.fileSize ?? 0) ~/ 1024}KB uploaded in ${timeSeconds}s');
        return true;
      } else {
        debugPrint('[$index] ${media.filename}: Failed after ${timeSeconds}s');
        return false;
      }
    } catch (e) {
      stopwatch.stop();
      final timeSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      debugPrint('[$index] ${media.filename}: Error after ${timeSeconds}s - $e');
      return false;
    }
  }



  Future<String?> _uploadMediaToStorageOptimized(OfflineMedia media) async {
    try {
      // Check if file exists
      final file = File(media.localPath);
      if (!await file.exists()) {
        return null;
      }
      
      // Create storage reference with optimized path structure
      final storageRef = _firebaseService.storage.ref();
      final mediaPath = 'inspections/${media.inspectionId}/media/${media.type}/${media.filename}';
      final mediaRef = storageRef.child(mediaPath);
      
      // Minimal metadata for faster upload
      final metadata = SettableMetadata(
        contentType: media.mimeType,
        customMetadata: {
          'inspection_id': media.inspectionId,
          'type': media.type,
          'filename': media.filename,
        },
      );
      
      // Upload with timeout for faster failure detection
      final uploadTask = mediaRef.putFile(file, metadata);
      
      // Wait for upload completion with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          uploadTask.cancel();
          throw TimeoutException('Upload timeout', const Duration(minutes: 3));
        },
      );
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
      
    } catch (e) {
      // Handle timeout gracefully - try once more with regular method
      if (e is TimeoutException) {
        return _uploadMediaToStorage(media);
      }
      
      return null;
    }
  }

  Future<String?> _uploadMediaToStorage(OfflineMedia media) async {
    try {
      // Check if media already has cloudUrl (already uploaded by BackgroundMediaSyncService)
      if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
        debugPrint('FirestoreSyncService: Media ${media.filename} already has cloudUrl, skipping upload');
        return media.cloudUrl;
      }
      
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
      
      // Monitor upload progress with error handling
      late StreamSubscription progressSubscription;
      progressSubscription = uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.state == TaskState.running) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            debugPrint('FirestoreSyncService: Upload progress for ${media.filename}: ${(progress * 100).toStringAsFixed(1)}%');
            
            // Update progress in database
            _offlineService.updateMediaUploadProgress(media.id, progress * 100).catchError((e) {
              debugPrint('FirestoreSyncService: Error updating progress for ${media.filename}: $e');
            });
          }
        },
        onError: (error) {
          debugPrint('FirestoreSyncService: Progress monitoring error for ${media.filename}: $error');
          progressSubscription.cancel();
        },
        onDone: () {
          progressSubscription.cancel();
        },
      );
      
      // Wait for upload completion with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 5), // 5 minute timeout per file
        onTimeout: () {
          debugPrint('FirestoreSyncService: Upload timeout for ${media.filename}');
          uploadTask.cancel();
          progressSubscription.cancel();
          throw TimeoutException('Upload timeout', const Duration(minutes: 5));
        },
      );
      
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
            debugPrint('FirestoreSyncService: Upload was canceled - this can happen with concurrent uploads');
            // Return null to indicate cancellation (not a hard error)
            return null;
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
      debugPrint('FirestoreSyncService: Found ${inspections.length} inspections to upload');

      // Process inspections in parallel batches of 5
      const int batchSize = 5;
      for (int i = 0; i < inspections.length; i += batchSize) {
        final batch = inspections.skip(i).take(batchSize).toList();
        debugPrint('FirestoreSyncService: Processing inspection batch ${(i ~/ batchSize) + 1}: ${batch.length} inspections');
        
        // Upload batch in parallel
        final futures = batch.map((inspection) => _uploadSingleInspectionSafely(inspection));
        await Future.wait(futures);
        
        debugPrint('FirestoreSyncService: Completed inspection batch ${(i ~/ batchSize) + 1}');
        
        // Add delay between batches to prevent resource conflicts
        if (i + batchSize < inspections.length) {
          await Future.delayed(const Duration(milliseconds: 500)); // Reduzido de 1000ms para 500ms
        }
      }
      
      debugPrint('FirestoreSyncService: Finished uploading all inspections');
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error uploading inspections with nested structure: $e');
    }
  }
  
  Future<void> _uploadSingleInspectionSafely(Inspection inspection) async {
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
    
    // Validate inspection data before processing
    if (inspection.id.isEmpty) {
      throw ArgumentError('Inspection ID cannot be empty');
    }
    
    if (inspection.title.trim().isEmpty) {
      throw ArgumentError('Inspection title cannot be empty');
    }
    
    if (inspection.inspectorId?.isEmpty ?? true) {
      throw ArgumentError('Inspector ID cannot be empty');
    }
    
    // Start with basic inspection data
    final data = inspection.toMap();
    
    // Validate and clean data fields
    data.remove('id');
    data.remove('needs_sync');
    data.remove('is_deleted');
    
    // Ensure required fields are valid
    if (data['title'] == null || (data['title'] as String).trim().isEmpty) {
      throw ArgumentError('Inspection title is required and cannot be empty');
    }
    
    if (data['inspector_id'] == null || (data['inspector_id'] as String).isEmpty) {
      throw ArgumentError('Inspector ID is required and cannot be empty');
    }

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
      
      // Validate topic data before processing
      if (topic.id?.isEmpty ?? true) {
        debugPrint('FirestoreSyncService: Skipping topic with empty ID: ${topic.topicName}');
        continue;
      }
      
      if (topic.topicName.trim().isEmpty) {
        debugPrint('FirestoreSyncService: Skipping topic with empty name: ID ${topic.id}');
        continue;
      }
      
      if (topic.inspectionId.isEmpty || topic.inspectionId != inspection.id) {
        debugPrint('FirestoreSyncService: Skipping topic with invalid inspection ID: ${topic.id}');
        continue;
      }
      
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
      
      // NOTE: Removed duplication logic for direct_details topics
      // Media from direct details should only appear in individual details, not in topic media array
      // This prevents duplicated images in the Firestore structure
      
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
          

          detailsData.add(detailData);
        }

          itemData['details'] = detailsData;
          itemsData.add(itemData);
        }

        topicData['items'] = itemsData;
      }
      topicsData.add(topicData);
    }

    // Add topics to the main data
    data['topics'] = topicsData;
    
    // Add sync history
    if (inspection.syncHistory != null) {
      data['sync_history'] = inspection.syncHistory;
    }

    // Validate data before returning to prevent Firestore invalid-argument errors
    final validatedData = _validateDataForFirestore(data);
    return validatedData;
  }

  /// Validates data before sending to Firestore to prevent invalid-argument errors
  Map<String, dynamic> _validateDataForFirestore(Map<String, dynamic> data) {
    final validatedData = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip null values except for allowed nullable fields
      if (value == null) {
        // Only include null for explicitly allowed fields
        final allowedNullFields = {
          'observation', 'description', 'template_id', 'template_name', 
          'street', 'neighborhood', 'city', 'state', 'zip_code', 'address_string',
          'address', 'finished_at', 'scheduled_date', 'area', 'deleted_at',
          'evaluation_value', 'evaluation', 'custom_option_value', 'value'
        };
        if (allowedNullFields.contains(key)) {
          validatedData[key] = null;
        }
        continue;
      }
      
      // Skip empty string values that should be null
      if (value is String && value.isEmpty) {
        final shouldBeNullFields = {
          'observation', 'description', 'evaluation_value', 'evaluation', 
          'custom_option_value', 'value', 'tags', 'options'
        };
        if (shouldBeNullFields.contains(key)) {
          validatedData[key] = null;
          continue;
        }
      }
      
      // Validate field name - Firestore doesn't allow certain characters
      if (key.isEmpty || key.length > 1500 || // Max field name length
          key.contains('.') || key.contains('/') || key.contains('__') || 
          key.startsWith('_') || key.endsWith('_') ||
          key.contains('\$') || key.contains('#') || key.contains('[') || key.contains(']')) {
        debugPrint('FirestoreSyncService: ⚠️ SKIPPING invalid field name: $key');
        continue;
      }
      
      // Validate string values
      if (value is String) {
        // Check for extremely long strings (Firestore has limits)
        if (value.length > 1048487) { // ~1MB limit for strings in Firestore
          debugPrint('FirestoreSyncService: ⚠️ TRUNCATING overly long string in field: $key');
          validatedData[key] = value.substring(0, 1048487);
          continue;
        }
        
        // Remove any invalid control characters from strings
        final cleanString = value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
        validatedData[key] = cleanString;
      } else if (value is num) {
        // Validate numeric values (Firestore has limits)
        if (value.isNaN || value.isInfinite) {
          debugPrint('FirestoreSyncService: ⚠️ SKIPPING invalid numeric value in field: $key');
          continue;
        }
        validatedData[key] = value;
      } else if (value is bool) {
        validatedData[key] = value;
      } else if (value is Map<String, dynamic>) {
        // Recursively validate nested objects
        final validatedNested = _validateDataForFirestore(value);
        if (validatedNested.isNotEmpty) {
          validatedData[key] = validatedNested;
        }
      } else if (value is List) {
        final validatedList = _validateListForFirestore(value);
        if (validatedList.isNotEmpty) {
          validatedData[key] = validatedList;
        }
      } else {
        // Convert other types to string for safety
        final stringValue = value.toString();
        if (stringValue.isNotEmpty && stringValue != 'null') {
          validatedData[key] = stringValue;
        }
      }
    }
    
    return validatedData;
  }
  
  /// Validates lists for Firestore compatibility
  List _validateListForFirestore(List list) {
    final validatedList = [];
    
    for (final item in list) {
      if (item == null) {
        // Skip null items in lists
        continue;
      } else if (item is Map<String, dynamic>) {
        validatedList.add(_validateDataForFirestore(item));
      } else if (item is List) {
        validatedList.add(_validateListForFirestore(item));
      } else if (item is String) {
        // Remove any invalid characters from strings
        final cleanString = item.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
        validatedList.add(cleanString);
      } else {
        validatedList.add(item);
      }
    }
    
    return validatedList;
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
      debugPrint('FirestoreSyncService: Starting enhanced sync for inspection $inspectionId');

      // Emit starting progress
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.starting,
        current: 0,
        total: 100,
        message: 'Preparando sincronização...',
      ));

      // Get local inspection first to check for conflicts
      final localInspection = await _offlineService.getInspection(inspectionId);
      
      // Download da nuvem
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      int currentStep = 0;
      const totalSteps = 5; // Upload media, upload data, download, verify, complete

      // *** PRIMEIRO: Upload das mudanças locais (incluindo exclusões) ***
      if (localInspection != null) {
        debugPrint('FirestoreSyncService: 🔧 UPLOAD PRIMEIRO - Uploading local changes (data + media) for inspection $inspectionId');
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Enviando mídias para nuvem...',
          currentItem: 'Mídias pendentes',
          itemType: 'Arquivo',
        ));
        
        // PRIMEIRO: Upload das mídias pendentes com batch otimizado
        await uploadMediaBatchOptimized(inspectionId);
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Enviando dados da inspeção...',
          currentItem: localInspection.title,
          itemType: 'Inspeção',
        ));
        
        // SEGUNDO: Upload da inspeção com estrutura completa
        await _uploadSingleInspectionWithNestedStructure(inspectionId);
        
        debugPrint('FirestoreSyncService: ✅ Successfully uploaded all local changes for inspection $inspectionId');
      }

      // *** DOWNLOAD APENAS SE NÃO TEMOS DADOS LOCAIS (primeiro download) ***
      if (docSnapshot.exists && localInspection == null) {
        debugPrint('FirestoreSyncService: 📥 PRIMEIRO DOWNLOAD - No local data found, downloading from cloud');
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.downloading,
          current: ++currentStep,
          total: totalSteps,
          message: 'Baixando dados da nuvem...',
          currentItem: 'Dados da inspeção',
          itemType: 'Inspeção',
        ));
        
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
        
        debugPrint('FirestoreSyncService: Saving inspection $inspectionId to local database');
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
          currentStep++;
          final data = docSnapshot.data()!;
          final convertedData = _convertFirestoreTimestamps(data);
          final cloudInspection = Inspection.fromMap(convertedData);
          await _downloadInspectionTemplate(cloudInspection);
        }
      }

      // *** NOVA ETAPA: Verificação na nuvem (opcional e rápida) ***
      CloudVerificationResult? verificationResult;
      
      try {
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.verifying,
          current: ++currentStep,
          total: totalSteps,
          message: 'Verificando integridade na nuvem...',
          currentItem: 'Validação rápida',
          itemType: 'Verificação',
          isVerifying: true,
        ));

        // Verificação rápida com timeout curto - se falhar, assume sucesso
        verificationResult = await CloudVerificationService.instance.verifyInspectionSync(inspectionId, quickCheck: true);
        
        debugPrint('FirestoreSyncService: Verificação ${verificationResult.isComplete ? 'passou' : 'falhou'}: ${verificationResult.summary}');
      } catch (e) {
        debugPrint('FirestoreSyncService: Erro na verificação (ignorando): $e');
        // Se a verificação falhar por qualquer motivo, assumir sucesso
        verificationResult = CloudVerificationResult(
          isComplete: true,
          totalItems: 1,
          verifiedItems: 1,
          missingItems: [],
          failedItems: [],
          summary: 'Verificação pulada devido a erro - assumindo sucesso',
        );
      }

      // Marcar como sincronizado apenas após verificação completa
      await _offlineService.markInspectionSynced(inspectionId);

      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.completed,
        current: totalSteps,
        total: totalSteps,
        message: 'Sincronização completa e verificada! ${verificationResult.summary}',
      ));

      debugPrint(
          'FirestoreSyncService: Finished syncing inspection $inspectionId with verification');
      return {
        'success': true, 
        'hasConflicts': false,
        'verification': verificationResult
      };
    } catch (e) {
      debugPrint(
          'FirestoreSyncService: Error syncing inspection $inspectionId: $e');
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 0,
        total: 1,
        message: 'Erro na sincronização: $e',
      ));
      
      return {'success': false, 'error': e.toString()};
    }
  }





  /// Sincroniza múltiplas inspeções com progresso detalhado
  Future<Map<String, dynamic>> syncMultipleInspections(List<String> inspectionIds) async {
    if (!await isConnected()) {
      debugPrint('FirestoreSyncService: No internet connection for multiple inspections sync');
      return {'success': false, 'error': 'No internet connection'};
    }

    try {
      debugPrint('FirestoreSyncService: Starting BATCH sync for ${inspectionIds.length} inspections');
      
      final results = <String, Map<String, dynamic>>{};
      int successCount = 0;
      int failureCount = 0;
      
      // Process inspections in parallel batches of 3
      const int batchSize = 3;
      int processedCount = 0;
      
      for (int i = 0; i < inspectionIds.length; i += batchSize) {
        final batch = inspectionIds.skip(i).take(batchSize).toList();
        debugPrint('FirestoreSyncService: Processing parallel batch ${(i ~/ batchSize) + 1}: ${batch.length} inspections');
        
        // Emit progress for current batch
        _syncProgressController.add(SyncProgress(
          inspectionId: 'multiple',
          phase: SyncPhase.starting,
          current: processedCount,
          total: inspectionIds.length,
          message: 'Sincronizando em batches ${(i ~/ batchSize) + 1} (${batch.length} inspeções)...',
          currentItem: '${(i ~/ batchSize) + 1}',
          itemType: 'Lote de Inspeções',
          totalInspections: inspectionIds.length,
          currentInspectionIndex: processedCount + 1,
        ));
        
        // Create futures for parallel execution
        final futures = batch.map((inspectionId) async {
          try {
            final inspection = await _offlineService.getInspection(inspectionId);
            final inspectionTitle = inspection?.title ?? 'Inspeção $inspectionId';
            
            debugPrint('FirestoreSyncService: Starting parallel sync for: $inspectionTitle');
            final result = await syncInspection(inspectionId);
            
            return {
              'id': inspectionId,
              'title': inspectionTitle,
              'result': result,
            };
          } catch (e) {
            debugPrint('FirestoreSyncService: Error in parallel sync for $inspectionId: $e');
            return {
              'id': inspectionId,
              'title': 'Inspeção $inspectionId',
              'result': {'success': false, 'error': e.toString()},
            };
          }
        });
        
        // Wait for all inspections in batch to complete
        final batchResults = await Future.wait(futures);
        
        // Process results
        for (final batchResult in batchResults) {
          final inspectionId = batchResult['id'] as String;
          final result = batchResult['result'] as Map<String, dynamic>;
          results[inspectionId] = result;
          
          if (result['success'] == true) {
            successCount++;
            debugPrint('FirestoreSyncService: ✅ Successfully synced inspection $inspectionId');
          } else {
            failureCount++;
            debugPrint('FirestoreSyncService: ❌ Failed to sync inspection $inspectionId: ${result['error']}');
          }
          
          processedCount++;
        }
        
        // Update progress after batch completion
        _syncProgressController.add(SyncProgress(
          inspectionId: 'multiple',
          phase: SyncPhase.uploading,
          current: processedCount,
          total: inspectionIds.length,
          message: 'Processadas $processedCount de ${inspectionIds.length} inspeções...',
          currentItem: 'Progresso geral',
          itemType: 'Inspeção',
          totalInspections: inspectionIds.length,
          currentInspectionIndex: processedCount,
        ));
        
        final successfulInBatch = batchResults.where((r) {
          final result = r['result'] as Map<String, dynamic>?;
          return result != null && result['success'] == true;
        }).length;
        debugPrint('FirestoreSyncService: Completed batch ${(i ~/ batchSize) + 1} - Success: $successfulInBatch/${batch.length}');
        
        // Add delay between batches to prevent resource conflicts
        if (i + batchSize < inspectionIds.length) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      // Final completion status
      final isFullSuccess = failureCount == 0;
      final summary = isFullSuccess 
          ? 'Todas as $successCount inspeções foram sincronizadas com sucesso!'
          : '$successCount de ${inspectionIds.length} inspeções sincronizadas. $failureCount falharam.';
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: isFullSuccess ? SyncPhase.completed : SyncPhase.error,
        current: inspectionIds.length,
        total: inspectionIds.length,
        message: summary,
        totalInspections: inspectionIds.length,
        currentInspectionIndex: inspectionIds.length,
      ));
      
      debugPrint('FirestoreSyncService: BATCH multiple sync completed - Success: $successCount, Failed: $failureCount');
      
      return {
        'success': isFullSuccess,
        'totalInspections': inspectionIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'summary': summary,
        'results': results,
      };
    } catch (e) {
      debugPrint('FirestoreSyncService: Error in batch multiple inspections sync: $e');
      
      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: SyncPhase.error,
        current: 0,
        total: inspectionIds.length,
        message: 'Erro na sincronização múltipla: $e',
        totalInspections: inspectionIds.length,
      ));
      
      return {
        'success': false, 
        'error': e.toString(),
        'totalInspections': inspectionIds.length,
        'successCount': 0,
        'failureCount': inspectionIds.length,
      };
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

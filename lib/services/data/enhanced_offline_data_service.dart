import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/repositories/inspection_repository.dart';
import 'package:lince_inspecoes/repositories/topic_repository.dart';
import 'package:lince_inspecoes/repositories/item_repository.dart';
import 'package:lince_inspecoes/repositories/detail_repository.dart';
import 'package:lince_inspecoes/repositories/non_conformity_repository.dart';
import 'package:lince_inspecoes/repositories/media_repository.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/models/template.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineDataService {
  static OfflineDataService? _instance;
  static OfflineDataService get instance =>
      _instance ??= OfflineDataService._();

  OfflineDataService._();

  // Repositórios
  late final InspectionRepository _inspectionRepository;
  late final TopicRepository _topicRepository;
  late final ItemRepository _itemRepository;
  late final DetailRepository _detailRepository;
  late final NonConformityRepository _nonConformityRepository;
  late final MediaRepository _mediaRepository;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar o Hive
    await DatabaseHelper.init();

    // Inicializar repositórios
    _inspectionRepository = InspectionRepository();
    _topicRepository = TopicRepository();
    _itemRepository = ItemRepository();
    _detailRepository = DetailRepository();
    _nonConformityRepository = NonConformityRepository();
    _mediaRepository = MediaRepository();

    _isInitialized = true;
  }

  // ===============================
  // OPERAÇÕES DE INSPEÇÃO
  // ===============================

  Future<Inspection?> getInspection(String id) async {
    final result = await _inspectionRepository.findById(id);
    return result;
  }

  Future<List<Inspection>> getInspectionsByInspector(String inspectorId) async {
    final result = await _inspectionRepository.findByInspectorId(inspectorId);
    return result;
  }

  Future<List<Inspection>> getAllInspections() async {
    return await _inspectionRepository.findAll();
  }

  Future<List<Inspection>> getInspectionsByStatus(String status) async {
    return await _inspectionRepository.findByStatus(status);
  }

  Future<String> saveInspection(Inspection inspection) async {
    final result = await _inspectionRepository.insert(inspection);
    debugPrint('DataService: Inspection saved with ID: $result');
    return result;
  }

  Future<void> updateInspection(Inspection inspection) async {
    await _inspectionRepository.update(inspection);
    debugPrint('DataService: Inspection ${inspection.id} updated successfully');
  }

  Future<void> insertOrUpdateInspection(Inspection inspection) async {
    await _inspectionRepository.insertOrUpdate(inspection);
  }

  Future<void> insertOrUpdateInspectionFromCloud(Inspection inspection) async {
    await _inspectionRepository.insertOrUpdateFromCloud(inspection);

    // Verificar se foi salvo corretamente
    final savedInspection = await _inspectionRepository.findById(inspection.id);
    if (savedInspection != null) {
    } else {
      debugPrint(
          'OfflineDataService: ❌ ERRO: Inspeção ${inspection.id} NÃO foi encontrada após salvamento!');
    }
  }

  Future<void> insertOrUpdateTopicFromCloud(Topic topic) async {
    await _topicRepository.insertOrUpdateFromCloud(topic);
  }

  Future<void> insertOrUpdateItemFromCloud(Item item) async {
    await _itemRepository.insertOrUpdateFromCloud(item);
  }

  Future<void> addSyncHistoryEntry(
      String inspectionId, String inspectorId, String action,
      {Map<String, dynamic>? metadata}) async {
    // Deprecated - sync history removed from Inspection model
    debugPrint(
        'DataService: Sync history entry ignored (feature removed): $action for inspection $inspectionId');
  }

  // Método público para forçar upload com debugging
  Future<void> forceUploadWithDebugging(String inspectionId) async {
    final syncService = FirestoreSyncService.instance;
    await syncService.forceUploadInspection(inspectionId);
  }

  Future<void> insertOrUpdateDetailFromCloud(Detail detail) async {
    await _detailRepository.insertOrUpdateFromCloud(detail);
  }

  Future<void> deleteInspection(String id) async {
    await _inspectionRepository.delete(id);
  }

  Future<void> updateInspectionProgress(
      String inspectionId, double progress, int completed, int total) async {
    await _inspectionRepository.updateProgress(
        inspectionId, progress, completed, total);
  }

  Future<void> updateInspectionStatus(
      String inspectionId, String status) async {
    debugPrint(
        'DataService: Updating inspection $inspectionId status to $status');
    await _inspectionRepository.updateStatus(inspectionId, status);

    debugPrint(
        'DataService: Inspection $inspectionId status updated to $status');
  }

  Future<Map<String, int>> getInspectionStats() async {
    return await _inspectionRepository.getInspectionStats();
  }

  // ===============================
  // OPERAÇÕES DE TÓPICO
  // ===============================

  Future<List<Topic>> getTopics(String inspectionId) async {
    final result =
        await _topicRepository.findByInspectionIdOrdered(inspectionId);
    return result;
  }

  Future<Topic?> getTopic(String topicId) async {
    return await _topicRepository.findById(topicId);
  }

  Future<String> saveTopic(Topic topic) async {
    debugPrint(
        'DataService: Saving topic ${topic.topicName} for inspection ${topic.inspectionId}');
    final result = await _topicRepository.insert(topic);
    debugPrint('DataService: Topic saved with ID: $result');
    return result;
  }

  Future<void> insertOrUpdateTopic(Topic topic) async {
    final existing = await _topicRepository.findById(topic.id);
    if (existing != null) {
      await _topicRepository.update(topic);
    } else {
      await _topicRepository.insert(topic);
    }
  }

  Future<void> updateTopic(Topic topic) async {
    await _topicRepository.update(topic);

    debugPrint('DataService: Topic ${topic.id} updated successfully');
  }

  Future<void> deleteTopic(String topicId) async {
    debugPrint('DataService: Deleting topic $topicId');

    await _topicRepository.delete(topicId);

    debugPrint('DataService: Topic $topicId deleted successfully');
  }

  Future<void> updateTopicProgress(
      String topicId, double progress, int completed, int total) async {
    await _topicRepository.updateProgress(topicId, progress, completed, total);
  }

  Future<void> reorderTopics(String inspectionId, List<String> topicIds) async {
    await _topicRepository.reorderTopics(inspectionId, topicIds);
  }

  // ===============================
  // OPERAÇÕES DE ITEM
  // ===============================

  Future<List<Item>> getItems(String topicId) async {
    return await _itemRepository.findByTopicIdOrdered(topicId);
  }

  Future<List<Item>> getItemsByInspection(String inspectionId) async {
    return await _itemRepository.findByInspectionIdOrdered(inspectionId);
  }

  Future<Item?> getItem(String itemId) async {
    return await _itemRepository.findById(itemId);
  }

  Future<String> saveItem(Item item) async {
    final result = await _itemRepository.insert(item);
    return result;
  }

  Future<void> insertOrUpdateItem(Item item) async {
    await _itemRepository.insertOrUpdate(item);
  }

  Future<void> updateItem(Item item) async {
    await _itemRepository.update(item);
  }

  Future<void> deleteItem(String itemId) async {
    debugPrint('DataService: Deleting item $itemId');

    await _itemRepository.delete(itemId);

    debugPrint('DataService: Item $itemId deleted successfully');
  }

  Future<void> updateItemProgress(
      String itemId, double progress, int completed, int total) async {
    await _itemRepository.updateProgress(itemId, progress, completed, total);
  }

  Future<void> reorderItems(String topicId, List<String> itemIds) async {
    await _itemRepository.reorderItems(topicId, itemIds);
  }

  Future<int> getItemCount(String topicId) async {
    return await _itemRepository.countByTopicId(topicId);
  }

  Future<int> getCompletedItemCount(String topicId) async {
    return await _itemRepository.countCompletedByTopicId(topicId);
  }

  // ===============================
  // OPERAÇÕES DE DETALHE
  // ===============================

  Future<List<Detail>> getDetails(String itemId) async {
    return await _detailRepository.findByItemIdOrdered(itemId);
  }

  // Buscar detalhes diretos de tópico (hierarquia flexível)
  Future<List<Detail>> getDirectDetails(String topicId) async {
    return await _detailRepository.findDirectDetailsByTopicIdOrdered(topicId);
  }

  Future<List<Detail>> getDetailsByTopic(String topicId) async {
    return await _detailRepository.findByTopicId(topicId);
  }

  Future<List<Detail>> getDetailsByInspection(String inspectionId) async {
    return await _detailRepository.findByInspectionId(inspectionId);
  }

  Future<Detail?> getDetail(String detailId) async {
    return await _detailRepository.findById(detailId);
  }

  Future<String> saveDetail(Detail detail) async {
    final result = await _detailRepository.insert(detail);
    return result;
  }

  Future<void> insertOrUpdateDetail(Detail detail) async {
    await _detailRepository.insertOrUpdate(detail);
  }

  Future<void> updateDetail(Detail detail) async {
    debugPrint(
        'DataService: Updating detail ${detail.id} - ${detail.detailName} with value: ${detail.detailValue}');
    await _detailRepository.update(detail);

    debugPrint('DataService: Detail ${detail.id} updated successfully');
  }

  Future<void> deleteDetail(String detailId) async {
    debugPrint('DataService: Deleting detail $detailId');

    await _detailRepository.delete(detailId);

    debugPrint('DataService: Detail $detailId deleted successfully');
  }

  Future<void> updateDetailValue(
      String detailId, String? value, String? observations) async {
    await _detailRepository.updateValue(detailId, value, observations);
  }

  Future<void> markDetailCompleted(String detailId) async {
    await _detailRepository.markAsCompleted(detailId);
  }

  Future<void> markDetailIncomplete(String detailId) async {
    await _detailRepository.markAsIncomplete(detailId);
  }

  Future<void> reorderDetails(String itemId, List<String> detailIds) async {
    await _detailRepository.reorderDetails(itemId, detailIds);
  }

  Future<int> getDetailCount(String itemId) async {
    return await _detailRepository.countByItemId(itemId);
  }

  Future<int> getCompletedDetailCount(String itemId) async {
    return await _detailRepository.countCompletedByItemId(itemId);
  }

  // Contadores para detalhes diretos de tópico
  Future<int> getDirectDetailCount(String topicId) async {
    return await _detailRepository.countDirectDetailsByTopicId(topicId);
  }

  Future<int> getDirectDetailCompletedCount(String topicId) async {
    return await _detailRepository
        .countDirectDetailsCompletedByTopicId(topicId);
  }

  // ===============================
  // OPERAÇÕES DE NÃO CONFORMIDADE
  // ===============================

  Future<List<NonConformity>> getNonConformities(String inspectionId) async {
    return await _nonConformityRepository.findByInspectionId(inspectionId);
  }

  Future<List<NonConformity>> getNonConformitiesByTopic(String topicId) async {
    return await _nonConformityRepository.findByTopicId(topicId);
  }

  Future<List<NonConformity>> getNonConformitiesByItem(String itemId) async {
    return await _nonConformityRepository.findByItemId(itemId);
  }

  Future<List<NonConformity>> getNonConformitiesByDetail(
      String detailId) async {
    return await _nonConformityRepository.findByDetailId(detailId);
  }

  Future<NonConformity?> getNonConformity(String nonConformityId) async {
    return await _nonConformityRepository.findById(nonConformityId);
  }

  Future<String> saveNonConformity(NonConformity nonConformity) async {
    final result = await _nonConformityRepository.insert(nonConformity);

    return result;
  }

  Future<void> updateNonConformity(NonConformity nonConformity) async {
    await _nonConformityRepository.update(nonConformity);
  }

  Future<void> insertOrUpdateNonConformity(NonConformity nonConformity) async {
    final existing = await _nonConformityRepository.findById(nonConformity.id);
    if (existing != null) {
      await _nonConformityRepository.update(nonConformity);
    } else {
      await _nonConformityRepository.insert(nonConformity);
    }
  }

  Future<void> deleteNonConformity(String nonConformityId) async {
    await _nonConformityRepository.delete(nonConformityId);
  }

  Future<void> updateNonConformityStatus(
      String nonConformityId, String status) async {
    await _nonConformityRepository.updateStatus(nonConformityId, status);
  }

  Future<void> updateNonConformitySeverity(
      String nonConformityId, String severity) async {
    await _nonConformityRepository.updateSeverity(nonConformityId, severity);
  }

  Future<Map<String, int>> getNonConformityStats(String inspectionId) async {
    return await _nonConformityRepository.getStatsByInspectionId(inspectionId);
  }

  Future<List<NonConformity>> getNonConformitiesByInspectionGroupedBySeverity(
      String inspectionId) async {
    return await _nonConformityRepository
        .findByInspectionIdGroupedBySeverity(inspectionId);
  }

  // ===============================
  // OPERAÇÕES DE MÍDIA
  // ===============================

  Future<List<OfflineMedia>> getMediaByInspection(String inspectionId) async {
    return await _mediaRepository.findByInspectionId(inspectionId);
  }

  Future<List<OfflineMedia>> getMediaByTopic(String topicId) async {
    return await _mediaRepository.findByTopicId(topicId);
  }

  Future<List<OfflineMedia>> getMediaByTopicDirectDetails(
      String topicId) async {
    return await _mediaRepository.findByTopicDirectDetails(topicId);
  }

  Future<List<OfflineMedia>> getMediaByItem(String itemId) async {
    return await _mediaRepository.findByItemId(itemId);
  }

  Future<List<OfflineMedia>> getMediaByDetail(String detailId) async {
    return await _mediaRepository.findByDetailId(detailId);
  }

  Future<List<OfflineMedia>> getMediaByNonConformity(
      String nonConformityId) async {
    return await _mediaRepository.findByNonConformityId(nonConformityId);
  }

  Future<OfflineMedia?> getMedia(String mediaId) async {
    return await _mediaRepository.findById(mediaId);
  }

  Future<String> saveMedia(OfflineMedia media) async {
    return await _mediaRepository.insert(media);
  }

  Future<void> updateMedia(OfflineMedia media) async {
    await _mediaRepository.update(media);
  }

  Future<void> deleteMedia(String mediaId) async {
    await _mediaRepository.delete(mediaId);
  }

  Future<List<OfflineMedia>> getMediaByFilename(String filename) async {
    return await _mediaRepository.findByFilename(filename);
  }

  Future<File> createMediaFile(String filename) async {
    return await _mediaRepository.createLocalFile(filename);
  }

  Future<String> saveOfflineMedia({
    required String inspectionId,
    required String filename,
    required String localPath,
    required String cloudUrl,
    required String type,
    required int fileSize,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    bool isUploaded = false,
    String? source,
    int? width,
    int? height,
    int? duration,
    DateTime? originalCreatedAt,
    DateTime? originalUpdatedAt,
    String? customId,
    bool isResolutionMedia = false,
  }) async {
    final now = DateTime.now();
    final media = OfflineMedia(
      id: customId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      nonConformityId: nonConformityId,
      filename: filename,
      localPath: localPath,
      cloudUrl: cloudUrl,
      type: type,
      fileSize: fileSize,
      source: source,
      isResolutionMedia: isResolutionMedia,
      width: width,
      height: height,
      duration: duration,
      isUploaded: isUploaded,
      createdAt: originalCreatedAt ?? now,
      updatedAt: originalUpdatedAt ?? now,
    );

    return await _mediaRepository.insert(media);
  }

  Future<List<OfflineMedia>> getImagesOnly() async {
    return await _mediaRepository.findImages();
  }

  Future<List<OfflineMedia>> getVideosOnly() async {
    return await _mediaRepository.findVideos();
  }

  Future<List<OfflineMedia>> getProcessedMedia() async {
    return await _mediaRepository.findProcessed();
  }

  Future<List<OfflineMedia>> getUnprocessedMedia() async {
    return await _mediaRepository.findUnprocessed();
  }

  Future<List<OfflineMedia>> getMediaPendingUpload() async {
    // Always return all media for upload
    return await _mediaRepository.findAll();
  }

  Future<List<OfflineMedia>> getDeletedMediaPendingSync() async {
    return await _mediaRepository.findDeletedPendingSync();
  }

  Future<void> markMediaAsProcessed(
      String mediaId, String? processedPath) async {
    await _mediaRepository.markAsProcessed(mediaId, processedPath);
  }

  Future<void> updateMediaUploadProgress(
      String mediaId, double progress) async {
    await _mediaRepository.updateUploadProgress(mediaId, progress);
  }

  Future<void> updateMediaCloudUrl(String mediaId, String cloudUrl) async {
    await _mediaRepository.markAsUploaded(mediaId, cloudUrl);
  }

  Future<void> updateMediaUploadStatus(String mediaId, bool isUploaded) async {
    await _mediaRepository.updateUploadStatus(mediaId, isUploaded);
  }

  Future<void> setMediaThumbnail(String mediaId, String thumbnailPath) async {
    await _mediaRepository.setThumbnail(mediaId, thumbnailPath);
  }

  Future<void> updateMediaDimensions(
      String mediaId, int width, int height) async {
    await _mediaRepository.updateDimensions(mediaId, width, height);
  }

  Future<void> updateMediaDuration(String mediaId, int duration) async {
    await _mediaRepository.updateDuration(mediaId, duration);
  }

  Future<Map<String, int>> getMediaStats(String inspectionId) async {
    return await _mediaRepository.getMediaStatsByInspectionId(inspectionId);
  }

  Future<double> getTotalMediaSize(String inspectionId) async {
    return await _mediaRepository.getTotalFileSizeByInspectionId(inspectionId);
  }

  Future<List<OfflineMedia>> getMediaPaginated(
      String inspectionId, int limit, int offset) async {
    return await _mediaRepository.findByInspectionIdPaginated(
        inspectionId, limit, offset);
  }

  Future<List<OfflineMedia>> searchMediaByFilename(String query) async {
    return await _mediaRepository.searchByFilename(query);
  }

  // ===============================
  // MÉTODOS DE COMPATIBILIDADE LEGACY
  // ===============================

  /// Buscar arquivo de mídia por ID (compatibilidade com OfflineDataService antigo)
  Future<File?> getMediaFile(String mediaId) async {
    final media = await _mediaRepository.findById(mediaId);
    if (media != null && media.localPath.isNotEmpty) {
      final file = File(media.localPath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  /// Buscar mídias por inspeção como mapas (compatibilidade)
  Future<List<Map<String, dynamic>>> getMediaFilesByInspection(
      String inspectionId) async {
    final mediaList = await _mediaRepository.findByInspectionId(inspectionId);
    return mediaList.map((media) => media.toMap()).toList();
  }

  /// Deletar arquivo de mídia físico e registro (compatibilidade)
  Future<void> deleteMediaFile(String mediaId) async {
    final media = await _mediaRepository.findById(mediaId);
    if (media != null && media.localPath.isNotEmpty) {
      final file = File(media.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _mediaRepository.delete(mediaId);
  }

  /// Buscar mídias que precisam de upload como mapas (compatibilidade)
  Future<List<Map<String, dynamic>>> getMediaFilesNeedingUpload() async {
    final mediaList = await _mediaRepository.findPendingUpload();
    return mediaList.map((media) => media.toMap()).toList();
  }

  /// Marcar mídia como enviada para nuvem (compatibilidade)
  Future<void> markMediaUploaded(String mediaId, String cloudUrl) async {
    await _mediaRepository.markAsUploaded(mediaId, cloudUrl);
  }

  /// Atualizar mídia de detalhe (compatibilidade com estrutura JSON legacy)
  Future<void> updateDetailMedia(String inspectionId, String topicId,
      String itemId, String detailId, Map<String, dynamic> mediaData) async {
    // Para compatibilidade, vamos apenas salvar a mídia associada ao detalhe
    // Esta funcionalidade era específica da estrutura JSON embedded antiga
    debugPrint(
        'OfflineDataService: updateDetailMedia called but not implemented in new architecture');
    debugPrint(
        'OfflineDataService: Use saveOfflineMedia with detailId parameter instead');
  }

  /// Buscar estatísticas gerais (compatibilidade)
  Future<Map<String, int>> getStats() async {
    final dbStats = await DatabaseHelper.getStatistics();
    return dbStats;
  }

  // ===============================
  // OPERAÇÕES DE SINCRONIZAÇÃO
  // ===============================

  Future<List<Inspection>> getInspectionsNeedingSync() async {
    return await getAllInspections(); // Always return all inspections for sync
  }

  Future<List<Topic>> getTopicsNeedingSync() async {
    // Get all topics from all inspections
    final allInspections = await getAllInspections();
    final List<Topic> allTopics = [];
    for (final inspection in allInspections) {
      final topics = await getTopics(inspection.id);
      allTopics.addAll(topics);
    }
    return allTopics; // Always return all topics for sync
  }

  Future<List<Item>> getItemsNeedingSync() async {
    // Get all items from all topics
    final allTopics = await getTopicsNeedingSync();
    final List<Item> allItems = [];
    for (final topic in allTopics) {
      final items = await getItems(topic.id);
      allItems.addAll(items);
    }
    return allItems; // Always return all items for sync
  }

  Future<List<Detail>> getDetailsNeedingSync() async {
    // Get all details from all items
    final allItems = await getItemsNeedingSync();
    final List<Detail> allDetails = [];
    for (final item in allItems) {
      final details = await getDetails(item.id);
      allDetails.addAll(details);
    }
    return allDetails; // Always return all details for sync
  }

  Future<List<NonConformity>> getNonConformitiesNeedingSync() async {
    // Get all non-conformities from all inspections
    final allInspections = await getAllInspections();
    final List<NonConformity> allNonConformities = [];
    for (final inspection in allInspections) {
      final ncs = await getNonConformities(inspection.id);
      allNonConformities.addAll(ncs);
    }
    return allNonConformities; // Always return all non-conformities for sync
  }

  Future<List<OfflineMedia>> getMediaNeedingSync() async {
    return await _mediaRepository.findAll(); // Always return all media for sync
  }

  // ===============================
  // HIERARQUIAS FLEXÍVEIS - OPERAÇÕES ESPECIALIZADAS
  // ===============================

  // Determinar se tópico tem detalhes diretos
  Future<bool> hasDirectDetails(String topicId) async {
    return await _topicRepository.hasDirectDetails(topicId);
  }

  // Buscar detalhes por contexto flexível (item ou tópico direto)
  Future<List<Detail>> getDetailsByContext({
    required String inspectionId,
    String? topicId,
    String? itemId,
    bool? directOnly,
  }) async {
    return await _detailRepository.findDetailsByContextOrdered(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      directOnly: directOnly,
    );
  }

  // Salvar detalhe com validação de hierarquia
  Future<String> saveDetailWithValidation(Detail detail) async {
    final isValid = await _detailRepository.validateDetailHierarchy(detail);
    if (!isValid) {
      throw Exception('Hierarquia inválida para o detalhe');
    }
    return await saveDetail(detail);
  }

  // Reordenar detalhes (automaticamente detecta se é de item ou tópico direto)
  Future<void> reorderDetailsByContext(String contextId, List<String> detailIds,
      {String? itemId}) async {
    if (itemId != null) {
      // Reordenar detalhes de item
      await _detailRepository.reorderDetails(itemId, detailIds);
    } else {
      // Reordenar detalhes diretos de tópico
      await _detailRepository.reorderDirectDetails(contextId, detailIds);
    }
  }

  // Reordenar detalhes diretos de tópico
  Future<void> reorderDirectDetails(
      String topicId, List<String> detailIds) async {
    await _detailRepository.reorderDirectDetails(topicId, detailIds);
  }

  // Atualizar configuração de hierarquia do tópico
  Future<void> updateTopicHierarchy(String topicId, bool directDetails) async {
    await _topicRepository.updateDirectDetailsConfig(topicId, directDetails);
  }

  // Converter tópico entre hierarquias
  Future<void> convertTopicHierarchy(
      String topicId, bool toDirectDetails) async {
    await _topicRepository.convertTopicHierarchy(topicId, toDirectDetails);
  }

  // Estatísticas de hierarquia
  Future<Map<String, int>> getHierarchyStats(String inspectionId) async {
    return await _topicRepository.getHierarchyStats(inspectionId);
  }

  // ===============================
  // IMPORTAÇÃO DE INSPEÇÕES JSON
  // ===============================

  // Criar inspeção completa a partir do formato JSON
  Future<String> createInspectionFromJson(Map<String, dynamic> jsonData) async {
    return await DatabaseHelper.transaction(() async {
      // 1. Criar inspeção principal
      final inspection = _createInspectionFromJsonData(jsonData);
      final inspectionId = await _inspectionRepository.insert(inspection);

      // 2. Processar tópicos
      final topicsData = jsonData['topics'] as List<dynamic>? ?? [];
      for (int topicIndex = 0; topicIndex < topicsData.length; topicIndex++) {
        final topicData = topicsData[topicIndex] as Map<String, dynamic>;
        await _processTopicFromJson(inspectionId, topicData, topicIndex);
      }

      debugPrint(
          'DataService: Inspection created from JSON with ID: $inspectionId');
      return inspectionId;
    });
  }

  // Processar tópico individual do JSON
  Future<String> _processTopicFromJson(
      String inspectionId, Map<String, dynamic> topicData, int position) async {
    // Criar tópico
    final topic = Topic(
      inspectionId: inspectionId,
      position: position,
      orderIndex: position,
      topicName: topicData['name'] ?? '',
      description: topicData['description'],
      directDetails: topicData['direct_details'] ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final topicId = await _topicRepository.insert(topic);
    debugPrint(
        'DataService: Topic created: ${topic.topicName} (${topic.directDetails == true ? 'direct details' : 'with items'})');

    // Determinar se tem detalhes diretos ou itens
    final hasDirectDetails = topicData['direct_details'] == true;

    if (hasDirectDetails) {
      // Processar detalhes diretos
      final detailsData = topicData['details'] as List<dynamic>? ?? [];
      for (int detailIndex = 0;
          detailIndex < detailsData.length;
          detailIndex++) {
        final detailData = detailsData[detailIndex] as Map<String, dynamic>;
        await _processDetailFromJson(
            inspectionId, topicId, null, detailData, detailIndex);
      }
    } else {
      // Processar itens
      final itemsData = topicData['items'] as List<dynamic>? ?? [];
      for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
        final itemData = itemsData[itemIndex] as Map<String, dynamic>;
        await _processItemFromJson(inspectionId, topicId, itemData, itemIndex);
      }
    }

    return topicId;
  }

  // Processar item individual do JSON
  Future<String> _processItemFromJson(String inspectionId, String topicId,
      Map<String, dynamic> itemData, int position) async {
    // Criar item
    final item = Item(
      inspectionId: inspectionId,
      topicId: topicId,
      position: position,
      orderIndex: position,
      itemName: itemData['name'] ?? '',
      description: itemData['description'],
      evaluable: itemData['evaluable'] ?? false,
      evaluationOptions: itemData['evaluation_options'] != null
          ? List<String>.from(itemData['evaluation_options'])
          : null,
      evaluationValue: itemData['evaluation_value'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final itemId = await _itemRepository.insert(item);
    debugPrint(
        'DataService: Item created: ${item.itemName} (evaluable: ${item.evaluable})');

    // Processar detalhes do item
    final detailsData = itemData['details'] as List<dynamic>? ?? [];
    for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
      final detailData = detailsData[detailIndex] as Map<String, dynamic>;
      await _processDetailFromJson(
          inspectionId, topicId, itemId, detailData, detailIndex);
    }

    return itemId;
  }

  // Processar detalhe individual do JSON
  Future<String> _processDetailFromJson(String inspectionId, String topicId,
      String? itemId, Map<String, dynamic> detailData, int position) async {
    // Determinar opções
    List<String>? options;
    if (detailData['options'] != null) {
      options = List<String>.from(detailData['options']);
    }

    // Criar detalhe
    final detail = Detail(
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId, // null para detalhes diretos de tópico
      position: position,
      orderIndex: position,
      detailName: detailData['name'] ?? '',
      type: detailData['type'] ?? 'text',
      options: options,
      detailValue: detailData['value']?.toString(),
      observation: detailData['observation'],
      allowCustomOption: false, // Será implementado posteriormente
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final detailId = await _detailRepository.insert(detail);
    debugPrint(
        'DataService: Detail created: ${detail.detailName} (${detail.type}) ${itemId != null ? 'for item' : 'direct'}');

    return detailId;
  }

  // Criar modelo de inspeção a partir dos dados JSON
  Inspection _createInspectionFromJsonData(Map<String, dynamic> jsonData) {
    // Processar endereço
    final addressData = jsonData['address'] as Map<String, dynamic>?;
    final addressString = jsonData['address_string'] as String?;

    // Processar datas
    DateTime? scheduledDate;
    if (jsonData['scheduled_date'] != null) {
      final scheduledDateData = jsonData['scheduled_date'];
      if (scheduledDateData is Map && scheduledDateData['_seconds'] != null) {
        // Formato Firestore Timestamp
        final seconds = scheduledDateData['_seconds'] as int;
        scheduledDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    DateTime? createdAt;
    if (jsonData['created_at'] != null) {
      final createdAtData = jsonData['created_at'];
      if (createdAtData is Map && createdAtData['_seconds'] != null) {
        final seconds = createdAtData['_seconds'] as int;
        createdAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    DateTime? updatedAt;
    if (jsonData['updated_at'] != null) {
      final updatedAtData = jsonData['updated_at'];
      if (updatedAtData is Map && updatedAtData['_seconds'] != null) {
        final seconds = updatedAtData['_seconds'] as int;
        updatedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    return Inspection(
      id: 'inspection_${DateTime.now().millisecondsSinceEpoch}', // Gerar ID único
      title: jsonData['title'] ?? '',
      cod: jsonData['cod'],
      projectId: jsonData['project_id'],
      templateId: jsonData['template_id'],
      inspectorId: jsonData['inspector_id'],
      status: jsonData['status'] ?? 'pending',
      scheduledDate: scheduledDate,
      observation: jsonData['observation'],
      street: addressData?['street'],
      neighborhood: addressData?['neighborhood'],
      city: addressData?['city'],
      state: addressData?['state'],
      zipCode: addressData?['cep'],
      addressString: addressString,
      address: addressData,
      isTemplated: jsonData['is_templated'] ?? false,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // ===============================
  // OPERAÇÕES TRANSACIONAIS
  // ===============================

  Future<void> saveCompleteInspection(Inspection inspection, List<Topic> topics,
      List<Item> items, List<Detail> details) async {
    await DatabaseHelper.transaction(() async {
      // Salvar inspeção
      await _inspectionRepository.insert(inspection);

      // Salvar tópicos
      for (final topic in topics) {
        await _topicRepository.insert(topic);
      }

      // Salvar itens
      for (final item in items) {
        await _itemRepository.insert(item);
      }

      // Salvar detalhes
      for (final detail in details) {
        await _detailRepository.insert(detail);
      }
    });
  }

  Future<void> deleteCompleteInspection(String inspectionId) async {
    await DatabaseHelper.transaction(() async {
      // Deletar todas as entidades relacionadas
      await _mediaRepository.deleteByInspectionId(inspectionId);
      await _nonConformityRepository.deleteByInspectionId(inspectionId);
      await _detailRepository.deleteByInspectionId(inspectionId);
      await _itemRepository.deleteByInspectionId(inspectionId);
      await _topicRepository.deleteByInspectionId(inspectionId);
      await _inspectionRepository.delete(inspectionId);
    });
  }

  // ===============================
  // OPERAÇÕES DE PROGRESSO
  // ===============================

  Future<void> recalculateInspectionProgress(String inspectionId) async {
    final topics = await getTopics(inspectionId);

    int totalUnits = 0; // Pode ser itens ou detalhes diretos
    int completedUnits = 0;

    for (final topic in topics) {
      final hasDirectDetails = topic.directDetails == true;

      if (hasDirectDetails) {
        // Tópico com detalhes diretos - contar detalhes
        final details = await getDirectDetails(topic.id);
        totalUnits += details.length;

        for (final detail in details) {
          // Treat completion based on the detail status or presence of a value.
          if (detail.status == 'completed') {
            completedUnits++;
          } else if (detail.detailValue != null &&
              detail.detailValue!.isNotEmpty) {
            completedUnits++;
          }
        }
      } else {
        // Tópico com itens - contar itens
        final items = await getItems(topic.id);
        totalUnits += items.length;

        for (final item in items) {
          final details = await getDetails(item.id);
          final completedDetails =
              details.where((d) => d.status == 'completed').toList();
          if (completedDetails.isNotEmpty) {
            completedUnits++;
          } else {
            final filledDetails = details
                .where(
                    (d) => d.detailValue != null && d.detailValue!.isNotEmpty)
                .toList();
            if (filledDetails.isNotEmpty) {
              completedUnits++;
            }
          }
        }
      }
    }

    final progress = totalUnits > 0 ? (completedUnits / totalUnits) * 100 : 0.0;
    await updateInspectionProgress(
        inspectionId, progress, completedUnits, totalUnits);
  }

  Future<void> recalculateTopicProgress(String topicId) async {
    // Verificar se é tópico com detalhes diretos ou com itens
    final hasDirectDetails = await this.hasDirectDetails(topicId);

    int totalUnits = 0;
    int completedUnits = 0;

    if (hasDirectDetails) {
      // Tópico com detalhes diretos
      final details = await getDirectDetails(topicId);
      totalUnits = details.length;
      completedUnits = details.where((d) => d.status == 'completed').length;
    } else {
      // Tópico com itens
      final items = await getItems(topicId);

      for (final item in items) {
        final details = await getDetails(item.id);
        totalUnits += details.length;
        completedUnits += details.where((d) => d.status == 'completed').length;
      }
    }

    final progress = totalUnits > 0 ? (completedUnits / totalUnits) * 100 : 0.0;
    await updateTopicProgress(topicId, progress, completedUnits, totalUnits);
  }

  Future<void> recalculateItemProgress(String itemId) async {
    final details = await getDetails(itemId);

    final totalDetails = details.length;
    final completedDetails =
        details.where((d) => d.status == 'completed').length;

    final progress =
        totalDetails > 0 ? (completedDetails / totalDetails) * 100 : 0.0;
    await updateItemProgress(itemId, progress, completedDetails, totalDetails);
  }

  // ===============================
  // OPERAÇÕES DE ESTATÍSTICAS
  // ===============================

  Future<Map<String, dynamic>> getGlobalStats() async {
    final inspectionStats = await getInspectionStats();
    final dbStats = await DatabaseHelper.getStatistics();

    return {
      'inspections': inspectionStats,
      'database': dbStats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> getInspectionCompleteStats(
      String inspectionId) async {
    final nonConformityStats = await getNonConformityStats(inspectionId);
    final mediaStats = await getMediaStats(inspectionId);
    final totalMediaSize = await getTotalMediaSize(inspectionId);

    return {
      'non_conformities': nonConformityStats,
      'media': mediaStats,
      'total_media_size': totalMediaSize,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ===============================
  // OPERAÇÕES DE DOWNLOAD DA NUVEM
  // ===============================

  /// Download completo de inspeção do Firestore
  Future<void> downloadInspectionFromCloud(String inspectionId) async {
    try {
      debugPrint(
          'OfflineDataService: Downloading inspection $inspectionId from cloud');

      // Buscar inspeção no Firestore
      final inspectionDoc = await FirebaseFirestore.instance
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found in cloud');
      }

      final inspectionData = inspectionDoc.data()!;

      // Converter timestamps do Firestore
      final convertedData = _convertFirestoreTimestamps(inspectionData);
      convertedData['id'] = inspectionId;

      // Criar objeto Inspection
      final inspection = Inspection.fromMap(convertedData);

      // Salvar localmente usando método unificado
      await insertOrUpdateInspectionFromCloud(inspection);

      // Baixar template se existir
      if (inspection.templateId != null) {
        await _downloadTemplate(inspection.templateId!);
      }

      debugPrint(
          'OfflineDataService: Successfully downloaded inspection $inspectionId');
    } catch (e) {
      debugPrint(
          'OfflineDataService: Error downloading inspection $inspectionId: $e');
      rethrow;
    }
  }

  /// Download de template do Firestore
  Future<void> _downloadTemplate(String templateId) async {
    try {
      // Verificar se já existe
      final existingTemplate = await DatabaseHelper.getTemplate(templateId);
      if (existingTemplate != null) {
        debugPrint('OfflineDataService: Template $templateId already exists');
        return;
      }

      // Buscar template no Firestore
      final templateDoc = await FirebaseFirestore.instance
          .collection('templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        debugPrint(
            'OfflineDataService: Template $templateId not found in cloud');
        return;
      }

      final templateData = templateDoc.data()!;
      final templateName = templateData['name'] ?? 'Unknown Template';

      // Salvar template localmente
      final template = Template(
        id: templateId,
        name: templateName,
        version: templateData['version'] ?? '1.0',
        description: templateData['description'],
        category: templateData['category'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
      await DatabaseHelper.insertTemplate(template);

      debugPrint('OfflineDataService: Downloaded template $templateId');
    } catch (e) {
      debugPrint(
          'OfflineDataService: Error downloading template $templateId: $e');
    }
  }

  /// Helper para converter timestamps do Firestore
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
  // OPERAÇÕES DE TEMPLATE
  // ===============================

  /// Buscar template por ID
  Future<Map<String, dynamic>?> getTemplate(String templateId) async {
    final template = await DatabaseHelper.getTemplate(templateId);
    if (template != null) {
      return template.toJson();
    }
    return null;
  }

  /// Verificar se uma inspeção existe
  Future<bool> hasInspection(String inspectionId) async {
    final inspection = await _inspectionRepository.findById(inspectionId);
    return inspection != null;
  }

  // ===============================
  // OPERAÇÕES DE LIMPEZA
  // ===============================

  Future<void> clearAllData() async {
    await DatabaseHelper.clearAllData();
  }

  Future<void> clearInspectionData(String inspectionId) async {
    await deleteCompleteInspection(inspectionId);
  }

  Future<void> optimizeDatabase() async {
    await DatabaseHelper.rawQuery('VACUUM');
  }

  // ===============================
  // OPERAÇÕES DE DUPLICAÇÃO RECURSIVA
  // ===============================

  Future<String> _generateUniqueTopicName(
      String baseName, String inspectionId) async {
    // Get all existing topics for this inspection
    final existingTopics =
        await _topicRepository.findByInspectionId(inspectionId);
    final existingNames = existingTopics.map((t) => t.topicName).toSet();

    // If base name doesn't exist, use it
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    // Find next available number (starting from 2)
    int counter = 2;
    String candidateName;
    do {
      candidateName = '$baseName $counter';
      counter++;
    } while (existingNames.contains(candidateName));

    return candidateName;
  }

  /// Duplica um tópico completo com todos os seus itens e detalhes
  Future<Topic> duplicateTopicWithChildren(String topicId) async {
    await initialize();

    if (topicId.isEmpty) {
      throw ArgumentError('ID do tópico não pode estar vazio');
    }

    // 1. Buscar o tópico original
    final originalTopic = await _topicRepository.findById(topicId);
    if (originalTopic == null) {
      throw Exception('Tópico não encontrado: $topicId');
    }

    // Validar dados do tópico original
    if (originalTopic.topicName.isEmpty) {
      throw Exception('Nome do tópico original não pode estar vazio');
    }

    if (originalTopic.inspectionId.isEmpty) {
      throw Exception('ID da inspeção não pode estar vazio');
    }

    // 2. Generate unique name for duplicated topic
    final uniqueName = await _generateUniqueTopicName(
        originalTopic.topicName, originalTopic.inspectionId);

    // 3. Criar tópico duplicado com validações
    final duplicatedTopic = Topic(
      id: null, // Será gerado automaticamente usando UUID
      inspectionId: originalTopic.inspectionId,
      position: originalTopic.position,
      orderIndex: originalTopic.orderIndex,
      topicName: uniqueName,
      topicLabel: originalTopic.topicLabel,
      directDetails: originalTopic.directDetails, // Preservar estrutura
      observation: null, // Reset observation
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Salvar tópico duplicado
    final newTopicId = await saveTopic(duplicatedTopic);

    if (newTopicId.isEmpty) {
      throw Exception('Falha ao gerar ID para tópico duplicado');
    }

    try {
      // 4. Buscar todos os itens e detalhes do tópico original em paralelo
      final futures = <Future>[
        getItems(topicId),
        if (originalTopic.directDetails == true) getDetailsByTopic(topicId),
      ];

      final results = await Future.wait(futures);
      final originalItems = results[0] as List;
      final originalDetails =
          originalTopic.directDetails == true && results.length > 1
              ? results[1] as List
              : <dynamic>[];

      // 5. Duplicar itens e detalhes em paralelo quando possível
      final duplicationFutures = <Future>[];

      // Duplicar cada item com seus detalhes
      for (final originalItem in originalItems) {
        if (originalItem.id != null && originalItem.id!.isNotEmpty) {
          duplicationFutures
              .add(_duplicateItemWithDetails(originalItem, newTopicId));
        }
      }

      // Duplicar detalhes diretos se existirem
      for (final originalDetail in originalDetails) {
        if (originalDetail.id != null && originalDetail.id!.isNotEmpty) {
          duplicationFutures
              .add(_duplicateDetailDirect(originalDetail, newTopicId));
        }
      }

      // Executar todas as duplicações em paralelo
      if (duplicationFutures.isNotEmpty) {
        await Future.wait(duplicationFutures);
      }

      debugPrint(
          'OfflineDataService: Successfully duplicated topic $topicId -> $newTopicId with ${originalItems.length} items and ${originalDetails.length} direct details');

      // 6. Buscar e retornar o tópico salvo (sem verificação redundante)
      final savedTopic = await getTopic(newTopicId);
      return savedTopic!;
    } catch (e) {
      // Se algo falhar durante a duplicação dos filhos, limpar o tópico criado
      debugPrint(
          'OfflineDataService: Error during duplication, cleaning up: $e');
      try {
        await deleteTopic(newTopicId);
      } catch (cleanupError) {
        debugPrint('OfflineDataService: Error during cleanup: $cleanupError');
      }
      rethrow;
    }
  }

  /// Duplica um item completo com todos os seus detalhes
  Future<Item> duplicateItemWithChildren(String itemId) async {
    await initialize();

    // 1. Buscar o item original
    final originalItem = await _itemRepository.findById(itemId);
    if (originalItem == null) {
      throw Exception('Item não encontrado: $itemId');
    }

    return await _duplicateItemWithDetails(
        originalItem, originalItem.topicId ?? '');
  }

  Future<String> _generateUniqueItemName(
      String baseName, String topicId) async {
    // Get all existing items for this topic
    final existingItems = await getItems(topicId);
    final existingNames = existingItems.map((i) => i.itemName).toSet();

    // If base name doesn't exist, use it
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    // Find next available number (starting from 2)
    int counter = 2;
    String candidateName;
    do {
      candidateName = '$baseName $counter';
      counter++;
    } while (existingNames.contains(candidateName));

    return candidateName;
  }

  /// Método auxiliar para duplicar um item e seus detalhes
  Future<Item> _duplicateItemWithDetails(
      Item originalItem, String newTopicId) async {
    // Validar dados do item original
    if (originalItem.id.isEmpty) {
      throw ArgumentError('ID do item original não pode estar vazio');
    }

    if (originalItem.itemName.trim().isEmpty) {
      throw ArgumentError('Nome do item original não pode estar vazio');
    }

    if (originalItem.inspectionId.isEmpty) {
      throw ArgumentError('ID da inspeção não pode estar vazio');
    }

    // 1. Generate unique name for duplicated item
    final uniqueName =
        await _generateUniqueItemName(originalItem.itemName, newTopicId);

    // 2. Criar item duplicado com validações
    final duplicatedItem = Item(
      id: null, // Será gerado automaticamente usando UUID
      inspectionId: originalItem.inspectionId,
      topicId: newTopicId,
      itemId: originalItem.itemId,
      position: originalItem.position,
      orderIndex: originalItem.orderIndex,
      itemName: uniqueName, // Use unique name
      itemLabel: originalItem.itemLabel,
      observation: null, // Reset observation
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      evaluable: originalItem.evaluable,
      evaluationOptions: originalItem.evaluationOptions,
      evaluationValue: null, // Reset evaluation
      evaluation: null, // Reset evaluation
    );

    // 2. Salvar item duplicado
    final newItemId = await saveItem(duplicatedItem);

    if (newItemId.isEmpty) {
      throw Exception('Falha ao gerar ID para item duplicado');
    }

    // Item foi salvo, continuar com duplicação dos detalhes

    // 4. Buscar todos os detalhes do item original
    final originalDetails = await getDetails(originalItem.id);

    // 5. Duplicar detalhes em paralelo para maior performance
    final detailFutures = originalDetails
        .where((detail) => detail.id.isNotEmpty)
        .map((originalDetail) async {
      final duplicatedDetail = Detail(
        id: null, // Será gerado automaticamente usando UUID
        inspectionId: originalDetail.inspectionId,
        topicId: newTopicId,
        itemId: newItemId,
        detailId: originalDetail.detailId,
        position: originalDetail.position,
        orderIndex: originalDetail.orderIndex,
        detailName: originalDetail.detailName,
        detailValue: originalDetail.detailValue,
        observation: null, // Reset observation
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: originalDetail.type,
        options: originalDetail.options,
        status: originalDetail.status,
      );

      return await saveDetail(duplicatedDetail);
    }).toList();

    if (detailFutures.isNotEmpty) {
      await Future.wait(detailFutures);
    }

    debugPrint(
        'OfflineDataService: Successfully duplicated item ${originalItem.id} -> $newItemId with ${originalDetails.length} details');

    // 5. Retornar o item duplicado (sem busca redundante)
    return duplicatedItem.copyWith(id: newItemId);
  }

  /// Método auxiliar para duplicar um detalhe direto do tópico
  Future<Detail> _duplicateDetailDirect(
      Detail originalDetail, String newTopicId) async {
    // Validar dados do detalhe original
    if (originalDetail.id.isEmpty) {
      throw ArgumentError('ID do detalhe original não pode estar vazio');
    }

    if (originalDetail.detailName.trim().isEmpty) {
      throw ArgumentError('Nome do detalhe original não pode estar vazio');
    }

    if (originalDetail.inspectionId.isEmpty) {
      throw ArgumentError('ID da inspeção não pode estar vazio');
    }

    if (newTopicId.isEmpty) {
      throw ArgumentError('ID do novo tópico não pode estar vazio');
    }

    // Gerar nome único para o detalhe duplicado
    final uniqueName = await _generateUniqueDetailName(
        originalDetail.detailName, newTopicId, null);

    // Criar detalhe duplicado com validações
    final duplicatedDetail = Detail(
      id: null, // Será gerado automaticamente usando UUID
      inspectionId: originalDetail.inspectionId,
      topicId: newTopicId,
      itemId: null, // Detalhe direto do tópico não tem itemId
      detailId: originalDetail.detailId,
      position: originalDetail.position,
      orderIndex: originalDetail.orderIndex,
      detailName: uniqueName, // Use unique name
      detailValue: originalDetail.detailValue,
      observation: null, // Reset observation
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: originalDetail.type,
      options: originalDetail.options,
      status: originalDetail.status,
    );

    // Salvar detalhe duplicado
    final newDetailId = await saveDetail(duplicatedDetail);

    if (newDetailId.isEmpty) {
      throw Exception('Falha ao gerar ID para detalhe duplicado');
    }

    // Retornar o detalhe duplicado (sem verificações redundantes)
    debugPrint(
        'OfflineDataService: Successfully duplicated direct detail ${originalDetail.id} -> $newDetailId');

    return duplicatedDetail.copyWith(id: newDetailId);
  }

  Future<String> _generateUniqueDetailName(
      String baseName, String? topicId, String? itemId) async {
    // Get all existing details for this topic/item context
    List<Detail> existingDetails;
    if (itemId != null) {
      existingDetails = await getDetails(itemId);
    } else if (topicId != null) {
      // For direct details (without item) - get all details for the topic and filter those without itemId
      final allTopicDetails = await _detailRepository.findByTopicId(topicId);
      existingDetails =
          allTopicDetails.where((detail) => detail.itemId == null).toList();
    } else {
      return baseName; // Fallback
    }

    final existingNames = existingDetails.map((d) => d.detailName).toSet();

    // If base name doesn't exist, use it
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    // Find next available number (starting from 2)
    int counter = 2;
    String candidateName;
    do {
      candidateName = '$baseName $counter';
      counter++;
    } while (existingNames.contains(candidateName));

    return candidateName;
  }

  /// Duplica um detalhe simples
  Future<Detail> duplicateDetailWithChildren(String detailId) async {
    await initialize();

    // 1. Buscar o detalhe original
    final originalDetail = await _detailRepository.findById(detailId);
    if (originalDetail == null) {
      throw Exception('Detalhe não encontrado: $detailId');
    }

    // 2. Generate unique name for duplicated detail
    final uniqueName = await _generateUniqueDetailName(
        originalDetail.detailName,
        originalDetail.topicId,
        originalDetail.itemId);

    // 3. Criar detalhe duplicado
    final duplicatedDetail = Detail(
      id: null, // Será gerado automaticamente
      inspectionId: originalDetail.inspectionId,
      topicId: originalDetail.topicId,
      itemId: originalDetail.itemId,
      detailId: originalDetail.detailId,
      position: originalDetail.position,
      orderIndex: originalDetail.orderIndex,
      detailName: uniqueName,
      detailValue: originalDetail.detailValue,
      observation: originalDetail.observation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: originalDetail.type,
      options: originalDetail.options,
      status: originalDetail.status,
    );

    // 3. Salvar detalhe duplicado
    final newDetailId = await saveDetail(duplicatedDetail);

    // 4. Buscar e retornar o detalhe completo salvo
    final savedDetail = await getDetail(newDetailId);
    return savedDetail!;
  }

  /// Reordena detalhes mantendo a consistência com índices
  Future<void> reorderDetailsByIndex(
      String itemId, int oldIndex, int newIndex) async {
    await initialize();

    // 1. Buscar todos os detalhes do item
    final details = await _detailRepository.findByItemId(itemId);
    if (details.isEmpty ||
        oldIndex >= details.length ||
        newIndex >= details.length) {
      throw Exception('Índices inválidos para reordenação');
    }

    // 2. Reordenar a lista
    final reorderedDetails = List<Detail>.from(details);
    final detailToMove = reorderedDetails.removeAt(oldIndex);
    reorderedDetails.insert(newIndex, detailToMove);

    // 3. Atualizar orderIndex de todos os detalhes
    for (int i = 0; i < reorderedDetails.length; i++) {
      final detail = reorderedDetails[i];
      final updatedDetail = Detail(
        id: detail.id,
        inspectionId: detail.inspectionId,
        topicId: detail.topicId,
        itemId: detail.itemId,
        detailId: detail.detailId,
        position: detail.position,
        orderIndex: i, // Novo índice de ordem
        detailName: detail.detailName,
        detailValue: detail.detailValue,
        observation: detail.observation,
        createdAt: detail.createdAt,
        updatedAt: DateTime.now(),
        type: detail.type,
        options: detail.options,
        status: detail.status,
      );
      await _detailRepository.update(updatedDetail);
    }
  }
}

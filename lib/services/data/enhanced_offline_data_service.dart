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
import 'package:lince_inspecoes/storage/database_helper.dart';

class EnhancedOfflineDataService {
  static EnhancedOfflineDataService? _instance;
  static EnhancedOfflineDataService get instance =>
      _instance ??= EnhancedOfflineDataService._();

  EnhancedOfflineDataService._();

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

    // Inicializar o banco de dados
    await DatabaseHelper.database;

    // Inicializar repositórios
    _inspectionRepository = InspectionRepository();
    _topicRepository = TopicRepository();
    _itemRepository = ItemRepository();
    _detailRepository = DetailRepository();
    _nonConformityRepository = NonConformityRepository();
    _mediaRepository = MediaRepository();

    _isInitialized = true;
    debugPrint(
        'EnhancedOfflineDataService: Initialized with repository pattern');
  }

  // ===============================
  // OPERAÇÕES DE INSPEÇÃO
  // ===============================

  Future<Inspection?> getInspection(String id) async {
    debugPrint('DataService: Getting inspection $id');
    final result = await _inspectionRepository.findById(id);
    debugPrint('DataService: Inspection $id found: ${result != null}');
    return result;
  }

  Future<List<Inspection>> getInspectionsByInspector(String inspectorId) async {
    return await _inspectionRepository.findByInspectorId(inspectorId);
  }

  Future<List<Inspection>> getAllInspections() async {
    return await _inspectionRepository.findAll();
  }

  Future<List<Inspection>> getInspectionsByStatus(String status) async {
    return await _inspectionRepository.findByStatus(status);
  }

  Future<String> saveInspection(Inspection inspection) async {
    debugPrint('DataService: Saving inspection ${inspection.id}');
    final result = await _inspectionRepository.insert(inspection);
    debugPrint('DataService: Inspection saved with ID: $result');
    return result;
  }

  Future<void> updateInspection(Inspection inspection) async {
    debugPrint('DataService: Updating inspection ${inspection.id}');
    await _inspectionRepository.update(inspection);
    debugPrint('DataService: Inspection ${inspection.id} updated successfully');
  }

  Future<void> insertOrUpdateInspection(Inspection inspection) async {
    debugPrint('DataService: Insert or update inspection ${inspection.id}');
    await _inspectionRepository.insertOrUpdate(inspection);
    debugPrint('DataService: Inspection ${inspection.id} insert/update completed');
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
    debugPrint('DataService: Getting topics for inspection $inspectionId');
    final result =
        await _topicRepository.findByInspectionIdOrdered(inspectionId);
    debugPrint(
        'DataService: Found ${result.length} topics for inspection $inspectionId');
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
    debugPrint('DataService: Insert or update topic ${topic.topicName} for inspection ${topic.inspectionId}');
    await _topicRepository.insertOrUpdate(topic);
    debugPrint('DataService: Topic ${topic.id} insert/update completed');
  }

  Future<void> updateTopic(Topic topic) async {
    debugPrint('DataService: Updating topic ${topic.id} - ${topic.topicName}');
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
    debugPrint('DataService: Getting items for topic $topicId');
    final result = await _itemRepository.findByTopicIdOrdered(topicId);
    debugPrint('DataService: Found ${result.length} items for topic $topicId');
    return result;
  }

  Future<List<Item>> getItemsByInspection(String inspectionId) async {
    return await _itemRepository.findByInspectionIdOrdered(inspectionId);
  }

  Future<Item?> getItem(String itemId) async {
    return await _itemRepository.findById(itemId);
  }

  Future<String> saveItem(Item item) async {
    debugPrint(
        'DataService: Saving item ${item.itemName} for topic ${item.topicId}');
    final result = await _itemRepository.insert(item);
    debugPrint('DataService: Item saved with ID: $result');
    return result;
  }

  Future<void> insertOrUpdateItem(Item item) async {
    debugPrint('DataService: Insert or update item ${item.itemName} for topic ${item.topicId}');
    await _itemRepository.insertOrUpdate(item);
    debugPrint('DataService: Item ${item.id} insert/update completed');
  }

  Future<void> updateItem(Item item) async {
    debugPrint('DataService: Updating item ${item.id} - ${item.itemName}');
    await _itemRepository.update(item);
    debugPrint('DataService: Item ${item.id} updated successfully');
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
    debugPrint('DataService: Getting details for item $itemId');
    final result = await _detailRepository.findByItemIdOrdered(itemId);
    debugPrint('DataService: Found ${result.length} details for item $itemId');
    return result;
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
    debugPrint(
        'DataService: Saving detail ${detail.detailName} for item ${detail.itemId}');
    final result = await _detailRepository.insert(detail);
    debugPrint('DataService: Detail saved with ID: $result');
    return result;
  }

  Future<void> insertOrUpdateDetail(Detail detail) async {
    debugPrint('DataService: Insert or update detail ${detail.detailName} for item ${detail.itemId}');
    await _detailRepository.insertOrUpdate(detail);
    debugPrint('DataService: Detail ${detail.id} insert/update completed');
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

  Future<void> setDetailNonConformity(
      String detailId, bool hasNonConformity) async {
    await _detailRepository.setNonConformity(detailId, hasNonConformity);
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

  Future<int> getRequiredDetailCount(String itemId) async {
    return await _detailRepository.countRequiredByItemId(itemId);
  }

  Future<int> getRequiredCompletedDetailCount(String itemId) async {
    return await _detailRepository.countRequiredCompletedByItemId(itemId);
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
    return await _nonConformityRepository.insert(nonConformity);
  }

  Future<void> updateNonConformity(NonConformity nonConformity) async {
    await _nonConformityRepository.update(nonConformity);
  }

  Future<void> insertOrUpdateNonConformity(NonConformity nonConformity) async {
    await _nonConformityRepository.insertOrUpdate(nonConformity);
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

  Future<void> updateMediaCloudUrl(String mediaId, String cloudUrl) async {
    debugPrint('DataService: Updating media $mediaId cloud URL');
    await _mediaRepository.markAsUploaded(mediaId, cloudUrl);
  }

  Future<void> markMediaSynced(String mediaId) async {
    await _mediaRepository.markSynced(mediaId);
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
    required String mimeType,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    bool isUploaded = false,
  }) async {
    final media = OfflineMedia(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      mimeType: mimeType,
      isProcessed: true,
      isUploaded: isUploaded,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
    return await _mediaRepository.findPendingUpload();
  }

  Future<String> saveMediaFile(
    String inspectionId,
    String fileName,
    List<int> fileBytes, {
    String? topicId,
    String? itemId,
    String? detailId,
    String fileType = 'image',
  }) async {
    // Implementar salvamento de arquivo de mídia usando SQLiteStorageService
    // Esta é uma funcionalidade que deveria estar no StorageService
    // Por enquanto, vamos implementar uma versão simplificada

    // Criar metadata da mídia
    final mediaId = DateTime.now().millisecondsSinceEpoch.toString();
    final media = OfflineMedia(
      id: mediaId,
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      type: fileType,
      localPath:
          '/temp/$fileName', // Caminho temporário, seria melhor usar StorageService
      filename: fileName,
      fileSize: fileBytes.length,
      isProcessed: true,
      needsSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _mediaRepository.insert(media);
    return mediaId;
  }

  Future<void> markMediaAsProcessed(
      String mediaId, String? processedPath) async {
    await _mediaRepository.markAsProcessed(mediaId, processedPath);
  }

  Future<void> updateMediaUploadProgress(
      String mediaId, double progress) async {
    await _mediaRepository.updateUploadProgress(mediaId, progress);
  }

  Future<void> markMediaAsUploaded(String mediaId, String cloudUrl) async {
    await _mediaRepository.markAsUploaded(mediaId, cloudUrl);
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
  // OPERAÇÕES DE SINCRONIZAÇÃO
  // ===============================

  Future<List<Inspection>> getInspectionsNeedingSync() async {
    return await _inspectionRepository.findPendingSync();
  }

  Future<List<Topic>> getTopicsNeedingSync() async {
    return await _topicRepository.findPendingSync();
  }

  Future<List<Item>> getItemsNeedingSync() async {
    return await _itemRepository.findPendingSync();
  }

  Future<List<Detail>> getDetailsNeedingSync() async {
    return await _detailRepository.findPendingSync();
  }

  Future<List<NonConformity>> getNonConformitiesNeedingSync() async {
    return await _nonConformityRepository.findPendingSync();
  }

  Future<List<OfflineMedia>> getMediaNeedingSync() async {
    return await _mediaRepository.findPendingSync();
  }

  Future<void> markInspectionSynced(String inspectionId) async {
    await _inspectionRepository.markSynced(inspectionId);
  }

  Future<void> markTopicSynced(String topicId) async {
    await _topicRepository.markSynced(topicId);
  }

  Future<void> markItemSynced(String itemId) async {
    await _itemRepository.markSynced(itemId);
  }

  Future<void> markDetailSynced(String detailId) async {
    await _detailRepository.markSynced(detailId);
  }

  Future<void> markNonConformitySynced(String nonConformityId) async {
    await _nonConformityRepository.markSynced(nonConformityId);
  }

  Future<void> markAllInspectionsSynced() async {
    await _inspectionRepository.markAllSynced();
  }

  Future<void> markAllTopicsSynced() async {
    await _topicRepository.markAllSynced();
  }

  Future<void> markAllItemsSynced() async {
    await _itemRepository.markAllSynced();
  }

  Future<void> markAllDetailsSynced() async {
    await _detailRepository.markAllSynced();
  }

  Future<void> markAllNonConformitiesSynced() async {
    await _nonConformityRepository.markAllSynced();
  }

  Future<void> markAllMediaSynced() async {
    await _mediaRepository.markAllSynced();
  }

  // ===============================
  // OPERAÇÕES TRANSACIONAIS
  // ===============================

  Future<void> saveCompleteInspection(Inspection inspection, List<Topic> topics,
      List<Item> items, List<Detail> details) async {
    await DatabaseHelper.transaction((txn) async {
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
    await DatabaseHelper.transaction((txn) async {
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

    int totalItems = 0;
    int completedItems = 0;

    for (final topic in topics) {
      final items = await getItems(topic.id ?? '');
      totalItems += items.length;

      for (final item in items) {
        final details = await getDetails(item.id ?? '');
        final requiredDetails =
            details.where((d) => d.isRequired == true).toList();

        if (requiredDetails.isNotEmpty) {
          final completedRequiredDetails =
              requiredDetails.where((d) => d.status == 'completed').toList();
          if (completedRequiredDetails.length == requiredDetails.length) {
            completedItems++;
          }
        } else {
          // Se não há detalhes obrigatórios, considerar o item como completo se tem ao menos um detalhe preenchido
          final completedDetails =
              details.where((d) => d.status == 'completed').toList();
          if (completedDetails.isNotEmpty) {
            completedItems++;
          }
        }
      }
    }

    final progress = totalItems > 0 ? (completedItems / totalItems) * 100 : 0.0;
    await updateInspectionProgress(
        inspectionId, progress, completedItems, totalItems);
  }

  Future<void> recalculateTopicProgress(String topicId) async {
    final items = await getItems(topicId);

    int totalDetails = 0;
    int completedDetails = 0;

    for (final item in items) {
      final details = await getDetails(item.id ?? '');
      totalDetails += details.length;
      completedDetails += details.where((d) => d.status == 'completed').length;
    }

    final progress =
        totalDetails > 0 ? (completedDetails / totalDetails) * 100 : 0.0;
    await updateTopicProgress(
        topicId, progress, completedDetails, totalDetails);
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

  /// Duplica um tópico completo com todos os seus itens e detalhes
  Future<Topic> duplicateTopicWithChildren(String topicId) async {
    await initialize();

    // 1. Buscar o tópico original
    final originalTopic = await _topicRepository.findById(topicId);
    if (originalTopic == null) {
      throw Exception('Tópico não encontrado: $topicId');
    }

    // 2. Criar tópico duplicado
    final duplicatedTopic = Topic(
      id: null, // Será gerado automaticamente
      inspectionId: originalTopic.inspectionId,
      position: originalTopic.position,
      topicName: '${originalTopic.topicName} (Cópia)',
      topicLabel: originalTopic.topicLabel,
      observation: null, // Reset observation
      isDamaged: false, // Reset damage status
      tags: originalTopic.tags ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Salvar tópico duplicado
    final newTopicId = await saveTopic(duplicatedTopic);

    // 4. Buscar todos os itens do tópico original
    final originalItems = await getItems(topicId);

    // 5. Duplicar cada item com seus detalhes
    for (final originalItem in originalItems) {
      await _duplicateItemWithDetails(originalItem, newTopicId);
    }

    debugPrint(
        'EnhancedOfflineDataService: Successfully duplicated topic $topicId -> $newTopicId with ${originalItems.length} items');

    // 6. Buscar e retornar o tópico completo salvo
    final savedTopic = await getTopic(newTopicId);
    return savedTopic!;
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

  /// Método auxiliar para duplicar um item e seus detalhes
  Future<Item> _duplicateItemWithDetails(
      Item originalItem, String newTopicId) async {
    // 1. Criar item duplicado (sem adicionar "(Cópia)" ao nome do item)
    final duplicatedItem = Item(
      id: null, // Será gerado automaticamente
      inspectionId: originalItem.inspectionId,
      topicId: newTopicId,
      itemId: originalItem.itemId,
      position: originalItem.position,
      itemName: originalItem.itemName, // Manter nome original do item
      itemLabel: originalItem.itemLabel,
      observation: null, // Reset observation
      isDamaged: false, // Reset damage status
      tags: originalItem.tags ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 2. Salvar item duplicado
    final newItemId = await saveItem(duplicatedItem);

    // 3. Buscar todos os detalhes do item original
    final originalDetails = await getDetails(originalItem.id!);

    // 4. Duplicar cada detalhe
    for (final originalDetail in originalDetails) {
      final duplicatedDetail = Detail(
        id: null, // Será gerado automaticamente
        inspectionId: originalDetail.inspectionId,
        topicId: newTopicId,
        itemId: newItemId,
        detailId: originalDetail.detailId,
        position: originalDetail.position,
        orderIndex: originalDetail.orderIndex,
        detailName: originalDetail.detailName,
        detailValue: originalDetail.detailValue,
        observation: null, // Reset observation
        isDamaged: false, // Reset damage status
        tags: originalDetail.tags ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: originalDetail.type,
        options: originalDetail.options,
        status: originalDetail.status,
        isRequired: originalDetail.isRequired,
      );

      await saveDetail(duplicatedDetail);
    }

    debugPrint(
        'EnhancedOfflineDataService: Successfully duplicated item ${originalItem.id} -> $newItemId with ${originalDetails.length} details');

    // 5. Buscar e retornar o item completo salvo
    final savedItem = await getItem(newItemId);
    return savedItem!;
  }

  /// Duplica um detalhe simples
  Future<Detail> duplicateDetailWithChildren(String detailId) async {
    await initialize();
    
    // 1. Buscar o detalhe original
    final originalDetail = await _detailRepository.findById(detailId);
    if (originalDetail == null) {
      throw Exception('Detalhe não encontrado: $detailId');
    }
    
    // 2. Criar detalhe duplicado
    final duplicatedDetail = Detail(
      id: null, // Será gerado automaticamente
      inspectionId: originalDetail.inspectionId,
      topicId: originalDetail.topicId,
      itemId: originalDetail.itemId,
      detailId: originalDetail.detailId,
      position: originalDetail.position,
      orderIndex: originalDetail.orderIndex,
      detailName: '${originalDetail.detailName} (Cópia)',
      detailValue: originalDetail.detailValue,
      observation: originalDetail.observation,
      isDamaged: originalDetail.isDamaged ?? false,
      tags: originalDetail.tags ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: originalDetail.type,
      options: originalDetail.options,
      status: originalDetail.status,
      isRequired: originalDetail.isRequired,
    );
    
    // 3. Salvar detalhe duplicado
    final newDetailId = await saveDetail(duplicatedDetail);
    
    debugPrint('EnhancedOfflineDataService: Successfully duplicated detail $detailId -> $newDetailId');
    
    // 4. Buscar e retornar o detalhe completo salvo
    final savedDetail = await getDetail(newDetailId);
    return savedDetail!;
  }

  /// Reordena detalhes mantendo a consistência com índices
  Future<void> reorderDetailsByIndex(String itemId, int oldIndex, int newIndex) async {
    await initialize();
    
    // 1. Buscar todos os detalhes do item
    final details = await _detailRepository.findByItemId(itemId);
    if (details.isEmpty || oldIndex >= details.length || newIndex >= details.length) {
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
        isDamaged: detail.isDamaged,
        tags: detail.tags,
        createdAt: detail.createdAt,
        updatedAt: DateTime.now(),
        type: detail.type,
        options: detail.options,
        status: detail.status,
        isRequired: detail.isRequired,
      );
      await _detailRepository.update(updatedDetail);
    }
    
    debugPrint('EnhancedOfflineDataService: Successfully reordered ${reorderedDetails.length} details');
  }
}

import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/non_conformity.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/repositories/inspection_repository.dart';
import 'package:inspection_app/repositories/topic_repository.dart';
import 'package:inspection_app/repositories/item_repository.dart';
import 'package:inspection_app/repositories/detail_repository.dart';
import 'package:inspection_app/repositories/non_conformity_repository.dart';
import 'package:inspection_app/repositories/media_repository.dart';
import 'package:inspection_app/storage/database_helper.dart';

class EnhancedOfflineDataService {
  static EnhancedOfflineDataService? _instance;
  static EnhancedOfflineDataService get instance => _instance ??= EnhancedOfflineDataService._();
  
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
    debugPrint('EnhancedOfflineDataService: Initialized with repository pattern');
  }
  
  // ===============================
  // OPERAÇÕES DE INSPEÇÃO
  // ===============================
  
  Future<Inspection?> getInspection(String id) async {
    return await _inspectionRepository.findById(id);
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
    return await _inspectionRepository.insert(inspection);
  }
  
  Future<void> updateInspection(Inspection inspection) async {
    await _inspectionRepository.update(inspection);
  }
  
  Future<void> deleteInspection(String id) async {
    await _inspectionRepository.delete(id);
  }
  
  Future<void> updateInspectionProgress(String inspectionId, double progress, int completed, int total) async {
    await _inspectionRepository.updateProgress(inspectionId, progress, completed, total);
  }
  
  Future<void> updateInspectionStatus(String inspectionId, String status) async {
    await _inspectionRepository.updateStatus(inspectionId, status);
  }
  
  Future<Map<String, int>> getInspectionStats() async {
    return await _inspectionRepository.getInspectionStats();
  }
  
  // ===============================
  // OPERAÇÕES DE TÓPICO
  // ===============================
  
  Future<List<Topic>> getTopics(String inspectionId) async {
    return await _topicRepository.findByInspectionIdOrdered(inspectionId);
  }
  
  Future<Topic?> getTopic(String topicId) async {
    return await _topicRepository.findById(topicId);
  }
  
  Future<String> saveTopic(Topic topic) async {
    return await _topicRepository.insert(topic);
  }
  
  Future<void> updateTopic(Topic topic) async {
    await _topicRepository.update(topic);
  }
  
  Future<void> deleteTopic(String topicId) async {
    await _topicRepository.delete(topicId);
  }
  
  Future<void> updateTopicProgress(String topicId, double progress, int completed, int total) async {
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
    return await _itemRepository.insert(item);
  }
  
  Future<void> updateItem(Item item) async {
    await _itemRepository.update(item);
  }
  
  Future<void> deleteItem(String itemId) async {
    await _itemRepository.delete(itemId);
  }
  
  Future<void> updateItemProgress(String itemId, double progress, int completed, int total) async {
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
    return await _detailRepository.insert(detail);
  }
  
  Future<void> updateDetail(Detail detail) async {
    await _detailRepository.update(detail);
  }
  
  Future<void> deleteDetail(String detailId) async {
    await _detailRepository.delete(detailId);
  }
  
  Future<void> updateDetailValue(String detailId, String? value, String? observations) async {
    await _detailRepository.updateValue(detailId, value, observations);
  }
  
  Future<void> markDetailCompleted(String detailId) async {
    await _detailRepository.markAsCompleted(detailId);
  }
  
  Future<void> markDetailIncomplete(String detailId) async {
    await _detailRepository.markAsIncomplete(detailId);
  }
  
  Future<void> setDetailNonConformity(String detailId, bool hasNonConformity) async {
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
  
  Future<List<NonConformity>> getNonConformitiesByDetail(String detailId) async {
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
  
  Future<void> deleteNonConformity(String nonConformityId) async {
    await _nonConformityRepository.delete(nonConformityId);
  }
  
  Future<void> updateNonConformityStatus(String nonConformityId, String status) async {
    await _nonConformityRepository.updateStatus(nonConformityId, status);
  }
  
  Future<void> updateNonConformitySeverity(String nonConformityId, String severity) async {
    await _nonConformityRepository.updateSeverity(nonConformityId, severity);
  }
  
  Future<Map<String, int>> getNonConformityStats(String inspectionId) async {
    return await _nonConformityRepository.getStatsByInspectionId(inspectionId);
  }
  
  Future<List<NonConformity>> getNonConformitiesByInspectionGroupedBySeverity(String inspectionId) async {
    return await _nonConformityRepository.findByInspectionIdGroupedBySeverity(inspectionId);
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
  
  Future<List<OfflineMedia>> getMediaByNonConformity(String nonConformityId) async {
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
  
  Future<String> saveMediaFile(String inspectionId, String fileName, List<int> fileBytes, {
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
      localPath: '/temp/$fileName', // Caminho temporário, seria melhor usar StorageService
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
  
  Future<void> markMediaAsProcessed(String mediaId, String? processedPath) async {
    await _mediaRepository.markAsProcessed(mediaId, processedPath);
  }
  
  Future<void> updateMediaUploadProgress(String mediaId, double progress) async {
    await _mediaRepository.updateUploadProgress(mediaId, progress);
  }
  
  Future<void> markMediaAsUploaded(String mediaId, String cloudUrl) async {
    await _mediaRepository.markAsUploaded(mediaId, cloudUrl);
  }
  
  Future<void> setMediaThumbnail(String mediaId, String thumbnailPath) async {
    await _mediaRepository.setThumbnail(mediaId, thumbnailPath);
  }
  
  Future<void> updateMediaDimensions(String mediaId, int width, int height) async {
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
  
  Future<List<OfflineMedia>> getMediaPaginated(String inspectionId, int limit, int offset) async {
    return await _mediaRepository.findByInspectionIdPaginated(inspectionId, limit, offset);
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
  
  Future<void> markMediaSynced(String mediaId) async {
    await _mediaRepository.markSynced(mediaId);
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
  
  Future<void> saveCompleteInspection(Inspection inspection, List<Topic> topics, List<Item> items, List<Detail> details) async {
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
        final requiredDetails = details.where((d) => d.isRequired == true).toList();
        
        if (requiredDetails.isNotEmpty) {
          final completedRequiredDetails = requiredDetails.where((d) => d.status == 'completed').toList();
          if (completedRequiredDetails.length == requiredDetails.length) {
            completedItems++;
          }
        } else {
          // Se não há detalhes obrigatórios, considerar o item como completo se tem ao menos um detalhe preenchido
          final completedDetails = details.where((d) => d.status == 'completed').toList();
          if (completedDetails.isNotEmpty) {
            completedItems++;
          }
        }
      }
    }
    
    final progress = totalItems > 0 ? (completedItems / totalItems) * 100 : 0.0;
    await updateInspectionProgress(inspectionId, progress, completedItems, totalItems);
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
    
    final progress = totalDetails > 0 ? (completedDetails / totalDetails) * 100 : 0.0;
    await updateTopicProgress(topicId, progress, completedDetails, totalDetails);
  }
  
  Future<void> recalculateItemProgress(String itemId) async {
    final details = await getDetails(itemId);
    
    final totalDetails = details.length;
    final completedDetails = details.where((d) => d.status == 'completed').length;
    
    final progress = totalDetails > 0 ? (completedDetails / totalDetails) * 100 : 0.0;
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
  
  Future<Map<String, dynamic>> getInspectionCompleteStats(String inspectionId) async {
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
}
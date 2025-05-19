import 'package:hive_flutter/hive_flutter.dart';
import 'package:inspection_app/models/cached_inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:uuid/uuid.dart';

class CacheService {
  static const String _inspectionsBoxName = 'inspections';
  static const String _topicsBoxName = 'topics';
  static const String _itemsBoxName = 'items';
  static const String _detailsBoxName = 'details';
  static const String _mediaBoxName = 'media';
  static const String _nonConformitiesBoxName = 'non_conformities';

  final _uuid = Uuid();

  // Initialize Hive
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(CachedInspectionAdapter());
    Hive.registerAdapter(CachedTopicAdapter());
    Hive.registerAdapter(CachedItemAdapter());
    Hive.registerAdapter(CachedDetailAdapter());
    Hive.registerAdapter(CachedMediaAdapter());
    Hive.registerAdapter(CachedNonConformityAdapter());
    
    // Open boxes
    await Hive.openBox<CachedInspection>(_inspectionsBoxName);
    await Hive.openBox<CachedTopic>(_topicsBoxName);
    await Hive.openBox<CachedItem>(_itemsBoxName);
    await Hive.openBox<CachedDetail>(_detailsBoxName);
    await Hive.openBox<CachedMedia>(_mediaBoxName);
    await Hive.openBox<CachedNonConformity>(_nonConformitiesBoxName);
  }

  // Get boxes
  Box<CachedInspection> get _inspectionsBox => Hive.box<CachedInspection>(_inspectionsBoxName);
  Box<CachedTopic> get _topicsBox => Hive.box<CachedTopic>(_topicsBoxName);
  Box<CachedItem> get _itemsBox => Hive.box<CachedItem>(_itemsBoxName);
  Box<CachedDetail> get _detailsBox => Hive.box<CachedDetail>(_detailsBoxName);
  Box<CachedMedia> get _mediaBox => Hive.box<CachedMedia>(_mediaBoxName);
  Box<CachedNonConformity> get _nonConformitiesBox => Hive.box<CachedNonConformity>(_nonConformitiesBoxName);

  // ======= INSPECTION METHODS =======
  
  Future<void> cacheInspection(Inspection inspection) async {
    final cached = CachedInspection(
      id: inspection.id,
      title: inspection.title,
      status: inspection.status,
      isTemplated: inspection.isTemplated,
      templateId: inspection.templateId,
      updatedAt: inspection.updatedAt,
      data: inspection.toMap(),
      needsSync: false,
    );
    await _inspectionsBox.put(inspection.id, cached);
  }

  CachedInspection? getCachedInspection(String id) {
    return _inspectionsBox.get(id);
  }

  Future<void> markInspectionForSync(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = true;
      await cached.save();
    }
  }

  // ======= TOPIC METHODS =======
  
  Future<String> cacheTopic(Topic topic) async {
    final id = topic.id ?? _uuid.v4();
    final cached = CachedTopic(
      id: id,
      inspectionId: topic.inspectionId,
      topicName: topic.topicName,
      topicLabel: topic.topicLabel,
      position: topic.position,
      observation: topic.observation,
      createdAt: topic.createdAt,
      updatedAt: topic.updatedAt,
      needsSync: true,
    );
    await _topicsBox.put(id, cached);
    return id;
  }

  List<CachedTopic> getCachedTopics(String inspectionId) {
    return _topicsBox.values
        .where((topic) => topic.inspectionId == inspectionId)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> updateCachedTopic(String id, Topic topic) async {
    final cached = _topicsBox.get(id);
    if (cached != null) {
      cached.topicName = topic.topicName;
      cached.topicLabel = topic.topicLabel;
      cached.observation = topic.observation;
      cached.updatedAt = DateTime.now();
      cached.needsSync = true;
      await cached.save();
    }
  }

  Future<void> deleteCachedTopic(String id) async {
    await _topicsBox.delete(id);
    
    // Delete related items
    final items = _itemsBox.values.where((item) => item.topicId == id).toList();
    for (final item in items) {
      await deleteCachedItem(item.id);
    }
  }

  // ======= ITEM METHODS =======
  
  Future<String> cacheItem(Item item) async {
    final id = item.id ?? _uuid.v4();
    final cached = CachedItem(
      id: id,
      topicId: item.topicId ?? '',
      inspectionId: item.inspectionId,
      itemName: item.itemName,
      itemLabel: item.itemLabel,
      position: item.position,
      observation: item.observation,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      needsSync: true,
    );
    await _itemsBox.put(id, cached);
    return id;
  }

  List<CachedItem> getCachedItems(String topicId) {
    return _itemsBox.values
        .where((item) => item.topicId == topicId)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> updateCachedItem(String id, Item item) async {
    final cached = _itemsBox.get(id);
    if (cached != null) {
      cached.itemName = item.itemName;
      cached.itemLabel = item.itemLabel;
      cached.observation = item.observation;
      cached.updatedAt = DateTime.now();
      cached.needsSync = true;
      await cached.save();
    }
  }

  Future<void> deleteCachedItem(String id) async {
    await _itemsBox.delete(id);
    
    // Delete related details
    final details = _detailsBox.values.where((detail) => detail.itemId == id).toList();
    for (final detail in details) {
      await deleteCachedDetail(detail.id);
    }
  }

  // ======= DETAIL METHODS =======
  
  Future<String> cacheDetail(Detail detail) async {
    final id = detail.id ?? _uuid.v4();
    final cached = CachedDetail(
      id: id,
      itemId: detail.itemId ?? '',
      topicId: detail.topicId ?? '',
      inspectionId: detail.inspectionId,
      detailName: detail.detailName,
      type: detail.type ?? 'text',
      options: detail.options,
      detailValue: detail.detailValue,
      observation: detail.observation,
      isDamaged: detail.isDamaged ?? false,
      position: detail.position,
      createdAt: detail.createdAt,
      updatedAt: detail.updatedAt,
      needsSync: true,
    );
    await _detailsBox.put(id, cached);
    return id;
  }

  List<CachedDetail> getCachedDetails(String itemId) {
    return _detailsBox.values
        .where((detail) => detail.itemId == itemId)
        .toList()
      ..sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
  }

  Future<void> updateCachedDetail(String id, Detail detail) async {
    final cached = _detailsBox.get(id);
    if (cached != null) {
      cached.detailName = detail.detailName;
      cached.detailValue = detail.detailValue;
      cached.observation = detail.observation;
      cached.isDamaged = detail.isDamaged ?? false;
      cached.updatedAt = DateTime.now();
      cached.needsSync = true;
      await cached.save();
    }
  }

  Future<void> deleteCachedDetail(String id) async {
    await _detailsBox.delete(id);
    
    // Delete related media
    final mediaItems = _mediaBox.values.where((media) => media.detailId == id).toList();
    for (final media in mediaItems) {
      await _mediaBox.delete(media.id);
    }
    
    // Delete related non-conformities
    final nonConformities = _nonConformitiesBox.values.where((nc) => nc.detailId == id).toList();
    for (final nc in nonConformities) {
      await _nonConformitiesBox.delete(nc.id);
    }
  }

  // ======= MEDIA METHODS =======
  
  Future<String> cacheMedia(Map<String, dynamic> mediaData) async {
    final id = mediaData['id'] ?? _uuid.v4();
    final cached = CachedMedia(
      id: id,
      detailId: mediaData['detail_id'] ?? '',
      itemId: mediaData['topic_item_id'] ?? '',
      topicId: mediaData['topic_id'] ?? '',
      inspectionId: mediaData['inspection_id'] ?? '',
      type: mediaData['type'] ?? 'image',
      localPath: mediaData['localPath'],
      url: mediaData['url'],
      isNonConformity: mediaData['is_non_conformity'] ?? false,
      observation: mediaData['observation'],
      nonConformityId: mediaData['non_conformity_id'],
      createdAt: mediaData['created_at'] is DateTime 
          ? mediaData['created_at'] 
          : DateTime.now(),
      updatedAt: mediaData['updated_at'] is DateTime 
          ? mediaData['updated_at'] 
          : DateTime.now(),
      needsSync: true,
    );
    await _mediaBox.put(id, cached);
    return id;
  }

  List<CachedMedia> getCachedMedia(String detailId) {
    return _mediaBox.values
        .where((media) => media.detailId == detailId)
        .toList();
  }

  // ======= NON-CONFORMITY METHODS =======
  
  Future<String> cacheNonConformity(Map<String, dynamic> ncData) async {
    final id = ncData['id'] ?? _uuid.v4();
    final cached = CachedNonConformity(
      id: id,
      detailId: ncData['detail_id'] ?? '',
      itemId: ncData['item_id'] ?? '',
      topicId: ncData['topic_id'] ?? '',
      inspectionId: ncData['inspection_id'] ?? '',
      description: ncData['description'] ?? '',
      severity: ncData['severity'] ?? 'Média',
      correctiveAction: ncData['corrective_action'],
      deadline: ncData['deadline'],
      status: ncData['status'] ?? 'pendente',
      createdAt: ncData['created_at'] is DateTime 
          ? ncData['created_at'] 
          : DateTime.now(),
      updatedAt: ncData['updated_at'] is DateTime 
          ? ncData['updated_at'] 
          : DateTime.now(),
      needsSync: true,
    );
    await _nonConformitiesBox.put(id, cached);
    return id;
  }

  List<CachedNonConformity> getCachedNonConformities(String inspectionId) {
    return _nonConformitiesBox.values
        .where((nc) => nc.inspectionId == inspectionId)
        .toList();
  }

  // ======= SYNC METHODS =======
  
  List<CachedInspection> getInspectionsNeedingSync() {
    return _inspectionsBox.values.where((inspection) => inspection.needsSync).toList();
  }

  List<CachedTopic> getTopicsNeedingSync() {
    return _topicsBox.values.where((topic) => topic.needsSync).toList();
  }

  List<CachedItem> getItemsNeedingSync() {
    return _itemsBox.values.where((item) => item.needsSync).toList();
  }

  List<CachedDetail> getDetailsNeedingSync() {
    return _detailsBox.values.where((detail) => detail.needsSync).toList();
  }

  List<CachedMedia> getMediaNeedingSync() {
    return _mediaBox.values.where((media) => media.needsSync).toList();
  }

  List<CachedNonConformity> getNonConformitiesNeedingSync() {
    return _nonConformitiesBox.values.where((nc) => nc.needsSync).toList();
  }

  Future<void> markTopicSynced(String id) async {
    final cached = _topicsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> markItemSynced(String id) async {
    final cached = _itemsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> markDetailSynced(String id) async {
    final cached = _detailsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> markMediaSynced(String id) async {
    final cached = _mediaBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> markNonConformitySynced(String id) async {
    final cached = _nonConformitiesBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  // ======= UTILITY METHODS =======
  
  Future<void> clearCache() async {
    await _inspectionsBox.clear();
    await _topicsBox.clear();
    await _itemsBox.clear();
    await _detailsBox.clear();
    await _mediaBox.clear();
    await _nonConformitiesBox.clear();
  }

  // Convert cached entities to regular models
  Topic cachedTopicToTopic(CachedTopic cached) {
    return Topic(
      id: cached.id,
      inspectionId: cached.inspectionId,
      topicName: cached.topicName,
      topicLabel: cached.topicLabel,
      position: cached.position,
      observation: cached.observation,
      createdAt: cached.createdAt,
      updatedAt: cached.updatedAt,
    );
  }

  Item cachedItemToItem(CachedItem cached) {
    return Item(
      id: cached.id,
      topicId: cached.topicId,
      inspectionId: cached.inspectionId,
      itemName: cached.itemName,
      itemLabel: cached.itemLabel,
      position: cached.position,
      observation: cached.observation,
      createdAt: cached.createdAt,
      updatedAt: cached.updatedAt,
    );
  }

  Detail cachedDetailToDetail(CachedDetail cached) {
    return Detail(
      id: cached.id,
      itemId: cached.itemId,
      topicId: cached.topicId,
      inspectionId: cached.inspectionId,
      detailName: cached.detailName,
      type: cached.type,
      options: cached.options,
      detailValue: cached.detailValue,
      observation: cached.observation,
      isDamaged: cached.isDamaged,
      position: cached.position,
      createdAt: cached.createdAt,
      updatedAt: cached.updatedAt,
    );
  }
}
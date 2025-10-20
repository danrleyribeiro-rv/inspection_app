import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/inspection.dart';
import '../models/topic.dart';
import '../models/item.dart';
import '../models/detail.dart';
import '../models/non_conformity.dart';
import '../models/offline_media.dart';
import '../models/template.dart';
import '../models/template_topic.dart';
import '../models/template_item.dart';
import '../models/template_detail.dart';

class DatabaseHelper {
  static bool _initialized = false;

  // Box names
  static const String _inspectionsBox = 'inspections';
  static const String _topicsBox = 'topics';
  static const String _itemsBox = 'items';
  static const String _detailsBox = 'details';
  static const String _nonConformitiesBox = 'non_conformities';
  static const String _offlineMediaBox = 'offline_media';
  static const String _templatesBox = 'templates';
  static const String _templateTopicsBox = 'template_topics';
  static const String _templateItemsBox = 'template_items';
  static const String _templateDetailsBox = 'template_details';

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(InspectionAdapter());
    Hive.registerAdapter(TopicAdapter());
    Hive.registerAdapter(ItemAdapter());
    Hive.registerAdapter(DetailAdapter());
    Hive.registerAdapter(NonConformityAdapter());
    Hive.registerAdapter(OfflineMediaAdapter());
    Hive.registerAdapter(TemplateAdapter());
    Hive.registerAdapter(TemplateTopicAdapter());
    Hive.registerAdapter(TemplateItemAdapter());
    Hive.registerAdapter(TemplateDetailAdapter());

    // Open boxes
    await Hive.openBox<Inspection>(_inspectionsBox);
    await Hive.openBox<Topic>(_topicsBox);
    await Hive.openBox<Item>(_itemsBox);
    await Hive.openBox<Detail>(_detailsBox);
    await Hive.openBox<NonConformity>(_nonConformitiesBox);

    // Try to open OfflineMedia box, clear if schema is incompatible
    try {
      await Hive.openBox<OfflineMedia>(_offlineMediaBox);
    } catch (e) {
      // Schema compatibility issue - delete the box and recreate
      await Hive.deleteBoxFromDisk(_offlineMediaBox);
      await Hive.openBox<OfflineMedia>(_offlineMediaBox);
    }

    await Hive.openBox<Template>(_templatesBox);
    await Hive.openBox<TemplateTopic>(_templateTopicsBox);
    await Hive.openBox<TemplateItem>(_templateItemsBox);
    await Hive.openBox<TemplateDetail>(_templateDetailsBox);

    _initialized = true;
  }

  // Get boxes (private)
  static Box<Inspection> get _inspections =>
      Hive.box<Inspection>(_inspectionsBox);
  static Box<Topic> get _topics => Hive.box<Topic>(_topicsBox);
  static Box<Item> get _items => Hive.box<Item>(_itemsBox);
  static Box<Detail> get _details => Hive.box<Detail>(_detailsBox);
  static Box<NonConformity> get _nonConformities =>
      Hive.box<NonConformity>(_nonConformitiesBox);
  static Box<OfflineMedia> get _offlineMedia =>
      Hive.box<OfflineMedia>(_offlineMediaBox);
  static Box<Template> get _templates => Hive.box<Template>(_templatesBox);
  static Box<TemplateTopic> get _templateTopics => Hive.box<TemplateTopic>(_templateTopicsBox);
  static Box<TemplateItem> get _templateItems => Hive.box<TemplateItem>(_templateItemsBox);
  static Box<TemplateDetail> get _templateDetails => Hive.box<TemplateDetail>(_templateDetailsBox);

  // Public accessors for repositories
  static Box<Inspection> get inspections => _inspections;
  static Box<Topic> get topics => _topics;
  static Box<Item> get items => _items;
  static Box<Detail> get details => _details;
  static Box<NonConformity> get nonConformities => _nonConformities;
  static Box<OfflineMedia> get offlineMedia => _offlineMedia;
  static Box<Template> get templates => _templates;
  static Box<TemplateTopic> get templateTopics => _templateTopics;
  static Box<TemplateItem> get templateItems => _templateItems;
  static Box<TemplateDetail> get templateDetails => _templateDetails;

  // Utility methods
  static Future<void> closeDatabase() async {
    await Hive.close();
    _initialized = false;
  }

  static Future<void> deleteDatabase() async {
    await Hive.deleteFromDisk();
    _initialized = false;
  }

  // Raw query methods (for compatibility)
  static Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    throw UnimplementedError(
        'Raw queries not supported in Hive. Use specific methods instead.');
  }

  static Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    throw UnimplementedError(
        'Raw inserts not supported in Hive. Use specific methods instead.');
  }

  static Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    throw UnimplementedError(
        'Raw updates not supported in Hive. Use specific methods instead.');
  }

  static Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    throw UnimplementedError(
        'Raw deletes not supported in Hive. Use specific methods instead.');
  }

  // Transaction methods (for compatibility)
  static Future<T> transaction<T>(Future<T> Function() action) async {
    // Hive operations are atomic by default
    return await action();
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await _inspections.clear();
    await _topics.clear();
    await _items.clear();
    await _details.clear();
    await _nonConformities.clear();
    await _offlineMedia.clear();
    await _templates.clear();
    await _templateTopics.clear();
    await _templateItems.clear();
    await _templateDetails.clear();
  }

  // Clear only offline media data to fix schema issues
  static Future<void> clearOfflineMediaData() async {
    await _offlineMedia.clear();
  }

  // Statistics
  static Future<Map<String, int>> getStatistics() async {
    return {
      'inspections': _inspections.length,
      'topics': _topics.length,
      'items': _items.length,
      'details': _details.length,
      'media': _offlineMedia.length,
      'non_conformities': _nonConformities.length,
    };
  }

  // Inspection CRUD operations
  static Future<void> insertInspection(Inspection inspection) async {
    await _inspections.put(inspection.id, inspection);
  }

  static Future<Inspection?> getInspection(String id) async {
    return _inspections.get(id);
  }

  static Future<List<Inspection>> getAllInspections() async {
    return _inspections.values.toList();
  }

  static Future<void> updateInspection(Inspection inspection) async {
    await _inspections.put(inspection.id, inspection);
  }

  static Future<void> deleteInspection(String id) async {
    await _inspections.delete(id);
  }

  // Topic CRUD operations
  static Future<void> insertTopic(Topic topic) async {
    await _topics.put(topic.id, topic);
  }

  static Future<Topic?> getTopic(String id) async {
    return _topics.get(id);
  }

  static Future<List<Topic>> getTopicsByInspection(String inspectionId) async {
    return _topics.values
        .where((topic) => topic.inspectionId == inspectionId)
        .toList();
  }

  static Future<void> updateTopic(Topic topic) async {
    await _topics.put(topic.id, topic);
  }

  static Future<void> deleteTopic(String id) async {
    await _topics.delete(id);
  }

  // Item CRUD operations
  static Future<void> insertItem(Item item) async {
    await _items.put(item.id, item);
  }

  static Future<Item?> getItem(String id) async {
    return _items.get(id);
  }

  static Future<List<Item>> getItemsByTopic(String topicId) async {
    return _items.values.where((item) => item.topicId == topicId).toList();
  }

  static Future<void> updateItem(Item item) async {
    await _items.put(item.id, item);
  }

  static Future<void> deleteItem(String id) async {
    await _items.delete(id);
  }

  // Detail CRUD operations
  static Future<void> insertDetail(Detail detail) async {
    await _details.put(detail.id, detail);
  }

  static Future<Detail?> getDetail(String id) async {
    return _details.get(id);
  }

  static Future<List<Detail>> getDetailsByItem(String itemId) async {
    return _details.values.where((detail) => detail.itemId == itemId).toList();
  }

  static Future<void> updateDetail(Detail detail) async {
    await _details.put(detail.id, detail);
  }

  static Future<void> deleteDetail(String id) async {
    await _details.delete(id);
  }

  // NonConformity CRUD operations
  static Future<void> insertNonConformity(NonConformity nonConformity) async {
    await _nonConformities.put(nonConformity.id, nonConformity);
  }

  static Future<NonConformity?> getNonConformity(String id) async {
    return _nonConformities.get(id);
  }

  static Future<List<NonConformity>> getNonConformitiesByInspection(
      String inspectionId) async {
    return _nonConformities.values
        .where((nc) => nc.inspectionId == inspectionId)
        .toList();
  }

  static Future<void> updateNonConformity(NonConformity nonConformity) async {
    await _nonConformities.put(nonConformity.id, nonConformity);
  }

  static Future<void> deleteNonConformity(String id) async {
    await _nonConformities.delete(id);
  }

  // OfflineMedia CRUD operations
  static Future<void> insertOfflineMedia(OfflineMedia media) async {
    await _offlineMedia.put(media.id, media);
  }

  static Future<OfflineMedia?> getOfflineMedia(String id) async {
    return _offlineMedia.get(id);
  }

  static Future<List<OfflineMedia>> getOfflineMediaByInspection(
      String inspectionId) async {
    final mediaList = _offlineMedia.values
        .where((media) => media.inspectionId == inspectionId)
        .toList();

    // Sort by creation date (newest first)
    mediaList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mediaList;
  }

  static Future<void> updateOfflineMedia(OfflineMedia media) async {
    await _offlineMedia.put(media.id, media);
  }

  static Future<void> deleteOfflineMedia(String id) async {
    await _offlineMedia.delete(id);
  }

  // Template CRUD operations
  static Future<void> insertTemplate(Template template) async {
    await _templates.put(template.id, template);
  }

  static Future<Template?> getTemplate(String id) async {
    return _templates.get(id);
  }

  static Future<List<Template>> getAllTemplates() async {
    return _templates.values.toList();
  }

  static Future<void> updateTemplate(Template template) async {
    await _templates.put(template.id, template);
  }

  static Future<void> deleteTemplate(String id) async {
    await _templates.delete(id);
    // Also delete all related template topics, items, and details
    final topicsToDelete = _templateTopics.values
        .where((topic) => topic.templateId == id)
        .map((topic) => topic.id)
        .toList();

    for (final topicId in topicsToDelete) {
      await deleteTemplateTopic(topicId);
    }
  }

  // TemplateTopic CRUD operations
  static Future<void> insertTemplateTopic(TemplateTopic topic) async {
    await _templateTopics.put(topic.id, topic);
  }

  static Future<TemplateTopic?> getTemplateTopic(String id) async {
    return _templateTopics.get(id);
  }

  static Future<List<TemplateTopic>> getTemplateTopicsByTemplate(String templateId) async {
    final topics = _templateTopics.values
        .where((topic) => topic.templateId == templateId)
        .toList();
    topics.sort((a, b) => a.position.compareTo(b.position));
    return topics;
  }

  static Future<void> updateTemplateTopic(TemplateTopic topic) async {
    await _templateTopics.put(topic.id, topic);
  }

  static Future<void> deleteTemplateTopic(String id) async {
    await _templateTopics.delete(id);
    // Also delete all related template items and details
    final itemsToDelete = _templateItems.values
        .where((item) => item.topicId == id)
        .map((item) => item.id)
        .toList();

    for (final itemId in itemsToDelete) {
      await deleteTemplateItem(itemId);
    }

    // Delete direct details (details without itemId)
    final detailsToDelete = _templateDetails.values
        .where((detail) => detail.topicId == id && detail.itemId == null)
        .map((detail) => detail.id)
        .toList();

    for (final detailId in detailsToDelete) {
      await _templateDetails.delete(detailId);
    }
  }

  // TemplateItem CRUD operations
  static Future<void> insertTemplateItem(TemplateItem item) async {
    await _templateItems.put(item.id, item);
  }

  static Future<TemplateItem?> getTemplateItem(String id) async {
    return _templateItems.get(id);
  }

  static Future<List<TemplateItem>> getTemplateItemsByTopic(String topicId) async {
    final items = _templateItems.values
        .where((item) => item.topicId == topicId)
        .toList();
    items.sort((a, b) => a.position.compareTo(b.position));
    return items;
  }

  static Future<void> updateTemplateItem(TemplateItem item) async {
    await _templateItems.put(item.id, item);
  }

  static Future<void> deleteTemplateItem(String id) async {
    await _templateItems.delete(id);
    // Also delete all related template details
    final detailsToDelete = _templateDetails.values
        .where((detail) => detail.itemId == id)
        .map((detail) => detail.id)
        .toList();

    for (final detailId in detailsToDelete) {
      await _templateDetails.delete(detailId);
    }
  }

  // TemplateDetail CRUD operations
  static Future<void> insertTemplateDetail(TemplateDetail detail) async {
    await _templateDetails.put(detail.id, detail);
  }

  static Future<TemplateDetail?> getTemplateDetail(String id) async {
    return _templateDetails.get(id);
  }

  static Future<List<TemplateDetail>> getTemplateDetailsByItem(String itemId) async {
    final details = _templateDetails.values
        .where((detail) => detail.itemId == itemId)
        .toList();
    details.sort((a, b) => a.position.compareTo(b.position));
    return details;
  }

  static Future<List<TemplateDetail>> getTemplateDetailsByTopic(String topicId) async {
    final details = _templateDetails.values
        .where((detail) => detail.topicId == topicId && detail.itemId == null)
        .toList();
    details.sort((a, b) => a.position.compareTo(b.position));
    return details;
  }

  static Future<void> updateTemplateDetail(TemplateDetail detail) async {
    await _templateDetails.put(detail.id, detail);
  }

  static Future<void> deleteTemplateDetail(String id) async {
    await _templateDetails.delete(id);
  }

}

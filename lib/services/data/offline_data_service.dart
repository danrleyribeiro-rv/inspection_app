import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/storage/sqlite_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineDataService {
  static OfflineDataService? _instance;
  static OfflineDataService get instance => _instance ??= OfflineDataService._();
  
  OfflineDataService._();
  
  final SQLiteStorageService _storage = SQLiteStorageService.instance;
  
  Future<void> initialize() async {
    await _storage.initialize();
    debugPrint('OfflineDataService: Initialized');
  }
  
  // DOWNLOAD DE DADOS DA NUVEM
  Future<void> downloadInspectionFromCloud(String inspectionId) async {
    try {
      debugPrint('OfflineDataService: Downloading inspection $inspectionId from cloud');
      
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
      
      // Salvar localmente
      await _storage.saveInspection(inspection);
      
      // Baixar template se existir
      if (inspection.templateId != null) {
        await _downloadTemplate(inspection.templateId!);
      }
      
      // Marcar como sincronizado (acabou de ser baixado)
      await _storage.markInspectionSynced(inspectionId);
      
      debugPrint('OfflineDataService: Successfully downloaded inspection $inspectionId');
    } catch (e) {
      debugPrint('OfflineDataService: Error downloading inspection $inspectionId: $e');
      rethrow;
    }
  }
  
  Future<void> _downloadTemplate(String templateId) async {
    try {
      // Verificar se já existe
      if (await _storage.hasTemplate(templateId)) {
        debugPrint('OfflineDataService: Template $templateId already exists');
        return;
      }
      
      // Buscar template no Firestore
      final templateDoc = await FirebaseFirestore.instance
          .collection('templates')
          .doc(templateId)
          .get();
      
      if (!templateDoc.exists) {
        debugPrint('OfflineDataService: Template $templateId not found in cloud');
        return;
      }
      
      final templateData = templateDoc.data()!;
      final templateName = templateData['name'] ?? 'Unknown Template';
      
      // Salvar template localmente
      await _storage.saveTemplate(templateId, templateName, templateData);
      
      debugPrint('OfflineDataService: Downloaded template $templateId');
    } catch (e) {
      debugPrint('OfflineDataService: Error downloading template $templateId: $e');
    }
  }
  
  // OPERAÇÕES OFFLINE
  Future<Inspection?> getInspection(String id) async {
    return await _storage.getInspection(id);
  }
  
  Future<List<Inspection>> getInspectionsByInspector(String inspectorId) async {
    return await _storage.getInspectionsByInspector(inspectorId);
  }
  
  Future<void> saveInspection(Inspection inspection) async {
    await _storage.saveInspection(inspection);
    debugPrint('OfflineDataService: Saved inspection ${inspection.id} offline');
  }
  
  Future<void> updateInspectionData(String inspectionId, Map<String, dynamic> updates) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    // Aplicar updates
    final updatedData = inspection.toMap();
    updates.forEach((key, value) {
      updatedData[key] = value;
    });
    
    final updatedInspection = Inspection.fromMap(updatedData);
    await _storage.saveInspection(updatedInspection);
    
    debugPrint('OfflineDataService: Updated inspection $inspectionId');
  }
  
  // TÓPICOS
  Future<List<Topic>> getTopics(String inspectionId) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection?.topics == null) return [];
    
    return inspection!.topics!.asMap().entries.map((entry) {
      final index = entry.key;
      final topicData = entry.value;
      return Topic(
        id: 'topic_$index',
        inspectionId: inspectionId,
        position: index,
        topicName: topicData['name'] ?? 'Tópico ${index + 1}',
        topicLabel: topicData['description'] ?? '',
      );
    }).toList();
  }
  
  Future<void> addTopic(String inspectionId, Map<String, dynamic> topicData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    topics.add(topicData);
    
    await updateInspectionData(inspectionId, {'topics': topics});
    debugPrint('OfflineDataService: Added topic to inspection $inspectionId');
  }
  
  Future<void> updateTopic(String inspectionId, int topicIndex, Map<String, dynamic> topicData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    if (topicIndex < 0 || topicIndex >= topics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }
    
    topics[topicIndex] = topicData;
    await updateInspectionData(inspectionId, {'topics': topics});
    debugPrint('OfflineDataService: Updated topic $topicIndex in inspection $inspectionId');
  }
  
  // ITENS
  Future<List<Item>> getItems(String inspectionId, int topicIndex) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection?.topics == null || topicIndex >= inspection!.topics!.length) {
      return [];
    }
    
    final topicData = inspection.topics![topicIndex];
    final items = topicData['items'] as List? ?? [];
    
    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final itemData = entry.value;
      return Item(
        id: 'item_$index',
        inspectionId: inspectionId,
        topicId: 'topic_$topicIndex',
        position: index,
        itemName: itemData['name'] ?? 'Item ${index + 1}',
        itemLabel: itemData['description'] ?? '',
      );
    }).toList();
  }
  
  Future<void> addItem(String inspectionId, int topicIndex, Map<String, dynamic> itemData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    if (topicIndex < 0 || topicIndex >= topics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }
    
    final items = List<Map<String, dynamic>>.from(topics[topicIndex]['items'] ?? []);
    items.add(itemData);
    
    topics[topicIndex]['items'] = items;
    await updateInspectionData(inspectionId, {'topics': topics});
    debugPrint('OfflineDataService: Added item to topic $topicIndex in inspection $inspectionId');
  }
  
  Future<void> updateItem(String inspectionId, int topicIndex, int itemIndex, Map<String, dynamic> itemData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    if (topicIndex < 0 || topicIndex >= topics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }
    
    final items = List<Map<String, dynamic>>.from(topics[topicIndex]['items'] ?? []);
    if (itemIndex < 0 || itemIndex >= items.length) {
      throw Exception('Item index out of bounds: $itemIndex');
    }
    
    items[itemIndex] = itemData;
    topics[topicIndex]['items'] = items;
    await updateInspectionData(inspectionId, {'topics': topics});
    debugPrint('OfflineDataService: Updated item $itemIndex in topic $topicIndex in inspection $inspectionId');
  }
  
  // DETALHES
  Future<List<Detail>> getDetails(String inspectionId, int topicIndex, int itemIndex) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection?.topics == null || 
        topicIndex >= inspection!.topics!.length) {
      return [];
    }
    
    final topicData = inspection.topics![topicIndex];
    final items = topicData['items'] as List? ?? [];
    
    if (itemIndex >= items.length) return [];
    
    final itemData = items[itemIndex];
    final details = itemData['details'] as List? ?? [];
    
    return details.asMap().entries.map((entry) {
      final index = entry.key;
      final detailData = entry.value;
      return Detail(
        id: 'detail_$index',
        inspectionId: inspectionId,
        topicId: 'topic_$topicIndex',
        itemId: 'item_$itemIndex',
        position: index,
        detailName: detailData['name'] ?? 'Detalhe ${index + 1}',
        detailValue: detailData['value'],
        observation: detailData['observation'],
      );
    }).toList();
  }
  
  Future<void> updateDetail(String inspectionId, int topicIndex, int itemIndex, int detailIndex, Map<String, dynamic> detailData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }
    
    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    if (topicIndex < 0 || topicIndex >= topics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }
    
    final items = List<Map<String, dynamic>>.from(topics[topicIndex]['items'] ?? []);
    if (itemIndex < 0 || itemIndex >= items.length) {
      throw Exception('Item index out of bounds: $itemIndex');
    }
    
    final details = List<Map<String, dynamic>>.from(items[itemIndex]['details'] ?? []);
    if (detailIndex < 0 || detailIndex >= details.length) {
      throw Exception('Detail index out of bounds: $detailIndex');
    }
    
    details[detailIndex] = detailData;
    items[itemIndex]['details'] = details;
    topics[topicIndex]['items'] = items;
    await updateInspectionData(inspectionId, {'topics': topics});
    debugPrint('OfflineDataService: Updated detail $detailIndex in item $itemIndex in topic $topicIndex in inspection $inspectionId');
  }
  
  // MÍDIA
  Future<String> saveMediaFile(String inspectionId, String fileName, List<int> fileBytes, {
    String? topicId,
    String? itemId,
    String? detailId,
    String fileType = 'image',
  }) async {
    return await _storage.saveMediaFile(
      inspectionId,
      fileName,
      fileBytes,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      fileType: fileType,
    );
  }
  
  Future<File?> getMediaFile(String mediaId) async {
    return await _storage.getMediaFile(mediaId);
  }
  
  Future<List<Map<String, dynamic>>> getMediaFilesByInspection(String inspectionId) async {
    return await _storage.getMediaFilesByInspection(inspectionId);
  }
  
  // TEMPLATES
  Future<Map<String, dynamic>?> getTemplate(String templateId) async {
    return await _storage.getTemplate(templateId);
  }
  
  // SINCRONIZAÇÃO
  Future<List<Inspection>> getInspectionsNeedingSync() async {
    return await _storage.getInspectionsNeedingSync();
  }
  
  Future<List<Map<String, dynamic>>> getMediaFilesNeedingUpload() async {
    return await _storage.getMediaFilesNeedingUpload();
  }
  
  Future<void> markInspectionSynced(String inspectionId) async {
    await _storage.markInspectionSynced(inspectionId);
  }
  
  Future<void> markMediaUploaded(String mediaId, String cloudUrl) async {
    await _storage.markMediaUploaded(mediaId, cloudUrl);
  }

  // Deletar arquivo de mídia
  Future<void> deleteMediaFile(String mediaId) async {
    await _storage.deleteMediaFile(mediaId);
  }
  
  Future<void> updateDetailMedia(String inspectionId, String topicId, String itemId, String detailId, Map<String, dynamic> mediaData) async {
    final inspection = await _storage.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final topics = List<Map<String, dynamic>>.from(inspection.topics ?? []);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null || topicIndex < 0 || topicIndex >= topics.length) {
      throw Exception('Topic index out of bounds: $topicIndex');
    }

    final items = List<Map<String, dynamic>>.from(topics[topicIndex]['items'] ?? []);
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (itemIndex == null || itemIndex < 0 || itemIndex >= items.length) {
      throw Exception('Item index out of bounds: $itemIndex');
    }

    final details = List<Map<String, dynamic>>.from(items[itemIndex]['details'] ?? []);
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));
    if (detailIndex == null || detailIndex < 0 || detailIndex >= details.length) {
      throw Exception('Detail index out of bounds: $detailIndex');
    }

    final detail = Map<String, dynamic>.from(details[detailIndex]);
    final mediaList = List<Map<String, dynamic>>.from(detail['media'] ?? []);
    mediaList.add(mediaData);
    detail['media'] = mediaList;

    details[detailIndex] = detail;
    items[itemIndex]['details'] = details;
    topics[topicIndex]['items'] = items;

    final updatedInspection = inspection.copyWith(topics: topics);
    await _storage.saveInspection(updatedInspection);
    debugPrint('OfflineDataService: Updated media for detail $detailId in inspection $inspectionId');
  }
  
  // UTILITÁRIOS
  Future<bool> hasInspection(String inspectionId) async {
    return await _storage.hasInspection(inspectionId);
  }
  
  Future<Map<String, int>> getStats() async {
    return await _storage.getStats();
  }
  
  Future<void> clearAllData() async {
    await _storage.clearAllData();
  }
  
  // Helper para converter timestamps do Firestore
  Map<String, dynamic> _convertFirestoreTimestamps(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map) {
        converted[key] = _convertFirestoreTimestamps(Map<String, dynamic>.from(value));
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
}
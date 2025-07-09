import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/offline_media.dart';
import 'package:inspection_app/services/data/enhanced_offline_data_service.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class FirestoreSyncService {
  static FirestoreSyncService? _instance;
  static FirestoreSyncService get instance => _instance ??= FirestoreSyncService._();
  
  FirestoreSyncService._();
  
  final FirebaseService _firebaseService = FirebaseService();
  final EnhancedOfflineDataService _offlineService = EnhancedOfflineDataService.instance;
  
  bool _isSyncing = false;
  
  // ===============================
  // VERIFICAÇÃO DE CONECTIVIDADE
  // ===============================
  
  Future<bool> isConnected() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      return connectivityResults.isNotEmpty && 
             !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('FirestoreSyncService: Error checking connectivity: $e');
      return false;
    }
  }
  
  // ===============================
  // SINCRONIZAÇÃO COMPLETA
  // ===============================
  
  Future<void> fullSync() async {
    if (_isSyncing) {
      debugPrint('FirestoreSyncService: Sync already in progress');
      return;
    }
    
    if (!await isConnected()) {
      debugPrint('FirestoreSyncService: No internet connection');
      return;
    }
    
    _isSyncing = true;
    
    try {
      debugPrint('FirestoreSyncService: Starting full sync');
      
      // Primeiro: fazer download de dados atualizados da nuvem
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
            
            debugPrint('FirestoreSyncService: Downloaded inspection ${doc.id}');
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Error processing inspection ${doc.id}: $e');
        }
      }
      
      debugPrint('FirestoreSyncService: Finished downloading inspections');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading inspections: $e');
    }
  }
  
  Future<void> _downloadInspectionRelatedData(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Processing nested structure for inspection $inspectionId');
      
      // A inspeção já foi baixada, agora vamos processar a estrutura aninhada
      final inspection = await _offlineService.getInspection(inspectionId);
      if (inspection != null && inspection.topics != null && inspection.topics!.isNotEmpty) {
        debugPrint('FirestoreSyncService: Processing nested topics structure from Firestore');
        await _processNestedTopicsStructure(inspectionId, inspection.topics!);
      } else {
        debugPrint('FirestoreSyncService: No nested topics found, creating default structure');
        await _createDefaultInspectionStructure(inspectionId);
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error downloading related data for $inspectionId: $e');
    }
  }
  
  
  
  Future<void> _createDefaultInspectionStructure(String inspectionId) async {
    try {
      debugPrint('FirestoreSyncService: Creating default structure for inspection $inspectionId');
      
      // Primeiro, verificar se a inspeção já tem topics no campo aninhado
      final inspection = await _offlineService.getInspection(inspectionId);
      if (inspection != null && inspection.topics != null && inspection.topics!.isNotEmpty) {
        debugPrint('FirestoreSyncService: Processing nested topics structure from Firestore');
        await _processNestedTopicsStructure(inspectionId, inspection.topics!);
        return;
      }
      
      // Se não houver estrutura aninhada, criar estrutura padrão simples
      debugPrint('FirestoreSyncService: Creating simple default structure');
      
      // Criar tópico padrão
      final defaultTopic = Topic(
        id: '${inspectionId}_default_topic',
        inspectionId: inspectionId,
        position: 0,
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
      
      debugPrint('FirestoreSyncService: Created default structure for inspection $inspectionId');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error creating default structure for $inspectionId: $e');
    }
  }

  Future<void> _processNestedTopicsStructure(String inspectionId, List<Map<String, dynamic>> topicsData) async {
    try {
      debugPrint('FirestoreSyncService: Processing ${topicsData.length} topics from nested structure');
      
      for (int topicIndex = 0; topicIndex < topicsData.length; topicIndex++) {
        final topicData = topicsData[topicIndex];
        
        // Criar tópico
        final topic = Topic(
          id: '${inspectionId}_topic_$topicIndex',
          inspectionId: inspectionId,
          position: topicIndex,
          topicName: topicData['name'] ?? 'Tópico ${topicIndex + 1}',
          topicLabel: topicData['description'],
          observation: topicData['observation'],
          isDamaged: false,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _offlineService.saveTopic(topic);
        debugPrint('FirestoreSyncService: Created topic ${topic.id}: ${topic.topicName}');
        
        // Processar itens do tópico
        final itemsData = topicData['items'] as List<dynamic>? ?? [];
        debugPrint('FirestoreSyncService: Processing ${itemsData.length} items for topic ${topic.id}');
        
        for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
          final itemData = itemsData[itemIndex];
          
          // Criar item
          final item = Item(
            id: '${inspectionId}_topic_${topicIndex}_item_$itemIndex',
            inspectionId: inspectionId,
            topicId: topic.id,
            itemId: null,
            position: itemIndex,
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
          debugPrint('FirestoreSyncService: Created item ${item.id}: ${item.itemName}');
          
          // Processar detalhes do item
          final detailsData = itemData['details'] as List<dynamic>? ?? [];
          debugPrint('FirestoreSyncService: Processing ${detailsData.length} details for item ${item.id}');
          
          for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
            final detailData = detailsData[detailIndex];
            
            // Criar detalhe
            final detail = Detail(
              id: '${inspectionId}_topic_${topicIndex}_item_${itemIndex}_detail_$detailIndex',
              inspectionId: inspectionId,
              topicId: topic.id,
              itemId: item.id,
              detailId: null,
              position: detailIndex,
              detailName: detailData['name'] ?? 'Detalhe ${detailIndex + 1}',
              detailValue: detailData['value'],
              observation: detailData['observation'],
              isDamaged: detailData['is_damaged'] == true,
              tags: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              type: detailData['type'] ?? 'text',
              options: detailData['options'] != null ? List<String>.from(detailData['options']) : null,
              status: 'pending',
              isRequired: detailData['required'] == true,
            );
            
            await _offlineService.saveDetail(detail);
            debugPrint('FirestoreSyncService: Created detail ${detail.id}: ${detail.detailName}');
          }
        }
      }
      
      debugPrint('FirestoreSyncService: Successfully processed nested topics structure');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error processing nested topics structure: $e');
    }
  }

  
  // ===============================
  // UPLOAD PARA A NUVEM
  // ===============================
  
  Future<void> uploadLocalChangesToCloud() async {
    try {
      debugPrint('FirestoreSyncService: Uploading local changes to cloud');
      
      await _uploadInspections();
      await _uploadTopics();
      await _uploadItems();
      await _uploadDetails();
      await _uploadNonConformities();
      await _uploadMedia();
      
      debugPrint('FirestoreSyncService: Finished uploading local changes');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading local changes: $e');
    }
  }
  
  Future<void> _uploadInspections() async {
    try {
      final inspections = await _offlineService.getInspectionsNeedingSync();
      
      for (final inspection in inspections) {
        try {
          final data = inspection.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(inspection.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markInspectionSynced(inspection.id);
          
          debugPrint('FirestoreSyncService: Uploaded inspection ${inspection.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading inspection ${inspection.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading inspections: $e');
    }
  }
  
  Future<void> _uploadTopics() async {
    try {
      final topics = await _offlineService.getTopicsNeedingSync();
      
      for (final topic in topics) {
        try {
          final data = topic.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(topic.inspectionId)
              .collection('topics')
              .doc(topic.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markTopicSynced(topic.id ?? '');
          
          debugPrint('FirestoreSyncService: Uploaded topic ${topic.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading topic ${topic.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading topics: $e');
    }
  }
  
  Future<void> _uploadItems() async {
    try {
      final items = await _offlineService.getItemsNeedingSync();
      
      for (final item in items) {
        try {
          final data = item.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(item.inspectionId)
              .collection('topics')
              .doc(item.topicId)
              .collection('items')
              .doc(item.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markItemSynced(item.id ?? '');
          
          debugPrint('FirestoreSyncService: Uploaded item ${item.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading item ${item.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading items: $e');
    }
  }
  
  Future<void> _uploadDetails() async {
    try {
      final details = await _offlineService.getDetailsNeedingSync();
      
      for (final detail in details) {
        try {
          final data = detail.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(detail.inspectionId)
              .collection('topics')
              .doc(detail.topicId)
              .collection('items')
              .doc(detail.itemId)
              .collection('details')
              .doc(detail.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markDetailSynced(detail.id ?? '');
          
          debugPrint('FirestoreSyncService: Uploaded detail ${detail.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading detail ${detail.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading details: $e');
    }
  }
  
  Future<void> _uploadNonConformities() async {
    try {
      final nonConformities = await _offlineService.getNonConformitiesNeedingSync();
      
      for (final nonConformity in nonConformities) {
        try {
          final data = nonConformity.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(nonConformity.inspectionId)
              .collection('non_conformities')
              .doc(nonConformity.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markNonConformitySynced(nonConformity.id);
          
          debugPrint('FirestoreSyncService: Uploaded non-conformity ${nonConformity.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading non-conformity ${nonConformity.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading non-conformities: $e');
    }
  }
  
  Future<void> _uploadMedia() async {
    try {
      final mediaList = await _offlineService.getMediaNeedingSync();
      
      for (final media in mediaList) {
        try {
          // Primeiro, fazer upload do arquivo se ainda não foi feito
          if (!media.isUploaded && media.isProcessed) {
            await _uploadMediaFile(media);
          }
          
          // Depois, salvar os metadados
          final data = media.toMap();
          data.remove('id');
          data.remove('needs_sync');
          data.remove('is_deleted');
          
          await _firebaseService.firestore
              .collection('inspections')
              .doc(media.inspectionId)
              .collection('media')
              .doc(media.id)
              .set(data, SetOptions(merge: true));
          
          await _offlineService.markMediaSynced(media.id);
          
          debugPrint('FirestoreSyncService: Uploaded media ${media.id}');
        } catch (e) {
          debugPrint('FirestoreSyncService: Error uploading media ${media.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media: $e');
    }
  }
  
  Future<void> _uploadMediaFile(OfflineMedia media) async {
    try {
      final file = File(media.localPath);
      if (!await file.exists()) {
        debugPrint('FirestoreSyncService: Media file not found: ${media.localPath}');
        return;
      }
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('inspections')
          .child(media.inspectionId)
          .child('media')
          .child(media.filename);
      
      final uploadTask = ref.putFile(file);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes * 100;
        _offlineService.updateMediaUploadProgress(media.id, progress);
      });
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      await _offlineService.markMediaAsUploaded(media.id, downloadUrl);
      
      debugPrint('FirestoreSyncService: Uploaded media file ${media.filename}');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error uploading media file ${media.filename}: $e');
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
  
  // ===============================
  // SINCRONIZAÇÃO DE INSPEÇÃO ESPECÍFICA
  // ===============================
  
  Future<void> syncInspection(String inspectionId) async {
    if (!await isConnected()) {
      debugPrint('FirestoreSyncService: No internet connection for inspection sync');
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
      }
      
      // Upload de alterações locais
      final localInspection = await _offlineService.getInspection(inspectionId);
      if (localInspection != null) {
        // Data will be synced individually in subsequent calls
        // final localTopics = await _offlineService.getTopics(inspectionId);
        // final localNonConformities = await _offlineService.getNonConformities(inspectionId);
        // final localMedia = await _offlineService.getMediaByInspection(inspectionId);
        
        // Upload da inspeção se necessário
        final inspectionsNeedingSync = await _offlineService.getInspectionsNeedingSync();
        final inspectionNeedsSync = inspectionsNeedingSync.any((i) => i.id == inspectionId);
        
        if (inspectionNeedsSync) {
          await _uploadInspections();
        }
        
        // Upload dos dados relacionados
        await _uploadTopics();
        await _uploadItems();
        await _uploadDetails();
        await _uploadNonConformities();
        await _uploadMedia();
      }
      
      debugPrint('FirestoreSyncService: Finished syncing inspection $inspectionId');
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing inspection $inspectionId: $e');
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
    final nonConformities = await _offlineService.getNonConformitiesNeedingSync();
    final media = await _offlineService.getMediaNeedingSync();
    
    return {
      'inspections': inspections.length,
      'topics': topics.length,
      'items': items.length,
      'details': details.length,
      'non_conformities': nonConformities.length,
      'media': media.length,
      'total': inspections.length + topics.length + items.length + details.length + nonConformities.length + media.length,
    };
  }
  
  Future<bool> hasUnsyncedData() async {
    final status = await getSyncStatus();
    return status['total']! > 0;
  }
}
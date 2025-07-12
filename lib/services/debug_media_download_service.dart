import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/services/media_download_verification_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class DebugMediaDownloadService {
  static DebugMediaDownloadService? _instance;
  static DebugMediaDownloadService get instance {
    _instance ??= DebugMediaDownloadService._internal();
    return _instance!;
  }
  
  DebugMediaDownloadService._internal();
  
  /// Método para testar o download de mídias de uma inspeção específica
  Future<void> testInspectionMediaDownload(String inspectionId) async {
    debugPrint('=== DEBUG: Starting media download test for inspection $inspectionId ===');
    
    try {
      // 1. Verificar estado antes do download
      debugPrint('--- 1. Checking media status BEFORE download ---');
      final statusBefore = await MediaDownloadVerificationService.instance.checkInspectionMediaDownloadStatus(inspectionId);
      debugPrint('Status before: $statusBefore');
      
      // 2. Verificar se a inspeção existe no Firestore
      debugPrint('--- 2. Checking inspection in Firestore ---');
      await _checkInspectionInFirestore(inspectionId);
      
      // 3. Executar o download
      debugPrint('--- 3. Starting download process ---');
      final result = await FirestoreSyncService.instance.syncInspection(inspectionId);
      debugPrint('Download result: $result');
      
      // 4. Verificar estado após o download
      debugPrint('--- 4. Checking media status AFTER download ---');
      final statusAfter = await MediaDownloadVerificationService.instance.checkInspectionMediaDownloadStatus(inspectionId);
      debugPrint('Status after: $statusAfter');
      
      // 5. Listar todas as mídias encontradas
      debugPrint('--- 5. Listing all media found ---');
      await _listAllMediaForInspection(inspectionId);
      
      debugPrint('=== DEBUG: Media download test completed ===');
      
    } catch (e) {
      debugPrint('=== DEBUG: Error during media download test: $e ===');
    }
  }
  
  Future<void> _checkInspectionInFirestore(String inspectionId) async {
    try {
      final serviceFactory = EnhancedOfflineServiceFactory.instance;
      final firebaseService = serviceFactory.firebaseService;
      
      final docSnapshot = await firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        debugPrint('FIRESTORE: Inspection $inspectionId not found');
        return;
      }
      
      final data = docSnapshot.data()!;
      final topics = data['topics'] as List<dynamic>? ?? [];
      
      debugPrint('FIRESTORE: Inspection $inspectionId found with ${topics.length} topics');
      
      int totalMediaInFirestore = 0;
      for (final topicData in topics) {
        final topic = Map<String, dynamic>.from(topicData);
        final topicMedias = topic['media'] as List<dynamic>? ?? [];
        totalMediaInFirestore += topicMedias.length;
        
        final items = topic['items'] as List<dynamic>? ?? [];
        for (final itemData in items) {
          final item = Map<String, dynamic>.from(itemData);
          final itemMedias = item['media'] as List<dynamic>? ?? [];
          totalMediaInFirestore += itemMedias.length;
          
          final details = item['details'] as List<dynamic>? ?? [];
          for (final detailData in details) {
            final detail = Map<String, dynamic>.from(detailData);
            final detailMedias = detail['media'] as List<dynamic>? ?? [];
            totalMediaInFirestore += detailMedias.length;
            
            final nonConformities = detail['non_conformities'] as List<dynamic>? ?? [];
            for (final ncData in nonConformities) {
              final nc = Map<String, dynamic>.from(ncData);
              final ncMedias = nc['media'] as List<dynamic>? ?? [];
              totalMediaInFirestore += ncMedias.length;
            }
          }
        }
      }
      
      debugPrint('FIRESTORE: Total media found in Firestore: $totalMediaInFirestore');
      
    } catch (e) {
      debugPrint('FIRESTORE: Error checking inspection in Firestore: $e');
    }
  }
  
  Future<void> _listAllMediaForInspection(String inspectionId) async {
    try {
      final serviceFactory = EnhancedOfflineServiceFactory.instance;
      final dataService = serviceFactory.dataService;
      
      final allMedia = await dataService.getMediaByInspection(inspectionId);
      
      debugPrint('MEDIA LIST: Found ${allMedia.length} media files for inspection $inspectionId');
      
      for (int i = 0; i < allMedia.length; i++) {
        final media = allMedia[i];
        debugPrint('MEDIA $i: ${media.filename}');
        debugPrint('  - Type: ${media.type}');
        debugPrint('  - Local Path: ${media.localPath}');
        debugPrint('  - Cloud URL: ${media.cloudUrl}');
        debugPrint('  - Is Uploaded: ${media.isUploaded}');
        debugPrint('  - File Size: ${media.fileSize}');
        debugPrint('  - MIME Type: ${media.mimeType}');
        debugPrint('  - Topic ID: ${media.topicId}');
        debugPrint('  - Item ID: ${media.itemId}');
        debugPrint('  - Detail ID: ${media.detailId}');
        debugPrint('  - Non-Conformity ID: ${media.nonConformityId}');
        debugPrint('  - Created At: ${media.createdAt}');
        debugPrint('  - Updated At: ${media.updatedAt}');
        debugPrint('  ---');
      }
      
    } catch (e) {
      debugPrint('MEDIA LIST: Error listing media: $e');
    }
  }
}
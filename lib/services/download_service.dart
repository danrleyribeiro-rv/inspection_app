// lib/services/download_service.dart
import 'package:flutter/foundation.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';

/// Serviço responsável apenas por baixar inspeções do servidor
/// Usado quando o usuário quer baixar uma inspeção para trabalhar offline
class DownloadService {
  final FirebaseService _firebase = FirebaseService();
  final CacheService _cacheService = CacheService();
  final MediaService _mediaService = MediaService();

  /// Baixa uma inspeção específica do Firestore para armazenamento local
  /// Retorna true se o download foi bem-sucedido
  Future<bool> downloadInspection(String inspectionId, {Function(double)? onProgress}) async {
    try {
      debugPrint('DownloadService.downloadInspection: Starting download of inspection $inspectionId');
      
      if (onProgress != null) onProgress(0.1);

      // 1. Baixar dados da inspeção do Firestore
      final doc = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!doc.exists) {
        debugPrint('DownloadService.downloadInspection: Inspection $inspectionId not found on server');
        return false;
      }

      if (onProgress != null) onProgress(0.3);

      final inspectionData = {
        'id': doc.id,
        ...doc.data() ?? {},
      };

      // 2. Salvar dados da inspeção localmente com status 'downloaded' 
      await _cacheService.cacheInspection(inspectionId, inspectionData, isFromCloud: true);
      
      // Ensure the inspection is marked as 'downloaded' for offline use
      final cached = _cacheService.getCachedInspection(inspectionId);
      if (cached != null) {
        cached.localStatus = 'downloaded';
        cached.needsSync = false;
        await cached.save();
      }
      
      if (onProgress != null) onProgress(0.5);

      // 3. Baixar template se existir
      final templateId = inspectionData['template_id'] as String?;
      if (templateId != null && templateId.isNotEmpty) {
        await _downloadTemplate(templateId);
      }

      if (onProgress != null) onProgress(0.7);

      // 4. Baixar todas as mídias associadas
      await _downloadInspectionMedia(inspectionData);

      if (onProgress != null) onProgress(1.0);

      debugPrint('DownloadService.downloadInspection: Successfully downloaded inspection $inspectionId');
      return true;

    } catch (e) {
      debugPrint('DownloadService.downloadInspection: Error downloading inspection $inspectionId: $e');
      return false;
    }
  }

  /// Baixa o template associado à inspeção
  Future<void> _downloadTemplate(String templateId) async {
    try {
      debugPrint('DownloadService._downloadTemplate: Downloading template $templateId');
      
      final templateDoc = await _firebase.firestore
          .collection('templates')
          .doc(templateId)
          .get();

      if (templateDoc.exists) {
        final templateData = templateDoc.data();
        if (templateData != null) {
          templateData['id'] = templateDoc.id;
          
          // Salvar template localmente usando cache service
          await _cacheService.cacheTemplate(templateId, templateData);
          debugPrint('DownloadService._downloadTemplate: Template $templateId downloaded and saved locally');
        }
      }
    } catch (e) {
      debugPrint('DownloadService._downloadTemplate: Error downloading template $templateId: $e');
      // Não falha o download da inspeção se o template falhar
    }
  }

  /// Baixa todas as mídias associadas à inspeção
  Future<void> _downloadInspectionMedia(Map<String, dynamic> inspectionData) async {
    try {
      debugPrint('DownloadService._downloadInspectionMedia: Starting media download');
      
      final mediaUrls = <String>[];
      
      // Extrair URLs de mídia de todos os níveis da hierarquia
      final topics = inspectionData['topics'] as List<dynamic>? ?? [];
      
      for (final topic in topics) {
        if (topic is Map<String, dynamic>) {
          // Mídias do tópico
          final topicMedia = topic['media'] as List<dynamic>? ?? [];
          for (final media in topicMedia) {
            if (media is Map<String, dynamic> && media['url'] is String) {
              mediaUrls.add(media['url']);
            }
          }
          
          // Mídias dos itens
          final items = topic['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final itemMedia = item['media'] as List<dynamic>? ?? [];
              for (final media in itemMedia) {
                if (media is Map<String, dynamic> && media['url'] is String) {
                  mediaUrls.add(media['url']);
                }
              }
              
              // Mídias dos detalhes
              final details = item['details'] as List<dynamic>? ?? [];
              for (final detail in details) {
                if (detail is Map<String, dynamic>) {
                  final detailMedia = detail['media'] as List<dynamic>? ?? [];
                  for (final media in detailMedia) {
                    if (media is Map<String, dynamic> && media['url'] is String) {
                      mediaUrls.add(media['url']);
                    }
                  }
                }
              }
            }
          }
        }
      }

      debugPrint('DownloadService._downloadInspectionMedia: Found ${mediaUrls.length} media files to download');
      
      // Baixar cada mídia
      for (final mediaUrl in mediaUrls) {
        await _mediaService.downloadAndCacheMedia(
          url: mediaUrl,
          inspectionId: inspectionData['id'],
        );
      }

    } catch (e) {
      debugPrint('DownloadService._downloadInspectionMedia: Error: $e');
      // Não falha o download da inspeção se as mídias falharem
    }
  }

  /// Obtém a lista de inspeções disponíveis no servidor que ainda não foram baixadas
  /// Usado para mostrar quais inspeções podem ser baixadas
  /// Filtra apenas as inspeções atribuídas ao vistoriador logado
  Future<List<Map<String, dynamic>>> getAvailableInspections() async {
    try {
      debugPrint('DownloadService.getAvailableInspections: Fetching available inspections from server');
      
      // Obter o ID do usuário logado
      final currentUser = _firebase.currentUser;
      if (currentUser == null) {
        debugPrint('DownloadService.getAvailableInspections: No user logged in');
        return [];
      }

      final currentUserId = currentUser.uid;
      debugPrint('DownloadService.getAvailableInspections: Filtering for inspector: $currentUserId');
      
      // Buscar inspector ID baseado no user ID ou document ID
      String? inspectorId;
      
      // Primeiro, tentar buscar por document ID (caso mais comum)
      try {
        final inspectorDoc = await _firebase.firestore
            .collection('inspectors')
            .doc(currentUserId)
            .get();
            
        if (inspectorDoc.exists) {
          inspectorId = inspectorDoc.id;
          debugPrint('DownloadService.getAvailableInspections: Found inspector by document ID: $inspectorId');
        }
      } catch (e) {
        debugPrint('DownloadService.getAvailableInspections: Document ID lookup failed: $e');
      }
      
      // Se não encontrou por document ID, buscar por user_id field
      if (inspectorId == null) {
        final inspectorSnapshot = await _firebase.firestore
            .collection('inspectors')
            .where('user_id', isEqualTo: currentUserId)
            .limit(1)
            .get();

        if (inspectorSnapshot.docs.isNotEmpty) {
          inspectorId = inspectorSnapshot.docs.first.id;
          debugPrint('DownloadService.getAvailableInspections: Found inspector by user_id field: $inspectorId');
        }
      }

      if (inspectorId == null) {
        debugPrint('DownloadService.getAvailableInspections: No inspector found for user $currentUserId');
        return [];
      }
      
      // Filtrar inspeções pelo inspector_id do usuário logado
      final snapshot = await _firebase.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: inspectorId)
          .where('deleted_at', isNull: true)
          .orderBy('updated_at', descending: true)
          .get();

      final inspections = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Include all inspections for the inspector, mark download status
        final cached = _cacheService.getCachedInspection(doc.id);
        final isDownloaded = cached != null && cached.localStatus == 'downloaded';
        
        // Add download status to the data
        data['isDownloaded'] = isDownloaded;
        data['downloadStatus'] = isDownloaded ? 'downloaded' : 'not_downloaded';
        
        inspections.add(data);
      }

      debugPrint('DownloadService.getAvailableInspections: Found ${inspections.length} available inspections for download');
      return inspections;

    } catch (e) {
      debugPrint('DownloadService.getAvailableInspections: Error: $e');
      return [];
    }
  }

  /// Verifica se uma inspeção está disponível para download
  Future<bool> isInspectionAvailable(String inspectionId) async {
    try {
      final doc = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      return doc.exists;
    } catch (e) {
      debugPrint('DownloadService.isInspectionAvailable: Error: $e');
      return false;
    }
  }
}
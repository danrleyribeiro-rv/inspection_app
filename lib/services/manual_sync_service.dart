// lib/services/manual_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';

/// Serviço para sincronização manual de inspeções com a nuvem
/// Usado quando o usuário clica em "Sincronizar" após editar uma inspeção
class ManualSyncService {
  final FirebaseService _firebase = FirebaseService();
  final CacheService _cacheService = CacheService();
  final MediaService _mediaService = MediaService();

  /// Sincroniza uma inspeção específica com a nuvem
  /// Retorna true se a sincronização foi bem-sucedida
  Future<bool> syncInspection(String inspectionId, {Function(double)? onProgress}) async {
    try {
      debugPrint('ManualSyncService.syncInspection: Starting sync of inspection $inspectionId');
      
      if (onProgress != null) onProgress(0.1);

      // 1. Obter dados locais da inspeção
      final cached = _cacheService.getCachedInspection(inspectionId);
      if (cached == null) {
        debugPrint('ManualSyncService.syncInspection: No cached data found for inspection $inspectionId');
        return false;
      }

      if (!cached.needsSync) {
        debugPrint('ManualSyncService.syncInspection: Inspection $inspectionId does not need sync');
        return true;
      }

      if (onProgress != null) onProgress(0.3);

      // 2. Sincronizar dados da inspeção
      final inspectionData = Map<String, dynamic>.from(cached.data);
      inspectionData.remove('id'); // Remove o ID para evitar conflitos

      await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .set(inspectionData, SetOptions(merge: true));

      if (onProgress != null) onProgress(0.7);

      // 3. Sincronizar mídias pendentes
      await _syncPendingMedia(inspectionId);

      if (onProgress != null) onProgress(0.9);

      // 4. Marcar como sincronizado mas manter status 'downloaded'
      cached.needsSync = false;
      cached.localStatus = 'downloaded'; // Keep as downloaded for offline editing
      cached.lastUpdated = DateTime.now();
      await cached.save();

      if (onProgress != null) onProgress(1.0);

      debugPrint('ManualSyncService.syncInspection: Successfully synced inspection $inspectionId');
      return true;

    } catch (e) {
      debugPrint('ManualSyncService.syncInspection: Error syncing inspection $inspectionId: $e');
      return false;
    }
  }

  /// Sincroniza todas as inspeções que precisam ser sincronizadas
  Future<Map<String, bool>> syncAllPendingInspections({Function(String, double)? onProgressPerInspection}) async {
    try {
      debugPrint('ManualSyncService.syncAllPendingInspections: Starting sync of all pending inspections');
      
      final pendingInspections = _cacheService.getInspectionsNeedingSync();
      final results = <String, bool>{};

      for (int i = 0; i < pendingInspections.length; i++) {
        final inspection = pendingInspections[i];
        debugPrint('ManualSyncService.syncAllPendingInspections: Syncing ${i + 1}/${pendingInspections.length}: ${inspection.id}');
        
        final success = await syncInspection(
          inspection.id,
          onProgress: (progress) {
            if (onProgressPerInspection != null) {
              onProgressPerInspection(inspection.id, progress);
            }
          },
        );
        
        results[inspection.id] = success;
      }

      debugPrint('ManualSyncService.syncAllPendingInspections: Completed sync. Results: $results');
      return results;

    } catch (e) {
      debugPrint('ManualSyncService.syncAllPendingInspections: Error: $e');
      return {};
    }
  }

  /// Sincroniza mídias pendentes de uma inspeção
  Future<void> _syncPendingMedia(String inspectionId) async {
    try {
      debugPrint('ManualSyncService._syncPendingMedia: Syncing media for inspection $inspectionId');
      
      await _mediaService.uploadPendingMediaForInspection(inspectionId);

    } catch (e) {
      debugPrint('ManualSyncService._syncPendingMedia: Error: $e');
      // Não falha a sincronização da inspeção se as mídias falharem
    }
  }

  /// Verifica quantas inspeções precisam ser sincronizadas
  int getPendingSyncCount() {
    return _cacheService.getInspectionsNeedingSync().length;
  }

  /// Obtém a lista de inspeções que precisam ser sincronizadas
  List<String> getPendingInspectionIds() {
    return _cacheService.getInspectionsNeedingSync().map((i) => i.id).toList();
  }

  /// Verifica se há conectividade para sincronização
  Future<bool> canSync() async {
    try {
      // Verificação simples de conectividade usando uma coleção real
      await _firebase.firestore
          .collection('inspections')
          .limit(1)
          .get();
      return true; // Se chegou até aqui, tem conectividade
    } catch (e) {
      debugPrint('ManualSyncService.canSync: No connectivity: $e');
      return false;
    }
  }
}
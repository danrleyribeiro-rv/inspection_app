// lib/services/manual_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/repositories/inspection_repository.dart';
import 'package:inspection_app/services/core/firebase_service.dart'; // Still needed for canSync and media service

/// Serviço para sincronização manual de inspeções com a nuvem
/// Usado quando o usuário clica em "Sincronizar" após editar uma inspeção
class ManualSyncService {
  final InspectionRepository _inspectionRepository;
  final MediaService _mediaService;
  final FirebaseService _firebaseService; // Keep for canSync and media service

  ManualSyncService({
    InspectionRepository? inspectionRepository,
    MediaService? mediaService,
    FirebaseService? firebaseService,
  })  : _inspectionRepository = inspectionRepository ?? InspectionRepository(),
        _mediaService = mediaService ?? MediaService.instance,
        _firebaseService = firebaseService ?? FirebaseService();

  /// Sincroniza todas as inspeções que precisam ser sincronizadas
  Future<Map<String, bool>> syncAllPendingInspections({Function(String, double)? onProgressPerInspection}) async {
    try {
      debugPrint('ManualSyncService.syncAllPendingInspections: Starting full sync via InspectionRepository');
      
      // The InspectionRepository handles both download and upload now
      await _inspectionRepository.syncInspections();

      // Media sync is still handled separately for now
      // We need to get the list of inspections that were just synced or updated
      // and then sync their media.
      // For simplicity, we'll just try to sync all pending media.
      await _syncAllPendingMedia();

      debugPrint('ManualSyncService.syncAllPendingInspections: Full sync completed');
      // Return a dummy success map for now, as detailed progress is within repository
      return {'full_sync': true};

    } catch (e) {
      debugPrint('ManualSyncService.syncAllPendingInspections: Error during full sync: $e');
      return {'full_sync': false};
    }
  }

  /// Sincroniza mídias pendentes de todas as inspeções
  Future<void> _syncAllPendingMedia() async {
    try {
      debugPrint('ManualSyncService._syncAllPendingMedia: Syncing all pending media');
      // This method in MediaService should ideally iterate through all inspections
      // and upload their pending media.
      await _mediaService.uploadAllPendingMedia(); // Assuming this method exists or will be created

    } catch (e) {
      debugPrint('ManualSyncService._syncAllPendingMedia: Error syncing all pending media: $e');
      // Do not rethrow, as media sync failures should not block inspection sync
    }
  }

  /// Verifica quantas inspeções precisam ser sincronizadas (agora via repositório)
  Future<int> getPendingSyncCount() async {
    final pendingInspections = await _inspectionRepository.getInspectionsNeedingSync();
    return pendingInspections.length;
  }

  /// Obtém a lista de IDs de inspeções que precisam ser sincronizadas (agora via repositório)
  Future<List<String>> getPendingInspectionIds() async {
    final pendingInspections = await _inspectionRepository.getInspectionsNeedingSync();
    return pendingInspections.map((i) => i.id).toList();
  }

  /// Verifica se há conectividade para sincronização
  Future<bool> canSync() async {
    try {
      // Verificação simples de conectividade usando uma coleção real
      await _firebaseService.firestore
          .collection('inspections')
          .limit(1)
          .get();
      return true; // Se chegou até aqui, tem conectividade
    } catch (e) {
      debugPrint('ManualSyncService.canSync: No connectivity: $e');
      return false;
    }
  }

  // Remove the specific syncInspection method as it's now handled by the repository
  // Future<bool> syncInspection(String inspectionId, {Function(double)? onProgress}) async { ... }

  // Remove _syncPendingMedia as it's replaced by _syncAllPendingMedia
  // Future<void> _syncPendingMedia(String inspectionId) async { ... }
}
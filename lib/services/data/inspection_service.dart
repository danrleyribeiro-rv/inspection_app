// lib/services/data/inspection_service.dart
import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/utils/cache_service.dart';

/// InspectionService que funciona com dados locais
/// Todas as operações são feitas usando o cache local
class InspectionService {
  final CacheService _cacheService = CacheService();

  /// Obtém uma inspeção usando dados locais
  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      debugPrint('InspectionService.getInspection: Getting inspection $inspectionId from cache');
      return await _cacheService.getInspection(inspectionId);
    } catch (e) {
      debugPrint('InspectionService.getInspection: Error: $e');
      return null;
    }
  }

  /// Salva uma inspeção usando cache local
  /// Marca automaticamente para sincronização posterior
  Future<void> saveInspection(Inspection inspection) async {
    try {
      debugPrint('InspectionService.saveInspection: Saving inspection ${inspection.id} to cache');
      await _cacheService.markAsLocallyModified(inspection.id, inspection.toJson());
    } catch (e) {
      debugPrint('InspectionService.saveInspection: Error: $e');
      rethrow;
    }
  }

  /// Obtém todas as inspeções locais
  Future<List<Inspection>> getAllInspections() async {
    try {
      debugPrint('InspectionService.getAllInspections: Getting all inspections from cache');
      final cachedInspections = _cacheService.getAllCachedInspections();
      final inspections = <Inspection>[];
      
      for (final cached in cachedInspections) {
        try {
          final inspection = Inspection.fromJson(cached.data);
          inspections.add(inspection);
        } catch (e) {
          debugPrint('InspectionService.getAllInspections: Error parsing inspection ${cached.id}: $e');
        }
      }
      
      return inspections;
    } catch (e) {
      debugPrint('InspectionService.getAllInspections: Error: $e');
      return [];
    }
  }

  /// Verifica se uma inspeção está disponível localmente
  bool isInspectionAvailable(String inspectionId) {
    return _cacheService.getCachedInspection(inspectionId) != null;
  }

  /// Verifica se uma inspeção precisa ser sincronizada
  bool needsSync(String inspectionId) {
    final cached = _cacheService.getCachedInspection(inspectionId);
    return cached?.needsSync ?? false;
  }

  /// Obtém o status de uma inspeção
  String? getInspectionStatus(String inspectionId) {
    final cached = _cacheService.getCachedInspection(inspectionId);
    return cached?.localStatus;
  }

  /// Remove uma inspeção do armazenamento local
  Future<void> deleteInspection(String inspectionId) async {
    try {
      debugPrint('InspectionService.deleteInspection: Deleting inspection $inspectionId from cache');
      final cached = _cacheService.getCachedInspection(inspectionId);
      if (cached != null) {
        await cached.delete();
      }
    } catch (e) {
      debugPrint('InspectionService.deleteInspection: Error: $e');
      rethrow;
    }
  }

  /// Obtém estatísticas do armazenamento local
  Map<String, int> getStorageStats() {
    final allCached = _cacheService.getAllCachedInspections();
    return {
      'total': allCached.length,
      'needsSync': allCached.where((i) => i.needsSync).length,
    };
  }

  /// MÉTODO DEPRECATED - mantido para compatibilidade
  /// Use DownloadService.downloadInspection() para baixar inspeções
  @Deprecated('Use DownloadService.downloadInspection() instead')
  Future<void> refreshFromFirestore(String inspectionId) async {
    debugPrint('InspectionService.refreshFromFirestore: Method deprecated - use DownloadService instead');
    // Não faz nada - operação offline apenas
  }
}
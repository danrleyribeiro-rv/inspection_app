// lib/services/data/inspection_service.dart
import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/services/storage/sqlite_storage_service.dart'; // Import SQLiteStorageService

/// InspectionService que funciona com dados locais
/// Todas as operações são feitas usando o SQLiteStorageService
class InspectionService {
  final SQLiteStorageService _localStorage =
      SQLiteStorageService.instance; // Use SQLiteStorageService directly

  /// Obtém uma inspeção usando dados locais
  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      debugPrint(
          'InspectionService.getInspection: Getting inspection $inspectionId from SQLite');
      return await _localStorage.getInspection(inspectionId);
    } catch (e) {
      debugPrint('InspectionService.getInspection: Error: $e');
      return null;
    }
  }

  /// Salva uma inspeção usando SQLiteStorageService
  /// Marca automaticamente para sincronização posterior
  Future<void> saveInspection(Inspection inspection) async {
    try {
      debugPrint(
          'InspectionService.saveInspection: Saving inspection ${inspection.id} to SQLite');
      await _localStorage.saveInspection(
          inspection); // SQLiteStorageService handles marking for sync
    } catch (e) {
      debugPrint('InspectionService.saveInspection: Error: $e');
      rethrow;
    }
  }

  /// Obtém todas as inspeções locais
  Future<List<Inspection>> getAllInspections(String inspectorId) async {
    // Added inspectorId parameter
    try {
      debugPrint(
          'InspectionService.getAllInspections: Getting all inspections from SQLite');
      return await _localStorage.getInspectionsByInspector(
          inspectorId); // Use getInspectionsByInspector
    } catch (e) {
      debugPrint('InspectionService.getAllInspections: Error: $e');
      return [];
    }
  }

  /// Verifica se uma inspeção está disponível localmente
  Future<bool> isInspectionAvailable(String inspectionId) async {
    // Made async
    return await _localStorage.hasInspection(inspectionId);
  }

  /// Verifica se uma inspeção precisa ser sincronizada
  Future<bool> needsSync(String inspectionId) async {
    // Made async
    final inspection = await _localStorage.getInspection(inspectionId);
    return (inspection?.hasLocalChanges ?? false) ||
        !(inspection?.isSynced ?? true);
  }

  /// Obtém o status de uma inspeção (this logic might need to be re-evaluated based on your status definitions)
  String? getInspectionStatus(String inspectionId) {
    // This method's logic needs to be adapted if status is not directly available from Inspection model
    // For now, returning null as it's not directly supported by SQLiteStorageService without fetching the full object
    debugPrint(
        'InspectionService.getInspectionStatus: Direct status retrieval not supported by SQLiteStorageService without fetching full object.');
    return null;
  }

  /// Remove uma inspeção do armazenamento local (SQLiteStorageService does not have a direct deleteInspection method for now)
  Future<void> deleteInspection(String inspectionId) async {
    debugPrint(
        'InspectionService.deleteInspection: Direct deletion of inspection not yet implemented in SQLiteStorageService.');
    // This would require a delete method in SQLiteStorageService for inspections
    throw UnimplementedError(
        'Deletion of inspection not yet implemented via SQLiteStorageService');
  }

  /// Obtém estatísticas do armazenamento local
  Future<Map<String, int>> getStorageStats() async {
    // Made async
    return await _localStorage.getStats();
  }

  /// MÉTODO DEPRECATED - mantido para compatibilidade
  /// Use DownloadService.downloadInspection() para baixar inspeções
  @Deprecated('Use DownloadService.downloadInspection() instead')
  Future<void> refreshFromFirestore(String inspectionId) async {
    debugPrint(
        'InspectionService.refreshFromFirestore: Method deprecated - use DownloadService instead');
    // Não faz nada - operação offline apenas
  }
}

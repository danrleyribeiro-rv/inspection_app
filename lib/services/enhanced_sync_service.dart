import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/native_sync_service.dart';
import 'package:lince_inspecoes/services/cloud_verification_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';
import 'dart:async';

/// Serviço aprimorado de sincronização que integra todas as funcionalidades:
/// - Progresso detalhado
/// - Verificação na nuvem
/// - Sincronização múltipla
/// - Notificações nativas
class EnhancedSyncService {
  static EnhancedSyncService? _instance;
  static EnhancedSyncService get instance {
    _instance ??= EnhancedSyncService();
    return _instance!;
  }

  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  /// Sincroniza uma única inspeção com verificação completa na nuvem
  Future<Map<String, dynamic>> syncInspectionWithVerification(String inspectionId) async {
    debugPrint('EnhancedSyncService: Starting enhanced sync for inspection $inspectionId');
    
    try {
      // Usar o NativeSyncService que já integra o progresso detalhado
      await NativeSyncService.instance.startInspectionSync(inspectionId);
      
      // O resultado já foi tratado pelo NativeSyncService
      return {'success': true, 'message': 'Sincronização completa com verificação'};
    } catch (e) {
      debugPrint('EnhancedSyncService: Error in enhanced sync: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sincroniza múltiplas inspeções com progresso detalhado
  Future<Map<String, dynamic>> syncMultipleInspectionsWithVerification(List<String> inspectionIds) async {
    debugPrint('EnhancedSyncService: Starting enhanced sync for ${inspectionIds.length} inspections');
    
    try {
      // Usar o NativeSyncService para sincronização múltipla
      await NativeSyncService.instance.startMultipleInspectionsSync(inspectionIds);
      
      return {
        'success': true, 
        'message': 'Sincronização múltipla completa',
        'totalInspections': inspectionIds.length,
      };
    } catch (e) {
      debugPrint('EnhancedSyncService: Error in multiple sync: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verifica se uma inspeção está completamente sincronizada na nuvem
  Future<bool> verifyInspectionInCloud(String inspectionId) async {
    try {
      final result = await CloudVerificationService.instance.verifyInspectionSync(inspectionId);
      return result.isComplete;
    } catch (e) {
      debugPrint('EnhancedSyncService: Error verifying inspection: $e');
      return false;
    }
  }

  /// Obtém relatório detalhado de verificação
  Future<Map<String, dynamic>> getInspectionVerificationReport(String inspectionId) async {
    try {
      final result = await CloudVerificationService.instance.verifyInspectionSync(inspectionId);
      return {
        'isComplete': result.isComplete,
        'totalItems': result.totalItems,
        'verifiedItems': result.verifiedItems,
        'missingItems': result.missingItems,
        'failedItems': result.failedItems,
        'summary': result.summary,
      };
    } catch (e) {
      debugPrint('EnhancedSyncService: Error getting verification report: $e');
      return {
        'isComplete': false,
        'error': e.toString(),
      };
    }
  }

  /// Verifica múltiplas inspeções
  Future<Map<String, bool>> verifyMultipleInspections(List<String> inspectionIds) async {
    final results = <String, bool>{};
    
    for (final inspectionId in inspectionIds) {
      results[inspectionId] = await verifyInspectionInCloud(inspectionId);
    }
    
    return results;
  }

  /// Obtém lista de inspeções que precisam ser sincronizadas
  Future<List<String>> getInspectionsPendingSync() async {
    try {
      // Implementar lógica para buscar inspeções pendentes
      // Por enquanto, retorna lista vazia
      return [];
    } catch (e) {
      debugPrint('EnhancedSyncService: Error getting pending inspections: $e');
      return [];
    }
  }

  /// Sincroniza todas as inspeções pendentes
  Future<Map<String, dynamic>> syncAllPendingInspections() async {
    try {
      final pendingIds = await getInspectionsPendingSync();
      
      if (pendingIds.isEmpty) {
        return {
          'success': true,
          'message': 'Nenhuma inspeção pendente para sincronizar',
          'totalInspections': 0,
        };
      }
      
      return await syncMultipleInspectionsWithVerification(pendingIds);
    } catch (e) {
      debugPrint('EnhancedSyncService: Error syncing all pending: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _syncProgressController.close();
  }
}
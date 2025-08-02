import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';
import 'dart:async';

/// Serviço de sincronização simplificado para casos onde a verificação completa está travando
class SimpleSyncService {
  static SimpleSyncService? _instance;
  static SimpleSyncService get instance {
    _instance ??= SimpleSyncService();
    return _instance!;
  }

  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Sincronização simples sem verificação na nuvem (mais rápida)
  Future<Map<String, dynamic>> syncInspectionSimple(String inspectionId) async {
    if (_isSyncing) {
      return {'success': false, 'error': 'Sincronização já em andamento'};
    }

    _isSyncing = true;

    try {
      debugPrint('SimpleSyncService: Iniciando sincronização simples para $inspectionId');

      // Emitir progresso inicial
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.starting,
        current: 0,
        total: 3,
        message: 'Preparando sincronização...',
      ));

      // Usar o método original do FirestoreSyncService mas modificado
      final result = await _performSimpleSync(inspectionId);

      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: result['success'] ? SyncPhase.completed : SyncPhase.error,
        current: 3,
        total: 3,
        message: result['success'] 
            ? 'Sincronização concluída sem verificação!'
            : 'Erro na sincronização: ${result['error']}',
      ));

      return result;
    } catch (e) {
      debugPrint('SimpleSyncService: Erro na sincronização simples: $e');
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.error,
        current: 0,
        total: 3,
        message: 'Erro na sincronização: $e',
      ));

      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
    }
  }

  Future<Map<String, dynamic>> _performSimpleSync(String inspectionId) async {
    try {
      // Verificar conectividade
      if (!await FirestoreSyncService.instance.isConnected()) {
        return {'success': false, 'error': 'Sem conexão com a internet'};
      }

      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.uploading,
        current: 1,
        total: 3,
        message: 'Enviando dados para nuvem...',
      ));

      // Usar o método syncInspection original mas ignorar falhas de verificação
      final result = await FirestoreSyncService.instance.syncInspection(inspectionId);
      
      _syncProgressController.add(SyncProgress(
        inspectionId: inspectionId,
        phase: SyncPhase.completed,
        current: 3,
        total: 3,
        message: 'Sincronização concluída!',
      ));

      // Sempre considerar sucesso, mesmo se a verificação falhar
      if (result['success'] == true || result['error']?.contains('Verificação') == true) {
        return {'success': true, 'simple': true, 'original_result': result};
      } else {
        return result;
      }
    } catch (e) {
      debugPrint('SimpleSyncService: Erro no _performSimpleSync: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sincronização múltipla simples
  Future<Map<String, dynamic>> syncMultipleInspectionsSimple(List<String> inspectionIds) async {
    if (_isSyncing) {
      return {'success': false, 'error': 'Sincronização já em andamento'};
    }

    _isSyncing = true;

    try {
      debugPrint('SimpleSyncService: Iniciando sincronização simples para ${inspectionIds.length} inspeções');

      final results = <String, Map<String, dynamic>>{};
      int successCount = 0;
      int failureCount = 0;

      for (int i = 0; i < inspectionIds.length; i++) {
        final inspectionId = inspectionIds[i];
        
        _syncProgressController.add(SyncProgress(
          inspectionId: inspectionId,
          phase: SyncPhase.uploading,
          current: i,
          total: inspectionIds.length,
          message: 'Sincronizando inspeção ${i + 1} de ${inspectionIds.length}...',
          totalInspections: inspectionIds.length,
          currentInspectionIndex: i + 1,
        ));

        final result = await syncInspectionSimple(inspectionId);
        results[inspectionId] = result;

        if (result['success'] == true) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      final isFullSuccess = failureCount == 0;
      final summary = isFullSuccess 
          ? 'Todas as $successCount inspeções foram sincronizadas!'
          : '$successCount de ${inspectionIds.length} sincronizadas. $failureCount falharam.';

      _syncProgressController.add(SyncProgress(
        inspectionId: 'multiple',
        phase: isFullSuccess ? SyncPhase.completed : SyncPhase.error,
        current: inspectionIds.length,
        total: inspectionIds.length,
        message: summary,
        totalInspections: inspectionIds.length,
      ));

      return {
        'success': isFullSuccess,
        'totalInspections': inspectionIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'summary': summary,
        'simple': true,
        'verification_skipped': true,
        'results': results,
      };
    } catch (e) {
      debugPrint('SimpleSyncService: Erro na sincronização múltipla simples: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _syncProgressController.close();
  }
}
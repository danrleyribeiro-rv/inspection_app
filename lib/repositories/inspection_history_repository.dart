import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/models/inspection_history.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'dart:convert';

class InspectionHistoryRepository {
  // Métodos básicos CRUD usando DatabaseHelper
  Future<String> insert(InspectionHistory history) async {
    await DatabaseHelper.insertInspectionHistory(history);
    return history.id;
  }

  Future<void> update(InspectionHistory history) async {
    await DatabaseHelper.updateInspectionHistory(history);
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.deleteInspectionHistory(id);
  }

  Future<InspectionHistory?> findById(String id) async {
    return await DatabaseHelper.getInspectionHistory(id);
  }

  InspectionHistory fromMap(Map<String, dynamic> map) {
    // Parse metadata if it's a JSON string
    Map<String, dynamic>? metadata;
    if (map['metadata'] != null) {
      if (map['metadata'] is String) {
        try {
          metadata = json.decode(map['metadata'] as String) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error parsing metadata JSON: $e');
          metadata = null;
        }
      } else if (map['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(map['metadata'] as Map);
      }
    }

    final mapWithParsedMetadata = Map<String, dynamic>.from(map);
    mapWithParsedMetadata['metadata'] = metadata;

    return InspectionHistory.fromMap(mapWithParsedMetadata);
  }

  Map<String, dynamic> toMap(InspectionHistory entity) {
    final map = entity.toMap();

    // Convert metadata to JSON string for storage
    if (map['metadata'] != null) {
      map['metadata'] = json.encode(map['metadata']);
    }

    return map;
  }

  // Métodos específicos do InspectionHistory

  /// Busca histórico por inspection_id ordenado por data (mais recente primeiro)
  Future<List<InspectionHistory>> findByInspectionId(String inspectionId) async {
    final allHistory = await DatabaseHelper.getInspectionHistoryByInspection(inspectionId);
    allHistory.sort((a, b) => b.date.compareTo(a.date)); // DESC order
    return allHistory;
  }

  /// Busca o último evento de um tipo específico para uma inspeção
  Future<InspectionHistory?> findLastEventByType(
    String inspectionId,
    HistoryStatus status
  ) async {
    final allHistory = DatabaseHelper.inspectionHistory.values.toList();
    final filtered = allHistory
        .where((h) => h.inspectionId == inspectionId && h.status == status)
        .toList();

    if (filtered.isEmpty) return null;

    filtered.sort((a, b) => b.date.compareTo(a.date)); // DESC order
    return filtered.first;
  }

  /// Busca o último download da inspeção
  Future<InspectionHistory?> findLastDownload(String inspectionId) async {
    return await findLastEventByType(inspectionId, HistoryStatus.downloadedInspection);
  }

  /// Busca o último upload da inspeção
  Future<InspectionHistory?> findLastUpload(String inspectionId) async {
    return await findLastEventByType(inspectionId, HistoryStatus.uploadedInspection);
  }

  /// Verifica se há algum upload após o último download
  Future<bool> hasUploadAfterLastDownload(String inspectionId) async {
    final lastDownload = await findLastDownload(inspectionId);
    final lastUpload = await findLastUpload(inspectionId);

    if (lastDownload == null) return lastUpload != null;
    if (lastUpload == null) return false;

    return lastUpload.date.isAfter(lastDownload.date);
  }

  /// Verifica se a inspeção foi sincronizada (upload mais recente que download)
  Future<bool> isInspectionSynced(String inspectionId) async {
    return await hasUploadAfterLastDownload(inspectionId);
  }

  /// Busca histórico por inspector
  Future<List<InspectionHistory>> findByInspectorId(String inspectorId) async {
    final allHistory = DatabaseHelper.inspectionHistory.values.toList();
    return allHistory.where((h) => h.inspectorId == inspectorId).toList();
  }

  /// Busca eventos de conflito
  Future<List<InspectionHistory>> findConflictEvents(String inspectionId) async {
    final allHistory = DatabaseHelper.inspectionHistory.values.toList();
    final filtered = allHistory.where((h) =>
      h.inspectionId == inspectionId &&
      (h.status == HistoryStatus.conflictDetected || h.status == HistoryStatus.conflictResolved)
    ).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date)); // DESC order
    return filtered;
  }

  /// Verifica se há conflitos não resolvidos
  Future<bool> hasUnresolvedConflicts(String inspectionId) async {
    final conflictEvents = await findConflictEvents(inspectionId);

    if (conflictEvents.isEmpty) return false;

    // Se o último evento é de conflito detectado, não foi resolvido
    final lastConflictEvent = conflictEvents.first;
    return lastConflictEvent.status == HistoryStatus.conflictDetected;
  }

  /// Adiciona um evento de histórico
  Future<String> addHistoryEvent({
    required String inspectionId,
    required HistoryStatus status,
    required String inspectorId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final history = InspectionHistory.create(
      inspectionId: inspectionId,
      status: status,
      inspectorId: inspectorId,
      description: description,
      metadata: metadata,
    );

    debugPrint('InspectionHistoryRepository: Adding history event - $status for inspection $inspectionId');
    return await insert(history);
  }

  /// Busca eventos que precisam ser sincronizados
  Future<List<InspectionHistory>> findPendingSync() async {
    final allHistory = DatabaseHelper.inspectionHistory.values.toList();
    return allHistory.where((h) => h.needsSync).toList();
  }

  // REMOVED: markSynced - Always sync all data on demand

  /// Estatísticas de histórico
  Future<Map<String, int>> getHistoryStats(String inspectionId) async {
    final allHistory = await findByInspectionId(inspectionId);

    final downloads = allHistory.where((h) => h.status == HistoryStatus.downloadedInspection).length;
    final uploads = allHistory.where((h) => h.status == HistoryStatus.uploadedInspection).length;
    final conflicts = allHistory.where((h) =>
      h.status == HistoryStatus.conflictDetected || h.status == HistoryStatus.conflictResolved
    ).length;

    return {
      'total_events': allHistory.length,
      'downloads': downloads,
      'uploads': uploads,
      'conflicts': conflicts,
    };
  }

  /// Deleta histórico de uma inspeção (usado quando inspeção é excluída)
  Future<void> deleteByInspectionId(String inspectionId) async {
    final historyList = await findByInspectionId(inspectionId);
    for (final history in historyList) {
      await delete(history.id);
    }
  }
}
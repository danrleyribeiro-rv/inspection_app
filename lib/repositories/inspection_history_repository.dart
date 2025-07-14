import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/models/inspection_history.dart';
import 'package:lince_inspecoes/repositories/base_repository.dart';
import 'dart:convert';

class InspectionHistoryRepository extends BaseRepository<InspectionHistory> {
  @override
  String get tableName => 'inspection_history';

  @override
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

  @override
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
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'date DESC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Busca o último evento de um tipo específico para uma inspeção
  Future<InspectionHistory?> findLastEventByType(
    String inspectionId, 
    HistoryStatus status
  ) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND status = ?',
      whereArgs: [inspectionId, status.toString().split('.').last],
      orderBy: 'date DESC',
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
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
    return await findWhere('inspector_id = ?', [inspectorId]);
  }

  /// Busca eventos de conflito
  Future<List<InspectionHistory>> findConflictEvents(String inspectionId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'inspection_id = ? AND (status = ? OR status = ?)',
      whereArgs: [
        inspectionId, 
        HistoryStatus.conflictDetected.toString().split('.').last,
        HistoryStatus.conflictResolved.toString().split('.').last,
      ],
      orderBy: 'date DESC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
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
  @override
  Future<List<InspectionHistory>> findPendingSync() async {
    return await findWhere('needs_sync = ?', [1]);
  }

  /// Marca evento como sincronizado
  @override
  Future<void> markSynced(String historyId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'needs_sync': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [historyId],
    );
  }

  /// Estatísticas de histórico
  Future<Map<String, int>> getHistoryStats(String inspectionId) async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ?',
        [inspectionId],
      ),
      db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND status = ?',
        [inspectionId, HistoryStatus.downloadedInspection.toString().split('.').last],
      ),
      db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND status = ?',
        [inspectionId, HistoryStatus.uploadedInspection.toString().split('.').last],
      ),
      db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE inspection_id = ? AND (status = ? OR status = ?)',
        [
          inspectionId, 
          HistoryStatus.conflictDetected.toString().split('.').last,
          HistoryStatus.conflictResolved.toString().split('.').last,
        ],
      ),
    ]);

    return {
      'total_events': results[0].first['count'] as int,
      'downloads': results[1].first['count'] as int,
      'uploads': results[2].first['count'] as int,
      'conflicts': results[3].first['count'] as int,
    };
  }

  /// Deleta histórico de uma inspeção (usado quando inspeção é excluída)
  Future<void> deleteByInspectionId(String inspectionId) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }
}
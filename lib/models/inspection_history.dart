
import 'package:hive/hive.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

part 'inspection_history.g.dart';

@HiveType(typeId: 6)
enum HistoryStatus {
  @HiveField(0)
  downloadedInspection,
  @HiveField(1)
  uploadedInspection,
  @HiveField(2)
  createdInspection,
  @HiveField(3)
  updatedInspection,
  @HiveField(4)
  completedInspection,
  @HiveField(5)
  mediaUploaded,
  @HiveField(6)
  conflictDetected,
  @HiveField(7)
  conflictResolved,
}

@HiveType(typeId: 7)
class InspectionHistory {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final DateTime date;
  @HiveField(3)
  final HistoryStatus status;
  @HiveField(4)
  final String inspectorId;
  @HiveField(5)
  final String? description;
  @HiveField(6)
  final Map<String, dynamic>? metadata;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final bool needsSync;

  const InspectionHistory({
    required this.id,
    required this.inspectionId,
    required this.date,
    required this.status,
    required this.inspectorId,
    this.description,
    this.metadata,
    required this.createdAt,
    this.needsSync = false,
  });

  factory InspectionHistory.create({
    required String inspectionId,
    required HistoryStatus status,
    required String inspectorId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateFormatter.now();
    return InspectionHistory(
      id: 'hist_${now.millisecondsSinceEpoch}',
      inspectionId: inspectionId,
      date: now,
      status: status,
      inspectorId: inspectorId,
      description: description,
      metadata: metadata,
      createdAt: now,
      needsSync: true,
    );
  }

  // Database Serialization
  factory InspectionHistory.fromMap(Map<String, dynamic> map) {
    return InspectionHistory(
      id: map['id'] as String,
      inspectionId: map['inspection_id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: HistoryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] as String),
        orElse: () => HistoryStatus.updatedInspection,
      ),
      inspectorId: map['inspector_id'] as String,
      description: map['description'] as String?,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      needsSync: (map['needs_sync'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'date': date.toIso8601String(),
      'status': status.toString().split('.').last,
      'inspector_id': inspectorId,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  InspectionHistory copyWith({
    String? id,
    String? inspectionId,
    DateTime? date,
    HistoryStatus? status,
    String? inspectorId,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? needsSync,
  }) {
    return InspectionHistory(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      date: date ?? this.date,
      status: status ?? this.status,
      inspectorId: inspectorId ?? this.inspectorId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  // Helper methods
  String get statusDisplayName {
    switch (status) {
      case HistoryStatus.downloadedInspection:
        return 'Baixado da nuvem';
      case HistoryStatus.uploadedInspection:
        return 'Enviado para nuvem';
      case HistoryStatus.createdInspection:
        return 'Criado';
      case HistoryStatus.updatedInspection:
        return 'Atualizado';
      case HistoryStatus.completedInspection:
        return 'Finalizado';
      case HistoryStatus.mediaUploaded:
        return 'Mídia enviada';
      case HistoryStatus.conflictDetected:
        return 'Conflito detectado';
      case HistoryStatus.conflictResolved:
        return 'Conflito resolvido';
    }
  }

  bool get isDownloadEvent => status == HistoryStatus.downloadedInspection;
  bool get isUploadEvent => status == HistoryStatus.uploadedInspection;
  bool get isConflictEvent => 
      status == HistoryStatus.conflictDetected || 
      status == HistoryStatus.conflictResolved;

  @override
  String toString() {
    return 'InspectionHistory(id: $id, inspectionId: $inspectionId, status: $status, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InspectionHistory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
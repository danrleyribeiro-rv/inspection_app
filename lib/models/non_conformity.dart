import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

part 'non_conformity.g.dart';

@HiveType(typeId: 4)
class NonConformity {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final String? topicId;
  @HiveField(3)
  final String? itemId;
  @HiveField(4)
  final String? detailId;
  @HiveField(5)
  final String title;
  @HiveField(6)
  final String description;
  @HiveField(7)
  final String severity; // low, medium, high, critical
  @HiveField(8)
  final String status; // open, closed, in_progress
  @HiveField(9)
  final String? correctiveAction;
  @HiveField(10)
  final DateTime? deadline;
  @HiveField(11)
  final bool isResolved; // NEW: flag for resolution status
  @HiveField(12)
  final DateTime? resolvedAt; // NEW: resolution timestamp
  @HiveField(13)
  final DateTime createdAt;
  @HiveField(14)
  final DateTime updatedAt;
  @HiveField(15)
  final bool isDeleted;

  NonConformity({
    String? id,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    this.detailId,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    this.correctiveAction,
    this.deadline,
    this.isResolved = false,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  }) : id = id ?? const Uuid().v4();

  factory NonConformity.create({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    required String title,
    required String description,
    required String severity,
    String status = 'open',
    String? correctiveAction,
    DateTime? deadline,
    bool isResolved = false,
    DateTime? resolvedAt,
  }) {
    final now = DateFormatter.now();
    return NonConformity(
      id: const Uuid().v4(),
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      title: title,
      description: description,
      severity: severity,
      status: status,
      correctiveAction: correctiveAction,
      deadline: deadline,
      isResolved: isResolved,
      resolvedAt: resolvedAt,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );
  }

  factory NonConformity.fromJson(Map<String, dynamic> json) {
    return NonConformity.fromMap(json);
  }

  Map<String, dynamic> toJson() => toMap();

  factory NonConformity.fromMap(Map<String, dynamic> map) {
    return NonConformity(
      id: map['id'] as String,
      inspectionId: map['inspection_id'] as String,
      topicId: map['topic_id'] as String?,
      itemId: map['item_id'] as String?,
      detailId: map['detail_id'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      severity: (map['severity'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
      correctiveAction: map['corrective_action'] as String?,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      isResolved: map['is_resolved'] is bool
          ? map['is_resolved']
          : (map['is_resolved'] as int? ?? 0) == 1,
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is String
              ? DateTime.parse(map['created_at'])
              : map['created_at']?.toDate?.call())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is String
              ? DateTime.parse(map['updated_at'])
              : map['updated_at']?.toDate?.call())
          : DateTime.now(),
      isDeleted: map['is_deleted'] is bool
          ? map['is_deleted']
          : (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'detail_id': detailId,
      'title': title,
      'description': description,
      'severity': severity,
      'status': status,
      'corrective_action': correctiveAction,
      'deadline': deadline?.toIso8601String(),
      'is_resolved': isResolved ? 1 : 0,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  NonConformity copyWith({
    String? id,
    String? inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? title,
    String? description,
    String? severity,
    String? status,
    String? correctiveAction,
    DateTime? deadline,
    bool? isResolved,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return NonConformity(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      deadline: deadline ?? this.deadline,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NonConformity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NonConformity(id: $id, title: $title, severity: $severity, status: $status)';
  }

  // Getters utilitários
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isInProgress => status == 'in_progress';

  bool get isLowSeverity => severity == 'low';
  bool get isMediumSeverity => severity == 'medium';
  bool get isHighSeverity => severity == 'high';
  bool get isCriticalSeverity => severity == 'critical';

  String get severityDisplayName {
    switch (severity) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'critical':
        return 'Crítica';
      default:
        return severity;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'open':
        return 'Aberta';
      case 'closed':
        return 'Fechada';
      case 'in_progress':
        return 'Em Andamento';
      default:
        return status;
    }
  }
}

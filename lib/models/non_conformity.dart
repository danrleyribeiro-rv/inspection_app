import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'non_conformity.g.dart';

@JsonSerializable()
class NonConformity {
  final String id;
  final String inspectionId;
  final String? topicId;
  final String? itemId;
  final String? detailId;
  final String title;
  final String description;
  final String severity; // low, medium, high, critical
  final String status; // open, closed, in_progress
  final String? correctiveAction;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsSync;
  final bool isDeleted;

  NonConformity({
    required this.id,
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
    required this.createdAt,
    required this.updatedAt,
    this.needsSync = false,
    this.isDeleted = false,
  });

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
  }) {
    final now = DateTime.now();
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
      createdAt: now,
      updatedAt: now,
      needsSync: true,
      isDeleted: false,
    );
  }

  factory NonConformity.fromJson(Map<String, dynamic> json) =>
      _$NonConformityFromJson(json);

  Map<String, dynamic> toJson() => _$NonConformityToJson(this);

  factory NonConformity.fromMap(Map<String, dynamic> map) {
    return NonConformity(
      id: map['id'] as String,
      inspectionId: map['inspection_id'] as String,
      topicId: map['topic_id'] as String?,
      itemId: map['item_id'] as String?,
      detailId: map['detail_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String,
      severity: map['severity'] as String,
      status: map['status'] as String,
      correctiveAction: map['corrective_action'] as String?,
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      needsSync: (map['needs_sync'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsSync,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsSync: needsSync ?? this.needsSync,
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
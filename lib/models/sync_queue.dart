import 'package:hive_ce/hive.dart';

part 'sync_queue.g.dart';

@HiveType(typeId: 9)
class SyncQueue {
  @HiveField(0)
  final int? id;
  @HiveField(1)
  final String entityType;
  @HiveField(2)
  final String entityId;
  @HiveField(3)
  final String action;
  @HiveField(4)
  final String? data;
  @HiveField(5)
  final DateTime createdAt;
  @HiveField(6)
  final int attempts;
  @HiveField(7)
  final DateTime? lastAttemptAt;
  @HiveField(8)
  final String? errorMessage;
  @HiveField(9)
  final bool isProcessed;

  SyncQueue({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.data,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.errorMessage,
    this.isProcessed = false,
  });

  factory SyncQueue.fromJson(Map<String, dynamic> json) {
    return SyncQueue(
      id: json['id'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      action: json['action'],
      data: json['data'],
      createdAt: DateTime.parse(json['created_at']),
      attempts: json['attempts'] ?? 0,
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.parse(json['last_attempt_at'])
          : null,
      errorMessage: json['error_message'],
      isProcessed: json['is_processed'] == 1 || json['is_processed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'attempts': attempts,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'error_message': errorMessage,
      'is_processed': isProcessed ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static SyncQueue fromMap(Map<String, dynamic> map) => SyncQueue.fromJson(map);

  SyncQueue copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? action,
    String? data,
    DateTime? createdAt,
    int? attempts,
    DateTime? lastAttemptAt,
    String? errorMessage,
    bool? isProcessed,
  }) {
    return SyncQueue(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }
}

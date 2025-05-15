// lib/models/topic.dart (adaptado)
class Topic {
  final String? id;
  final String inspectionId;
  final int position;
  final String topicName;
  final String? topicLabel;
  final String? observation;
  final bool? isDamaged;
  final List<String>? tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Topic({
    this.id,
    required this.inspectionId,
    required this.position,
    required this.topicName,
    this.topicLabel,
    this.observation,
    this.isDamaged,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      position: json['position'] is int ? json['position'] : 0,
      topicName: json['topic_name'],
      topicLabel: json['topic_label'],
      observation: json['observation'],
      isDamaged: json['is_damaged'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is String
              ? DateTime.parse(json['created_at'])
              : (json['created_at']?.toDate?.call()))
          : null,
      updatedAt: json['updated_at'] != null
          ? (json['updated_at'] is String
              ? DateTime.parse(json['updated_at'])
              : (json['updated_at']?.toDate?.call()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'position': position,
      'topic_name': topicName,
      'topic_label': topicLabel,
      'observation': observation,
      'is_damaged': isDamaged,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static Topic fromMap(Map<String, dynamic> map) => Topic.fromJson(map);

  Topic copyWith({
    String? id,
    String? inspectionId,
    int? position,
    String? topicName,
    String? topicLabel,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Topic(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      position: position ?? this.position,
      topicName: topicName ?? this.topicName,
      topicLabel: topicLabel ?? this.topicLabel,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
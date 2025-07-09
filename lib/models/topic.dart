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
    // Converter boolean corretamente
    bool? isDamaged;
    if (json['is_damaged'] != null) {
      if (json['is_damaged'] is bool) {
        isDamaged = json['is_damaged'];
      } else if (json['is_damaged'] is int) {
        isDamaged = json['is_damaged'] == 1;
      } else if (json['is_damaged'] is String) {
        isDamaged = json['is_damaged'].toLowerCase() == 'true';
      }
    }
    
    // Converter tags corretamente
    List<String>? tags;
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        tags = List<String>.from(json['tags']);
      } else if (json['tags'] is String) {
        final tagsString = json['tags'] as String;
        tags = tagsString.isEmpty ? [] : tagsString.split(',');
      }
    }
    
    return Topic(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      position: json['position'] is int ? json['position'] : 0,
      topicName: json['topic_name'],
      topicLabel: json['topic_label'],
      observation: json['observation'],
      isDamaged: isDamaged,
      tags: tags,
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
      'is_damaged': isDamaged == true ? 1 : 0,
      'tags': tags?.join(',') ?? '',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'needs_sync': 1,
      'is_deleted': 0,
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
      observation: observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
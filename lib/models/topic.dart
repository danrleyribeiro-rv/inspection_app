// lib/models/topic.dart (adaptado)
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'topic.g.dart';

@HiveType(typeId: 1)
class Topic {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final int position;
  @HiveField(3)
  final int orderIndex;
  @HiveField(4)
  final String topicName;
  @HiveField(5)
  final String? topicLabel;
  @HiveField(6)
  final String? description;
  @HiveField(7)
  final bool? directDetails;
  @HiveField(8)
  final String? observation;
  @HiveField(9)
  final bool? isDamaged;
  @HiveField(10)
  final List<String>? tags;
  @HiveField(11)
  final DateTime? createdAt;
  @HiveField(12)
  final DateTime? updatedAt;

  Topic({
    String? id,
    required this.inspectionId,
    required this.position,
    int? orderIndex,
    required this.topicName,
    this.topicLabel,
    this.description,
    this.directDetails,
    this.observation,
    this.isDamaged,
    this.tags,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4(),
       orderIndex = orderIndex ?? position;

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

    // Converter directDetails corretamente
    bool? directDetails;
    if (json['direct_details'] != null) {
      if (json['direct_details'] is bool) {
        directDetails = json['direct_details'];
      } else if (json['direct_details'] is int) {
        directDetails = json['direct_details'] == 1;
      } else if (json['direct_details'] is String) {
        directDetails = json['direct_details'].toLowerCase() == 'true';
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
      orderIndex: json['order_index'] is int
          ? json['order_index']
          : (json['position'] is int ? json['position'] : 0),
      topicName: json['topic_name'] ?? json['name'],
      topicLabel: json['topic_label'],
      description: json['description'],
      directDetails: directDetails,
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
      'order_index': orderIndex,
      'topic_name': topicName,
      'topic_label': topicLabel,
      'description': description,
      'direct_details': directDetails == true ? 1 : 0,
      'observation': observation,
      'is_damaged': isDamaged == true ? 1 : 0,
      'tags': tags?.join(',') ?? '',
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
    int? orderIndex,
    String? topicName,
    String? topicLabel,
    String? description,
    bool? directDetails,
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
      orderIndex: orderIndex ?? this.orderIndex,
      topicName: topicName ?? this.topicName,
      topicLabel: topicLabel ?? this.topicLabel,
      description: description ?? this.description,
      directDetails: directDetails ?? this.directDetails,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Topic) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

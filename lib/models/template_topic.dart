import 'package:hive_ce/hive.dart';

part 'template_topic.g.dart';

@HiveType(typeId: 20)
class TemplateTopic {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String templateId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final bool directDetails;

  @HiveField(5)
  final String? observation;

  @HiveField(6)
  final int position;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  TemplateTopic({
    required this.id,
    required this.templateId,
    required this.name,
    this.description,
    this.directDetails = false,
    this.observation,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemplateTopic.fromJson(Map<String, dynamic> json, String templateId, int position) {
    return TemplateTopic(
      id: json['id'] ?? '${templateId}_topic_$position',
      templateId: templateId,
      name: json['name'] ?? json['topic_name'] ?? 'Tópico',
      description: json['description'] ?? json['topic_label'],
      directDetails: json['direct_details'] == true,
      observation: json['observation'],
      position: position,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'name': name,
      'description': description,
      'direct_details': directDetails,
      'observation': observation,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static TemplateTopic fromMap(Map<String, dynamic> map) {
    return TemplateTopic(
      id: map['id'],
      templateId: map['template_id'],
      name: map['name'],
      description: map['description'],
      directDetails: map['direct_details'] == 1 || map['direct_details'] == true,
      observation: map['observation'],
      position: map['position'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

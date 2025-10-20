import 'package:hive_ce/hive.dart';

part 'template_item.g.dart';

@HiveType(typeId: 21)
class TemplateItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topicId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final bool evaluable;

  @HiveField(5)
  final List<String>? evaluationOptions;

  @HiveField(6)
  final int position;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  TemplateItem({
    required this.id,
    required this.topicId,
    required this.name,
    this.description,
    this.evaluable = false,
    this.evaluationOptions,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemplateItem.fromJson(Map<String, dynamic> json, String topicId, int position) {
    List<String>? evalOptions;
    if (json['evaluation_options'] != null) {
      final optionsData = json['evaluation_options'];
      if (optionsData is List) {
        evalOptions = optionsData.map((e) => e.toString()).toList();
      } else if (optionsData is String) {
        evalOptions = optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    return TemplateItem(
      id: json['id'] ?? '${topicId}_item_$position',
      topicId: topicId,
      name: json['name'] ?? json['item_name'] ?? 'Item',
      description: json['description'] ?? json['item_label'],
      evaluable: json['evaluable'] == true || evalOptions != null,
      evaluationOptions: evalOptions,
      position: position,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'name': name,
      'description': description,
      'evaluable': evaluable,
      'evaluation_options': evaluationOptions,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static TemplateItem fromMap(Map<String, dynamic> map) {
    return TemplateItem(
      id: map['id'],
      topicId: map['topic_id'],
      name: map['name'],
      description: map['description'],
      evaluable: map['evaluable'] == 1 || map['evaluable'] == true,
      evaluationOptions: map['evaluation_options'] != null
          ? List<String>.from(map['evaluation_options'])
          : null,
      position: map['position'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

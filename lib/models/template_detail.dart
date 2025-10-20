import 'package:hive_ce/hive.dart';

part 'template_detail.g.dart';

@HiveType(typeId: 22)
class TemplateDetail {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topicId;

  @HiveField(2)
  final String? itemId;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String type;

  @HiveField(5)
  final List<String>? options;

  @HiveField(6)
  final bool required;

  @HiveField(7)
  final int position;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  TemplateDetail({
    required this.id,
    required this.topicId,
    this.itemId,
    required this.name,
    this.type = 'text',
    this.options,
    this.required = false,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemplateDetail.fromJson(
    Map<String, dynamic> json,
    String topicId,
    int position, {
    String? itemId,
  }) {
    List<String>? detailOptions;
    if (json['options'] != null) {
      final optionsData = json['options'];
      if (optionsData is List) {
        detailOptions = optionsData.map((e) => e.toString()).toList();
      } else if (optionsData is String) {
        detailOptions = optionsData
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    final baseId = itemId ?? topicId;
    return TemplateDetail(
      id: json['id'] ?? '${baseId}_detail_$position',
      topicId: topicId,
      itemId: itemId,
      name: json['name'] ?? json['detail_name'] ?? 'Detalhe',
      type: json['type'] ?? 'text',
      options: detailOptions,
      required: json['required'] == true,
      position: position,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'item_id': itemId,
      'name': name,
      'type': type,
      'options': options,
      'required': required,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static TemplateDetail fromMap(Map<String, dynamic> map) {
    return TemplateDetail(
      id: map['id'],
      topicId: map['topic_id'],
      itemId: map['item_id'],
      name: map['name'],
      type: map['type'] ?? 'text',
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      required: map['required'] == 1 || map['required'] == true,
      position: map['position'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

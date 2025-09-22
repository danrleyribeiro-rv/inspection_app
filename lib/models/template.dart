import 'package:hive/hive.dart';

part 'template.g.dart';

@HiveType(typeId: 8)
class Template {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String version;
  @HiveField(3)
  final String? description;
  @HiveField(4)
  final String? category;
  @HiveField(5)
  final String structure;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final DateTime updatedAt;
  @HiveField(8)
  final bool isActive;
  @HiveField(9)
  final bool needsSync;

  Template({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.category,
    required this.structure,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.needsSync = false,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'],
      name: json['name'],
      version: json['version'],
      description: json['description'],
      category: json['category'],
      structure: json['structure'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      needsSync: json['needs_sync'] == 1 || json['needs_sync'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'category': category,
      'structure': structure,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() => toJson();
  static Template fromMap(Map<String, dynamic> map) => Template.fromJson(map);

  Template copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? category,
    String? structure,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? needsSync,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      category: category ?? this.category,
      structure: structure ?? this.structure,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}
// lib/models/item.dart
class Item {
  final String? id;
  final String inspectionId;
  final String? topicId;
  final String? itemId;
  final int position;
  final String itemName;
  final String? itemLabel;
  final String? evaluation;
  final String? observation;
  final bool? isDamaged;
  final List<String>? tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Item({
    this.id,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    required this.position,
    required this.itemName,
    this.itemLabel,
    this.evaluation,
    this.observation,
    this.isDamaged,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      topicId: json['topic_id']?.toString(),
      itemId: json['item_id']?.toString(),
      position: json['position'] is int ? json['position'] : 0,
      itemName: json['item_name'],
      itemLabel: json['item_label'],
      evaluation: json['evaluation'],
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

  static Item fromMap(Map<String, dynamic> map) => Item.fromJson(map);
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'position': position,
      'item_name': itemName,
      'item_label': itemLabel,
      'evaluation': evaluation,
      'observation': observation,
      'is_damaged': isDamaged,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  Item copyWith({
    String? id,
    String? inspectionId,
    String? topicId,
    String? itemId,
    int? position,
    String? itemName,
    String? itemLabel,
    String? evaluation,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      itemName: itemName ?? this.itemName,
      itemLabel: itemLabel ?? this.itemLabel,
      evaluation: evaluation ?? this.evaluation,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
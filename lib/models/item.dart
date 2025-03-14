// lib/models/item.dart

class Item {
  final int? id;
  final int inspectionId;
  final int? roomId;
  final int? itemId; //Original item_id from the template.
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
    this.roomId,
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
      id: json['id'],
      inspectionId: json['inspection_id'],
      roomId: json['room_id'],
      itemId: json['item_id'],
      position: json['position'],
      itemName: json['item_name'],
      itemLabel: json['item_label'],
      evaluation: json['evaluation'],
      observation: json['observation'],
      isDamaged: json['is_damaged'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
    Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'room_id': roomId,
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
}

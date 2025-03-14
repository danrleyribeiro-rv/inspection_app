// lib/models/detail.dart
class Detail {
  final int? id;
  final int inspectionId;
  final int? roomId;
  final int? itemId;
  final int? detailId; // Original id of detail from template.
  final int? position;
  final String detailName;
  final String? detailValue;
  final String? observation;
  final bool? isDamaged;
  final List<String>? tags;
    final DateTime? createdAt;
  final DateTime? updatedAt;

  Detail({
    this.id,
    required this.inspectionId,
    this.roomId,
    this.itemId,
    this.detailId,
    this.position,
    required this.detailName,
    this.detailValue,
    this.observation,
    this.isDamaged,
    this.tags,
        this.createdAt,
    this.updatedAt
  });

   factory Detail.fromJson(Map<String, dynamic> json) {
    return Detail(
      id: json['id'],
      inspectionId: json['inspection_id'],
      roomId: json['room_id'],
      itemId: json['item_id'],
      detailId: json['detail_id'],
      position: json['position'],
      detailName: json['detail_name'],
      detailValue: json['detail_value'],
      observation: json['observation'],
      isDamaged: json['is_damaged'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'room_id': roomId,
      'item_id': itemId,
      'detail_id': detailId,
      'position': position,
      'detail_name': detailName,
      'detail_value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
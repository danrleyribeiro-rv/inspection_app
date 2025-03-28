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
      itemId: json['room_item_id'],
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
      'room_item_id': itemId,
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

  Detail copyWith({
    int? id,
    int? inspectionId,
    int? roomId,
    int? itemId,
    int? detailId,
    int? position,
    String? detailName,
    String? detailValue,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Detail(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      roomId: roomId ?? this.roomId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      position: position ?? this.position,
      detailName: detailName ?? this.detailName,
      detailValue: detailValue ?? this.detailValue,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
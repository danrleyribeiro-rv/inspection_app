// lib/models/detail.dart
class Detail {
  final String? id; 
  final String inspectionId;
  final String? roomId; 
  final String? itemId; 
  final String? detailId; 
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
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      roomId: json['room_id']?.toString(),
      itemId: json['room_item_id']?.toString(),
      detailId: json['detail_id']?.toString(),
      position: json['position'] is int ? json['position'] : null,
      detailName: json['detail_name'],
      detailValue: json['detail_value'],
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
    String? id,
    String? inspectionId,
    String? roomId,
    String? itemId,
    String? detailId,
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
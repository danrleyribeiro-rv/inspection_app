// lib/models/detail.dart (modificado)
class Detail {
  final String? id;
  final String inspectionId;
  final String? topicId;
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
  final String? type; // Tipo do detalhe (text, select, number, boolean)
  final List<String>? options; // Opções para o tipo select

  Detail(
      {this.id,
      required this.inspectionId,
      this.topicId,
      this.itemId,
      this.detailId,
      this.position,
      required this.detailName,
      this.detailValue,
      this.observation,
      this.isDamaged,
      this.tags,
      this.createdAt,
      this.updatedAt,
      this.type,
      this.options});

  factory Detail.fromJson(Map<String, dynamic> json) {
    List<String>? parseOptions(dynamic optionsData) {
      if (optionsData == null) return null;

      if (optionsData is List) {
        return List<String>.from(optionsData);
      } else if (optionsData is String) {
        // Se for uma string separada por vírgulas
        return optionsData.split(',').map((e) => e.trim()).toList();
      }

      return null;
    }

    return Detail(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      topicId: json['topic_id']?.toString(),
      itemId: json['topic_item_id']?.toString(),
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
      type: json['type']?.toString(),
      options: parseOptions(json['options']),
    );
  }

  static Detail fromMap(Map<String, dynamic> map) => Detail.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'position': position,
      'detail_name': detailName,
      'detail_value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type,
      'options': options,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic_id': topicId,
      'item_id': itemId,
      'inspection_id': inspectionId,
      'detail_name': detailName,
      'type': type,
      'options': options,
      'detail_value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged,
      'position': position,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Detail copyWith({
    String? id,
    String? inspectionId,
    String? topicId,
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
    String? type,
    List<String>? options,
  }) {
    return Detail(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      position: position ?? this.position,
      detailName: detailName ?? this.detailName,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }
}

// lib/models/detail.dart (modificado)
class Detail {
  final String? id;
  final String inspectionId;
  final String? topicId;
  final String? itemId;
  final String? detailId;
  final int? position;
  final int orderIndex;
  final String detailName;
  final String? detailValue;
  final String? observation;
  final bool? isDamaged;
  final List<String>? tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? type; // Tipo do detalhe (text, select, number, boolean)
  final List<String>? options; // Opções para o tipo select
  final String? status; // Status do detalhe (pending, completed, etc)
  final bool? isRequired; // Se o detalhe é obrigatório

  Detail(
      {this.id,
      required this.inspectionId,
      this.topicId,
      this.itemId,
      this.detailId,
      this.position,
      int? orderIndex,
      required this.detailName,
      this.detailValue,
      this.observation,
      this.isDamaged,
      this.tags,
      this.createdAt,
      this.updatedAt,
      this.type,
      this.options,
      this.status,
      this.isRequired}) : orderIndex = orderIndex ?? position ?? 0;

  factory Detail.fromJson(Map<String, dynamic> json) {
    List<String>? parseOptions(dynamic optionsData) {
      if (optionsData == null) return null;

      if (optionsData is List) {
        return List<String>.from(optionsData);
      } else if (optionsData is String) {
        // Se for uma string separada por vírgulas
        if (optionsData.isEmpty) return [];
        return optionsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      return null;
    }

    List<String>? parseTags(dynamic tagsData) {
      if (tagsData == null) return null;

      if (tagsData is List) {
        return List<String>.from(tagsData);
      } else if (tagsData is String) {
        // Se for uma string separada por vírgulas
        if (tagsData.isEmpty) return [];
        return tagsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      return null;
    }

    return Detail(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      topicId: json['topic_id']?.toString(),
      itemId: json['item_id']?.toString(),
      detailId: json['detail_id']?.toString(),
      position: json['position'] is int ? json['position'] : null,
      orderIndex: json['order_index'] is int ? json['order_index'] : (json['position'] is int ? json['position'] : 0),
      detailName: json['detail_name'],
      detailValue: json['detail_value']?.toString(),
      observation: json['observation'],
      isDamaged: json['is_damaged'] is bool ? json['is_damaged'] : (json['is_damaged'] is int ? json['is_damaged'] == 1 : null),
      tags: parseTags(json['tags']),
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
      status: json['status']?.toString(),
      isRequired: json['is_required'] is bool ? json['is_required'] : (json['is_required'] is int ? json['is_required'] == 1 : null),
    );
  }

  static Detail fromMap(Map<String, dynamic> map) => Detail.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'detail_id': detailId,
      'position': position,
      'order_index': orderIndex,
      'detail_name': detailName,
      'detail_value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged == true ? 1 : 0,
      'tags': tags?.join(',') ?? '',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type,
      'options': options != null ? options!.join(',') : '',
      'status': status,
      'is_required': isRequired == true ? 1 : 0,
      'needs_sync': 1,
      'is_deleted': 0,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'detail_id': detailId,
      'position': position,
      'order_index': orderIndex,
      'detail_name': detailName,
      'detail_value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged == true ? 1 : 0,
      'tags': tags?.join(',') ?? '',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type,
      'options': options != null ? options!.join(',') : '',
      'status': status,
      'is_required': isRequired == true ? 1 : 0,
      'needs_sync': 1,
      'is_deleted': 0,
    };
  }

  Detail copyWith({
    String? id,
    String? inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    int? position,
    int? orderIndex,
    String? detailName,
    String? detailValue,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
    List<String>? options,
    String? status,
    bool? isRequired,
  }) {
    return Detail(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      position: position ?? this.position,
      orderIndex: orderIndex ?? this.orderIndex,
      detailName: detailName ?? this.detailName,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      options: options ?? this.options,
      status: status ?? this.status,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Detail) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

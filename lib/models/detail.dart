// lib/models/detail.dart (modificado)
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'detail.g.dart';

@HiveType(typeId: 3)
class Detail {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final String? topicId;
  @HiveField(3)
  final String? itemId;
  @HiveField(4)
  final String? detailId;
  @HiveField(5)
  final int? position;
  @HiveField(6)
  final int orderIndex;
  @HiveField(7)
  final String detailName;
  @HiveField(8)
  final String? detailValue;
  @HiveField(9)
  final String? observation;
  @HiveField(12)
  final DateTime? createdAt;
  @HiveField(13)
  final DateTime? updatedAt;
  @HiveField(14)
  final String? type; // Tipo do detalhe (text, select, number, boolean)
  @HiveField(15)
  final List<String>? options; // Opções para o tipo select
  @HiveField(16)
  final bool?
      allowCustomOption; // Se permite opção customizada (somente para select)
  @HiveField(17)
  final String? customOptionValue; // Valor da opção customizada
  @HiveField(18)
  final String? status; // Status do detalhe (pending, completed, etc)

  Detail({
      String? id,
      required this.inspectionId,
      this.topicId,
      this.itemId,
      this.detailId,
      this.position,
      int? orderIndex,
      required this.detailName,
      this.detailValue,
      this.observation,
      this.createdAt,
      this.updatedAt,
      this.type,
      this.options,
      this.allowCustomOption,
      this.customOptionValue,
      this.status})
      : id = id ?? const Uuid().v4(),
        orderIndex = orderIndex ?? position ?? 0;

  factory Detail.fromJson(Map<String, dynamic> json) {
    List<String>? parseOptions(dynamic optionsData) {
      if (optionsData == null) return null;

      if (optionsData is List) {
        return List<String>.from(optionsData);
      } else if (optionsData is String) {
        // Se for uma string separada por vírgulas
        if (optionsData.isEmpty) return [];
        return optionsData
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
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
      orderIndex: json['order_index'] is int
          ? json['order_index']
          : (json['position'] is int ? json['position'] : 0),
      detailName: json['detail_name'] ?? json['name'],
      detailValue: json['detail_value'] ?? json['value']?.toString(),
      observation: json['observation'],
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
      allowCustomOption: json['allow_custom_option'] is bool
          ? json['allow_custom_option']
          : (json['allow_custom_option'] is int
              ? json['allow_custom_option'] == 1
              : null),
      customOptionValue: json['custom_option_value']?.toString(),
      status: json['status']?.toString(),
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type,
      'options': options != null ? options!.join(',') : '',
      'allow_custom_option': allowCustomOption == true ? 1 : 0,
      'custom_option_value': customOptionValue,
      'status': status,
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type,
      'options': options != null ? options!.join(',') : '',
      'allow_custom_option': allowCustomOption == true ? 1 : 0,
      'custom_option_value': customOptionValue,
      'status': status,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
    List<String>? options,
    bool? allowCustomOption,
    String? customOptionValue,
    String? status,
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
      detailValue: detailValue ?? this.detailValue,
      observation: observation ?? this.observation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      options: options ?? this.options,
      allowCustomOption: allowCustomOption ?? this.allowCustomOption,
      customOptionValue: customOptionValue ?? this.customOptionValue,
      status: status ?? this.status,
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

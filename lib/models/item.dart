// lib/models/item.dart
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'item.g.dart';

@HiveType(typeId: 2)
class Item {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final String? topicId;
  @HiveField(3)
  final String? itemId;
  @HiveField(4)
  final int position;
  @HiveField(5)
  final int orderIndex;
  @HiveField(6)
  final String itemName;
  @HiveField(7)
  final String? itemLabel;
  @HiveField(8)
  final String? description;
  @HiveField(9)
  final bool? evaluable;
  @HiveField(10)
  final List<String>? evaluationOptions;
  @HiveField(11)
  final String? evaluationValue;
  @HiveField(12)
  final String? evaluation;
  @HiveField(13)
  final String? observation;
  @HiveField(16)
  final DateTime? createdAt;
  @HiveField(17)
  final DateTime? updatedAt;

  Item({
    String? id,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    required this.position,
    int? orderIndex,
    required this.itemName,
    this.itemLabel,
    this.description,
    this.evaluable,
    this.evaluationOptions,
    this.evaluationValue,
    this.evaluation,
    this.observation,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4(),
       orderIndex = orderIndex ?? position;

  factory Item.fromJson(Map<String, dynamic> json) {

    // Converter evaluable corretamente
    bool? evaluable;
    if (json['evaluable'] != null) {
      if (json['evaluable'] is bool) {
        evaluable = json['evaluable'];
      } else if (json['evaluable'] is int) {
        evaluable = json['evaluable'] == 1;
      } else if (json['evaluable'] is String) {
        evaluable = json['evaluable'].toLowerCase() == 'true';
      }
    }

    // Converter evaluation_options corretamente
    List<String>? evaluationOptions;
    if (json['evaluation_options'] != null) {
      if (json['evaluation_options'] is List) {
        evaluationOptions = List<String>.from(json['evaluation_options']);
      } else if (json['evaluation_options'] is String) {
        final optionsString = json['evaluation_options'] as String;
        evaluationOptions =
            optionsString.isEmpty ? [] : optionsString.split(',');
      }
    }

    return Item(
      id: json['id']?.toString(),
      inspectionId: json['inspection_id'],
      topicId: json['topic_id']?.toString(),
      itemId: json['item_id']?.toString(),
      position: json['position'] is int ? json['position'] : 0,
      orderIndex: json['order_index'] is int
          ? json['order_index']
          : (json['position'] is int ? json['position'] : 0),
      itemName: json['item_name'] ?? json['name'],
      itemLabel: json['item_label'],
      description: json['description'],
      evaluable: evaluable,
      evaluationOptions: evaluationOptions,
      evaluationValue: json['evaluation_value'],
      evaluation: json['evaluation'],
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
      'order_index': orderIndex,
      'item_name': itemName,
      'item_label': itemLabel,
      'description': description,
      'evaluable': evaluable == true ? 1 : 0,
      'evaluation_options': evaluationOptions?.join(',') ?? '',
      'evaluation_value': evaluationValue,
      'evaluation': evaluation,
      'observation': observation,
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
    int? orderIndex,
    String? itemName,
    String? itemLabel,
    String? description,
    bool? evaluable,
    List<String>? evaluationOptions,
    String? evaluationValue,
    String? evaluation,
    String? observation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      orderIndex: orderIndex ?? this.orderIndex,
      itemName: itemName ?? this.itemName,
      itemLabel: itemLabel ?? this.itemLabel,
      description: description ?? this.description,
      evaluable: evaluable ?? this.evaluable,
      evaluationOptions: evaluationOptions ?? this.evaluationOptions,
      evaluationValue: evaluationValue ?? this.evaluationValue,
      evaluation: evaluation ?? this.evaluation,
      observation: observation ?? this.observation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Item) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

import 'package:hive/hive.dart';

part 'cached_inspection.g.dart';

@HiveType(typeId: 0)
class CachedInspection extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? title;

  @HiveField(2)
  String? status;

  @HiveField(3)
  bool? isTemplated;

  @HiveField(4)
  String? templateId;

  @HiveField(5)
  DateTime? updatedAt;

  @HiveField(6)
  Map<String, dynamic>? data;

  @HiveField(7)
  bool needsSync;

  CachedInspection({
    required this.id,
    this.title,
    this.status,
    this.isTemplated,
    this.templateId,
    this.updatedAt,
    this.data,
    this.needsSync = false,
  });

  factory CachedInspection.fromFirestore(Map<String, dynamic> data, String id) {
    return CachedInspection(
      id: id,
      title: data['title'],
      status: data['status'],
      isTemplated: data['is_templated'],
      templateId: data['template_id'],
      updatedAt: data['updated_at']?.toDate(),
      data: data,
      needsSync: false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return data ?? {};
  }
}

@HiveType(typeId: 1)
class CachedTopic extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String inspectionId;

  @HiveField(2)
  String topicName;

  @HiveField(3)
  String? topicLabel;

  @HiveField(4)
  int position;

  @HiveField(5)
  String? observation;

  @HiveField(6)
  DateTime? createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  @HiveField(8)
  bool needsSync;

  CachedTopic({
    required this.id,
    required this.inspectionId,
    required this.topicName,
    this.topicLabel,
    required this.position,
    this.observation,
    this.createdAt,
    this.updatedAt,
    this.needsSync = false,
  });
}

@HiveType(typeId: 2)
class CachedItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String topicId;

  @HiveField(2)
  String inspectionId;

  @HiveField(3)
  String itemName;

  @HiveField(4)
  String? itemLabel;

  @HiveField(5)
  int position;

  @HiveField(6)
  String? observation;

  @HiveField(7)
  DateTime? createdAt;

  @HiveField(8)
  DateTime? updatedAt;

  @HiveField(9)
  bool needsSync;

  CachedItem({
    required this.id,
    required this.topicId,
    required this.inspectionId,
    required this.itemName,
    this.itemLabel,
    required this.position,
    this.observation,
    this.createdAt,
    this.updatedAt,
    this.needsSync = false,
  });
}

@HiveType(typeId: 3)
class CachedDetail extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String itemId;

  @HiveField(2)
  String topicId;

  @HiveField(3)
  String inspectionId;

  @HiveField(4)
  String detailName;

  @HiveField(5)
  String type;

  @HiveField(6)
  List<String>? options;

  @HiveField(7)
  String? detailValue;

  @HiveField(8)
  String? observation;

  @HiveField(9)
  bool isDamaged;

  @HiveField(10)
  int? position;

  @HiveField(11)
  DateTime? createdAt;

  @HiveField(12)
  DateTime? updatedAt;

  @HiveField(13)
  bool needsSync;

  CachedDetail({
    required this.id,
    required this.itemId,
    required this.topicId,
    required this.inspectionId,
    required this.detailName,
    this.type = 'text',
    this.options,
    this.detailValue,
    this.observation,
    this.isDamaged = false,
    this.position,
    this.createdAt,
    this.updatedAt,
    this.needsSync = false,
  });
}

@HiveType(typeId: 4)
class CachedMedia extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String detailId;

  @HiveField(2)
  String itemId;

  @HiveField(3)
  String topicId;

  @HiveField(4)
  String inspectionId;

  @HiveField(5)
  String type;

  @HiveField(6)
  String? localPath;

  @HiveField(7)
  String? url;

  @HiveField(8)
  bool isNonConformity;

  @HiveField(9)
  String? observation;

  @HiveField(10)
  String? nonConformityId;

  @HiveField(11)
  DateTime? createdAt;

  @HiveField(12)
  DateTime? updatedAt;

  @HiveField(13)
  bool needsSync;

  CachedMedia({
    required this.id,
    required this.detailId,
    required this.itemId,
    required this.topicId,
    required this.inspectionId,
    required this.type,
    this.localPath,
    this.url,
    this.isNonConformity = false,
    this.observation,
    this.nonConformityId,
    this.createdAt,
    this.updatedAt,
    this.needsSync = false,
  });
}

@HiveType(typeId: 5)
class CachedNonConformity extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String detailId;

  @HiveField(2)
  String itemId;

  @HiveField(3)
  String topicId;

  @HiveField(4)
  String inspectionId;

  @HiveField(5)
  String description;

  @HiveField(6)
  String severity;

  @HiveField(7)
  String? correctiveAction;

  @HiveField(8)
  String? deadline;

  @HiveField(9)
  String status;

  @HiveField(10)
  DateTime? createdAt;

  @HiveField(11)
  DateTime? updatedAt;

  @HiveField(12)
  bool needsSync;

  CachedNonConformity({
    required this.id,
    required this.detailId,
    required this.itemId,
    required this.topicId,
    required this.inspectionId,
    required this.description,
    this.severity = 'Média',
    this.correctiveAction,
    this.deadline,
    this.status = 'pendente',
    this.createdAt,
    this.updatedAt,
    this.needsSync = false,
  });
}
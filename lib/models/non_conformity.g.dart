// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'non_conformity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NonConformity _$NonConformityFromJson(Map<String, dynamic> json) =>
    NonConformity(
      id: json['id'] as String,
      inspectionId: json['inspectionId'] as String,
      topicId: json['topicId'] as String?,
      itemId: json['itemId'] as String?,
      detailId: json['detailId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      correctiveAction: json['correctiveAction'] as String?,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      needsSync: json['needsSync'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$NonConformityToJson(NonConformity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspectionId': instance.inspectionId,
      'topicId': instance.topicId,
      'itemId': instance.itemId,
      'detailId': instance.detailId,
      'title': instance.title,
      'description': instance.description,
      'severity': instance.severity,
      'status': instance.status,
      'correctiveAction': instance.correctiveAction,
      'deadline': instance.deadline?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'needsSync': instance.needsSync,
      'isDeleted': instance.isDeleted,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'non_conformity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NonConformity _$NonConformityFromJson(Map<String, dynamic> json) =>
    NonConformity(
      id: json['id'] as String,
      inspectionId: json['inspection_id'] as String,
      topicId: json['topic_id'] as String?,
      itemId: json['item_id'] as String?,
      detailId: json['detail_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      needsSync: json['needs_sync'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$NonConformityToJson(NonConformity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspection_id': instance.inspectionId,
      'topic_id': instance.topicId,
      'item_id': instance.itemId,
      'detail_id': instance.detailId,
      'title': instance.title,
      'description': instance.description,
      'severity': instance.severity,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'needs_sync': instance.needsSync,
      'is_deleted': instance.isDeleted,
    };
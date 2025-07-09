// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflineMedia _$OfflineMediaFromJson(Map<String, dynamic> json) =>
    OfflineMedia(
      id: json['id'] as String,
      inspectionId: json['inspection_id'] as String,
      topicId: json['topic_id'] as String?,
      itemId: json['item_id'] as String?,
      detailId: json['detail_id'] as String?,
      nonConformityId: json['non_conformity_id'] as String?,
      type: json['type'] as String,
      localPath: json['local_path'] as String,
      cloudUrl: json['cloud_url'] as String?,
      filename: json['filename'] as String,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      duration: json['duration'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      isProcessed: json['is_processed'] as bool? ?? false,
      isUploaded: json['is_uploaded'] as bool? ?? false,
      uploadProgress: (json['upload_progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      needsSync: json['needs_sync'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$OfflineMediaToJson(OfflineMedia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspection_id': instance.inspectionId,
      'topic_id': instance.topicId,
      'item_id': instance.itemId,
      'detail_id': instance.detailId,
      'non_conformity_id': instance.nonConformityId,
      'type': instance.type,
      'local_path': instance.localPath,
      'cloud_url': instance.cloudUrl,
      'filename': instance.filename,
      'file_size': instance.fileSize,
      'mime_type': instance.mimeType,
      'thumbnail_path': instance.thumbnailPath,
      'duration': instance.duration,
      'width': instance.width,
      'height': instance.height,
      'is_processed': instance.isProcessed,
      'is_uploaded': instance.isUploaded,
      'upload_progress': instance.uploadProgress,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'needs_sync': instance.needsSync,
      'is_deleted': instance.isDeleted,
    };
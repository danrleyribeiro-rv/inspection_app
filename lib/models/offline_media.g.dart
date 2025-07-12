// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflineMedia _$OfflineMediaFromJson(Map<String, dynamic> json) => OfflineMedia(
      id: json['id'] as String,
      inspectionId: json['inspectionId'] as String,
      topicId: json['topicId'] as String?,
      itemId: json['itemId'] as String?,
      detailId: json['detailId'] as String?,
      nonConformityId: json['nonConformityId'] as String?,
      type: json['type'] as String,
      localPath: json['localPath'] as String,
      cloudUrl: json['cloudUrl'] as String?,
      filename: json['filename'] as String,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      isProcessed: json['isProcessed'] as bool? ?? false,
      isUploaded: json['isUploaded'] as bool? ?? false,
      uploadProgress: (json['uploadProgress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      needsSync: json['needsSync'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      source: json['source'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OfflineMediaToJson(OfflineMedia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspectionId': instance.inspectionId,
      'topicId': instance.topicId,
      'itemId': instance.itemId,
      'detailId': instance.detailId,
      'nonConformityId': instance.nonConformityId,
      'type': instance.type,
      'localPath': instance.localPath,
      'cloudUrl': instance.cloudUrl,
      'filename': instance.filename,
      'fileSize': instance.fileSize,
      'mimeType': instance.mimeType,
      'thumbnailPath': instance.thumbnailPath,
      'duration': instance.duration,
      'width': instance.width,
      'height': instance.height,
      'isProcessed': instance.isProcessed,
      'isUploaded': instance.isUploaded,
      'uploadProgress': instance.uploadProgress,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'needsSync': instance.needsSync,
      'isDeleted': instance.isDeleted,
      'source': instance.source,
      'metadata': instance.metadata,
    };

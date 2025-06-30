// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineMediaAdapter extends TypeAdapter<OfflineMedia> {
  @override
  final int typeId = 2;

  @override
  OfflineMedia read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineMedia(
      id: fields[0] as String,
      localPath: fields[1] as String,
      inspectionId: fields[2] as String,
      topicId: fields[3] as String?,
      itemId: fields[4] as String?,
      detailId: fields[5] as String?,
      type: fields[6] as String,
      fileName: fields[7] as String,
      createdAt: fields[8] as DateTime,
      isProcessed: fields[9] as bool,
      isUploaded: fields[10] as bool,
      uploadUrl: fields[11] as String?,
      metadata: (fields[12] as Map?)?.cast<String, dynamic>(),
      fileSize: fields[13] as int?,
      retryCount: fields[14] as int,
      lastRetryAt: fields[15] as DateTime?,
      errorMessage: fields[16] as String?,
      cloudUrl: fields[17] as String?,
      isDownloadedFromCloud: fields[18] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineMedia obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.localPath)
      ..writeByte(2)
      ..write(obj.inspectionId)
      ..writeByte(3)
      ..write(obj.topicId)
      ..writeByte(4)
      ..write(obj.itemId)
      ..writeByte(5)
      ..write(obj.detailId)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.fileName)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isProcessed)
      ..writeByte(10)
      ..write(obj.isUploaded)
      ..writeByte(11)
      ..write(obj.uploadUrl)
      ..writeByte(12)
      ..write(obj.metadata)
      ..writeByte(13)
      ..write(obj.fileSize)
      ..writeByte(14)
      ..write(obj.retryCount)
      ..writeByte(15)
      ..write(obj.lastRetryAt)
      ..writeByte(16)
      ..write(obj.errorMessage)
      ..writeByte(17)
      ..write(obj.cloudUrl)
      ..writeByte(18)
      ..write(obj.isDownloadedFromCloud);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineMediaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflineMedia _$OfflineMediaFromJson(Map<String, dynamic> json) => OfflineMedia(
      id: json['id'] as String,
      localPath: json['localPath'] as String,
      inspectionId: json['inspectionId'] as String,
      topicId: json['topicId'] as String?,
      itemId: json['itemId'] as String?,
      detailId: json['detailId'] as String?,
      type: json['type'] as String,
      fileName: json['fileName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isProcessed: json['isProcessed'] as bool? ?? false,
      isUploaded: json['isUploaded'] as bool? ?? false,
      uploadUrl: json['uploadUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      lastRetryAt: json['lastRetryAt'] == null
          ? null
          : DateTime.parse(json['lastRetryAt'] as String),
      errorMessage: json['errorMessage'] as String?,
      cloudUrl: json['cloudUrl'] as String?,
      isDownloadedFromCloud: json['isDownloadedFromCloud'] as bool? ?? false,
    );

Map<String, dynamic> _$OfflineMediaToJson(OfflineMedia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'localPath': instance.localPath,
      'inspectionId': instance.inspectionId,
      'topicId': instance.topicId,
      'itemId': instance.itemId,
      'detailId': instance.detailId,
      'type': instance.type,
      'fileName': instance.fileName,
      'createdAt': instance.createdAt.toIso8601String(),
      'isProcessed': instance.isProcessed,
      'isUploaded': instance.isUploaded,
      'uploadUrl': instance.uploadUrl,
      'metadata': instance.metadata,
      'fileSize': instance.fileSize,
      'retryCount': instance.retryCount,
      'lastRetryAt': instance.lastRetryAt?.toIso8601String(),
      'errorMessage': instance.errorMessage,
      'cloudUrl': instance.cloudUrl,
      'isDownloadedFromCloud': instance.isDownloadedFromCloud,
    };

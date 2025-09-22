// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineMediaAdapter extends TypeAdapter<OfflineMedia> {
  @override
  final int typeId = 5;

  @override
  OfflineMedia read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineMedia(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      topicId: fields[2] as String?,
      itemId: fields[3] as String?,
      detailId: fields[4] as String?,
      nonConformityId: fields[5] as String?,
      type: fields[6] as String,
      localPath: fields[7] as String,
      cloudUrl: fields[8] as String?,
      filename: fields[9] as String,
      fileSize: fields[10] as int?,
      thumbnailPath: fields[11] as String?,
      duration: fields[12] as int?,
      width: fields[13] as int?,
      height: fields[14] as int?,
      isUploaded: fields[15] as bool? ?? false,
      uploadProgress: fields[16] as double? ?? 0.0,
      createdAt: fields[17] as DateTime? ?? DateTime.now(),
      updatedAt: fields[18] as DateTime? ?? DateTime.now(),
      needsSync: fields[19] as bool? ?? false,
      isDeleted: fields[20] as bool? ?? false,
      source: fields[21] as String?,
      isResolutionMedia: fields[22] as bool? ?? false,
      orderIndex: fields[23] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineMedia obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.topicId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.detailId)
      ..writeByte(5)
      ..write(obj.nonConformityId)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.localPath)
      ..writeByte(8)
      ..write(obj.cloudUrl)
      ..writeByte(9)
      ..write(obj.filename)
      ..writeByte(10)
      ..write(obj.fileSize)
      ..writeByte(11)
      ..write(obj.thumbnailPath)
      ..writeByte(12)
      ..write(obj.duration)
      ..writeByte(13)
      ..write(obj.width)
      ..writeByte(14)
      ..write(obj.height)
      ..writeByte(15)
      ..write(obj.isUploaded)
      ..writeByte(16)
      ..write(obj.uploadProgress)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.needsSync)
      ..writeByte(20)
      ..write(obj.isDeleted)
      ..writeByte(21)
      ..write(obj.source)
      ..writeByte(22)
      ..write(obj.isResolutionMedia)
      ..writeByte(23)
      ..write(obj.orderIndex);
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

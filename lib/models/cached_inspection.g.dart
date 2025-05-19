// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_inspection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedInspectionAdapter extends TypeAdapter<CachedInspection> {
  @override
  final int typeId = 0;

  @override
  CachedInspection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedInspection(
      id: fields[0] as String,
      title: fields[1] as String?,
      status: fields[2] as String?,
      isTemplated: fields[3] as bool?,
      templateId: fields[4] as String?,
      updatedAt: fields[5] as DateTime?,
      data: (fields[6] as Map?)?.cast<String, dynamic>(),
      needsSync: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedInspection obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.isTemplated)
      ..writeByte(4)
      ..write(obj.templateId)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.data)
      ..writeByte(7)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedInspectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedTopicAdapter extends TypeAdapter<CachedTopic> {
  @override
  final int typeId = 1;

  @override
  CachedTopic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedTopic(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      topicName: fields[2] as String,
      topicLabel: fields[3] as String?,
      position: fields[4] as int,
      observation: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      needsSync: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedTopic obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.topicName)
      ..writeByte(3)
      ..write(obj.topicLabel)
      ..writeByte(4)
      ..write(obj.position)
      ..writeByte(5)
      ..write(obj.observation)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedTopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedItemAdapter extends TypeAdapter<CachedItem> {
  @override
  final int typeId = 2;

  @override
  CachedItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedItem(
      id: fields[0] as String,
      topicId: fields[1] as String,
      inspectionId: fields[2] as String,
      itemName: fields[3] as String,
      itemLabel: fields[4] as String?,
      position: fields[5] as int,
      observation: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      needsSync: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.inspectionId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.itemLabel)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.observation)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedDetailAdapter extends TypeAdapter<CachedDetail> {
  @override
  final int typeId = 3;

  @override
  CachedDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedDetail(
      id: fields[0] as String,
      itemId: fields[1] as String,
      topicId: fields[2] as String,
      inspectionId: fields[3] as String,
      detailName: fields[4] as String,
      type: fields[5] as String,
      options: (fields[6] as List?)?.cast<String>(),
      detailValue: fields[7] as String?,
      observation: fields[8] as String?,
      isDamaged: fields[9] as bool,
      position: fields[10] as int?,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
      needsSync: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedDetail obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.topicId)
      ..writeByte(3)
      ..write(obj.inspectionId)
      ..writeByte(4)
      ..write(obj.detailName)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.options)
      ..writeByte(7)
      ..write(obj.detailValue)
      ..writeByte(8)
      ..write(obj.observation)
      ..writeByte(9)
      ..write(obj.isDamaged)
      ..writeByte(10)
      ..write(obj.position)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedMediaAdapter extends TypeAdapter<CachedMedia> {
  @override
  final int typeId = 4;

  @override
  CachedMedia read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedMedia(
      id: fields[0] as String,
      detailId: fields[1] as String,
      itemId: fields[2] as String,
      topicId: fields[3] as String,
      inspectionId: fields[4] as String,
      type: fields[5] as String,
      localPath: fields[6] as String?,
      url: fields[7] as String?,
      isNonConformity: fields[8] as bool,
      observation: fields[9] as String?,
      nonConformityId: fields[10] as String?,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
      needsSync: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMedia obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.detailId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.topicId)
      ..writeByte(4)
      ..write(obj.inspectionId)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.localPath)
      ..writeByte(7)
      ..write(obj.url)
      ..writeByte(8)
      ..write(obj.isNonConformity)
      ..writeByte(9)
      ..write(obj.observation)
      ..writeByte(10)
      ..write(obj.nonConformityId)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedMediaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedNonConformityAdapter extends TypeAdapter<CachedNonConformity> {
  @override
  final int typeId = 5;

  @override
  CachedNonConformity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedNonConformity(
      id: fields[0] as String,
      detailId: fields[1] as String,
      itemId: fields[2] as String,
      topicId: fields[3] as String,
      inspectionId: fields[4] as String,
      description: fields[5] as String,
      severity: fields[6] as String,
      correctiveAction: fields[7] as String?,
      deadline: fields[8] as String?,
      status: fields[9] as String,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      needsSync: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedNonConformity obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.detailId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.topicId)
      ..writeByte(4)
      ..write(obj.inspectionId)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.severity)
      ..writeByte(7)
      ..write(obj.correctiveAction)
      ..writeByte(8)
      ..write(obj.deadline)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedNonConformityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

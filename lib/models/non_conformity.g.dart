// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'non_conformity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NonConformityAdapter extends TypeAdapter<NonConformity> {
  @override
  final int typeId = 4;

  @override
  NonConformity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NonConformity(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      topicId: fields[2] as String?,
      itemId: fields[3] as String?,
      detailId: fields[4] as String?,
      title: fields[5] as String,
      description: fields[6] as String,
      severity: fields[7] as String,
      status: fields[8] as String,
      correctiveAction: fields[9] as String?,
      deadline: fields[10] as DateTime?,
      isResolved: fields[11] as bool,
      resolvedAt: fields[12] as DateTime?,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      needsSync: fields[15] as bool,
      isDeleted: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NonConformity obj) {
    writer
      ..writeByte(17)
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
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.severity)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.correctiveAction)
      ..writeByte(10)
      ..write(obj.deadline)
      ..writeByte(11)
      ..write(obj.isResolved)
      ..writeByte(12)
      ..write(obj.resolvedAt)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.needsSync)
      ..writeByte(16)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NonConformityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

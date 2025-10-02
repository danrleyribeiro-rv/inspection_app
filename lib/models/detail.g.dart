// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DetailAdapter extends TypeAdapter<Detail> {
  @override
  final typeId = 3;

  @override
  Detail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Detail(
      id: fields[0] as String?,
      inspectionId: fields[1] as String,
      topicId: fields[2] as String?,
      itemId: fields[3] as String?,
      detailId: fields[4] as String?,
      position: (fields[5] as num?)?.toInt(),
      orderIndex: (fields[6] as num?)?.toInt(),
      detailName: fields[7] as String,
      detailValue: fields[8] as String?,
      observation: fields[9] as String?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      type: fields[14] as String?,
      options: (fields[15] as List?)?.cast<String>(),
      allowCustomOption: fields[16] as bool?,
      customOptionValue: fields[17] as String?,
      status: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Detail obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.orderIndex)
      ..writeByte(7)
      ..write(obj.detailName)
      ..writeByte(8)
      ..write(obj.detailValue)
      ..writeByte(9)
      ..write(obj.observation)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.type)
      ..writeByte(15)
      ..write(obj.options)
      ..writeByte(16)
      ..write(obj.allowCustomOption)
      ..writeByte(17)
      ..write(obj.customOptionValue)
      ..writeByte(18)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 2;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String?,
      inspectionId: fields[1] as String,
      topicId: fields[2] as String?,
      itemId: fields[3] as String?,
      position: fields[4] as int,
      orderIndex: fields[5] as int?,
      itemName: fields[6] as String,
      itemLabel: fields[7] as String?,
      description: fields[8] as String?,
      evaluable: fields[9] as bool?,
      evaluationOptions: (fields[10] as List?)?.cast<String>(),
      evaluationValue: fields[11] as String?,
      evaluation: fields[12] as String?,
      observation: fields[13] as String?,
      isDamaged: fields[14] as bool?,
      tags: (fields[15] as List?)?.cast<String>(),
      createdAt: fields[16] as DateTime?,
      updatedAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.topicId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.position)
      ..writeByte(5)
      ..write(obj.orderIndex)
      ..writeByte(6)
      ..write(obj.itemName)
      ..writeByte(7)
      ..write(obj.itemLabel)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.evaluable)
      ..writeByte(10)
      ..write(obj.evaluationOptions)
      ..writeByte(11)
      ..write(obj.evaluationValue)
      ..writeByte(12)
      ..write(obj.evaluation)
      ..writeByte(13)
      ..write(obj.observation)
      ..writeByte(14)
      ..write(obj.isDamaged)
      ..writeByte(15)
      ..write(obj.tags)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

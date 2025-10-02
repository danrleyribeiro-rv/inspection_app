// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TopicAdapter extends TypeAdapter<Topic> {
  @override
  final typeId = 1;

  @override
  Topic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Topic(
      id: fields[0] as String?,
      inspectionId: fields[1] as String,
      position: (fields[2] as num).toInt(),
      orderIndex: (fields[3] as num?)?.toInt(),
      topicName: fields[4] as String,
      topicLabel: fields[5] as String?,
      description: fields[6] as String?,
      directDetails: fields[7] as bool?,
      observation: fields[8] as String?,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Topic obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.orderIndex)
      ..writeByte(4)
      ..write(obj.topicName)
      ..writeByte(5)
      ..write(obj.topicLabel)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.directDetails)
      ..writeByte(8)
      ..write(obj.observation)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

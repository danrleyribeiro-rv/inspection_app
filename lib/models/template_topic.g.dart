// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_topic.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateTopicAdapter extends TypeAdapter<TemplateTopic> {
  @override
  final typeId = 20;

  @override
  TemplateTopic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateTopic(
      id: fields[0] as String,
      templateId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String?,
      directDetails: fields[4] == null ? false : fields[4] as bool,
      observation: fields[5] as String?,
      position: (fields[6] as num).toInt(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateTopic obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.templateId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.directDetails)
      ..writeByte(5)
      ..write(obj.observation)
      ..writeByte(6)
      ..write(obj.position)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateTopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateItemAdapter extends TypeAdapter<TemplateItem> {
  @override
  final typeId = 21;

  @override
  TemplateItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateItem(
      id: fields[0] as String,
      topicId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String?,
      evaluable: fields[4] == null ? false : fields[4] as bool,
      evaluationOptions: (fields[5] as List?)?.cast<String>(),
      position: (fields[6] as num).toInt(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.evaluable)
      ..writeByte(5)
      ..write(obj.evaluationOptions)
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
      other is TemplateItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

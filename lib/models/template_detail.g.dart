// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_detail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateDetailAdapter extends TypeAdapter<TemplateDetail> {
  @override
  final typeId = 22;

  @override
  TemplateDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateDetail(
      id: fields[0] as String,
      topicId: fields[1] as String,
      itemId: fields[2] as String?,
      name: fields[3] as String,
      type: fields[4] == null ? 'text' : fields[4] as String,
      options: (fields[5] as List?)?.cast<String>(),
      required: fields[6] == null ? false : fields[6] as bool,
      position: (fields[7] as num).toInt(),
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateDetail obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.options)
      ..writeByte(6)
      ..write(obj.required)
      ..writeByte(7)
      ..write(obj.position)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

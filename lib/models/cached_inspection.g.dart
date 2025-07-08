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
      data: (fields[1] as Map).cast<String, dynamic>(),
      lastUpdated: fields[2] as DateTime,
      needsSync: fields[3] as bool,
      localStatus: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CachedInspection obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.data)
      ..writeByte(2)
      ..write(obj.lastUpdated)
      ..writeByte(3)
      ..write(obj.needsSync)
      ..writeByte(4)
      ..write(obj.localStatus);
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

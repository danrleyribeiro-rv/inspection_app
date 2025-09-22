// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueAdapter extends TypeAdapter<SyncQueue> {
  @override
  final int typeId = 9;

  @override
  SyncQueue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueue(
      id: fields[0] as int?,
      entityType: fields[1] as String,
      entityId: fields[2] as String,
      action: fields[3] as String,
      data: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      attempts: fields[6] as int,
      lastAttemptAt: fields[7] as DateTime?,
      errorMessage: fields[8] as String?,
      isProcessed: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueue obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityType)
      ..writeByte(2)
      ..write(obj.entityId)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.data)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.attempts)
      ..writeByte(7)
      ..write(obj.lastAttemptAt)
      ..writeByte(8)
      ..write(obj.errorMessage)
      ..writeByte(9)
      ..write(obj.isProcessed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

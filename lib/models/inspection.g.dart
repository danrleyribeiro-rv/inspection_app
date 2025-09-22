// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InspectionAdapter extends TypeAdapter<Inspection> {
  @override
  final int typeId = 0;

  @override
  Inspection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Inspection(
      id: fields[0] as String,
      title: fields[1] as String,
      cod: fields[2] as String?,
      street: fields[3] as String?,
      neighborhood: fields[4] as String?,
      city: fields[5] as String?,
      state: fields[6] as String?,
      zipCode: fields[7] as String?,
      addressString: fields[8] as String?,
      address: (fields[9] as Map?)?.cast<String, dynamic>(),
      status: fields[10] as String,
      observation: fields[11] as String?,
      scheduledDate: fields[12] as DateTime?,
      finishedAt: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
      projectId: fields[16] as String?,
      inspectorId: fields[17] as String?,
      isTemplated: fields[18] as bool,
      templateId: fields[19] as String?,
      isSynced: fields[20] as bool,
      lastSyncAt: fields[21] as DateTime?,
      hasLocalChanges: fields[22] as bool,
      topics: (fields[23] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      needsSync: fields[24] as bool,
      syncHistory: (fields[25] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      area: fields[26] as String?,
      deletedAt: fields[27] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Inspection obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.cod)
      ..writeByte(3)
      ..write(obj.street)
      ..writeByte(4)
      ..write(obj.neighborhood)
      ..writeByte(5)
      ..write(obj.city)
      ..writeByte(6)
      ..write(obj.state)
      ..writeByte(7)
      ..write(obj.zipCode)
      ..writeByte(8)
      ..write(obj.addressString)
      ..writeByte(9)
      ..write(obj.address)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.observation)
      ..writeByte(12)
      ..write(obj.scheduledDate)
      ..writeByte(13)
      ..write(obj.finishedAt)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt)
      ..writeByte(16)
      ..write(obj.projectId)
      ..writeByte(17)
      ..write(obj.inspectorId)
      ..writeByte(18)
      ..write(obj.isTemplated)
      ..writeByte(19)
      ..write(obj.templateId)
      ..writeByte(20)
      ..write(obj.isSynced)
      ..writeByte(21)
      ..write(obj.lastSyncAt)
      ..writeByte(22)
      ..write(obj.hasLocalChanges)
      ..writeByte(23)
      ..write(obj.topics)
      ..writeByte(24)
      ..write(obj.needsSync)
      ..writeByte(25)
      ..write(obj.syncHistory)
      ..writeByte(26)
      ..write(obj.area)
      ..writeByte(27)
      ..write(obj.deletedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

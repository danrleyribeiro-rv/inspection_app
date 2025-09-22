// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InspectionHistoryAdapter extends TypeAdapter<InspectionHistory> {
  @override
  final int typeId = 7;

  @override
  InspectionHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InspectionHistory(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      date: fields[2] as DateTime,
      status: fields[3] as HistoryStatus,
      inspectorId: fields[4] as String,
      description: fields[5] as String?,
      metadata: (fields[6] as Map?)?.cast<String, dynamic>(),
      createdAt: fields[7] as DateTime,
      needsSync: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, InspectionHistory obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.inspectorId)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.metadata)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HistoryStatusAdapter extends TypeAdapter<HistoryStatus> {
  @override
  final int typeId = 6;

  @override
  HistoryStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HistoryStatus.downloadedInspection;
      case 1:
        return HistoryStatus.uploadedInspection;
      case 2:
        return HistoryStatus.createdInspection;
      case 3:
        return HistoryStatus.updatedInspection;
      case 4:
        return HistoryStatus.completedInspection;
      case 5:
        return HistoryStatus.mediaUploaded;
      case 6:
        return HistoryStatus.conflictDetected;
      case 7:
        return HistoryStatus.conflictResolved;
      default:
        return HistoryStatus.downloadedInspection;
    }
  }

  @override
  void write(BinaryWriter writer, HistoryStatus obj) {
    switch (obj) {
      case HistoryStatus.downloadedInspection:
        writer.writeByte(0);
        break;
      case HistoryStatus.uploadedInspection:
        writer.writeByte(1);
        break;
      case HistoryStatus.createdInspection:
        writer.writeByte(2);
        break;
      case HistoryStatus.updatedInspection:
        writer.writeByte(3);
        break;
      case HistoryStatus.completedInspection:
        writer.writeByte(4);
        break;
      case HistoryStatus.mediaUploaded:
        writer.writeByte(5);
        break;
      case HistoryStatus.conflictDetected:
        writer.writeByte(6);
        break;
      case HistoryStatus.conflictResolved:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// lib/models/model_extensions.dart
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';


extension InspectionExtension on Inspection {
  // Convert to a map that can be stored in Hive
  Map<String, dynamic> toHiveMap() {
    final map = toJson();
    
    // Convert DateTime objects to strings
    if (scheduledDate != null) map['scheduled_date'] = scheduledDate!.toIso8601String();
    if (finishedAt != null) map['finished_at'] = finishedAt!.toIso8601String();
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (deletedAt != null) map['deleted_at'] = deletedAt!.toIso8601String();
    
    return map;
  }
  
  // Create a copy with updated fields
  Inspection copyWith({
    int? id,
    String? title,
    String? observation,
    String? cep,
    String? street,
    String? number,
    String? neighborhood,
    String? state,
    String? city,
    int? templateId,
    String? inspectorId,
    String? status,
    DateTime? scheduledDate,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? projectId,
  }) {
    return Inspection(
      id: id ?? this.id,
      title: title ?? this.title,
      observation: observation ?? this.observation,
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      neighborhood: neighborhood ?? this.neighborhood,
      state: state ?? this.state,
      city: city ?? this.city,
      templateId: templateId ?? this.templateId,
      inspectorId: inspectorId ?? this.inspectorId,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: projectId ?? this.projectId,
    );
  }
  
  // Check if inspection data is complete
  bool get isComplete => status == 'completed';
  
  // Check if inspection is in progress
  bool get isInProgress => status == 'in_progress';
  
  // Check if inspection is pending
  bool get isPending => status == 'pending';
}

extension RoomExtension on Room {
  // Convert to a map that can be stored in Hive
  Map<String, dynamic> toHiveMap() {
    final map = toJson();
    
    // Convert DateTime objects to strings
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    
    return map;
  }
  
  // Create a copy with updated fields
  Room copyWith({
    int? id,
    int? inspectionId,
    int? roomId,
    int? position,
    String? roomName,
    String? roomLabel,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      roomId: roomId ?? this.roomId,
      position: position ?? this.position,
      roomName: roomName ?? this.roomName,
      roomLabel: roomLabel ?? this.roomLabel,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // Check if data is filled
  bool get isDataFilled => 
    observation != null && observation!.isNotEmpty;
}

extension ItemExtension on Item {
  // Convert to a map that can be stored in Hive
  Map<String, dynamic> toHiveMap() {
    final map = toJson();
    
    // Convert DateTime objects to strings
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    
    return map;
  }
  
  // Create a copy with updated fields
  Item copyWith({
    int? id,
    int? inspectionId,
    int? roomId,
    int? itemId,
    int? position,
    String? itemName,
    String? itemLabel,
    String? evaluation,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      roomId: roomId ?? this.roomId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      itemName: itemName ?? this.itemName,
      itemLabel: itemLabel ?? this.itemLabel,
      evaluation: evaluation ?? this.evaluation,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // Check if data is filled
  bool get isDataFilled => 
    (evaluation != null && evaluation!.isNotEmpty) || 
    (observation != null && observation!.isNotEmpty);
}

extension DetailExtension on Detail {
  // Convert to a map that can be stored in Hive
  Map<String, dynamic> toHiveMap() {
    final map = toJson();
    
    // Convert DateTime objects to strings
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    
    return map;
  }
  
  // Create a copy with updated fields
  Detail copyWith({
    int? id,
    int? inspectionId,
    int? roomId,
    int? itemId,
    int? detailId,
    int? position,
    String? detailName,
    String? detailValue,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Detail(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      roomId: roomId ?? this.roomId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      position: position ?? this.position,
      detailName: detailName ?? this.detailName,
      detailValue: detailValue ?? this.detailValue,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // Check if data is filled
  bool get isDataFilled => 
    (detailValue != null && detailValue!.isNotEmpty) || 
    (observation != null && observation!.isNotEmpty);
}
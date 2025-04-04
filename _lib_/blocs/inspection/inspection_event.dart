// lib/blocs/inspection/inspection_event.dart
import 'package:equatable/equatable.dart';
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/data/models/detail.dart';

abstract class InspectionEvent extends Equatable {
  const InspectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadInspection extends InspectionEvent {
  final int inspectionId;

  const LoadInspection(this.inspectionId);

  @override
  List<Object> get props => [inspectionId];
}

class SyncInspection extends InspectionEvent {
  final int inspectionId;
  final bool showSuccess;

  const SyncInspection(this.inspectionId, {this.showSuccess = true});

  @override
  List<Object> get props => [inspectionId, showSuccess];
}

class AddRoom extends InspectionEvent {
  final int inspectionId;
  final String roomName;
  final String? roomLabel;

  const AddRoom(this.inspectionId, this.roomName, {this.roomLabel});

  @override
  List<Object?> get props => [inspectionId, roomName, roomLabel];
}

class UpdateRoom extends InspectionEvent {
  final Room room;

  const UpdateRoom(this.room);

  @override
  List<Object> get props => [room];
}

class DeleteRoom extends InspectionEvent {
  final int inspectionId;
  final int roomId;

  const DeleteRoom(this.inspectionId, this.roomId);

  @override
  List<Object> get props => [inspectionId, roomId];
}

class AddItem extends InspectionEvent {
  final int inspectionId;
  final int roomId;
  final String itemName;
  final String? itemLabel;

  const AddItem(this.inspectionId, this.roomId, this.itemName, {this.itemLabel});

  @override
  List<Object?> get props => [inspectionId, roomId, itemName, itemLabel];
}

class UpdateItem extends InspectionEvent {
  final Item item;

  const UpdateItem(this.item);

  @override
  List<Object> get props => [item];
}

class DeleteItem extends InspectionEvent {
  final int inspectionId;
  final int roomId;
  final int itemId;

  const DeleteItem(this.inspectionId, this.roomId, this.itemId);

  @override
  List<Object> get props => [inspectionId, roomId, itemId];
}

class AddDetail extends InspectionEvent {
  final int inspectionId;
  final int roomId;
  final int itemId;
  final String detailName;
  final String? detailValue;

  const AddDetail(this.inspectionId, this.roomId, this.itemId, this.detailName, {this.detailValue});

  @override
  List<Object?> get props => [inspectionId, roomId, itemId, detailName, detailValue];
}

class UpdateDetail extends InspectionEvent {
  final Detail detail;

  const UpdateDetail(this.detail);

  @override
  List<Object> get props => [detail];
}

class DeleteDetail extends InspectionEvent {
  final int inspectionId;
  final int roomId;
  final int itemId;
  final int detailId;

  const DeleteDetail(this.inspectionId, this.roomId, this.itemId, this.detailId);

  @override
  List<Object> get props => [inspectionId, roomId, itemId, detailId];
}

class CompleteInspection extends InspectionEvent {
  final int inspectionId;

  const CompleteInspection(this.inspectionId);

  @override
  List<Object> get props => [inspectionId];
}

class SaveInspection extends InspectionEvent {
  final int inspectionId;

  const SaveInspection(this.inspectionId);

  @override
  List<Object> get props => [inspectionId];
}

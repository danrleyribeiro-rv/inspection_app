// lib/data/repositories/inspection_repository.dart
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/data/models/detail.dart';

abstract class InspectionRepository {
  // Inspection methods
  Future<Inspection?> getInspection(int id);
  Future<List<Inspection>> getAllInspections();
  Future<void> saveInspection(Inspection inspection, {bool syncNow = true});
  Future<bool> downloadInspection(int id);
  Future<bool> syncInspection(int id);
  Future<void> syncAllPending();
  Future<double> calculateCompletionPercentage(int inspectionId);

  // Room methods
  Future<List<Room>> getRooms(int inspectionId);
  Future<Room> addRoom(int inspectionId, String name, {String? label, int? position});
  Future<void> updateRoom(Room room);
  Future<void> deleteRoom(int inspectionId, int roomId);

  // Item methods
  Future<List<Item>> getItems(int inspectionId, int roomId);
  Future<Item> addItem(int inspectionId, int roomId, String name, {String? label, int? position});
  Future<void> updateItem(Item item);
  Future<void> deleteItem(int inspectionId, int roomId, int itemId);

  // Detail methods
  Future<List<Detail>> getDetails(int inspectionId, int roomId, int itemId);
  Future<Detail> addDetail(int inspectionId, int roomId, int itemId, String name, {String? value, int? position});
  Future<void> updateDetail(Detail detail);
  Future<void> deleteDetail(int inspectionId, int roomId, int itemId, int detailId);
}
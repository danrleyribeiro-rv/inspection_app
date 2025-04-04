// lib/data/repositories/inspection_repository_impl.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/data/models/detail.dart';
import 'package:inspection_app/data/repositories/inspection_repository.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:inspection_app/services/sync_service.dart';

class InspectionRepositoryImpl implements InspectionRepository {
  final LocalDatabaseService _localDatabaseService;
  final SyncService _syncService;

  InspectionRepositoryImpl({
    required LocalDatabaseService localDatabaseService,
    required SyncService syncService,
  })  : _localDatabaseService = localDatabaseService,
        _syncService = syncService;

  @override
  Future<Inspection?> getInspection(int id) async {
    return await _localDatabaseService.getInspection(id);
  }

  @override
  Future<List<Inspection>> getAllInspections() async {
    return await _localDatabaseService.getAllInspections();
  }

  @override
  Future<void> saveInspection(Inspection inspection, {bool syncNow = true}) async {
    await _localDatabaseService.saveInspection(inspection);
    
    if (syncNow) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await _syncService.uploadInspection(inspection);
      }
    }
  }

  @override
  Future<bool> downloadInspection(int id) async {
    return await _syncService.downloadInspection(id);
  }

  @override
  Future<bool> syncInspection(int id) async {
    final inspection = await _localDatabaseService.getInspection(id);
    if (inspection == null) return false;
    
    return await _syncService.uploadInspection(inspection);
  }

  @override
  Future<void> syncAllPending() async {
    await _syncService.syncAllPendingInspections();
  }

  @override
  Future<double> calculateCompletionPercentage(int inspectionId) async {
    // Optimized calculation logic
    final rooms = await getRooms(inspectionId);
    
    int totalDetails = 0;
    int filledDetails = 0;
    
    for (var room in rooms) {
      if (room.id == null) continue;
      
      final items = await getItems(inspectionId, room.id!);
      
      for (var item in items) {
        if (item.id == null || item.roomId == null) continue;
        
        final details = await getDetails(inspectionId, item.roomId!, item.id!);
        
        totalDetails += details.length;
        
        for (var detail in details) {
          if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
            filledDetails++;
          }
        }
      }
    }
    
    return totalDetails > 0 ? filledDetails / totalDetails : 0.0;
  }

  @override
  Future<List<Room>> getRooms(int inspectionId) async {
    try {
      final rooms = await _localDatabaseService.getRoomsByInspection(inspectionId);
      return rooms;
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  @override
  Future<Room> addRoom(int inspectionId, String name, {String? label, int? position}) async {
    final room = await _localDatabaseService.addRoom(
      inspectionId,
      name,
      label: label,
      position: position,
    );
    
    // Mark inspection as needing sync
    await _localDatabaseService.setSyncStatus(inspectionId, false);
    
    return room;
  }

  @override
  Future<void> updateRoom(Room room) async {
    await _localDatabaseService.saveRoom(room);
    await _localDatabaseService.setSyncStatus(room.inspectionId, false);
  }

  @override
  Future<void> deleteRoom(int inspectionId, int roomId) async {
    await _localDatabaseService.deleteRoom(inspectionId, roomId);
    await _localDatabaseService.setSyncStatus(inspectionId, false);
  }

  @override
  Future<List<Item>> getItems(int inspectionId, int roomId) async {
    try {
      return await _localDatabaseService.getItemsByRoom(inspectionId, roomId);
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

  @override
  Future<Item> addItem(int inspectionId, int roomId, String name, {String? label, int? position}) async {
    final item = await _localDatabaseService.addItem(
      inspectionId,
      roomId,
      name,
      label: label,
      position: position,
    );
    
    // Mark inspection as needing sync
    await _localDatabaseService.setSyncStatus(inspectionId, false);
    
    return item;
  }

  @override
  Future<void> updateItem(Item item) async {
    await _localDatabaseService.saveItem(item);
    await _localDatabaseService.setSyncStatus(item.inspectionId, false);
  }

  @override
  Future<void> deleteItem(int inspectionId, int roomId, int itemId) async {
    await _localDatabaseService.deleteItem(inspectionId, roomId, itemId);
    await _localDatabaseService.setSyncStatus(inspectionId, false);
  }

  @override
  Future<List<Detail>> getDetails(int inspectionId, int roomId, int itemId) async {
    try {
      return await _localDatabaseService.getDetailsByItem(inspectionId, roomId, itemId);
    } catch (e) {
      print('Error fetching details: $e');
      return [];
    }
  }

  @override
  Future<Detail> addDetail(int inspectionId, int roomId, int itemId, String name, {String? value, int? position}) async {
    final detail = await _localDatabaseService.addDetail(
      inspectionId,
      roomId,
      itemId,
      name,
      value: value,
      position: position,
    );
    
    // Mark inspection as needing sync
    await _localDatabaseService.setSyncStatus(inspectionId, false);
    
    return detail;
  }

  @override
  Future<void> updateDetail(Detail detail) async {
    await _localDatabaseService.saveDetail(detail);
    await _localDatabaseService.setSyncStatus(detail.inspectionId, false);
  }

  @override
  Future<void> deleteDetail(int inspectionId, int roomId, int itemId, int detailId) async {
    await _localDatabaseService.deleteDetail(inspectionId, roomId, itemId, detailId);
    await _localDatabaseService.setSyncStatus(inspectionId, false);
  }
}
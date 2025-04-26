// lib/services/import_export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImportExportService {
  final FirebaseInspectionService _inspectionService = FirebaseInspectionService();
  
  static final ImportExportService _instance = ImportExportService._internal();
  
  factory ImportExportService() {
    return _instance;
  }
  
  ImportExportService._internal();

  // Export inspection to JSON file
  Future<String> exportInspection(String inspectionId) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        // Get inspection
        final inspection = await _inspectionService.getInspection(inspectionId);
        if (inspection == null) {
          throw Exception('Inspection not found');
        }
        
        // Get rooms
        final rooms = await _inspectionService.getRooms(inspectionId);
        
        // Build complete data structure
        final exportData = {
          'inspection': inspection.toJson(),
          'rooms': [],
        };
        
        // Add rooms with their items and details
        for (var room in rooms) {
          if (room.id == null) continue;
          
          final items = await _inspectionService.getItems(inspectionId, room.id!);
          
          final Map<String, dynamic> roomData = {
            ...room.toJson(),
            'items': [],
          };
          
          for (var item in items) {
            if (item.id == null || item.roomId == null) continue;
            
            final details = await _inspectionService.getDetails(
              inspectionId, 
              item.roomId!, 
              item.id!,
            );
            
            final Map<String, dynamic> itemData = {
              ...item.toJson(),
              'details': details.map((detail) => detail.toJson()).toList(),
            };
            
            roomData['items']!.add(itemData);
          }
          
        (exportData['rooms'] as List).add(roomData);
        }
        
        // Get non-conformities
        final nonConformities = await _inspectionService.getNonConformitiesByInspection(inspectionId);
        exportData['non_conformities'] = nonConformities;
        
        // Format filename with date and inspection ID
        final now = DateTime.now();
        final formatter = DateFormat('yyyyMMdd_HHmmss');
        final formattedDate = formatter.format(now);
        final fileName = 'inspection_${inspectionId}_$formattedDate.json';
        
        // Get app documents directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath = path.join(directory.path, fileName);
        
        // Write to file
        final file = File(filePath);
        final jsonString = jsonEncode(exportData);
        await file.writeAsString(jsonString);
        
        return filePath;
      } else {
        throw Exception('Storage permission denied');
      }
    } catch (e) {
      print('Error exporting inspection: $e');
      rethrow;
    }
  }
  
  // Import inspection from JSON file
  Future<bool> importInspection(String inspectionId, String jsonData) async {
    try {
      // Parse JSON
      final Map<String, dynamic> importData = jsonDecode(jsonData);
      
      // Get existing inspection
      final inspection = await _inspectionService.getInspection(inspectionId);
      if (inspection == null) {
        throw Exception('Destination inspection not found');
      }
      
      // Process rooms
      final List<dynamic> roomsData = importData['rooms'] ?? [];
      
      for (var roomData in roomsData) {
        // Check if this is a valid room object
        if (!roomData.containsKey('room_name')) continue;
        
        // Get or create room
        final roomName = roomData['room_name'];
        
        // Check if room with this name exists
        final existingRooms = await _inspectionService.getRooms(inspectionId);
        bool roomExists = false;
        String? existingRoomId;
        
        for (var existing in existingRooms) {
          if (existing.roomName == roomName) {
            roomExists = true;
            existingRoomId = existing.id;
            break;
          }
        }
        
        late String roomId;
        
        if (roomExists && existingRoomId != null) {
          // Update existing room
          roomId = existingRoomId;
        } else {
          // Create new room
          final newRoom = await _inspectionService.addRoom(
            inspectionId,
            roomName,
            label: roomData['room_label'],
          );
          
          if (newRoom.id == null) {
            print('Failed to create room: $roomName');
            continue;
          }
          
          roomId = newRoom.id!;
        }
        
        // Process items for this room
        final List<dynamic> itemsData = roomData['items'] ?? [];
        
        for (var itemData in itemsData) {
          // Check if this is a valid item object
          if (!itemData.containsKey('item_name')) continue;
          
          // Get or create item
          final itemName = itemData['item_name'];
          
          // Check if item with this name exists in this room
          final existingItems = await _inspectionService.getItems(inspectionId, roomId);
          bool itemExists = false;
          String? existingItemId;
          
          for (var existing in existingItems) {
            if (existing.itemName == itemName) {
              itemExists = true;
              existingItemId = existing.id;
              break;
            }
          }
          
          late String itemId;
          
          if (itemExists && existingItemId != null) {
            // Use existing item
            itemId = existingItemId;
          } else {
            // Create new item
            final newItem = await _inspectionService.addItem(
              inspectionId,
              roomId,
              itemName,
              label: itemData['item_label'],
            );
            
            if (newItem.id == null) {
              print('Failed to create item: $itemName');
              continue;
            }
            
            itemId = newItem.id!;
          }
          
          // Process details for this item
          final List<dynamic> detailsData = itemData['details'] ?? [];
          
          for (var detailData in detailsData) {
            // Check if this is a valid detail object
            if (!detailData.containsKey('detail_name')) continue;
            
            // Get or create detail
            final detailName = detailData['detail_name'];
            final detailValue = detailData['detail_value'];
            
            // Check if detail with this name exists in this item
            final existingDetails = await _inspectionService.getDetails(inspectionId, roomId, itemId);
            bool detailExists = false;
            String? existingDetailId;
            
            for (var existing in existingDetails) {
              if (existing.detailName == detailName) {
                detailExists = true;
                existingDetailId = existing.id;
                break;
              }
            }
            
            if (detailExists && existingDetailId != null) {
              // Only update value if not already set
              final existingDetail = existingDetails.firstWhere(
                (detail) => detail.id == existingDetailId
              );
              
              if (existingDetail.detailValue == null || existingDetail.detailValue!.isEmpty) {
                await _inspectionService.updateDetail(existingDetail.copyWith(
                  detailValue: detailValue,
                  updatedAt: DateTime.now(),
                ));
              }
            } else {
              // Create new detail
              await _inspectionService.addDetail(
                inspectionId,
                roomId,
                itemId,
                detailName,
                value: detailValue,
              );
            }
          }
        }
      }
      
      return true;
    } catch (e) {
      print('Error importing inspection: $e');
      return false;
    }
  }
  
  // Show file picker dialog to select a JSON file for import
  Future<String?> pickJsonFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
      
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }
  
  // Show confirmation dialogs for import/export
  Future<bool> showExportConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Inspection'),
        content: const Text(
          'This will export all inspection data to a JSON file. '
          'The file will be saved to your device\'s documents folder. '
          '\n\nContinue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Export', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }
  
  Future<bool> showImportConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Inspection'),
        content: const Text(
          'This will import inspection data from a JSON file. '
          'Existing data will not be overwritten, only complemented. '
          '\n\nContinue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }
  
  // Show success or error messages
  void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
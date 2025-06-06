import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/services/core/firebase_service.dart';

class ImportExportService {
  final FirebaseService _firebase = FirebaseService();

  Future<String> exportInspection(String inspectionId) async {
    try {
      final inspection = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!inspection.exists) {
        throw Exception('Inspection not found');
      }

      Map<String, dynamic> inspectionData = inspection.data() ?? {};
      inspectionData['id'] = inspectionId;

      inspectionData = _convertTimestampsToStrings(inspectionData);

      final String jsonContent = json.encode(inspectionData);

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission not granted');
        }
      }

      final directory = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'inspection_${inspectionId}_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(jsonContent);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export inspection: $e');
    }
  }

  dynamic _convertTimestampsToStrings(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data.map(
          (key, value) => MapEntry(key, _convertTimestampsToStrings(value)));
    } else if (data is List) {
      return data.map((item) => _convertTimestampsToStrings(item)).toList();
    } else if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else {
      return data;
    }
  }

  Future<bool> importInspection(
      String inspectionId, Map<String, dynamic> jsonData) async {
    try {
      if (jsonData.isEmpty) {
        throw Exception('Invalid JSON data');
      }

      jsonData.remove('id');

      jsonData['updated_at'] = FieldValue.serverTimestamp();
      jsonData['imported_at'] = FieldValue.serverTimestamp();

      await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .set(jsonData, SetOptions(merge: false));

      return true;
    } catch (e) {
      throw Exception('Failed to import inspection: $e');
    }
  }

  Future<Map<String, dynamic>?> pickJsonFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      return json.decode(jsonString);
    } catch (e) {
      throw Exception('Failed to read JSON file: $e');
    }
  }

  Future<bool> showExportConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Inspection'),
            content: const Text(
                'This will export the inspection data to a JSON file. '
                'Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Export'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> showImportConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Inspection'),
            content: const Text(
                'This will replace all current inspection data with the imported data. '
                'This action cannot be undone. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
                child: const Text('Import'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

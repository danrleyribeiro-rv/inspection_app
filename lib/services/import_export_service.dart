import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class ImportExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // Export inspection to a JSON file
  Future<String> exportInspection(String inspectionId) async {
    try {
      // Get inspection document
      final inspection =
          await _firestore.collection('inspections').doc(inspectionId).get();

      if (!inspection.exists) {
        throw Exception('Inspection not found');
      }

      // Convert to JSON
      final Map<String, dynamic> inspectionData = inspection.data() ?? {};
      inspectionData['id'] = inspectionId;

      // Get all topics (topics)
      final topicsSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .get();

      List<Map<String, dynamic>> topicsData = [];

      // For each topic, get items and their details
      for (var topicDoc in topicsSnapshot.docs) {
        final topicId = topicDoc.id;
        final topicData = topicDoc.data();

        // Get all items for this topic
        final itemsSnapshot = await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .get();

        List<Map<String, dynamic>> itemsData = [];

        // For each item, get details
        for (var itemDoc in itemsSnapshot.docs) {
          final itemId = itemDoc.id;
          final itemData = itemDoc.data();

          // Get all details for this item
          final detailsSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .get();

          List<Map<String, dynamic>> detailsData = [];

          // For each detail, get media and non-conformities
          for (var detailDoc in detailsSnapshot.docs) {
            final detailId = detailDoc.id;
            final detailData = detailDoc.data();

            // Get all media for this detail
            final mediaSnapshot = await _firestore
                .collection('inspections')
                .doc(inspectionId)
                .collection('topics')
                .doc(topicId)
                .collection('topic_items')
                .doc(itemId)
                .collection('item_details')
                .doc(detailId)
                .collection('media')
                .get();

            List<Map<String, dynamic>> mediaData = [];

            for (var mediaDoc in mediaSnapshot.docs) {
              mediaData.add({
                'id': mediaDoc.id,
                ...mediaDoc.data(),
              });
            }

            // Get all non-conformities for this detail
            final ncSnapshot = await _firestore
                .collection('inspections')
                .doc(inspectionId)
                .collection('topics')
                .doc(topicId)
                .collection('topic_items')
                .doc(itemId)
                .collection('item_details')
                .doc(detailId)
                .collection('non_conformities')
                .get();

            List<Map<String, dynamic>> ncData = [];

            // For each non-conformity, get media
            for (var ncDoc in ncSnapshot.docs) {
              final ncId = ncDoc.id;
              final nonConformityData = ncDoc.data();

              // Get all media for this non-conformity
              final ncMediaSnapshot = await _firestore
                  .collection('inspections')
                  .doc(inspectionId)
                  .collection('topics')
                  .doc(topicId)
                  .collection('topic_items')
                  .doc(itemId)
                  .collection('item_details')
                  .doc(detailId)
                  .collection('non_conformities')
                  .doc(ncId)
                  .collection('nc_media')
                  .get();

              List<Map<String, dynamic>> ncMediaData = [];

              for (var ncMediaDoc in ncMediaSnapshot.docs) {
                ncMediaData.add({
                  'id': ncMediaDoc.id,
                  ...ncMediaDoc.data(),
                });
              }

              // Add media to non-conformity
              ncData.add({
                'id': ncId,
                ...nonConformityData,
                'media': ncMediaData,
              });
            }

            // Add media and non-conformities to detail
            detailsData.add({
              'id': detailId,
              ...detailData,
              'media': mediaData,
              'non_conformities': ncData,
            });
          }

          // Add details to item
          itemsData.add({
            'id': itemId,
            ...itemData,
            'details': detailsData,
          });
        }

        // Add items to topic
        topicsData.add({
          'id': topicId,
          ...topicData,
          'items': itemsData,
        });
      }

      // Add topics to inspection data
      inspectionData['topics'] = topicsData;

      final String jsonContent = json.encode(inspectionData);

      // Get storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission not granted');
        }
      }

      // Get directory for saving file
      final directory = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

      // Format the timestamp for the filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // Generate a filename
      final fileName = 'inspection_${inspectionId}_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonContent);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export inspection: $e');
    }
  }

  // Import inspection from a JSON file
  Future<bool> importInspection(
      String inspectionId, Map<String, dynamic> jsonData) async {
    try {
      // Validate the data
      if (jsonData.isEmpty) {
        throw Exception('Invalid JSON data');
      }

      final topicsData = jsonData['topics'] as List<dynamic>? ?? [];

      // Remove topics, ID, and other metadata from jsonData
      jsonData.remove('id');
      jsonData.remove('topics');

      // Update the timestamp
      jsonData['updated_at'] = FieldValue.serverTimestamp();
      jsonData['imported_at'] = FieldValue.serverTimestamp();

      // Start a batch operation
      WriteBatch batch = _firestore.batch();

      // Update the inspection document
      batch.set(
        _firestore.collection('inspections').doc(inspectionId),
        jsonData,
        SetOptions(merge: true),
      );

      // Process all topics
      for (var topicData in topicsData) {
        final topicId = topicData['id'];
        final topicRef = _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId);

        // Remove nested data and ID
        final cleanTopicData = Map<String, dynamic>.from(topicData);
        cleanTopicData.remove('id');
        cleanTopicData.remove('items');

        // Set topic data
        batch.set(topicRef, cleanTopicData, SetOptions(merge: true));

        // Process all items for this topic
        final itemsData = topicData['items'] as List<dynamic>? ?? [];

        for (var itemData in itemsData) {
          final itemId = itemData['id'];
          final itemRef = topicRef.collection('topic_items').doc(itemId);

          // Remove nested data and ID
          final cleanItemData = Map<String, dynamic>.from(itemData);
          cleanItemData.remove('id');
          cleanItemData.remove('details');

          // Set item data
          batch.set(itemRef, cleanItemData, SetOptions(merge: true));

          // Process all details for this item
          final detailsData = itemData['details'] as List<dynamic>? ?? [];

          for (var detailData in detailsData) {
            final detailId = detailData['id'];
            final detailRef = itemRef.collection('item_details').doc(detailId);

            // Remove nested data and ID
            final cleanDetailData = Map<String, dynamic>.from(detailData);
            cleanDetailData.remove('id');
            cleanDetailData.remove('media');
            cleanDetailData.remove('non_conformities');

            // Set detail data
            batch.set(detailRef, cleanDetailData, SetOptions(merge: true));

            // Process all media for this detail
            final mediaData = detailData['media'] as List<dynamic>? ?? [];

            for (var media in mediaData) {
              final mediaId = media['id'];
              final mediaRef = detailRef.collection('media').doc(mediaId);

              // Remove ID
              final cleanMediaData = Map<String, dynamic>.from(media);
              cleanMediaData.remove('id');

              // Set media data
              batch.set(mediaRef, cleanMediaData, SetOptions(merge: true));
            }

            // Process all non-conformities for this detail
            final ncData =
                detailData['non_conformities'] as List<dynamic>? ?? [];

            for (var nc in ncData) {
              final ncId = nc['id'];
              final ncRef = detailRef.collection('non_conformities').doc(ncId);

              // Remove nested data and ID
              final cleanNcData = Map<String, dynamic>.from(nc);
              cleanNcData.remove('id');
              cleanNcData.remove('media');

              // Set non-conformity data
              batch.set(ncRef, cleanNcData, SetOptions(merge: true));

              // Process all media for this non-conformity
              final ncMediaData = nc['media'] as List<dynamic>? ?? [];

              for (var ncMedia in ncMediaData) {
                final ncMediaId = ncMedia['id'];
                final ncMediaRef = ncRef.collection('nc_media').doc(ncMediaId);

                // Remove ID
                final cleanNcMediaData = Map<String, dynamic>.from(ncMedia);
                cleanNcMediaData.remove('id');

                // Set non-conformity media data
                batch.set(
                    ncMediaRef, cleanNcMediaData, SetOptions(merge: true));
              }
            }
          }
        }
      }

      // Commit the batch
      await batch.commit();

      return true;
    } catch (e) {
      throw Exception('Failed to import inspection: $e');
    }
  }

  // Pick a JSON file and parse its contents
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

  // Show confirmation dialog before exporting
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

  // Show confirmation dialog before importing
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

  // Show success message
  void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Show error message
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

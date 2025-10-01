// lib/utils/inspection_json_converter.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/inspection.dart';
import '../models/topic.dart';
import '../models/item.dart';
import '../models/detail.dart';
import '../models/non_conformity.dart';
import '../models/offline_media.dart';
import '../storage/database_helper.dart';

/// Utility class for converting between Hive storage and nested JSON format
/// Used for: Export, Import, Sync Upload, Sync Download
class InspectionJsonConverter {
  /// Build nested JSON structure from Hive boxes for export/sync upload
  static Future<Map<String, dynamic>> toNestedJson(String inspectionId) async {
    // Get inspection
    final inspection = await DatabaseHelper.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    // Get all topics for this inspection
    final topics = await DatabaseHelper.getTopicsByInspection(inspectionId);

    // Get ALL non-conformities and media for this inspection
    final allNonConformities = await DatabaseHelper.getNonConformitiesByInspection(inspectionId);
    final allMedia = await DatabaseHelper.getOfflineMediaByInspection(inspectionId);

    // Build nested topics structure
    final topicsJson = <Map<String, dynamic>>[];

    for (final topic in topics) {
      // Get items for this topic
      final items = DatabaseHelper.items.values
          .where((item) => item.topicId == topic.id)
          .toList();

      // Build nested items structure
      final itemsJson = <Map<String, dynamic>>[];

      for (final item in items) {
        // Get details for this item
        final details = DatabaseHelper.details.values
            .where((detail) => detail.itemId == item.id)
            .toList();

        // Build nested details with their NCs and media
        final detailsJson = <Map<String, dynamic>>[];
        for (final detail in details) {
          final detailMap = detail.toJson();

          // Add NCs for this detail
          final detailNCs = allNonConformities.where((nc) => nc.detailId == detail.id).toList();
          if (detailNCs.isNotEmpty) {
            detailMap['non_conformities'] = await _buildNCsJson(detailNCs, allMedia);
          }

          // Add media for this detail
          final detailMedia = allMedia.where((m) =>
            m.detailId == detail.id && m.nonConformityId == null
          ).toList();
          if (detailMedia.isNotEmpty) {
            detailMap['media'] = detailMedia.map((m) => m.toJson()).toList();
          }

          detailsJson.add(detailMap);
        }

        // Build item JSON with nested details, NCs, and media
        final itemMap = item.toJson();
        if (detailsJson.isNotEmpty) {
          itemMap['details'] = detailsJson;
        }

        // Add NCs for this item (only those NOT in details)
        final itemNCs = allNonConformities.where((nc) =>
          nc.itemId == item.id && nc.detailId == null
        ).toList();
        if (itemNCs.isNotEmpty) {
          itemMap['non_conformities'] = await _buildNCsJson(itemNCs, allMedia);
        }

        // Add media for this item
        final itemMedia = allMedia.where((m) =>
          m.itemId == item.id && m.detailId == null && m.nonConformityId == null
        ).toList();
        if (itemMedia.isNotEmpty) {
          itemMap['media'] = itemMedia.map((m) => m.toJson()).toList();
        }

        itemsJson.add(itemMap);
      }

      // Get details directly under topic (for direct_details mode)
      final topicDetails = DatabaseHelper.details.values
          .where((detail) => detail.topicId == topic.id && detail.itemId == null)
          .toList();

      // Build direct details with their NCs and media
      final topicDetailsJson = <Map<String, dynamic>>[];
      for (final detail in topicDetails) {
        final detailMap = detail.toJson();

        // Add NCs for this direct detail
        final detailNCs = allNonConformities.where((nc) => nc.detailId == detail.id).toList();
        if (detailNCs.isNotEmpty) {
          detailMap['non_conformities'] = await _buildNCsJson(detailNCs, allMedia);
        }

        // Add media for this direct detail
        final detailMedia = allMedia.where((m) =>
          m.detailId == detail.id && m.nonConformityId == null
        ).toList();
        if (detailMedia.isNotEmpty) {
          detailMap['media'] = detailMedia.map((m) => m.toJson()).toList();
        }

        topicDetailsJson.add(detailMap);
      }

      // Build topic JSON with nested items, details, NCs, and media
      final topicMap = topic.toJson();
      if (itemsJson.isNotEmpty) {
        topicMap['items'] = itemsJson;
      }
      if (topicDetailsJson.isNotEmpty) {
        topicMap['details'] = topicDetailsJson;
      }

      // Add NCs for this topic (only those NOT in items/details)
      final topicNCs = allNonConformities.where((nc) =>
        nc.topicId == topic.id && nc.itemId == null && nc.detailId == null
      ).toList();
      if (topicNCs.isNotEmpty) {
        topicMap['non_conformities'] = await _buildNCsJson(topicNCs, allMedia);
      }

      // Add media for this topic
      final topicMedia = allMedia.where((m) =>
        m.topicId == topic.id && m.itemId == null && m.detailId == null && m.nonConformityId == null
      ).toList();
      if (topicMedia.isNotEmpty) {
        topicMap['media'] = topicMedia.map((m) => m.toJson()).toList();
      }

      topicsJson.add(topicMap);
    }

    // Get root-level non-conformities (no topic/item/detail)
    final rootNCs = allNonConformities.where((nc) =>
      nc.topicId == null && nc.itemId == null && nc.detailId == null
    ).toList();

    // Get root-level media (no topic/item/detail/NC)
    final rootMedia = allMedia.where((m) =>
      m.topicId == null && m.itemId == null && m.detailId == null && m.nonConformityId == null
    ).toList();

    // Build inspection JSON with nested structure
    final inspectionJson = inspection.toJson();
    if (topicsJson.isNotEmpty) {
      inspectionJson['topics'] = topicsJson;
    }
    if (rootNCs.isNotEmpty) {
      inspectionJson['non_conformities'] = await _buildNCsJson(rootNCs, allMedia);
    }
    if (rootMedia.isNotEmpty) {
      inspectionJson['media'] = rootMedia.map((m) => m.toJson()).toList();
    }

    return inspectionJson;
  }

  /// Helper to build NC JSON with separated regular and resolution media
  static Future<List<Map<String, dynamic>>> _buildNCsJson(
    List<NonConformity> ncs,
    List<OfflineMedia> allMedia,
  ) async {
    final ncsJson = <Map<String, dynamic>>[];

    for (final nc in ncs) {
      final ncMap = nc.toJson();

      // Separate regular media and resolution media
      final ncMedia = allMedia.where((m) => m.nonConformityId == nc.id).toList();
      final regularMedia = ncMedia.where((m) =>
        m.source != 'resolution_camera' && m.source != 'resolution_gallery'
      ).toList();
      final resolutionMedia = ncMedia.where((m) =>
        m.source == 'resolution_camera' || m.source == 'resolution_gallery'
      ).toList();

      if (regularMedia.isNotEmpty) {
        ncMap['media'] = regularMedia.map((m) => m.toJson()).toList();
      }
      if (resolutionMedia.isNotEmpty) {
        ncMap['solved_media'] = resolutionMedia.map((m) => m.toJson()).toList();
      }

      ncsJson.add(ncMap);
    }

    return ncsJson;
  }

  /// Parse nested JSON and populate all Hive boxes for import/sync download
  static Future<void> fromNestedJson(Map<String, dynamic> json) async {
    // Create inspection (without topics field)
    final inspection = Inspection.fromJson(json);
    await DatabaseHelper.insertInspection(inspection);

    final inspectionId = inspection.id;

    // Parse and store topics
    final topicsData = json['topics'] as List<dynamic>?;
    if (topicsData != null) {
      for (int topicIndex = 0; topicIndex < topicsData.length; topicIndex++) {
        final topicData = topicsData[topicIndex];
        final topicMap = Map<String, dynamic>.from(topicData as Map);

        // Add inspection_id and position to topic data
        topicMap['inspection_id'] = inspectionId;
        topicMap['position'] = topicMap['position'] ?? topicIndex;

        // Create topic
        final topic = Topic.fromJson(topicMap);
        await DatabaseHelper.insertTopic(topic);

        // Process topic-level media
        await _processMediaList(
          topicMap['media'] as List<dynamic>?,
          inspectionId,
          topicId: topic.id,
        );

        // Process topic-level non-conformities
        await _processNonConformitiesList(
          topicMap['non_conformities'] as List<dynamic>?,
          inspectionId,
          topicId: topic.id,
        );

        // Parse and store items
        final itemsData = topicMap['items'] as List<dynamic>?;
        if (itemsData != null) {
          for (int itemIndex = 0; itemIndex < itemsData.length; itemIndex++) {
            final itemData = itemsData[itemIndex];
            final itemMap = Map<String, dynamic>.from(itemData as Map);

            // Add relationship fields and position
            itemMap['inspection_id'] = inspectionId;
            itemMap['topic_id'] = topic.id;
            itemMap['position'] = itemMap['position'] ?? itemIndex;

            // Create item
            final item = Item.fromJson(itemMap);
            await DatabaseHelper.insertItem(item);

            // Process item-level media
            await _processMediaList(
              itemMap['media'] as List<dynamic>?,
              inspectionId,
              topicId: topic.id,
              itemId: item.id,
            );

            // Process item-level non-conformities
            await _processNonConformitiesList(
              itemMap['non_conformities'] as List<dynamic>?,
              inspectionId,
              topicId: topic.id,
              itemId: item.id,
            );

            // Parse and store details under item
            final detailsData = itemMap['details'] as List<dynamic>?;
            if (detailsData != null) {
              for (int detailIndex = 0; detailIndex < detailsData.length; detailIndex++) {
                final detailData = detailsData[detailIndex];
                final detailMap = Map<String, dynamic>.from(detailData as Map);

                // Add relationship fields and position
                detailMap['inspection_id'] = inspectionId;
                detailMap['topic_id'] = topic.id;
                detailMap['item_id'] = item.id;
                detailMap['position'] = detailMap['position'] ?? detailIndex;

                final detail = Detail.fromJson(detailMap);
                await DatabaseHelper.insertDetail(detail);

                // Process detail-level media
                await _processMediaList(
                  detailMap['media'] as List<dynamic>?,
                  inspectionId,
                  topicId: topic.id,
                  itemId: item.id,
                  detailId: detail.id,
                );

                // Process detail-level non-conformities
                await _processNonConformitiesList(
                  detailMap['non_conformities'] as List<dynamic>?,
                  inspectionId,
                  topicId: topic.id,
                  itemId: item.id,
                  detailId: detail.id,
                );
              }
            }
          }
        }

        // Parse and store details directly under topic (for direct_details mode)
        final topicDetailsData = topicMap['details'] as List<dynamic>?;
        if (topicDetailsData != null) {
          for (int detailIndex = 0; detailIndex < topicDetailsData.length; detailIndex++) {
            final detailData = topicDetailsData[detailIndex];
            final detailMap = Map<String, dynamic>.from(detailData as Map);

            // Add relationship fields and position (no item_id for direct details)
            detailMap['inspection_id'] = inspectionId;
            detailMap['topic_id'] = topic.id;
            detailMap['position'] = detailMap['position'] ?? detailIndex;

            final detail = Detail.fromJson(detailMap);
            await DatabaseHelper.insertDetail(detail);

            // Process direct detail-level media
            await _processMediaList(
              detailMap['media'] as List<dynamic>?,
              inspectionId,
              topicId: topic.id,
              detailId: detail.id,
            );

            // Process direct detail-level non-conformities
            await _processNonConformitiesList(
              detailMap['non_conformities'] as List<dynamic>?,
              inspectionId,
              topicId: topic.id,
              detailId: detail.id,
            );
          }
        }
      }
    }

    // Parse and store root-level non-conformities
    await _processNonConformitiesList(
      json['non_conformities'] as List<dynamic>?,
      inspectionId,
    );

    // Parse and store root-level media
    await _processMediaList(
      json['media'] as List<dynamic>?,
      inspectionId,
    );
  }

  /// Get complete inspection data with all relationships (for UI display)
  static Future<Map<String, dynamic>> getInspectionWithRelations(String inspectionId) async {
    final inspection = await DatabaseHelper.getInspection(inspectionId);
    if (inspection == null) {
      throw Exception('Inspection not found: $inspectionId');
    }

    final topics = await DatabaseHelper.getTopicsByInspection(inspectionId);
    final nonConformities = await DatabaseHelper.getNonConformitiesByInspection(inspectionId);
    final media = await DatabaseHelper.getOfflineMediaByInspection(inspectionId);

    return {
      'inspection': inspection,
      'topics': topics,
      'nonConformities': nonConformities,
      'media': media,
    };
  }

  /// Helper method to process media list at any hierarchical level
  static Future<void> _processMediaList(
    List<dynamic>? mediaList,
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    bool isResolutionMedia = false,
  }) async {
    if (mediaList == null || mediaList.isEmpty) return;

    for (final mediaItem in mediaList) {
      final mediaMap = Map<String, dynamic>.from(mediaItem as Map);

      // Normalize camelCase fields from Firestore to snake_case
      if (mediaMap.containsKey('cloudUrl') && !mediaMap.containsKey('cloud_url')) {
        mediaMap['cloud_url'] = mediaMap['cloudUrl'];
      }
      if (mediaMap.containsKey('localPath') && !mediaMap.containsKey('local_path')) {
        mediaMap['local_path'] = mediaMap['localPath'];
      }
      if (mediaMap.containsKey('isResolutionMedia') && !mediaMap.containsKey('is_resolution_media')) {
        mediaMap['is_resolution_media'] = mediaMap['isResolutionMedia'];
      }

      // Add relationship fields
      mediaMap['inspection_id'] = mediaMap['inspection_id'] ?? inspectionId;
      if (topicId != null) mediaMap['topic_id'] = mediaMap['topic_id'] ?? topicId;
      if (itemId != null) mediaMap['item_id'] = mediaMap['item_id'] ?? itemId;
      if (detailId != null) mediaMap['detail_id'] = mediaMap['detail_id'] ?? detailId;
      if (nonConformityId != null) mediaMap['non_conformity_id'] = mediaMap['non_conformity_id'] ?? nonConformityId;

      // Mark as resolution media if from solved_media array (takes precedence)
      if (isResolutionMedia) {
        mediaMap['is_resolution_media'] = true;
      }

      final media = OfflineMedia.fromJson(mediaMap);

      // Check if media with this ID already exists to avoid duplicates
      final existingMedia = await DatabaseHelper.getOfflineMedia(media.id);
      if (existingMedia == null) {
        // Only insert if doesn't exist
        await DatabaseHelper.insertOfflineMedia(media);
      }
      // If exists, skip it to avoid duplicates (first occurrence wins)
    }
  }

  /// Helper method to process non-conformities list at any hierarchical level
  static Future<void> _processNonConformitiesList(
    List<dynamic>? ncList,
    String inspectionId, {
    String? topicId,
    String? itemId,
    String? detailId,
  }) async {
    if (ncList == null || ncList.isEmpty) return;

    for (final ncData in ncList) {
      final ncMap = Map<String, dynamic>.from(ncData as Map);
      final ncId = ncMap['id'];

      debugPrint('📥 Processing NC $ncId at level - Topic: $topicId, Item: $itemId, Detail: $detailId');

      // Check if this NC already exists - skip duplicates
      final existingNc = await DatabaseHelper.getNonConformity(ncId);
      if (existingNc != null) {
        debugPrint('⚠️ NC $ncId already exists - SKIPPING to avoid duplicates');
        continue; // Skip this NC and continue with next one
      }

      // IMPORTANT: Override relationship fields with context values
      // This ensures NCs are placed at the correct hierarchical level
      ncMap['inspection_id'] = inspectionId;
      ncMap['topic_id'] = topicId;
      ncMap['item_id'] = itemId;
      ncMap['detail_id'] = detailId;

      final nonConformity = NonConformity.fromJson(ncMap);
      await DatabaseHelper.insertNonConformity(nonConformity);
      debugPrint('✅ Inserted NC $ncId');

      // Process media for this non-conformity (both regular and resolution media)
      final regularMediaList = ncMap['media'] as List<dynamic>?;
      final solvedMediaList = ncMap['solved_media'] as List<dynamic>?;

      debugPrint('   Regular media count: ${regularMediaList?.length ?? 0}');
      debugPrint('   Resolution media count: ${solvedMediaList?.length ?? 0}');

      await _processMediaList(
        regularMediaList,
        inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformity.id,
      );

      await _processMediaList(
        solvedMediaList,
        inspectionId,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformity.id,
        isResolutionMedia: true,
      );
    }
  }

  /// Delete inspection and all related data from Hive boxes
  static Future<void> deleteInspectionWithRelations(String inspectionId) async {
    // Delete all topics and their items/details
    final topics = await DatabaseHelper.getTopicsByInspection(inspectionId);
    for (final topic in topics) {
      // Delete items and their details
      final items = DatabaseHelper.items.values
          .where((item) => item.topicId == topic.id)
          .toList();
      for (final item in items) {
        // Delete details
        final details = DatabaseHelper.details.values
            .where((detail) => detail.itemId == item.id)
            .toList();
        for (final detail in details) {
          await DatabaseHelper.deleteDetail(detail.id);
        }
        await DatabaseHelper.deleteItem(item.id);
      }

      // Delete topic details
      final topicDetails = DatabaseHelper.details.values
          .where((detail) => detail.topicId == topic.id && detail.itemId == null)
          .toList();
      for (final detail in topicDetails) {
        await DatabaseHelper.deleteDetail(detail.id);
      }

      await DatabaseHelper.deleteTopic(topic.id);
    }

    // Delete non-conformities
    final nonConformities = await DatabaseHelper.getNonConformitiesByInspection(inspectionId);
    for (final nc in nonConformities) {
      await DatabaseHelper.deleteNonConformity(nc.id);
    }

    // Delete media files and records (including physical files)
    await _deleteInspectionMedia(inspectionId);

    // Delete inspection
    await DatabaseHelper.deleteInspection(inspectionId);
  }

  /// Delete all media files (physical files and records) for an inspection
  static Future<void> _deleteInspectionMedia(String inspectionId) async {
    try {
      final mediaList = await DatabaseHelper.getOfflineMediaByInspection(inspectionId);

      for (final media in mediaList) {
        // Delete physical file if exists
        if (media.localPath.isNotEmpty) {
          try {
            final file = File(media.localPath);
            if (await file.exists()) {
              await file.delete();
              debugPrint('InspectionJsonConverter: Deleted media file: ${media.filename}');
            }
          } catch (e) {
            debugPrint('InspectionJsonConverter: Error deleting media file ${media.filename}: $e');
          }
        }

        // Delete thumbnail if exists
        if (media.thumbnailPath != null && media.thumbnailPath!.isNotEmpty) {
          try {
            final thumbFile = File(media.thumbnailPath!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          } catch (e) {
            debugPrint('InspectionJsonConverter: Error deleting thumbnail ${media.filename}: $e');
          }
        }

        // Delete media record from database
        await DatabaseHelper.deleteOfflineMedia(media.id);
      }

      debugPrint('InspectionJsonConverter: Deleted ${mediaList.length} media files for inspection $inspectionId');
    } catch (e) {
      debugPrint('InspectionJsonConverter: Error deleting inspection media: $e');
    }
  }
}

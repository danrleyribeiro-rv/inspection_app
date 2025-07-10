// lib/services/download_service.dart - Compatibility layer for old code

import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

/// Compatibility layer for old code that still references DownloadService
/// This redirects to the new service architecture
class DownloadService {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  /// Download inspection for offline editing
  Future<bool> downloadInspection(String inspectionId,
      {Function(double)? onProgress}) async {
    try {
      debugPrint(
          'DownloadService: Starting download of inspection $inspectionId');

      if (onProgress != null) onProgress(0.1);

      // Step 1: Check if inspection already exists locally
      final existingInspection =
          await _serviceFactory.dataService.getInspection(inspectionId);
      if (existingInspection != null) {
        debugPrint('DownloadService: Inspection already exists locally');
        if (onProgress != null) onProgress(1.0);
        return true;
      }

      if (onProgress != null) onProgress(0.2);

      // Step 2: Download inspection from Firestore
      try {
        await _serviceFactory.syncService.downloadInspectionsFromCloud();
        final inspectionData =
            await _serviceFactory.dataService.getInspection(inspectionId);
        if (inspectionData == null) {
          debugPrint(
              'DownloadService: Failed to download inspection from Firestore');
          return false;
        }
      } catch (e) {
        debugPrint('DownloadService: Error downloading inspection: $e');
        return false;
      }

      if (onProgress != null) onProgress(0.5);

      // Step 3: Data is already saved locally via sync service
      debugPrint(
          'DownloadService: Inspection data saved locally via sync service');

      if (onProgress != null) onProgress(0.7);

      // Step 4: Template download is handled by sync service
      debugPrint('DownloadService: Template download handled by sync service');

      if (onProgress != null) onProgress(0.9);

      // Step 5: Media download is handled by sync service
      try {
        debugPrint('DownloadService: Media download handled by sync service');
        // Additional media processing can be added here if needed
      } catch (e) {
        debugPrint('DownloadService: Warning - Media processing error: $e');
        // Continue without media - this is not critical
      }

      if (onProgress != null) onProgress(1.0);

      debugPrint(
          'DownloadService: Successfully downloaded inspection $inspectionId');
      return true;
    } catch (e) {
      debugPrint('DownloadService: Error downloading inspection: $e');
      return false;
    }
  }

  /// Download inspection for offline editing - compatibility method
  Future<void> downloadInspectionForOfflineEditing(String inspectionId) async {
    debugPrint(
        'DownloadService: downloadInspectionForOfflineEditing called - redirecting to new system');
    final result = await downloadInspection(inspectionId);
    if (result) {
      debugPrint(
          'DownloadService: Successfully downloaded inspection for offline editing');
    } else {
      debugPrint(
          'DownloadService: Failed to download inspection for offline editing');
    }
  }

  /// Check if inspection is downloaded
  Future<bool> isInspectionDownloaded(String inspectionId) async {
    debugPrint(
        'DownloadService: isInspectionDownloaded called - redirecting to new system');
    final inspection =
        await _serviceFactory.dataService.getInspection(inspectionId);
    return inspection != null;
  }

  /// Returns empty list for compatibility - deprecated method
  Future<List<Map<String, dynamic>>> getAvailableInspections() async {
    debugPrint(
        'DownloadService: getAvailableInspections called - returning empty list (deprecated)');
    return [];
  }

  /// Returns true for compatibility - deprecated method
  Future<bool> isInspectionAvailable(String inspectionId) async {
    debugPrint(
        'DownloadService: isInspectionAvailable called - using new system');
    final inspection =
        await _serviceFactory.dataService.getInspection(inspectionId);
    return inspection != null;
  }
}

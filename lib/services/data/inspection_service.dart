import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/service_factory.dart';

class InspectionService {
  final FirebaseService _firebase = FirebaseService();

  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      final cacheService = ServiceFactory().cacheService;
      
      // First, try to get from local cache
      final cachedInspection = cacheService.getCachedInspection(inspectionId);
      
      // Check if we're online
      bool isOnline = false;
      try {
        await _firebase.firestore.collection('inspections').limit(1).get();
        isOnline = true;
      } catch (e) {
        isOnline = false;
        debugPrint('InspectionService.getInspection: Offline mode detected');
      }
      
      // If offline and we have cached data, return it
      if (!isOnline && cachedInspection != null) {
        debugPrint('InspectionService.getInspection: Using cached data (offline) for inspection $inspectionId');
        return Inspection.fromMap(cachedInspection.data);
      }
      
      // If online, try to fetch from Firestore
      if (isOnline) {
        try {
          final doc = await _firebase.firestore
              .collection('inspections')
              .doc(inspectionId)
              .get();

          if (doc.exists) {
            final inspectionData = {
              'id': doc.id,
              ...doc.data() ?? {},
            };
            
            // Cache the fresh data
            await cacheService.cacheInspection(inspectionId, inspectionData);
            debugPrint('InspectionService.getInspection: Fetched from Firestore and cached inspection $inspectionId');
            
            return Inspection.fromMap(inspectionData);
          }
        } catch (e) {
          debugPrint('InspectionService.getInspection: Error fetching from Firestore: $e');
          // Fall back to cache if Firestore fails
          if (cachedInspection != null) {
            debugPrint('InspectionService.getInspection: Falling back to cached data for inspection $inspectionId');
            return Inspection.fromMap(cachedInspection.data);
          }
        }
      }
      
      // If we have cached data but couldn't reach Firestore, use cache
      if (cachedInspection != null) {
        debugPrint('InspectionService.getInspection: Using cached data (fallback) for inspection $inspectionId');
        return Inspection.fromMap(cachedInspection.data);
      }
      
      return null;
    } catch (e) {
      debugPrint('InspectionService.getInspection: Error: $e');
      
      // Final fallback to cache
      try {
        final cacheService = ServiceFactory().cacheService;
        final cachedInspection = cacheService.getCachedInspection(inspectionId);
        if (cachedInspection != null) {
          debugPrint('InspectionService.getInspection: Final fallback to cached data for inspection $inspectionId');
          return Inspection.fromMap(cachedInspection.data);
        }
      } catch (cacheError) {
        debugPrint('InspectionService.getInspection: Cache fallback failed: $cacheError');
      }
      
      return null;
    }
  }

  Future<void> saveInspection(Inspection inspection) async {
    try {
      final cacheService = ServiceFactory().cacheService;
      
      // Always cache the inspection data locally first
      await cacheService.cacheInspection(inspection.id, inspection.toMap());
      await cacheService.markForSync(inspection.id);
      
      // Try to save to Firestore if online
      final data = inspection.toMap();
      data.remove('id');
      
      try {
        await _firebase.firestore
            .collection('inspections')
            .doc(inspection.id)
            .set(data, SetOptions(merge: true));
        
        // Mark as synced if Firestore save succeeded
        await cacheService.markSynced(inspection.id);
        debugPrint('InspectionService.saveInspection: Saved to Firestore and marked as synced: ${inspection.id}');
      } catch (e) {
        // Firestore save failed, but local cache succeeded
        debugPrint('InspectionService.saveInspection: Failed to save to Firestore, but cached locally: $e');
        // The inspection will be synced later when online
      }
    } catch (e) {
      debugPrint('InspectionService.saveInspection: Error saving inspection: $e');
      rethrow;
    }
  }

  // Force refresh inspection data from Firestore (bypassing cache)
  Future<void> refreshFromFirestore(String inspectionId) async {
    try {
      // Force fetch from server only (no cache)
      final doc = await _firebase.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) {
        throw Exception('Inspection not found on server');
      }

      // Cache the downloaded data locally for offline access
      final inspectionData = {
        'id': doc.id,
        ...doc.data() ?? {},
      };
      
      final cacheService = ServiceFactory().cacheService;
      await cacheService.cacheInspection(inspectionId, inspectionData);
      
      // Make sure it's marked as synced since we just downloaded fresh data
      await cacheService.markSynced(inspectionId);

      // Download all media for this inspection
      try {
        final cloudMediaDownloader = ServiceFactory().cloudMediaDownloader;
        await cloudMediaDownloader.downloadAllInspectionMedia(inspectionId);
        debugPrint('InspectionService.refreshFromFirestore: Successfully downloaded all media for inspection $inspectionId');
      } catch (e) {
        debugPrint('InspectionService.refreshFromFirestore: Error downloading media for inspection $inspectionId: $e');
        // Don't fail the whole operation if media download fails
      }

      // The document data is now refreshed from server and cached locally
      debugPrint('InspectionService.refreshFromFirestore: Successfully refreshed and cached inspection $inspectionId from server');
    } catch (e) {
      debugPrint('InspectionService.refreshFromFirestore: Error refreshing inspection $inspectionId: $e');
      rethrow;
    }
  }
}

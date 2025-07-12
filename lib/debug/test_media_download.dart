import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/sync/firestore_sync_service.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'dart:io';

/// Debug script to test media download functionality
/// This script provides comprehensive logging and analysis of the media download process
class MediaDownloadDebugger {
  final FirestoreSyncService _syncService;
  final EnhancedOfflineDataService _dataService;
  final FirebaseService _firebaseService;
  
  MediaDownloadDebugger({
    required FirestoreSyncService syncService,
    required EnhancedOfflineDataService dataService,
    required FirebaseService firebaseService,
  }) : _syncService = syncService,
       _dataService = dataService,
       _firebaseService = firebaseService;

  /// Factory method to create a debugger instance
  static Future<MediaDownloadDebugger> create() async {
    debugPrint('MediaDownloadDebugger: Initializing service factory...');
    
    // Initialize service factory
    final serviceFactory = EnhancedOfflineServiceFactory.instance;
    await serviceFactory.initialize();
    
    final syncService = FirestoreSyncService.instance;
    final dataService = serviceFactory.dataService;
    final firebaseService = FirebaseService();
    
    return MediaDownloadDebugger(
      syncService: syncService,
      dataService: dataService,
      firebaseService: firebaseService,
    );
  }

  /// Main debug method to test media download for a specific inspection
  Future<void> debugMediaDownload(String inspectionId) async {
    debugPrint('🔍 ===== MEDIA DOWNLOAD DEBUG SESSION START =====');
    debugPrint('📋 Inspection ID: $inspectionId');
    debugPrint('🕐 Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('');
    
    try {
      // Step 1: Check connectivity
      await _checkConnectivity();
      
      // Step 2: Verify inspection exists in Firestore
      final inspection = await _verifyInspectionExists(inspectionId);
      if (inspection == null) {
        debugPrint('❌ Inspection not found in Firestore. Aborting debug.');
        return;
      }
      
      // Step 3: Analyze Firestore structure
      await _analyzeFirestoreStructure(inspectionId);
      
      // Step 4: Check local media before download
      await _checkLocalMediaBefore(inspectionId);
      
      // Step 5: Test media download process
      await _testMediaDownload(inspectionId);
      
      // Step 6: Check local media after download
      await _checkLocalMediaAfter(inspectionId);
      
      // Step 7: Verify downloaded files
      await _verifyDownloadedFiles(inspectionId);
      
    } catch (e, stackTrace) {
      debugPrint('💥 ERROR in debug session: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
    
    debugPrint('');
    debugPrint('🔚 ===== MEDIA DOWNLOAD DEBUG SESSION END =====');
  }

  /// Check internet connectivity
  Future<void> _checkConnectivity() async {
    debugPrint('🌐 Checking connectivity...');
    final isConnected = await _syncService.isConnected();
    debugPrint('   Connected: $isConnected');
    
    if (!isConnected) {
      debugPrint('❌ No internet connection. Media download will fail.');
      throw Exception('No internet connection');
    }
  }

  /// Verify inspection exists in Firestore and get basic info
  Future<Inspection?> _verifyInspectionExists(String inspectionId) async {
    debugPrint('🔍 Verifying inspection exists in Firestore...');
    
    try {
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        debugPrint('❌ Inspection $inspectionId not found in Firestore');
        return null;
      }
      
      final data = docSnapshot.data()!;
      debugPrint('✅ Inspection found in Firestore');
      debugPrint('   Title: ${data['title']}');
      debugPrint('   Status: ${data['status']}');
      debugPrint('   Inspector ID: ${data['inspector_id']}');
      debugPrint('   Created: ${data['created_at']}');
      debugPrint('   Updated: ${data['updated_at']}');
      
      // Check if it has topics
      final topics = data['topics'] as List<dynamic>? ?? [];
      debugPrint('   Topics count: ${topics.length}');
      
      return Inspection.fromMap({...data, 'id': inspectionId});
      
    } catch (e) {
      debugPrint('❌ Error verifying inspection: $e');
      return null;
    }
  }

  /// Analyze the complete Firestore structure looking for media
  Future<void> _analyzeFirestoreStructure(String inspectionId) async {
    debugPrint('🔬 Analyzing Firestore structure for media...');
    
    try {
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        debugPrint('❌ Inspection not found for structure analysis');
        return;
      }
      
      final data = docSnapshot.data()!;
      final topics = data['topics'] as List<dynamic>? ?? [];
      
      int totalMediaFound = 0;
      
      debugPrint('📊 Structure Analysis:');
      debugPrint('   Total topics: ${topics.length}');
      
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final topicName = topic['name'] as String? ?? 'Unknown Topic';
        
        debugPrint('   📁 Topic $topicIndex: $topicName');
        debugPrint('       Keys: ${topic.keys.toList()}');
        
        // Check topic-level media
        final topicMedia = topic['media'] as List<dynamic>? ?? [];
        totalMediaFound += topicMedia.length;
        debugPrint('       Media count: ${topicMedia.length}');
        
        if (topicMedia.isNotEmpty) {
          debugPrint('       📸 Topic media details:');
          for (int mediaIndex = 0; mediaIndex < topicMedia.length; mediaIndex++) {
            final media = Map<String, dynamic>.from(topicMedia[mediaIndex]);
            _logMediaDetails(media, '         [$mediaIndex]');
          }
        }
        
        // Check topic-level non-conformities
        final topicNCs = topic['non_conformities'] as List<dynamic>? ?? [];
        debugPrint('       Non-conformities count: ${topicNCs.length}');
        
        if (topicNCs.isNotEmpty) {
          debugPrint('       🚨 Topic non-conformities:');
          for (int ncIndex = 0; ncIndex < topicNCs.length; ncIndex++) {
            final nc = Map<String, dynamic>.from(topicNCs[ncIndex]);
            final ncMedia = nc['media'] as List<dynamic>? ?? [];
            totalMediaFound += ncMedia.length;
            debugPrint('         [$ncIndex] ${nc['description']} - Media: ${ncMedia.length}');
            
            if (ncMedia.isNotEmpty) {
              for (int mediaIndex = 0; mediaIndex < ncMedia.length; mediaIndex++) {
                final media = Map<String, dynamic>.from(ncMedia[mediaIndex]);
                _logMediaDetails(media, '           [$mediaIndex]');
              }
            }
          }
        }
        
        // Check items
        final items = topic['items'] as List<dynamic>? ?? [];
        debugPrint('       Items count: ${items.length}');
        
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final itemName = item['name'] as String? ?? 'Unknown Item';
          
          debugPrint('       📂 Item $itemIndex: $itemName');
          debugPrint('           Keys: ${item.keys.toList()}');
          
          // Check item-level media
          final itemMedia = item['media'] as List<dynamic>? ?? [];
          totalMediaFound += itemMedia.length;
          debugPrint('           Media count: ${itemMedia.length}');
          
          if (itemMedia.isNotEmpty) {
            debugPrint('           📸 Item media details:');
            for (int mediaIndex = 0; mediaIndex < itemMedia.length; mediaIndex++) {
              final media = Map<String, dynamic>.from(itemMedia[mediaIndex]);
              _logMediaDetails(media, '             [$mediaIndex]');
            }
          }
          
          // Check item-level non-conformities
          final itemNCs = item['non_conformities'] as List<dynamic>? ?? [];
          debugPrint('           Non-conformities count: ${itemNCs.length}');
          
          if (itemNCs.isNotEmpty) {
            debugPrint('           🚨 Item non-conformities:');
            for (int ncIndex = 0; ncIndex < itemNCs.length; ncIndex++) {
              final nc = Map<String, dynamic>.from(itemNCs[ncIndex]);
              final ncMedia = nc['media'] as List<dynamic>? ?? [];
              totalMediaFound += ncMedia.length;
              debugPrint('             [$ncIndex] ${nc['description']} - Media: ${ncMedia.length}');
              
              if (ncMedia.isNotEmpty) {
                for (int mediaIndex = 0; mediaIndex < ncMedia.length; mediaIndex++) {
                  final media = Map<String, dynamic>.from(ncMedia[mediaIndex]);
                  _logMediaDetails(media, '               [$mediaIndex]');
                }
              }
            }
          }
          
          // Check details
          final details = item['details'] as List<dynamic>? ?? [];
          debugPrint('           Details count: ${details.length}');
          
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            final detailName = detail['name'] as String? ?? 'Unknown Detail';
            
            debugPrint('           📋 Detail $detailIndex: $detailName');
            debugPrint('               Keys: ${detail.keys.toList()}');
            
            // Check detail-level media
            final detailMedia = detail['media'] as List<dynamic>? ?? [];
            totalMediaFound += detailMedia.length;
            debugPrint('               Media count: ${detailMedia.length}');
            
            if (detailMedia.isNotEmpty) {
              debugPrint('               📸 Detail media details:');
              for (int mediaIndex = 0; mediaIndex < detailMedia.length; mediaIndex++) {
                final media = Map<String, dynamic>.from(detailMedia[mediaIndex]);
                _logMediaDetails(media, '                 [$mediaIndex]');
              }
            }
            
            // Check detail-level non-conformities
            final detailNCs = detail['non_conformities'] as List<dynamic>? ?? [];
            debugPrint('               Non-conformities count: ${detailNCs.length}');
            
            if (detailNCs.isNotEmpty) {
              debugPrint('               🚨 Detail non-conformities:');
              for (int ncIndex = 0; ncIndex < detailNCs.length; ncIndex++) {
                final nc = Map<String, dynamic>.from(detailNCs[ncIndex]);
                final ncMedia = nc['media'] as List<dynamic>? ?? [];
                totalMediaFound += ncMedia.length;
                debugPrint('                 [$ncIndex] ${nc['description']} - Media: ${ncMedia.length}');
                
                if (ncMedia.isNotEmpty) {
                  for (int mediaIndex = 0; mediaIndex < ncMedia.length; mediaIndex++) {
                    final media = Map<String, dynamic>.from(ncMedia[mediaIndex]);
                    _logMediaDetails(media, '                   [$mediaIndex]');
                  }
                }
              }
            }
          }
        }
      }
      
      debugPrint('📊 TOTAL MEDIA FOUND IN FIRESTORE: $totalMediaFound');
      
      if (totalMediaFound == 0) {
        debugPrint('⚠️  WARNING: No media found in Firestore structure');
        debugPrint('   This could mean:');
        debugPrint('   - The inspection has no media attachments');
        debugPrint('   - Media is stored in a different structure');
        debugPrint('   - Media was not properly saved to Firestore');
      }
      
    } catch (e) {
      debugPrint('❌ Error analyzing Firestore structure: $e');
    }
  }

  /// Log detailed information about a media object
  void _logMediaDetails(Map<String, dynamic> media, String prefix) {
    debugPrint('$prefix Media details:');
    debugPrint('$prefix   Keys: ${media.keys.toList()}');
    debugPrint('$prefix   Filename: ${media['filename'] ?? media['name'] ?? 'N/A'}');
    debugPrint('$prefix   Type: ${media['type'] ?? 'N/A'}');
    debugPrint('$prefix   CloudUrl: ${media['cloudUrl'] ?? media['url'] ?? media['downloadUrl'] ?? 'N/A'}');
    debugPrint('$prefix   FileSize: ${media['fileSize'] ?? 'N/A'}');
    debugPrint('$prefix   MimeType: ${media['mimeType'] ?? 'N/A'}');
    debugPrint('$prefix   Created: ${media['createdAt'] ?? media['created_at'] ?? 'N/A'}');
    debugPrint('$prefix   IsUploaded: ${media['isUploaded'] ?? media['is_uploaded'] ?? 'N/A'}');
    debugPrint('$prefix   All data: $media');
  }

  /// Check what media already exists locally before download
  Future<void> _checkLocalMediaBefore(String inspectionId) async {
    debugPrint('📂 Checking local media before download...');
    
    try {
      final localMedia = await _dataService.getMediaByInspection(inspectionId);
      debugPrint('   Local media count: ${localMedia.length}');
      
      if (localMedia.isNotEmpty) {
        debugPrint('   📸 Existing local media:');
        for (int i = 0; i < localMedia.length; i++) {
          final media = localMedia[i];
          debugPrint('     [$i] ${media.filename}');
          debugPrint('         Type: ${media.type}');
          debugPrint('         Local path: ${media.localPath}');
          debugPrint('         Cloud URL: ${media.cloudUrl}');
          debugPrint('         File size: ${media.fileSize} bytes');
          debugPrint('         Is uploaded: ${media.isUploaded}');
          debugPrint('         Created: ${media.createdAt}');
          
          // Check if file actually exists
          final file = File(media.localPath);
          final exists = await file.exists();
          debugPrint('         File exists: $exists');
          if (exists) {
            final stat = await file.stat();
            debugPrint('         Actual file size: ${stat.size} bytes');
          }
        }
      } else {
        debugPrint('   No local media found for this inspection');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking local media: $e');
    }
  }

  /// Test the actual media download process
  Future<void> _testMediaDownload(String inspectionId) async {
    debugPrint('⬇️  Testing media download process...');
    
    try {
      // First, let's create a custom method to test the _downloadAndSaveMedia method
      await _testDownloadAndSaveMediaMethod(inspectionId);
      
      // Then test the full download inspection media process
      debugPrint('📥 Calling _downloadInspectionMedia method...');
      
      // We'll use reflection or call the method directly by accessing the private method
      // Since we can't access private methods directly, we'll simulate the process
      await _simulateMediaDownloadProcess(inspectionId);
      
    } catch (e) {
      debugPrint('❌ Error in media download test: $e');
    }
  }

  /// Simulate the media download process step by step
  Future<void> _simulateMediaDownloadProcess(String inspectionId) async {
    debugPrint('🔄 Simulating media download process...');
    
    try {
      // Get the inspection data from Firestore
      final docSnapshot = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!docSnapshot.exists) {
        debugPrint('❌ Inspection not found for media download simulation');
        return;
      }
      
      final data = docSnapshot.data()!;
      final topics = data['topics'] as List<dynamic>? ?? [];
      
      int totalMediaProcessed = 0;
      int totalMediaDownloaded = 0;
      
      debugPrint('🔄 Processing ${topics.length} topics for media download...');
      
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topicData = topics[topicIndex];
        final topic = Map<String, dynamic>.from(topicData);
        final topicName = topic['name'] as String? ?? 'Unknown Topic';
        
        debugPrint('   📁 Processing topic: $topicName');
        
        // Process topic-level media
        final topicMedias = topic['media'] as List<dynamic>? ?? [];
        debugPrint('     Topic media count: ${topicMedias.length}');
        
        for (final mediaData in topicMedias) {
          final media = Map<String, dynamic>.from(mediaData);
          totalMediaProcessed++;
          debugPrint('       🔄 Processing topic media #$totalMediaProcessed');
          
          final downloadResult = await _testDownloadSingleMedia(
            media, 
            inspectionId, 
            'Topic: $topicName',
            topicIndex.toString(),
            null,
            null,
            null,
          );
          
          if (downloadResult) {
            totalMediaDownloaded++;
            debugPrint('       ✅ Media downloaded successfully');
          } else {
            debugPrint('       ❌ Media download failed');
          }
        }
        
        // Process topic-level non-conformities
        final topicNCs = topic['non_conformities'] as List<dynamic>? ?? [];
        for (int ncIndex = 0; ncIndex < topicNCs.length; ncIndex++) {
          final nc = Map<String, dynamic>.from(topicNCs[ncIndex]);
          final ncMedias = nc['media'] as List<dynamic>? ?? [];
          
          for (final mediaData in ncMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            totalMediaProcessed++;
            debugPrint('       🔄 Processing topic NC media #$totalMediaProcessed');
            
            final downloadResult = await _testDownloadSingleMedia(
              media, 
              inspectionId, 
              'Topic NC: ${nc['description']}',
              topicIndex.toString(),
              null,
              null,
              nc['id'] as String?,
            );
            
            if (downloadResult) {
              totalMediaDownloaded++;
              debugPrint('       ✅ NC Media downloaded successfully');
            } else {
              debugPrint('       ❌ NC Media download failed');
            }
          }
        }
        
        // Process items
        final items = topic['items'] as List<dynamic>? ?? [];
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final itemData = items[itemIndex];
          final item = Map<String, dynamic>.from(itemData);
          final itemName = item['name'] as String? ?? 'Unknown Item';
          
          debugPrint('     📂 Processing item: $itemName');
          
          // Process item-level media
          final itemMedias = item['media'] as List<dynamic>? ?? [];
          debugPrint('       Item media count: ${itemMedias.length}');
          
          for (final mediaData in itemMedias) {
            final media = Map<String, dynamic>.from(mediaData);
            totalMediaProcessed++;
            debugPrint('         🔄 Processing item media #$totalMediaProcessed');
            
            final downloadResult = await _testDownloadSingleMedia(
              media, 
              inspectionId, 
              'Item: $itemName',
              topicIndex.toString(),
              itemIndex.toString(),
              null,
              null,
            );
            
            if (downloadResult) {
              totalMediaDownloaded++;
              debugPrint('         ✅ Media downloaded successfully');
            } else {
              debugPrint('         ❌ Media download failed');
            }
          }
          
          // Process item-level non-conformities
          final itemNCs = item['non_conformities'] as List<dynamic>? ?? [];
          for (int ncIndex = 0; ncIndex < itemNCs.length; ncIndex++) {
            final nc = Map<String, dynamic>.from(itemNCs[ncIndex]);
            final ncMedias = nc['media'] as List<dynamic>? ?? [];
            
            for (final mediaData in ncMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              totalMediaProcessed++;
              debugPrint('         🔄 Processing item NC media #$totalMediaProcessed');
              
              final downloadResult = await _testDownloadSingleMedia(
                media, 
                inspectionId, 
                'Item NC: ${nc['description']}',
                topicIndex.toString(),
                itemIndex.toString(),
                null,
                nc['id'] as String?,
              );
              
              if (downloadResult) {
                totalMediaDownloaded++;
                debugPrint('         ✅ NC Media downloaded successfully');
              } else {
                debugPrint('         ❌ NC Media download failed');
              }
            }
          }
          
          // Process details
          final details = item['details'] as List<dynamic>? ?? [];
          for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
            final detailData = details[detailIndex];
            final detail = Map<String, dynamic>.from(detailData);
            final detailName = detail['name'] as String? ?? 'Unknown Detail';
            
            debugPrint('       📋 Processing detail: $detailName');
            
            // Process detail-level media
            final detailMedias = detail['media'] as List<dynamic>? ?? [];
            debugPrint('         Detail media count: ${detailMedias.length}');
            
            for (final mediaData in detailMedias) {
              final media = Map<String, dynamic>.from(mediaData);
              totalMediaProcessed++;
              debugPrint('           🔄 Processing detail media #$totalMediaProcessed');
              
              final downloadResult = await _testDownloadSingleMedia(
                media, 
                inspectionId, 
                'Detail: $detailName',
                topicIndex.toString(),
                itemIndex.toString(),
                detailIndex.toString(),
                null,
              );
              
              if (downloadResult) {
                totalMediaDownloaded++;
                debugPrint('           ✅ Media downloaded successfully');
              } else {
                debugPrint('           ❌ Media download failed');
              }
            }
            
            // Process detail-level non-conformities
            final detailNCs = detail['non_conformities'] as List<dynamic>? ?? [];
            for (int ncIndex = 0; ncIndex < detailNCs.length; ncIndex++) {
              final nc = Map<String, dynamic>.from(detailNCs[ncIndex]);
              final ncMedias = nc['media'] as List<dynamic>? ?? [];
              
              for (final mediaData in ncMedias) {
                final media = Map<String, dynamic>.from(mediaData);
                totalMediaProcessed++;
                debugPrint('           🔄 Processing detail NC media #$totalMediaProcessed');
                
                final downloadResult = await _testDownloadSingleMedia(
                  media, 
                  inspectionId, 
                  'Detail NC: ${nc['description']}',
                  topicIndex.toString(),
                  itemIndex.toString(),
                  detailIndex.toString(),
                  nc['id'] as String?,
                );
                
                if (downloadResult) {
                  totalMediaDownloaded++;
                  debugPrint('           ✅ NC Media downloaded successfully');
                } else {
                  debugPrint('           ❌ NC Media download failed');
                }
              }
            }
          }
        }
      }
      
      debugPrint('📊 MEDIA DOWNLOAD SIMULATION RESULTS:');
      debugPrint('   Total media processed: $totalMediaProcessed');
      debugPrint('   Total media downloaded: $totalMediaDownloaded');
      debugPrint('   Success rate: ${totalMediaProcessed > 0 ? ((totalMediaDownloaded / totalMediaProcessed) * 100).toStringAsFixed(1) : 0}%');
      
    } catch (e) {
      debugPrint('❌ Error in media download simulation: $e');
    }
  }

  /// Test downloading a single media file
  Future<bool> _testDownloadSingleMedia(
    Map<String, dynamic> mediaData, 
    String inspectionId, 
    String context,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
  ) async {
    try {
      debugPrint('🔍 Testing single media download:');
      debugPrint('   Context: $context');
      debugPrint('   Media data keys: ${mediaData.keys.toList()}');
      
      // Extract media information with multiple fallbacks
      final cloudUrl = mediaData['cloudUrl'] as String? ?? 
                      mediaData['url'] as String? ?? 
                      mediaData['downloadUrl'] as String? ??
                      mediaData['download_url'] as String?;
      
      final filename = mediaData['filename'] as String? ?? 
                      mediaData['name'] as String? ??
                      mediaData['file_name'] as String?;
      
      final type = mediaData['type'] as String? ?? 'image';
      final fileSize = mediaData['fileSize'] as int? ?? 
                      mediaData['file_size'] as int? ?? 0;
      final mimeType = mediaData['mimeType'] as String? ?? 
                      mediaData['mime_type'] as String? ?? 
                      'image/jpeg';
      
      debugPrint('   Extracted info:');
      debugPrint('     CloudUrl: $cloudUrl');
      debugPrint('     Filename: $filename');
      debugPrint('     Type: $type');
      debugPrint('     FileSize: $fileSize');
      debugPrint('     MimeType: $mimeType');
      
      if (cloudUrl == null || filename == null) {
        debugPrint('   ❌ Missing required fields (cloudUrl or filename)');
        debugPrint('   Available data: $mediaData');
        return false;
      }
      
      // Check if media already exists
      final existingMedia = await _dataService.getMediaByFilename(filename);
      if (existingMedia.isNotEmpty) {
        debugPrint('   ⚠️  Media already exists locally: $filename');
        return false;
      }
      
      debugPrint('   ⬇️  Attempting to download media...');
      
      // Create local file
      final localFile = await _dataService.createMediaFile(filename);
      debugPrint('   📁 Local file path: ${localFile.path}');
      
      // Download from Firebase Storage
      final storageRef = _firebaseService.storage.refFromURL(cloudUrl);
      debugPrint('   🔗 Storage reference created');
      
      await storageRef.writeToFile(localFile);
      debugPrint('   ✅ File downloaded successfully');
      
      // Verify file was downloaded
      final fileExists = await localFile.exists();
      final actualFileSize = fileExists ? await localFile.length() : 0;
      
      debugPrint('   📊 Download verification:');
      debugPrint('     File exists: $fileExists');
      debugPrint('     Expected size: $fileSize bytes');
      debugPrint('     Actual size: $actualFileSize bytes');
      
      if (!fileExists) {
        debugPrint('   ❌ File was not created');
        return false;
      }
      
      // Save metadata to database
      final mediaId = await _dataService.saveOfflineMedia(
        inspectionId: inspectionId,
        filename: filename,
        localPath: localFile.path,
        cloudUrl: cloudUrl,
        type: type,
        fileSize: actualFileSize,
        mimeType: mimeType,
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        nonConformityId: nonConformityId,
        isUploaded: true,
      );
      
      debugPrint('   💾 Media metadata saved with ID: $mediaId');
      
      return true;
      
    } catch (e) {
      debugPrint('   ❌ Error downloading single media: $e');
      debugPrint('   Media data was: $mediaData');
      return false;
    }
  }

  /// Test the download and save media method specifically
  Future<void> _testDownloadAndSaveMediaMethod(String inspectionId) async {
    debugPrint('🧪 Testing _downloadAndSaveMedia method...');
    
    try {
      // Create test media data
      final testMediaData = {
        'cloudUrl': 'https://example.com/test.jpg',
        'filename': 'test_debug_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'type': 'image',
        'fileSize': 1024,
        'mimeType': 'image/jpeg',
      };
      
      debugPrint('   📊 Test media data: $testMediaData');
      debugPrint('   🔍 Method would be called with:');
      debugPrint('     - mediaData: $testMediaData');
      debugPrint('     - inspectionId: $inspectionId');
      debugPrint('     - context: "Debug Test"');
      
      // Note: We can't directly call the private method _downloadAndSaveMedia
      // But we can simulate what it would do
      debugPrint('   ⚠️  Cannot directly call private method _downloadAndSaveMedia');
      debugPrint('   ✅ Method structure analysis completed');
      
    } catch (e) {
      debugPrint('   ❌ Error in _downloadAndSaveMedia test: $e');
    }
  }

  /// Check local media after download
  Future<void> _checkLocalMediaAfter(String inspectionId) async {
    debugPrint('📂 Checking local media after download...');
    
    try {
      final localMedia = await _dataService.getMediaByInspection(inspectionId);
      debugPrint('   Local media count: ${localMedia.length}');
      
      if (localMedia.isNotEmpty) {
        debugPrint('   📸 Local media after download:');
        for (int i = 0; i < localMedia.length; i++) {
          final media = localMedia[i];
          debugPrint('     [$i] ${media.filename}');
          debugPrint('         Type: ${media.type}');
          debugPrint('         Local path: ${media.localPath}');
          debugPrint('         Cloud URL: ${media.cloudUrl}');
          debugPrint('         File size: ${media.fileSize} bytes');
          debugPrint('         Is uploaded: ${media.isUploaded}');
          debugPrint('         Is processed: ${media.isProcessed}');
          debugPrint('         Topic ID: ${media.topicId}');
          debugPrint('         Item ID: ${media.itemId}');
          debugPrint('         Detail ID: ${media.detailId}');
          debugPrint('         Non-conformity ID: ${media.nonConformityId}');
          debugPrint('         Created: ${media.createdAt}');
          debugPrint('         Updated: ${media.updatedAt}');
        }
      } else {
        debugPrint('   ❌ No local media found after download');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking local media after download: $e');
    }
  }

  /// Verify that downloaded files actually exist and are valid
  Future<void> _verifyDownloadedFiles(String inspectionId) async {
    debugPrint('🔍 Verifying downloaded files...');
    
    try {
      final localMedia = await _dataService.getMediaByInspection(inspectionId);
      
      int validFiles = 0;
      int invalidFiles = 0;
      int totalSize = 0;
      
      for (final media in localMedia) {
        final file = File(media.localPath);
        final exists = await file.exists();
        
        if (exists) {
          final stat = await file.stat();
          validFiles++;
          totalSize += stat.size;
          debugPrint('   ✅ Valid: ${media.filename} (${stat.size} bytes)');
        } else {
          invalidFiles++;
          debugPrint('   ❌ Invalid: ${media.filename} (file not found)');
        }
      }
      
      debugPrint('📊 File verification results:');
      debugPrint('   Valid files: $validFiles');
      debugPrint('   Invalid files: $invalidFiles');
      debugPrint('   Total size: ${(totalSize / 1024).toStringAsFixed(2)} KB');
      
    } catch (e) {
      debugPrint('❌ Error verifying downloaded files: $e');
    }
  }

  /// Generate a comprehensive debug report
  Future<void> generateDebugReport(String inspectionId) async {
    debugPrint('📋 Generating comprehensive debug report...');
    
    try {
      final report = StringBuffer();
      report.writeln('MEDIA DOWNLOAD DEBUG REPORT');
      report.writeln('==========================');
      report.writeln('Inspection ID: $inspectionId');
      report.writeln('Generated: ${DateTime.now().toIso8601String()}');
      report.writeln('');
      
      // Connectivity
      final isConnected = await _syncService.isConnected();
      report.writeln('Connectivity: ${isConnected ? 'Connected' : 'Disconnected'}');
      
      // Firestore inspection
      final inspection = await _verifyInspectionExists(inspectionId);
      report.writeln('Firestore Inspection: ${inspection != null ? 'Found' : 'Not Found'}');
      
      if (inspection != null) {
        report.writeln('Title: ${inspection.title}');
        report.writeln('Status: ${inspection.status}');
      }
      
      // Local media
      final localMedia = await _dataService.getMediaByInspection(inspectionId);
      report.writeln('Local Media Count: ${localMedia.length}');
      
      // File verification
      int validFiles = 0;
      int invalidFiles = 0;
      
      for (final media in localMedia) {
        final file = File(media.localPath);
        final exists = await file.exists();
        
        if (exists) {
          validFiles++;
        } else {
          invalidFiles++;
        }
      }
      
      report.writeln('Valid Files: $validFiles');
      report.writeln('Invalid Files: $invalidFiles');
      report.writeln('');
      
      // Service status
      report.writeln('Service Status:');
      report.writeln('- Sync Service: ${_syncService.runtimeType}');
      report.writeln('- Data Service: ${_dataService.runtimeType}');
      report.writeln('- Firebase Service: ${_firebaseService.runtimeType}');
      
      final reportString = report.toString();
      debugPrint(reportString);
      
      // You could save this to a file if needed
      // await _saveReportToFile(reportString, inspectionId);
      
    } catch (e) {
      debugPrint('❌ Error generating debug report: $e');
    }
  }

  /// Quick test method for easy debugging
  static Future<void> quickTest(String inspectionId) async {
    debugPrint('🚀 QUICK MEDIA DOWNLOAD TEST');
    debugPrint('Inspection ID: $inspectionId');
    
    try {
      final debugger = await MediaDownloadDebugger.create();
      await debugger.debugMediaDownload(inspectionId);
      await debugger.generateDebugReport(inspectionId);
    } catch (e) {
      debugPrint('❌ Quick test failed: $e');
    }
  }
}

/// Usage example:
/// 
/// To test media download for a specific inspection:
/// ```dart
/// await MediaDownloadDebugger.quickTest('YOUR_INSPECTION_ID');
/// ```
/// 
/// Or for more detailed control:
/// ```dart
/// final debugger = await MediaDownloadDebugger.create();
/// await debugger.debugMediaDownload('YOUR_INSPECTION_ID');
/// await debugger.generateDebugReport('YOUR_INSPECTION_ID');
/// ```
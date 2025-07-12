import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/debug/test_media_download.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

/// Simple runner to execute the media download debug script
/// 
/// Usage:
/// 1. Import this file in your main.dart or a test file
/// 2. Call runMediaDebug() with your inspection ID
/// 3. Check the debug console for detailed logs
/// 
/// Example:
/// ```dart
/// import 'package:lince_inspecoes/debug/run_media_debug.dart';
/// 
/// // In your code:
/// await runMediaDebug('YOUR_INSPECTION_ID_HERE');
/// ```

/// Run the media download debug test for a specific inspection
Future<void> runMediaDebug(String inspectionId) async {
  debugPrint('🔥 Starting Media Download Debug');
  debugPrint('📋 Inspection ID: $inspectionId');
  debugPrint('');
  
  try {
    await MediaDownloadDebugger.quickTest(inspectionId);
  } catch (e, stackTrace) {
    debugPrint('💥 Fatal error in media debug: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }
}

/// Run debug for multiple inspections
Future<void> runMediaDebugBatch(List<String> inspectionIds) async {
  debugPrint('🔥 Starting Batch Media Download Debug');
  debugPrint('📋 Inspections: ${inspectionIds.length}');
  debugPrint('');
  
  for (int i = 0; i < inspectionIds.length; i++) {
    final inspectionId = inspectionIds[i];
    debugPrint('');
    debugPrint('🔄 Processing inspection ${i + 1}/${inspectionIds.length}');
    debugPrint('📋 ID: $inspectionId');
    
    try {
      await MediaDownloadDebugger.quickTest(inspectionId);
    } catch (e) {
      debugPrint('💥 Error processing inspection $inspectionId: $e');
    }
    
    // Add a small delay between inspections
    await Future.delayed(const Duration(seconds: 1));
  }
  
  debugPrint('');
  debugPrint('✅ Batch debug completed');
}

/// Get all inspections that need media debugging
Future<List<String>> getInspectionsForDebug() async {
  debugPrint('🔍 Finding inspections for debug...');
  
  try {
    // Access the data service directly
    final serviceFactory = EnhancedOfflineServiceFactory.instance;
    await serviceFactory.initialize();
    final dataService = serviceFactory.dataService;
    
    final allInspections = await dataService.getAllInspections();
    
    // Filter inspections that might have media issues
    final inspectionIds = allInspections
        .where((inspection) => 
            inspection.status == 'in_progress' || 
            inspection.status == 'pending' ||
            inspection.status == 'completed')
        .map((inspection) => inspection.id)
        .toList();
    
    debugPrint('Found ${inspectionIds.length} inspections for debug');
    return inspectionIds;
    
  } catch (e) {
    debugPrint('❌ Error getting inspections for debug: $e');
    return [];
  }
}

/// Debug all inspections automatically
Future<void> runDebugForAllInspections() async {
  debugPrint('🔥 Starting Debug for All Inspections');
  
  try {
    final inspectionIds = await getInspectionsForDebug();
    
    if (inspectionIds.isEmpty) {
      debugPrint('⚠️  No inspections found for debug');
      return;
    }
    
    await runMediaDebugBatch(inspectionIds);
    
  } catch (e) {
    debugPrint('💥 Error in debug for all inspections: $e');
  }
}

/// Quick debug with a commonly used inspection ID
/// Replace 'YOUR_DEFAULT_INSPECTION_ID' with an actual inspection ID from your Firestore
Future<void> runQuickDebug() async {
  const defaultInspectionId = 'ZxloaNQP35lfHV6kHK7l'; // Example from CLAUDE.md
  
  debugPrint('🚀 Running Quick Debug');
  debugPrint('📋 Using example inspection ID: $defaultInspectionId');
  debugPrint('⚠️  Replace this with your actual inspection ID');
  debugPrint('');
  
  await runMediaDebug(defaultInspectionId);
}

/// Test specific media download scenarios
Future<void> runScenarioTests() async {
  debugPrint('🧪 Running Media Download Scenario Tests');
  debugPrint('');
  
  // Test 1: Basic media download
  debugPrint('📋 Test 1: Basic Media Download');
  await runQuickDebug();
  
  // Test 2: Multiple inspections
  debugPrint('');
  debugPrint('📋 Test 2: Multiple Inspections');
  final inspectionIds = await getInspectionsForDebug();
  if (inspectionIds.isNotEmpty) {
    await runMediaDebugBatch(inspectionIds.take(3).toList());
  }
  
  debugPrint('');
  debugPrint('✅ Scenario tests completed');
}

/// Generate detailed debug report
Future<void> generateDetailedReport(String inspectionId) async {
  debugPrint('📊 Generating Detailed Debug Report');
  
  try {
    final debugger = await MediaDownloadDebugger.create();
    await debugger.generateDebugReport(inspectionId);
  } catch (e) {
    debugPrint('❌ Error generating detailed report: $e');
  }
}

/// Example of how to use in your code:
/// 
/// ```dart
/// import 'package:lince_inspecoes/debug/run_media_debug.dart';
/// 
/// // In your button onPressed or wherever you want to debug:
/// void onDebugPressed() async {
///   await runQuickDebug();
/// }
/// 
/// // Or for a specific inspection:
/// void onDebugSpecificPressed(String inspectionId) async {
///   await runMediaDebug(inspectionId);
/// }
/// 
/// // Or to test all inspections:
/// void onDebugAllPressed() async {
///   await runDebugForAllInspections();
/// }
/// ```
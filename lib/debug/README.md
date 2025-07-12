# Media Download Debug Tools

This directory contains comprehensive debugging tools for testing and analyzing the media download functionality in the inspection app.

## Overview

The debug tools help you:
- 🔍 Analyze Firestore structure for media data
- ⬇️ Test media download processes
- 📊 Generate detailed reports
- 🐛 Identify and fix media download issues

## Files

### 1. `test_media_download.dart`
The main debug engine that provides comprehensive media download testing.

**Key Features:**
- Connectivity checking
- Firestore structure analysis
- Media download simulation
- File verification
- Detailed logging at every step

### 2. `run_media_debug.dart`
Simple runner functions for easy debugging.

**Key Functions:**
- `runMediaDebug(inspectionId)` - Debug single inspection
- `runQuickDebug()` - Quick test with example ID
- `runDebugForAllInspections()` - Test all inspections
- `runScenarioTests()` - Run multiple test scenarios

### 3. `debug_integration.dart`
UI components for easy integration into your app.

**Components:**
- `MediaDebugPanel` - Debug panel widget
- `MediaDebugScreen` - Full-screen debug interface
- `DebugFloatingButton` - Floating action button

## Quick Start

### Method 1: Using the Debug Panel (Recommended)

1. Add the debug button to your main screen:
```dart
import 'package:lince_inspecoes/debug/debug_integration.dart';

// In your main screen's build method:
floatingActionButton: const DebugFloatingButton(),
```

2. Tap the orange debug button to open the debug screen
3. Enter an inspection ID and tap "Debug Single"
4. Check the Flutter console for detailed logs

### Method 2: Manual Function Calls

```dart
import 'package:lince_inspecoes/debug/run_media_debug.dart';

// Debug a specific inspection
await runMediaDebug('YOUR_INSPECTION_ID');

// Quick debug with example ID
await runQuickDebug();

// Debug all inspections
await runDebugForAllInspections();
```

### Method 3: Direct API Usage

```dart
import 'package:lince_inspecoes/debug/test_media_download.dart';

// Create debugger instance
final debugger = await MediaDownloadDebugger.create();

// Run comprehensive debug
await debugger.debugMediaDownload('YOUR_INSPECTION_ID');

// Generate detailed report
await debugger.generateDebugReport('YOUR_INSPECTION_ID');
```

## Understanding the Debug Output

The debug tools provide extensive logging organized in sections:

### 🌐 Connectivity Check
```
🌐 Checking connectivity...
   Connected: true
```

### 🔍 Firestore Verification
```
🔍 Verifying inspection exists in Firestore...
✅ Inspection found in Firestore
   Title: Test Inspection
   Status: in_progress
   Topics count: 2
```

### 🔬 Structure Analysis
```
🔬 Analyzing Firestore structure for media...
📊 Structure Analysis:
   Total topics: 2
   📁 Topic 0: Sala de Estar
       Media count: 1
       📸 Topic media details:
         [0] Media details:
         [0]   Filename: image_123.jpg
         [0]   CloudUrl: https://firebasestorage.googleapis.com/...
```

### ⬇️ Download Process
```
⬇️ Testing media download process...
🔄 Processing 2 topics for media download...
   📁 Processing topic: Sala de Estar
     🔄 Processing topic media #1
       ✅ Media downloaded successfully
```

### 📂 Local Media Check
```
📂 Checking local media after download...
   Local media count: 3
   📸 Local media after download:
     [0] image_123.jpg
         Local path: /storage/emulated/0/Android/data/.../image_123.jpg
         File size: 245760 bytes
         Is uploaded: true
```

### 🔍 File Verification
```
🔍 Verifying downloaded files...
   ✅ Valid: image_123.jpg (245760 bytes)
📊 File verification results:
   Valid files: 3
   Invalid files: 0
   Total size: 720.50 KB
```

## Common Issues and Solutions

### ❌ No Media Found
```
⚠️ WARNING: No media found in Firestore structure
```
**Solutions:**
- Check if the inspection actually has media
- Verify the media structure in Firestore
- Ensure media was properly uploaded

### ❌ Download Failures
```
❌ Media download failed
   Missing required fields (cloudUrl or filename)
```
**Solutions:**
- Check Firestore media data structure
- Verify Firebase Storage URLs are valid
- Ensure proper media metadata

### ❌ Local File Issues
```
❌ Invalid: image_123.jpg (file not found)
```
**Solutions:**
- Check app storage permissions
- Verify local file paths
- Clear app data and retry

## Example Inspection ID

The debug tools come with a pre-configured example inspection ID from the CLAUDE.md documentation:
```
ZxloaNQP35lfHV6kHK7l
```

This inspection contains:
- 2 topics (Sala de Estar, Cozinha)
- Multiple items and details
- Various media files
- Non-conformities with media

## Integration Examples

### Add to Settings Screen
```dart
// In your settings screen
ListTile(
  leading: const Icon(Icons.bug_report),
  title: const Text('Media Debug'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MediaDebugScreen(),
      ),
    );
  },
),
```

### Add to Developer Menu
```dart
// In your developer options
ElevatedButton(
  onPressed: () async {
    await runQuickDebug();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug completed - check console')),
    );
  },
  child: const Text('Debug Media Download'),
),
```

### Background Debug
```dart
// Run debug in background
void runBackgroundDebug() {
  runMediaDebug('your_inspection_id').then((_) {
    print('Background debug completed');
  }).catchError((error) {
    print('Background debug failed: $error');
  });
}
```

## Best Practices

1. **Always check connectivity** before running debug
2. **Use valid inspection IDs** that exist in your Firestore
3. **Monitor console output** for detailed information
4. **Test with different inspection types** (with/without media)
5. **Clear local data** between tests if needed
6. **Run tests in development mode** only

## Performance Notes

- Debug tools are designed for development use only
- Don't include debug panels in production builds
- Large inspections may take longer to analyze
- Network speed affects download testing

## Troubleshooting

### Debug Tools Not Working
1. Ensure Firebase is properly initialized
2. Check internet connectivity
3. Verify inspection ID exists in Firestore
4. Check app permissions for file access

### No Console Output
1. Ensure Flutter is running in debug mode
2. Check that `debugPrint` statements are enabled
3. Use `flutter logs` to see all output

### Memory Issues
1. Run debug on smaller inspections first
2. Clear app data between large tests
3. Monitor memory usage during debug

## Contributing

To add new debug features:
1. Add methods to `MediaDownloadDebugger` class
2. Create wrapper functions in `run_media_debug.dart`
3. Add UI components in `debug_integration.dart`
4. Update this README with new features

## Support

If you encounter issues with the debug tools:
1. Check the console for error messages
2. Verify your inspection data structure
3. Test with the example inspection ID
4. Check Firebase configuration

The debug tools are designed to help identify and resolve media download issues quickly and efficiently. Use them during development to ensure your media download functionality works correctly.
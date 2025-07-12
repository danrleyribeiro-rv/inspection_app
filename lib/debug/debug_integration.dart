import 'package:flutter/material.dart';
import 'package:lince_inspecoes/debug/run_media_debug.dart';

/// Debug integration widget for easy access to media download debugging
/// 
/// This widget provides a simple UI to test media download functionality
/// Add this to your app during development to debug media issues
class MediaDebugPanel extends StatefulWidget {
  const MediaDebugPanel({super.key});

  @override
  State<MediaDebugPanel> createState() => _MediaDebugPanelState();
}

class _MediaDebugPanelState extends State<MediaDebugPanel> {
  final TextEditingController _inspectionIdController = TextEditingController();
  bool _isDebugging = false;
  String _lastLog = '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with example inspection ID from CLAUDE.md
    _inspectionIdController.text = 'ZxloaNQP35lfHV6kHK7l';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Media Download Debug',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _inspectionIdController,
              decoration: const InputDecoration(
                labelText: 'Inspection ID',
                hintText: 'Enter inspection ID to debug',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment),
              ),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isDebugging ? null : _debugSingleInspection,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Debug Single'),
                ),
                ElevatedButton.icon(
                  onPressed: _isDebugging ? null : _debugQuick,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Quick Debug'),
                ),
                ElevatedButton.icon(
                  onPressed: _isDebugging ? null : _debugAllInspections,
                  icon: const Icon(Icons.all_inclusive),
                  label: const Text('Debug All'),
                ),
                ElevatedButton.icon(
                  onPressed: _isDebugging ? null : _runScenarioTests,
                  icon: const Icon(Icons.science),
                  label: const Text('Scenario Tests'),
                ),
              ],
            ),
            
            if (_isDebugging) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Debugging in progress... Check console for detailed logs',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            
            if (_lastLog.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Last Result:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastLog,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Debug Information:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Check Flutter console for detailed logs\n'
                      '• Logs include Firestore structure analysis\n'
                      '• Media download progress tracking\n'
                      '• File verification and error reporting\n'
                      '• Use example ID: ZxloaNQP35lfHV6kHK7l',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _debugSingleInspection() async {
    final inspectionId = _inspectionIdController.text.trim();
    if (inspectionId.isEmpty) {
      _showError('Please enter an inspection ID');
      return;
    }

    setState(() {
      _isDebugging = true;
      _lastLog = '';
    });

    try {
      await runMediaDebug(inspectionId);
      _updateLog('Debug completed for inspection: $inspectionId');
    } catch (e) {
      _updateLog('Error: $e');
    } finally {
      setState(() {
        _isDebugging = false;
      });
    }
  }

  Future<void> _debugQuick() async {
    setState(() {
      _isDebugging = true;
      _lastLog = '';
    });

    try {
      await runQuickDebug();
      _updateLog('Quick debug completed');
    } catch (e) {
      _updateLog('Error: $e');
    } finally {
      setState(() {
        _isDebugging = false;
      });
    }
  }

  Future<void> _debugAllInspections() async {
    setState(() {
      _isDebugging = true;
      _lastLog = '';
    });

    try {
      await runDebugForAllInspections();
      _updateLog('Debug completed for all inspections');
    } catch (e) {
      _updateLog('Error: $e');
    } finally {
      setState(() {
        _isDebugging = false;
      });
    }
  }

  Future<void> _runScenarioTests() async {
    setState(() {
      _isDebugging = true;
      _lastLog = '';
    });

    try {
      await runScenarioTests();
      _updateLog('Scenario tests completed');
    } catch (e) {
      _updateLog('Error: $e');
    } finally {
      setState(() {
        _isDebugging = false;
      });
    }
  }

  void _updateLog(String message) {
    setState(() {
      _lastLog = message;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _inspectionIdController.dispose();
    super.dispose();
  }
}

/// Debug screen for full-screen media debugging
class MediaDebugScreen extends StatelessWidget {
  const MediaDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Download Debug'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        child: Column(
          children: [
            MediaDebugPanel(),
            // Add more debug panels here if needed
          ],
        ),
      ),
    );
  }
}

/// Floating debug button for easy access
class DebugFloatingButton extends StatelessWidget {
  const DebugFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'debug_media',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MediaDebugScreen(),
          ),
        );
      },
      backgroundColor: Colors.orange,
      child: const Icon(Icons.bug_report),
    );
  }
}

/// Integration instructions:
/// 
/// 1. Add debug button to your main screen:
/// ```dart
/// // In your main screen's build method:
/// floatingActionButton: const DebugFloatingButton(),
/// ```
/// 
/// 2. Or add the debug panel to any screen:
/// ```dart
/// // In your screen's build method:
/// Column(
///   children: [
///     // Your existing content
///     const MediaDebugPanel(),
///   ],
/// ),
/// ```
/// 
/// 3. Or create a debug-only screen:
/// ```dart
/// // Add this to your routes:
/// '/debug': (context) => const MediaDebugScreen(),
/// ```
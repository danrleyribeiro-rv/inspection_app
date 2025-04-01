// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/presentation/screens/inspection/offline_inspection_screen.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InspectionTab extends StatefulWidget {
  const InspectionTab({super.key});

  @override
  State<InspectionTab> createState() => _InspectionTabState();
}

class _InspectionTabState extends State<InspectionTab> {
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  final _syncService = SyncService();

  bool _isLoading = true;
  List<Inspection> _localInspections = [];
  List<Map<String, dynamic>> _remoteInspections = [];
  bool _isOffline = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadInspections();
    _checkConnectivity();
    _checkAndShowOfflineGuide();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });

      // If we're back online, refresh the list
      if (result != ConnectivityResult.none) {
        _loadInspections();
      }
    });
  }

  Future<void> _checkAndShowOfflineGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('has_seen_offline_guide') ?? false;
    if (!hasSeenGuide && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOfflineGuide();
      });
    }
  }

  void _showOfflineGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode Available'),
        content: const Text(
            'This app now works offline! Download inspections to work without an internet connection. '
            'Changes will automatically sync when you\'re back online.'),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_seen_offline_guide', true);
              Navigator.of(context).pop();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);

    try {
      // Load local inspections first - these will always be available
      final localInspections = await _inspectionService.getAllInspections();
      setState(() => _localInspections = localInspections);

      // If online, also load remote inspections
      List<Map<String, dynamic>> remoteInspections = [];

      if (!_isOffline) {
        // Get inspector ID first
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          try {
            final inspectorData = await _supabase
                .from('inspectors')
                .select('id')
                .eq('user_id', userId)
                .single();

            final inspectorId = inspectorData['id'];

            // Get inspections assigned to this inspector
            remoteInspections = await _supabase
                .from('inspections')
                .select('*, rooms(count)')
                .eq('inspector_id', inspectorId)
                .filter('deleted_at', 'is', null)
                .order('scheduled_date', ascending: true);

            setState(() => _remoteInspections = remoteInspections);
          } catch (e) {
            // Ignore errors here, we'll just use local inspections
            print('Error fetching remote inspections: $e');
          }
        }
      }
    } catch (e) {
      print('Error loading inspections: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadInspection(int inspectionId) async {
    if (_isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot download while offline')),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final success = await _syncService.downloadInspection(inspectionId);

      if (success) {
        // Refresh the list
        await _loadInspections();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspection downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error downloading inspection'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading inspection: $e')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncAllInspections() async {
    if (_isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot sync while offline')),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      await _inspectionService.syncAllPending();

      // Refresh the list
      await _loadInspections();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All inspections synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing inspections: $e')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _navigateToInspection(int inspectionId) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) =>
            OfflineInspectionScreen(inspectionId: inspectionId),
      ),
    )
        .then((_) {
      // Refresh the list when returning from the inspection screen
      _loadInspections();
    });
  }

  bool _isInspectionDownloaded(int inspectionId) {
    return _localInspections.any((inspection) => inspection.id == inspectionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspections'),
        actions: [
          // Sync button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed:
                    _isSyncing || _isOffline ? null : _syncAllInspections,
                tooltip: 'Sync All',
              ),
              if (_isSyncing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInspections,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildInspectionList(),
    );
  }

  Widget _buildInspectionList() {
    // Show local inspections first
    final localInspectionIds = _localInspections.map((i) => i.id).toSet();

    // Then, show remote inspections that aren't downloaded yet
    final remoteOnlyInspections = _remoteInspections
        .where((i) => !localInspectionIds.contains(i['id']))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadInspections,
      child: (_localInspections.isEmpty && remoteOnlyInspections.isEmpty)
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Connection status
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isOffline ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOffline
                            ? Icons.signal_wifi_off
                            : Icons.signal_wifi_4_bar,
                        color: _isOffline ? Colors.red[700] : Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isOffline
                              ? 'You are offline. Only downloaded inspections are available.'
                              : 'You are online. All inspections are available.',
                          style: TextStyle(
                            color:
                                _isOffline ? Colors.red[700] : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Local inspections (always show these first)
                if (_localInspections.isNotEmpty) ...[
                  const Text(
                    'Downloaded Inspections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._localInspections
                      .map((inspection) => _buildInspectionCard(inspection)),
                  const SizedBox(height: 16),
                ],

                // Remote inspections (only show when online)
                if (remoteOnlyInspections.isNotEmpty && !_isOffline) ...[
                  const Text(
                    'Available Inspections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...remoteOnlyInspections.map(
                      (inspection) => _buildRemoteInspectionCard(inspection)),
                ],
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No inspections found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isOffline
                ? 'You are offline. Connect to download inspections.'
                : 'Pull down to refresh or tap the refresh button.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard(Inspection inspection) {
    // Calculate progress indicator value based on inspection status
    double progress = 0.0;
    switch (inspection.status) {
      case 'pending':
        progress = 0.0;
        break;
      case 'in_progress':
        progress = 0.5;
        break;
      case 'completed':
        progress = 1.0;
        break;
    }

    // Check if inspection needs sync
    final Future<bool> isSynced =
        _inspectionService.isInspectionSynced(inspection.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToInspection(inspection.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      inspection.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(inspection.status),
                ],
              ),
              const SizedBox(height: 8),
              if (inspection.street != null && inspection.street!.isNotEmpty)
                Text(
                  '${inspection.street}, ${inspection.city ?? ''} ${inspection.state ?? ''}',
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${_formatDate(inspection.scheduledDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  FutureBuilder<bool>(
                    future: isSynced,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && !snapshot.data!) {
                        return const Chip(
                          label: Text('Needs Sync'),
                          backgroundColor: Colors.amber,
                          labelStyle: TextStyle(color: Colors.black),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _navigateToInspection(inspection.id),
                    child: Text(
                      inspection.status == 'completed' ? 'View' : 'Continue',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteInspectionCard(Map<String, dynamic> inspection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    inspection['title'] ?? 'Unnamed Inspection',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(inspection['status']),
              ],
            ),
                          const SizedBox(height: 8),
            if (inspection['street'] != null)
              Text(
                '${inspection['street']}, ${inspection['city'] ?? ''} ${inspection['state'] ?? ''}',
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(inspection['scheduled_date'] != null ? DateTime.parse(inspection['scheduled_date']) : null)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSyncing
                      ? null
                      : () => _downloadInspection(inspection['id']),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        label = 'Pending';
        color = Colors.orange;
        break;
      case 'in_progress':
        label = 'In Progress';
        color = Colors.blue;
        break;
      case 'completed':
        label = 'Completed';
        color = Colors.green;
        break;
      default:
        label = 'Unknown';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date set';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
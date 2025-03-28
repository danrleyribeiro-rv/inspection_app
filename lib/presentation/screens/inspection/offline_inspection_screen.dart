// lib/presentation/screens/inspection/offline_inspection_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineInspectionScreen extends StatefulWidget {
  final int inspectionId;

  const OfflineInspectionScreen({
    Key? key,
    required this.inspectionId,
  }) : super(key: key);

  @override
  State<OfflineInspectionScreen> createState() =>
      _OfflineInspectionScreenState();
}

class _OfflineInspectionScreenState extends State<OfflineInspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  Inspection? _inspection;
  List<Room> _rooms = [];
  dynamic _template;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOffline = false;
  int _expandedRoomIndex = -1;
  double _completionPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInspection();
    _checkConnectivity();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });

      // If we're back online and have pending changes, try to sync
      if (result != ConnectivityResult.none) {
        _syncInspection(showSuccess: false);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

// Modificação para o method _loadInspection em offline_inspection_screen.dart

  Future<void> _loadInspection() async {
    setState(() => _isLoading = true);

    try {
      // Load inspection from local database
      final inspection =
          await _inspectionService.getInspection(widget.inspectionId);

      if (inspection == null) {
        // Inspection not found locally, try to download from server
        final downloaded =
            await _syncService.downloadInspection(widget.inspectionId);

        if (!downloaded) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Inspection not found and could not be downloaded')),
            );
            Navigator.of(context).pop();
          }
          return;
        }

        // Now load the downloaded inspection
        final downloadedInspection =
            await _inspectionService.getInspection(widget.inspectionId);
        if (downloadedInspection == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Error loading downloaded inspection')),
            );
            Navigator.of(context).pop();
          }
          return;
        }

        _inspection = downloadedInspection;
      } else {
        _inspection = inspection;
      }

      // Load template from database if online
      if (!_isOffline && _inspection!.templateId != null) {
        try {
          final templateData = await _supabase
              .from('templates')
              .select('*')
              .eq('id', _inspection!.templateId ?? 0)
              .single();

          if (templateData != null) {
            // Parse o campo 'rooms' que está armazenado como JSON
            if (templateData['rooms'] is String) {
              try {
                // Converte o campo rooms de String para objeto JSON
                templateData['rooms'] = json.decode(templateData['rooms']);
              } catch (e) {
                print('Error parsing template rooms JSON: $e');
                templateData['rooms'] =
                    []; // Fallback para array vazio em caso de erro
              }
            }

            _template = templateData;
          } else {
            // Fallback to default template if not found
            _template = _getDefaultTemplate();
          }
        } catch (e) {
          print('Error loading template: $e');
          // Fallback to default template
          _template = _getDefaultTemplate();
        }
      } else {
        // Use default template if offline
        _template = _getDefaultTemplate();
      }

      // Load rooms
      await _loadRooms();

      // Calculate completion percentage
      await _updateCompletionPercentage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inspection: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      setState(() {
        _rooms = rooms;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rooms: $e')),
        );
      }
    }
  }

// Método auxiliar para criar um template padrão
  dynamic _getDefaultTemplate() {
    return {
      'id': _inspection!.templateId ?? 0,
      'title': 'Template for ${_inspection!.title}',
      'rooms': [
        {
          'name': 'Living Room',
          'description': 'The main living area',
          'items': [
            {
              'name': 'Walls',
              'description': 'Condition of walls',
              'details': [
                {
                  'name': 'Paint',
                  'type': 'select',
                  'options': ['Excellent', 'Good', 'Fair', 'Poor']
                },
                {'name': 'Cracks', 'type': 'text'},
              ]
            },
            {
              'name': 'Floor',
              'description': 'Condition of flooring',
              'details': [
                {
                  'name': 'Type',
                  'type': 'select',
                  'options': ['Hardwood', 'Tile', 'Carpet', 'Laminate', 'Other']
                },
                {
                  'name': 'Condition',
                  'type': 'select',
                  'options': ['Excellent', 'Good', 'Fair', 'Poor']
                },
              ]
            },
          ]
        },
        {
          'name': 'Kitchen',
          'description': 'Kitchen area',
          'items': [
            {
              'name': 'Countertops',
              'description': 'Kitchen countertops',
              'details': [
                {
                  'name': 'Material',
                  'type': 'select',
                  'options': ['Granite', 'Quartz', 'Laminate', 'Other']
                },
                {
                  'name': 'Condition',
                  'type': 'select',
                  'options': ['Excellent', 'Good', 'Fair', 'Poor']
                },
              ]
            },
            {
              'name': 'Appliances',
              'description': 'Kitchen appliances',
              'details': [
                {
                  'name': 'Refrigerator',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
                {
                  'name': 'Stove',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
                {
                  'name': 'Dishwasher',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
              ]
            },
          ]
        },
        {
          'name': 'Bathroom',
          'description': 'Bathroom area',
          'items': [
            {
              'name': 'Fixtures',
              'description': 'Bathroom fixtures',
              'details': [
                {
                  'name': 'Sink',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
                {
                  'name': 'Toilet',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
                {
                  'name': 'Shower/Bath',
                  'type': 'select',
                  'options': ['Working', 'Not Working', 'Not Present']
                },
              ]
            },
            {
              'name': 'Walls/Floor',
              'description': 'Bathroom walls and floor',
              'details': [
                {
                  'name': 'Tile Condition',
                  'type': 'select',
                  'options': ['Excellent', 'Good', 'Fair', 'Poor']
                },
                {
                  'name': 'Grout Condition',
                  'type': 'select',
                  'options': ['Excellent', 'Good', 'Fair', 'Poor']
                },
              ]
            },
          ]
        }
      ]
    };
  }

  Future<void> _updateCompletionPercentage() async {
    try {
      final percentage = await _inspectionService
          .calculateCompletionPercentage(widget.inspectionId);
      setState(() {
        _completionPercentage = percentage;
      });
    } catch (e) {
      // Just ignore errors here
    }
  }

  Future<void> _syncInspection({bool showSuccess = true}) async {
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
      final success =
          await _inspectionService.syncInspection(widget.inspectionId);

      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Inspection synced successfully'
                : 'Error syncing inspection'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sync: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _addRoom() async {
    // Find a room template that's not already implemented
    List<dynamic> roomTemplates = _template['rooms'] ?? [];
    List<String> existingRoomNames = _rooms.map((r) => r.roomName).toList();

    List<dynamic> availableTemplates = roomTemplates
        .where((t) => !existingRoomNames.contains(t['name']))
        .toList();

    if (availableTemplates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All available rooms have been added')),
        );
      }
      return;
    }

    // Show dialog to select a room to add
    final selectedTemplate = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Room'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300, // Set a fixed height to make the dialog scrollable
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTemplates.length,
            itemBuilder: (context, index) {
              final template = availableTemplates[index];
              return ListTile(
                title: Text(template['name']),
                subtitle: Text(template['description'] ?? ''),
                onTap: () => Navigator.of(context).pop(template),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedTemplate == null) return;

    setState(() => _isLoading = true);

    try {
      // Add the room to local database
      final newRoom = await _inspectionService.addRoom(
        widget.inspectionId,
        selectedTemplate['name'],
        label: selectedTemplate['description'],
      );

      // Refresh rooms list
      await _loadRooms();

      // Expand the new room
      setState(() {
        _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
      });

      // Mark inspection as modified
      await _inspectionService.saveInspection(
        _inspection!.copyWith(updatedAt: DateTime.now()),
        syncNow: false,
      );

      // Try to sync if online
      if (!_isOffline) {
        _syncInspection(showSuccess: false);
      }

      // Update completion percentage
      await _updateCompletionPercentage();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding room: $e')),
        );
      }
    }
  }

  void _handleRoomUpdate(Room updatedRoom) async {
    setState(() {
      final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
      if (index >= 0) {
        _rooms[index] = updatedRoom;
      }
    });

    await _inspectionService.updateRoom(updatedRoom);

    // Mark inspection as modified
    await _inspectionService.saveInspection(
      _inspection!.copyWith(updatedAt: DateTime.now()),
      syncNow: false,
    );

    // Try to sync if online
    if (!_isOffline) {
      _syncInspection(showSuccess: false);
    }

    // Update completion percentage
    await _updateCompletionPercentage();
  }

  Future<void> _handleRoomDelete(int roomId) async {
    try {
      await _inspectionService.deleteRoom(widget.inspectionId, roomId);

      setState(() {
        _rooms.removeWhere((r) => r.id == roomId);
      });

      // Mark inspection as modified
      await _inspectionService.saveInspection(
        _inspection!.copyWith(updatedAt: DateTime.now()),
        syncNow: false,
      );

      // Try to sync if online
      if (!_isOffline) {
        _syncInspection(showSuccess: false);
      }

      // Update completion percentage
      await _updateCompletionPercentage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting room: $e')),
        );
      }
    }
  }

  Future<void> _completeInspection() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Inspection'),
        content: const Text(
            'Are you sure you want to mark this inspection as completed?\n\nOnce completed, you won\'t be able to make further changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.green),
            child:
                const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Update inspection status and add completion timestamp
      final updatedInspection = _inspection!.copyWith(
        status: 'completed',
        finishedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to local database
      await _inspectionService.saveInspection(updatedInspection,
          syncNow: false);

      // Update state
      setState(() {
        _inspection = updatedInspection;
      });

      // Try to sync immediately
      await _syncInspection();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to the previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing inspection: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _inspection == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Inspection...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_inspection == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Error loading inspection. Please try again.'),
        ),
      );
    }

    // Get status for completed inspections
    final bool isCompleted = _inspection!.status == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: Text(_inspection!.title),
        actions: [
          // Sync button - only show if not completed
          if (!isCompleted)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed:
                      _isSyncing || _isOffline ? null : () => _syncInspection(),
                  tooltip: _isOffline ? 'Offline' : 'Sync',
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
        ],
      ),
      body: Column(
        children: [
          // Status indicator and progress bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and sync indicators
                Row(
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_inspection!.status),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getStatusText(_inspection!.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sync status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isOffline ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isOffline ? 'Offline' : 'Online',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_inspection!.scheduledDate != null)
                      Text(
                        'Date: ${_formatDate(_inspection!.scheduledDate!)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                LinearProgressIndicator(
                  value: _completionPercentage,
                  backgroundColor: Colors.grey[300],
                  minHeight: 10,
                ),
                const SizedBox(height: 4),
                Text(
                  'Completion: ${(_completionPercentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Address if available
                if (_inspection!.street != null &&
                    _inspection!.street!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_inspection!.street}, ${_inspection!.city ?? ''} ${_inspection!.state ?? ''}',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Rooms list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // List of rooms
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rooms.length,
                        itemBuilder: (context, index) {
                          final room = _rooms[index];

                          // Find the template for this room
                          final roomTemplate =
                              (_template['rooms'] as List?)?.firstWhere(
                            (t) => t['name'] == room.roomName,
                            orElse: () => <String,
                                Object>{}, // Corrigido o tipo de retorno
                          );

                          return RoomWidget(
                            room: room,
                            roomTemplate: roomTemplate,
                            onRoomUpdated: _handleRoomUpdate,
                            onRoomDeleted: _handleRoomDelete,
                            isExpanded: index == _expandedRoomIndex,
                            onExpansionChanged: () {
                              setState(() {
                                _expandedRoomIndex =
                                    _expandedRoomIndex == index ? -1 : index;
                              });
                            },
                          );
                        },
                      ),

                      // Empty state
                      if (_rooms.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.home_work_outlined,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No rooms added yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Click the + button to add rooms to this inspection',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: isCompleted ? null : _addRoom,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Room'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),

      // FAB para adicionar rooms e completar inspeção - SEMPRE visível quando não completado
      floatingActionButton: isCompleted
          ? null // No FAB for completed inspections
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add room button
                FloatingActionButton(
                  onPressed: _addRoom,
                  heroTag: 'addRoom',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                // Complete inspection button
                FloatingActionButton.extended(
                  onPressed: _completeInspection,
                  heroTag: 'complete',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

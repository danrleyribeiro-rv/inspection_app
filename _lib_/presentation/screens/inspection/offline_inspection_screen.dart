// lib/presentation/screens/inspection/offline_inspection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_event.dart';
import 'package:inspection_app/blocs/inspection/inspection_state.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/presentation/screens/inspection/components/room_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/components/status_indicator.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';

class OfflineInspectionScreen extends StatefulWidget {
  final int inspectionId;

  const OfflineInspectionScreen({
    Key? key,
    required this.inspectionId,
  }) : super(key: key);

  @override
  State<OfflineInspectionScreen> createState() => _OfflineInspectionScreenState();
}

class _OfflineInspectionScreenState extends State<OfflineInspectionScreen> {
  int _expandedRoomIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadInspection();
  }

  void _loadInspection() {
    context.read<InspectionBloc>().add(LoadInspection(widget.inspectionId));
  }

  Future<void> _addRoom() async {
    // Show template selector dialog
    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const TemplateSelectorDialog(
        title: 'Add Room',
        type: 'room',
      ),
    );
    
    if (template == null) return;
    
    // Name of the room comes from the selected template or custom name
    final roomName = template['name'] as String;
    String? roomLabel = template['label'] as String?;
    
    // Add room via bloc
    context.read<InspectionBloc>().add(AddRoom(
      widget.inspectionId,
      roomName,
      roomLabel: roomLabel,
    ));
  }

  void _handleRoomUpdate(Room updatedRoom) {
    context.read<InspectionBloc>().add(UpdateRoom(updatedRoom));
  }

  Future<void> _handleRoomDelete(int roomId) async {
    context.read<InspectionBloc>().add(DeleteRoom(widget.inspectionId, roomId));
  }

  Future<void> _syncInspection() async {
    context.read<InspectionBloc>().add(SyncInspection(widget.inspectionId));
  }

  Future<void> _saveInspection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Do you want to save the changes made to this inspection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      context.read<InspectionBloc>().add(SaveInspection(widget.inspectionId));
    }
  }

  Future<void> _completeInspection() async {
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
            child: const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      context.read<InspectionBloc>().add(CompleteInspection(widget.inspectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InspectionBloc, InspectionState>(
      listener: (context, state) {
        if (state is InspectionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is InspectionOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          
          // If the operation was "complete inspection", go back
          if (state.message.contains('completed successfully')) {
            Navigator.of(context).pop();
          }
        }
      },
      builder: (context, state) {
        if (state is InspectionLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading Inspection...'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (state is! InspectionLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: const Center(
              child: Text('Error loading inspection. Please try again.'),
            ),
          );
        }
        
        final inspectionState = state as InspectionLoaded;
        final inspection = inspectionState.inspection;
        final rooms = inspectionState.rooms;
        final completionPercentage = inspectionState.completionPercentage;
        final isOffline = inspectionState.isOffline;
        final isSyncing = inspectionState.isSyncing;
        
        // Check if inspection is completed
        final bool isCompleted = inspection.status == 'completed';
        
        return Scaffold(
          appBar: AppBar(
            title: Text(inspection.title),
            actions: [
              // Add room button
              if (!isCompleted)
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addRoom,
                  tooltip: 'Add Room',
                ),
              
              // Sync button
              if (!isCompleted)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: (isSyncing || isOffline) ? null : _syncInspection,
                      tooltip: isOffline ? 'Offline' : 'Sync',
                    ),
                    if (isSyncing)
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
                
              // Save button
              if (!isCompleted)
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveInspection,
                  tooltip: 'Save',
                ),
            ],
          ),
          body: Column(
            children: [
              // Status indicator and progress bar
              StatusIndicator(
                status: inspection.status,
                isOffline: isOffline,
                completionPercentage: completionPercentage,
                scheduledDate: inspection.scheduledDate,
                address: _formatAddress(inspection),
              ),

              // Rooms list
              Expanded(
                child: Stack(
                  children: [
                    // List of rooms
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];

                        return RoomWidget(
                          room: room,
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
                    if (rooms.isEmpty)
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
                              'No rooms added',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Click the + button in the toolbar to add rooms',
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

          floatingActionButton: isCompleted 
              ? null
              : FloatingActionButton.extended(
                  onPressed: _completeInspection,
                  heroTag: 'complete',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                ),
        );
      },
    );
  }

  String _formatAddress(dynamic inspection) {
    if (inspection.street == null || inspection.street.isEmpty) {
      return '';
    }
    
    return '${inspection.street}, ${inspection.city ?? ''} ${inspection.state ?? ''}';
  }
}
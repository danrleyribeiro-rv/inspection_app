// lib/presentation/screens/inspection/offline_inspection_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';


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


  Future<void> _duplicateRoom(Room room) async {
  setState(() => _isLoading = true);
  
  try {
    // Create a copy of the room with a new name
    final copyName = "${room.roomName} (cópia)";
    
    // Add the new room
    final newRoom = await _inspectionService.addRoom(
      widget.inspectionId,
      copyName,
      label: room.roomLabel,
    );
    
    // Duplicate all items if original room has an ID
    if (room.id != null) {
      // Get items from the original room
      final items = await _inspectionService.getItems(
        widget.inspectionId,
        room.id!
      );
      
      // Add each item to the new room
      for (final item in items) {
        final newItem = await _inspectionService.addItem(
          widget.inspectionId,
          newRoom.id!,
          item.itemName,
          label: item.itemLabel,
        );
        
        // Update item with the same observation as original
        if (item.observation != null) {
          await _inspectionService.updateItem(
            newItem.copyWith(observation: item.observation)
          );
        }
        
        // If the original item has an ID, duplicate its details
        if (item.id != null) {
          // Get details from the original item
          final details = await _inspectionService.getDetails(
            widget.inspectionId,
            room.id!,
            item.id!
          );
          
          // Add each detail to the new item
          for (final detail in details) {
            final newDetail = await _inspectionService.addDetail(
              widget.inspectionId,
              newRoom.id!,
              newItem.id!,
              detail.detailName,
              value: detail.detailValue,
            );
            
            // Update detail with the same observation as original
            if (detail.observation != null) {
              await _inspectionService.updateDetail(
                newDetail.copyWith(observation: detail.observation)
              );
            }
          }
        }
      }
    }
    
    // Reload rooms
    await _loadRooms();
    
    // Expand the new room
    setState(() {
      _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ambiente duplicado com sucesso!'))
    );
  } catch (e) {
    print('Erro ao duplicar ambiente: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao duplicar ambiente: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  Future<void> _loadInspection() async {
    setState(() => _isLoading = true);

    try {
      // Load inspection from local database
      final inspection =
          await _inspectionService.getInspection(widget.inspectionId);

      if (inspection == null) {
        // Try to download if online
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
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
          // Offline and no local data
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Inspection not found in offline storage')),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      } else {
        _inspection = inspection;
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
    setState(() => _isLoading = true);
    
    try {
      // Limpar lista existente para evitar duplicações
      _rooms.clear();
      
      // Verificar se já existem ambientes
      final existingRooms = await _inspectionService.getRooms(widget.inspectionId);
      
      if (existingRooms.isNotEmpty) {
        // Usar os ambientes existentes
        setState(() {
          _rooms = existingRooms;
          _isLoading = false;
        });
        return;
      }
      
      // Se não houver ambientes, deixar a lista vazia
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar ambientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ambientes: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
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
  // Mostrar dialog de seleção de templates
  final template = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => const TemplateSelectorDialog(
      title: 'Adicionar Ambiente',
      type: 'room',
    ),
  );
  
  if (template == null) return;
  
  setState(() => _isLoading = true);

  try {
    // Nome do ambiente vem do template selecionado ou de um nome personalizado
    final roomName = template['name'] as String;
    String? roomLabel = template['label'] as String?;
    
    // Adicionar o ambiente no banco de dados local
    final newRoom = await _inspectionService.addRoom(
      widget.inspectionId,
      roomName,
      label: roomLabel,
    );

    // Atualizar o ambiente com campos adicionais do template, se não for personalizado
    if (template['isCustom'] != true && template['description'] != null) {
      final updatedRoom = newRoom.copyWith(
        roomLabel: roomLabel,
        observation: template['description'] as String?,
      );
      await _inspectionService.updateRoom(updatedRoom);
    }

    // Recarregar lista de ambientes
    await _loadRooms();

    // Expandir o novo ambiente
    setState(() {
      _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
    });

    // Marcar inspeção como modificada
    await _inspectionService.saveInspection(
      _inspection!.copyWith(updatedAt: DateTime.now()),
      syncNow: false,
    );

    // Tentar sincronizar se estiver online
    if (!_isOffline) {
      _syncInspection(showSuccess: false);
    }

    // Atualizar percentual de conclusão
    await _updateCompletionPercentage();
  } catch (e) {
    print('Erro ao adicionar ambiente: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar ambiente: $e')),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}


    Future<void> _saveInspection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar Alterações'),
        content: const Text('Deseja salvar as alterações feitas na inspeção?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Atualizar status da inspeção para "in_progress" se estiver "pending"
      if (_inspection?.status == 'pending') {
        final updatedInspection = _inspection!.copyWith(
          status: 'in_progress', 
          updatedAt: DateTime.now()
        );
        
        await _inspectionService.saveInspection(updatedInspection, syncNow: !_isOffline);
        
        setState(() {
          _inspection = updatedInspection;
        });
      } else {
        // Apenas marcar como atualizado
        final updatedInspection = _inspection!.copyWith(
          updatedAt: DateTime.now()
        );
        
        await _inspectionService.saveInspection(updatedInspection, syncNow: !_isOffline);
      }
      
      // Tentar sincronizar se estiver online
      if (!_isOffline) {
        await _syncInspection(showSuccess: false);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção salva com sucesso!'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      print('Erro ao salvar inspeção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar inspeção: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result;
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
          title: const Text('Carregando Inspeção...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_inspection == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erro'),
        ),
        body: const Center(
          child: Text('Erro ao carregar inspeção. Tente novamente.'),
        ),
      );
    }

    // Get status for completed inspections
    final bool isCompleted = _inspection!.status == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: Text(_inspection!.title),
        actions: [
          // Botão de adicionar ambiente
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _addRoom,
              tooltip: 'Adicionar Ambiente',
            ),
          
          // Botão de sincronização
          if (!isCompleted)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed:
                      _isSyncing || _isOffline ? null : () => _syncInspection(),
                  tooltip: _isOffline ? 'Offline' : 'Sincronizar',
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
            
          // Botão de salvar
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveInspection,
              tooltip: 'Salvar',
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
                        'Data: ${_formatDate(_inspection!.scheduledDate!)}',
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
                  'Progresso: ${(_completionPercentage * 100).toInt()}%',
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

                          return RoomWidget(
                            room: room,
                            onRoomDuplicated: (room) => _duplicateRoom(room),
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
                                'Nenhum ambiente adicionado',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Clique no botão + na barra superior para adicionar ambientes',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: isCompleted ? null : _addRoom,
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar Ambiente'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),

      // Remover FAB, já que agora temos botões na AppBar
      floatingActionButton: isCompleted 
          ? null
          : FloatingActionButton.extended(
              onPressed: _completeInspection,
              heroTag: 'complete',
              backgroundColor: Colors.green,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar'),
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
// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/presentation/screens/inspection/components/rooms_list.dart';
import 'package:inspection_app/presentation/screens/inspection/components/landscape_view.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/components/empty_room_state.dart';
import 'package:inspection_app/presentation/screens/inspection/components/loading_state.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/services/import_export_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/gemini_service.dart';
import 'package:inspection_app/presentation/widgets/ai_suggestion_button.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:inspection_app/presentation/widgets/create_checkpoint_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_history_dialog.dart';
import 'package:inspection_app/presentation/widgets/inspection_checkpoint_bar.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final _inspectionService = FirebaseInspectionService();
  final _connectivityService = Connectivity();
  final _importExportService = ImportExportService();
  final _firestore = FirebaseFirestore.instance;
  final _checkpointService = InspectionCheckpointService();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  bool _isCalculatingProgress = false;
  Inspection? _inspection;
  List<Room> _rooms = [];
  int _expandedRoomIndex = -1;
  double _completionPercentage = 0.0;

  int _completedItems = 0;
  int _totalItems = 0;
  int _itemsWithMedia = 0;
  int _totalItemsForMedia = 0;
  double _detailsScore = 0.0;
  double _mediaScore = 0.0;

  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
    _loadInspection().then((_) {
      _calculateInspectionProgress();
    });
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });

        // If we're back online and have a pending template to apply
        if (_isOnline &&
            _inspection != null &&
            _inspection!.templateId != null &&
            _inspection!.isTemplated != true) {
          _checkAndApplyTemplate();
        }
      }
    });

    _connectivityService.checkConnectivity().then((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });
      }
    });
  }

  void _showCreateCheckpointDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateCheckpointDialog(
        inspectionId: widget.inspectionId,
        completedItems: _completedItems,
        totalItems: _totalItems,
        completionPercentage: _completionPercentage,
        itemsWithMedia: _itemsWithMedia,
        totalItemsForMedia: _totalItemsForMedia,
        detailsScore: _detailsScore,
        mediaScore: _mediaScore,
        onCheckpointCreated: () {
          // Recarregar inspeção após criar checkpoint
          _loadInspection();
        },
      ),
    );
  }

  void _showCheckpointHistory() {
    showDialog(
      context: context,
      builder: (context) => CheckpointHistoryDialog(
        inspectionId: widget.inspectionId,
      ),
    );
  }

  Future<void> _calculateInspectionProgress() async {
    if (!mounted) return;

    setState(() => _isCalculatingProgress = true);

    try {
      final progress =
          await _checkpointService.getInspectionProgress(widget.inspectionId);

      if (mounted) {
        setState(() {
          // Armazenar todos os valores de progresso
          _completedItems = progress['completed_items'];
          _totalItems = progress['total_items'];
          _itemsWithMedia = progress['items_with_media'];
          _totalItemsForMedia = progress['total_items_for_media'];
          _detailsScore = progress['details_score'];
          _mediaScore = progress['media_score'];
          _completionPercentage = progress['completion_percentage'];
        });
      }
    } catch (e) {
      print('Erro ao calcular progresso: $e');
      if (mounted) {
        setState(() => _isCalculatingProgress = false);
      }
    }
  }

  Future<void> _loadInspection() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final inspection =
          await _inspectionService.getInspection(widget.inspectionId);

      if (!mounted) return;

      if (inspection != null) {
        setState(() {
          _inspection = inspection;
        });

        // Load inspection rooms
        await _loadRooms();

        // Check if there's a template to apply
        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
            // Template hasn't been applied yet
            await _checkAndApplyTemplate();
          } else {
            print(
                'Inspeção já tem template aplicado: ${inspection.templateId}');
          }
        }
      } else {
        _showErrorSnackBar('Inspeção não encontrada.');
      }
    } catch (e) {
      print("Erro ao carregar inspeção: $e");
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndApplyTemplate() async {
    if (_inspection == null) return;

    // Only proceed if the inspection has a template ID and hasn't been applied yet
    if (_inspection!.templateId != null && _inspection!.isTemplated != true) {
      setState(() => _isApplyingTemplate = true);

      try {
        // Show loading message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplicando template à inspeção...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Log for diagnostic purposes
        print(
            'Iniciando aplicação de template: ${_inspection!.templateId} para inspeção: ${_inspection!.id}');
        print(
            'Status atual da aplicação de template: ${_inspection!.isTemplated}');

        // Apply the template
        final success = await _inspectionService.applyTemplateToInspection(
            _inspection!.id, _inspection!.templateId!);

        print(
            'Resultado da aplicação de template: ${success ? 'SUCESSO' : 'FALHA'}');

        if (success) {
          // Update inspection status locally AND on Firestore
          await _firestore
              .collection('inspections')
              .doc(_inspection!.id)
              .update({
            'is_templated': true,
            'status': 'in_progress',
            'updated_at': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            // Update state
            final updatedInspection = _inspection!.copyWith(
              isTemplated: true,
              status: 'in_progress',
              updatedAt: DateTime.now(),
            );

            setState(() {
              _inspection = updatedInspection;
            });
          }

          // Reload inspection data completely to get the updated structure
          await _loadInspection();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template aplicado com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Falha ao aplicar template. Tente novamente.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Erro ao aplicar template: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aplicar template: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isApplyingTemplate = false);
        }
      }
    } else {
      print('Nenhum template para aplicar ou já aplicado');
      if (_inspection!.isTemplated == true) {
        print('A inspeção já tem um template aplicado');
      }
      if (_inspection!.templateId == null) {
        print('Nenhum ID de template associado a esta inspeção');
      }
    }
  }

  // Function for manual template application (for the UI button)
  Future<void> _manuallyApplyTemplate() async {
    if (_inspection == null || !_isOnline || _isApplyingTemplate) return;

    // Show confirmation dialog
    final shouldApply = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicar Template'),
            content: Text(_inspection!.isTemplated
                ? 'Esta inspeção já tem um template aplicado. Deseja reaplicá-lo?'
                : 'Deseja aplicar o template a esta inspeção?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                child: const Text('Aplicar Template'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldApply) {
      setState(() => _isApplyingTemplate = true);

      try {
        // Show loading message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplicando template à inspeção...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Force reset of template flag in Firestore
        await _firestore.collection('inspections').doc(_inspection!.id).update({
          'is_templated': false,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Update local instance
        setState(() {
          _inspection = _inspection!.copyWith(
            isTemplated: false,
            updatedAt: DateTime.now(),
          );
        });

        // Apply the template
        await _checkAndApplyTemplate();
      } catch (e) {
        print('Erro na aplicação manual de template: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aplicar template: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isApplyingTemplate = false);
        }
      }
    }
  }

  Future<void> _loadRooms() async {
    if (_inspection?.id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final rooms = await _inspectionService.getRooms(widget.inspectionId);

      if (!mounted) return;
      setState(() {
        _rooms = rooms;

        // Reset selection state
        _selectedRoomIndex = -1;
        _selectedItemIndex = -1;
        _selectedRoomItems = [];
        _selectedItemDetails = [];
      });
    } catch (e) {
      print('Erro ao carregar salas: $e');
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar salas: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _addRoom() async {
    try {
      final template = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => TemplateSelectorDialog(
          title: 'Adicionar Sala',
          type: 'room',
          parentName: 'Inspeção',
        ),
      );

      if (template == null || !mounted) return;

      final roomName = template['name'] as String;
      final roomLabel = template['value'] as String?;

      setState(() => _isLoading = true);

      try {
        final position = _rooms.isNotEmpty ? _rooms.last.position + 1 : 0;
        await _inspectionService.addRoom(
          widget.inspectionId,
          roomName,
          label: roomLabel,
          position: position,
        );

        await _loadRooms();

        // Expand the newly added room
        if (_rooms.isNotEmpty) {
          setState(() {
            _expandedRoomIndex = _rooms.length - 1;
          });
        }

        // Update inspection status to in_progress if it was pending
        if (_inspection?.status == 'pending') {
          final updatedInspection = _inspection!.copyWith(
            status: 'in_progress',
            updatedAt: DateTime.now(),
          );
          await _inspectionService.saveInspection(updatedInspection);
          setState(() {
            _inspection = updatedInspection;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sala adicionada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar sala: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Erro ao adicionar sala: $e');
    }
  }

  Future<void> _duplicateRoom(Room room) async {
    setState(() => _isLoading = true);

    try {
      await _inspectionService.isRoomDuplicate(
          widget.inspectionId, room.roomName);

      await _loadRooms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sala "${room.roomName}" duplicada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar sala: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRoom(Room updatedRoom) async {
    try {
      await _inspectionService.updateRoom(updatedRoom);

      final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
      if (index >= 0 && mounted) {
        setState(() {
          _rooms[index] = updatedRoom;
        });
      }
    } catch (e) {
      print('Erro ao atualizar sala: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar sala: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoom(dynamic roomId) async {
    setState(() => _isLoading = true);

    try {
      await _inspectionService.deleteRoom(widget.inspectionId, roomId);

      await _loadRooms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sala excluída com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir sala: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Methods for landscape view
  Future<void> _handleRoomSelected(int index) async {
    if (index < 0 || index >= _rooms.length) return;

    setState(() {
      _selectedRoomIndex = index;
      _selectedItemIndex = -1;
      _selectedRoomItems = [];
      _selectedItemDetails = [];
    });

    // Load items for the selected room
    try {
      final room = _rooms[index];
      if (room.id != null) {
        final items = await _inspectionService.getItems(
          widget.inspectionId,
          room.id!,
        );

        if (mounted) {
          setState(() {
            _selectedRoomItems = items;
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar itens: $e');
    }
  }

  Future<void> _handleItemSelected(int index) async {
    if (index < 0 || index >= _selectedRoomItems.length) return;

    setState(() {
      _selectedItemIndex = index;
      _selectedItemDetails = [];
    });

    // Load details for the selected item
    try {
      final item = _selectedRoomItems[index];
      if (item.id != null && item.roomId != null) {
        final details = await _inspectionService.getDetails(
          widget.inspectionId,
          item.roomId!,
          item.id!,
        );

        if (mounted) {
          setState(() {
            _selectedItemDetails = details;
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
    }
  }

  // Import/Export functions
  Future<void> _exportInspection() async {
    final confirmed =
        await _importExportService.showExportConfirmationDialog(context);
    if (!confirmed) return;

    setState(() => _isSyncing = true);

    try {
      final filePath =
          await _importExportService.exportInspection(widget.inspectionId);

      if (mounted) {
        _importExportService.showSuccessMessage(
            context, 'Inspeção exportada com sucesso para:\n$filePath');
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
            context, 'Erro ao exportar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _importInspection() async {
    final confirmed =
        await _importExportService.showImportConfirmationDialog(context);
    if (!confirmed) return;

    setState(() => _isSyncing = true);

    try {
      final jsonData = await _importExportService.pickJsonFile();

      if (jsonData == null) {
        if (mounted) {
          setState(() => _isSyncing = false);
        }
        return;
      }

      final success = await _importExportService.importInspection(
          widget.inspectionId, jsonData);

      if (success) {
        // Reload data
        await _loadInspection();

        if (mounted) {
          _importExportService.showSuccessMessage(
              context, 'Dados da inspeção importados com sucesso');
        }
      } else {
        if (mounted) {
          _importExportService.showErrorMessage(
              context, 'Falha ao importar dados da inspeção');
        }
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
            context, 'Erro ao importar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Método para navegar para a tela de galeria de mídia
  void _navigateToMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size; // Get screen dimensions
    final bottomPadding =
        MediaQuery.of(context).padding.bottom; // Obter o padding inferior

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspeção'),
        actions: [
          // Connectivity status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: _isOnline
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOnline ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.signal_wifi_4_bar : Icons.wifi_off,
                  size: 12,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
          // Template apply button - more compact for small screens
          if (_isOnline &&
              _inspection != null &&
              _inspection!.templateId != null)
            IconButton(
              icon: const Icon(Icons.architecture, size: 22),
              tooltip: _inspection!.isTemplated
                  ? 'Reaplicar Template'
                  : 'Aplicar Template',
              onPressed: _isApplyingTemplate ? null : _manuallyApplyTemplate,
              padding: const EdgeInsets.all(8),
              visualDensity: VisualDensity.compact,
            ),

          // Loading indicator
          if (_isSyncing || _isApplyingTemplate)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),

          // Menu button with proper spacing
          if (!(_isSyncing || _isApplyingTemplate))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(8),
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: (value) async {
                switch (value) {
                  case 'export':
                    await _exportInspection();
                    break;
                  case 'import':
                    await _importInspection();
                    break;
                  case 'nonConformities':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NonConformityScreen(
                          inspectionId: widget.inspectionId,
                        ),
                      ),
                    );
                    break;
                  case 'media':
                    _navigateToMediaGallery();
                    break;
                  case 'refresh':
                    await _loadInspection();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Exportar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload),
                      SizedBox(width: 8),
                      Text('Importar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Atualizar Dados'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
            bottom: bottomPadding), // Adicionar padding inferior
        child: _buildBody(isLandscape, screenSize),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildBody(bool isLandscape, Size screenSize) {
    if (_isLoading) {
      return LoadingState(
          isDownloading: false, isApplyingTemplate: _isApplyingTemplate);
    }

    // Calculate available height by subtracting app bar, status bar, etc.
    final double availableHeight = screenSize.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        InspectionCheckpointBar.HEIGHT; // Altura da barra de checkpoint

    return Column(
      children: [
        // Checkpoint bar
        if (_inspection != null)
        InspectionCheckpointBar(
          lastCheckpointAt: _inspection!.lastCheckpointAt,
          lastCheckpointMessage: _inspection!.lastCheckpointMessage,
          lastCheckpointCompletion: _inspection!.lastCheckpointCompletion,
          
          // Adicionar novos parâmetros de progresso detalhado
          completedItems: _completedItems,
          totalItems: _totalItems,
          itemsWithMedia: _itemsWithMedia,
          totalItemsForMedia: _totalItemsForMedia,
          detailsScore: _detailsScore,
          mediaScore: _mediaScore,
          
          onAddCheckpoint: _showCreateCheckpointDialog,
          onViewHistory: _showCheckpointHistory,
        ),

        // Main content area
        Expanded(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width,
            maxHeight: availableHeight,
          ),
          child: _rooms.isEmpty
              ? EmptyRoomState(onAddRoom: _addRoom)
              : isLandscape
                  ? LandscapeView(
                      rooms: _rooms,
                      selectedRoomIndex: _selectedRoomIndex,
                      selectedItemIndex: _selectedItemIndex,
                      selectedRoomItems: _selectedRoomItems,
                      selectedItemDetails: _selectedItemDetails,
                      inspectionId: widget.inspectionId,
                      onRoomSelected: _handleRoomSelected,
                      onItemSelected: _handleItemSelected,
                      onRoomDuplicate: _duplicateRoom,
                      onRoomDelete: _deleteRoom,
                      inspectionService: _inspectionService,
                      onAddRoom: _addRoom,
                    )
                  : StatefulBuilder(
                      builder: (context, setState) {
                        return RoomsList(
                          rooms: _rooms,
                          expandedRoomIndex: _expandedRoomIndex,
                          onRoomUpdated: _updateRoom,
                          onRoomDeleted: _deleteRoom,
                          onRoomDuplicated: _duplicateRoom,
                          onExpansionChanged: (index) {
                            setState(() {
                              _expandedRoomIndex =
                                  _expandedRoomIndex == index ? -1 : index;
                            });
                          },
                          inspectionId: widget.inspectionId,
                          onRoomsReordered: _loadRooms,
                        );
                      },
                    ),
        ),
      ),
        // Adicione um espaçamento inferior para evitar sobreposição
        SizedBox(height: 2),

        // Barra de atalhos para funcionalidades principais
        if (!_isLoading && _rooms.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Atalho para Galeria de Mídia
                _buildShortcutButton(
                  icon: Icons.photo_library,
                  label: 'Galeria',
                  onTap: _navigateToMediaGallery,
                  color: Colors.purple,
                ),

                // Atalho para Não Conformidades
                _buildShortcutButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'NCs',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NonConformityScreen(
                          inspectionId: widget.inspectionId,
                        ),
                      ),
                    );
                  },
                  color: const Color.fromARGB(255, 255, 0, 0),
                ),

                // Atalho para Adicionar Sala/Tópico
                _buildShortcutButton(
                  icon: Icons.add_circle_outline,
                  label: '+ Tópico',
                  onTap: _addRoom,
                  color: Colors.blue,
                ),

                // Atalho para Exportar
                _buildShortcutButton(
                  icon: Icons.download,
                  label: 'Exportar',
                  onTap: _exportInspection,
                  color: Colors.green,
                ),

                // Botão de IA para sugestão de salas
                AISuggestionButton(
                  tooltip: 'Sugerir tópicos de vistoria',
                  onGeneratingSuggestions: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Gerando sugestão de tópicos de vistoria...')),
                    );
                  },
                  onError: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  generateSuggestions: () async {
                    final geminiService = GeminiService();
                    final inspectionType = _inspection?.title ?? 'Inspeção';
                    final existingRooms =
                        _rooms.map((room) => room.roomName).toList();
                    return await geminiService.suggestCompleteRooms(
                        inspectionType, existingRooms);
                  },
                  onSuggestionSelected: (suggestion) async {
                    if (suggestion is Map<String, dynamic>) {
                      setState(() => _isLoading = true);
                      try {
                        // Criar sala
                        final room = await _inspectionService.addRoom(
                          widget.inspectionId,
                          suggestion['room_name'],
                        );

                        // Criar itens e detalhes
                        if (room.id != null && suggestion['items'] != null) {
                          for (var itemData in suggestion['items']) {
                            final item = await _inspectionService.addItem(
                              widget.inspectionId,
                              room.id!,
                              itemData['item_name'],
                            );

                            // Criar detalhes
                            if (item.id != null &&
                                itemData['details'] != null) {
                              for (var detailData in itemData['details']) {
                                await _inspectionService.addDetail(
                                  widget.inspectionId,
                                  room.id!,
                                  item.id!,
                                  detailData['detail_name'],
                                  type: detailData['type'],
                                  options: detailData['options'] != null
                                      ? List<String>.from(detailData['options'])
                                      : null,
                                );
                              }
                            }
                          }
                        }

                        await _loadRooms();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Sala "${suggestion['room_name']}" criada com sucesso'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Erro ao criar sala: $e'),
                              backgroundColor: Colors.red),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.zero, // Remove padding to stretch to edges
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero, // Remove border radius
          child: Container(
            width: double.infinity, // Make container take full width
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

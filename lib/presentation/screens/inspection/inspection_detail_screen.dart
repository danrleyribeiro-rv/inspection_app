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
import 'package:inspection_app/presentation/screens/inspection/components/inspection_header.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/services/import_export_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/gemini_service.dart';
import 'package:inspection_app/presentation/widgets/ai_suggestion_button.dart';
// Importação da tela de galeria de mídia
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen>
    with SingleTickerProviderStateMixin {
  final _inspectionService = FirebaseInspectionService();
  final _connectivityService = Connectivity();
  final _importExportService = ImportExportService();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  Inspection? _inspection;
  List<Room> _rooms = [];
  int _expandedRoomIndex = -1;
  double _completionPercentage = 0.0;

  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  // State for expandable action buttons
  bool _isRoomButtonExpanded = false;
  bool _isExportButtonExpanded = false;
  late AnimationController _animationController;

  // Checkpoint state
  int _checkpointCounter = 0;
  List<Map<String, dynamic>> _checkpoints = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _listenToConnectivity();
    _loadInspection();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

        // Calculate completion percentage
        await _calculateCompletionPercentage();

        // Check if there's a template to apply
        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
            // Template hasn't been applied yet
            await _checkAndApplyTemplate();
          } else {
            print(
                'Inspection already has template applied: ${inspection.templateId}');
          }
        }
      } else {
        _showErrorSnackBar('Inspection not found.');
      }
    } catch (e) {
      print("Error in _loadInspection: $e");
      if (mounted) {
        _showErrorSnackBar('Error loading inspection: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateCompletionPercentage() async {
    try {
      final percentage = await _inspectionService
          .calculateCompletionPercentage(widget.inspectionId);
      if (mounted) {
        setState(() {
          _completionPercentage = percentage;
        });
      }
    } catch (e) {
      print('Error calculating completion percentage: $e');
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
            'Starting template application: ${_inspection!.templateId} for inspection: ${_inspection!.id}');
        print(
            'Current template application status: ${_inspection!.isTemplated}');

        // Apply the template
        final success = await _inspectionService.applyTemplateToInspection(
            _inspection!.id, _inspection!.templateId!);

        print(
            'Template application result: ${success ? 'SUCCESS' : 'FAILURE'}');

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
        print('Error applying template: $e');
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
      print('No template to apply or already applied');
      if (_inspection!.isTemplated == true) {
        print('The inspection already has an applied template');
      }
      if (_inspection!.templateId == null) {
        print('No template ID associated with this inspection');
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
        print('Error in manual template application: $e');
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
      print('Error loading rooms: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading rooms: $e');
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
        await _calculateCompletionPercentage();

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
      print('Error in _addRoom: $e');
    }
  }

  Future<void> _duplicateRoom(Room room) async {
    setState(() => _isLoading = true);

    try {
      await _inspectionService.isRoomDuplicate(
          widget.inspectionId, room.roomName);

      await _loadRooms();
      await _calculateCompletionPercentage();

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

      await _calculateCompletionPercentage();
    } catch (e) {
      print('Error updating room: $e');
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
      await _calculateCompletionPercentage();

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
      print('Error loading items: $e');
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
      print('Error loading details: $e');
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

  // Método para salvar checkpoint da inspeção atual
  Future<void> _saveCheckpoint() async {
    if (_inspection == null) return;

    try {
      setState(() => _isSyncing = true);

      _checkpointCounter++;
      final timestamp = DateTime.now();

      // Criar um objeto de checkpoint com os dados atuais
      final checkpoint = {
        'id':
            'checkpoint_${_checkpointCounter}_${timestamp.millisecondsSinceEpoch}',
        'timestamp': timestamp,
        'inspection': _inspection!.toJson(),
        'completion_percentage': _completionPercentage,
      };

      // Adicionar à lista de checkpoints
      setState(() {
        _checkpoints.add(checkpoint);
      });

      // Também poderia salvar no Firestore para persistência
      // await _firestore.collection('inspection_checkpoints').add({
      //   'inspection_id': widget.inspectionId,
      //   'timestamp': FieldValue.serverTimestamp(),
      //   'data': checkpoint,
      // });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkpoint #$_checkpointCounter salvo com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving checkpoint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar checkpoint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Método para listar e restaurar checkpoints
  void _showCheckpoints() {
    if (_checkpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum checkpoint disponível'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkpoints Salvos'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _checkpoints.length,
            itemBuilder: (context, index) {
              final checkpoint = _checkpoints[_checkpoints.length - 1 - index];
              final timestamp = checkpoint['timestamp'] as DateTime;
              final formattedDate =
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);

              return ListTile(
                title: Text('Checkpoint #${_checkpoints.length - index}'),
                subtitle: Text(formattedDate),
                trailing: Text(
                    '${(checkpoint['completion_percentage'] as double).toStringAsFixed(1)}%'),
                onTap: () {
                  // Aqui implementaríamos a lógica para restaurar o checkpoint
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Restauração de checkpoints ainda não implementada'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size; // Get screen dimensions

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspeção'),
        actions: [
          // Galeria de mídia button
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () => _navigateToMediaGallery(),
            tooltip: 'Galeria de Mídia',
          ),

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

          // NEW: Checkpoint save button
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSyncing ? null : _saveCheckpoint,
            tooltip: 'Salvar Checkpoint',
          ),

          // NEW: Checkpoint history button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _checkpoints.isEmpty ? null : _showCheckpoints,
            tooltip: 'Ver Checkpoints',
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
        ],
      ),
      body: _buildBody(isLandscape, screenSize),
      // Bottom bar with 4 main functions - only show when we have rooms and aren't loading
      bottomNavigationBar: !_isLoading
          ? BottomAppBar(
              height: 60,
              color: Colors.grey[850],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Galeria de mídia
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.purple),
                    onPressed: _navigateToMediaGallery,
                    tooltip: 'Galeria de Mídia',
                  ),

                  // Não conformidades
                  IconButton(
                    icon: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NonConformityScreen(
                            inspectionId: widget.inspectionId,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Não Conformidades',
                  ),

                  // Adicionar sala - expandable with AI suggestion
                  _buildExpandableRoomButton(),

                  // Importar/Exportar - expandable
                  _buildExpandableImportExportButton(),
                ],
              ),
            )
          : null,
    );
  }

  // Expandable room button with AI suggestion option
  Widget _buildExpandableRoomButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Normal Add Room button
        IconButton(
          icon: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _animationController,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() {
              _isRoomButtonExpanded = !_isRoomButtonExpanded;
              _isExportButtonExpanded = false; // Close other expandable

              if (_isRoomButtonExpanded) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            });
          },
          tooltip: 'Adicionar Tópico',
        ),

        // Expandable menu
        if (_isRoomButtonExpanded)
          Positioned(
            bottom: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // AI suggestion button
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: AISuggestionButton(
                      icon: Icons.lightbulb_outline,
                      color: Colors.amber,
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
                        setState(() {
                          _isRoomButtonExpanded = false;
                          _animationController.reverse();
                          _isLoading = true;
                        });

                        try {
                          if (suggestion is Map<String, dynamic>) {
                            // Criar sala
                            final room = await _inspectionService.addRoom(
                              widget.inspectionId,
                              suggestion['room_name'],
                            );

                            // Criar itens e detalhes
                            if (room.id != null &&
                                suggestion['items'] != null) {
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
                                          ? List<String>.from(
                                              detailData['options'])
                                          : null,
                                    );
                                  }
                                }
                              }
                            }

                            await _loadRooms();
                            await _calculateCompletionPercentage();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Sala "${suggestion['room_name']}" criada com sucesso'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
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
                      },
                    ),
                  ),

                  // Manual Add button
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Colors.blue, size: 30),
                      tooltip: 'Adicionar tópico manualmente',
                      onPressed: () {
                        setState(() {
                          _isRoomButtonExpanded = false;
                          _animationController.reverse();
                        });
                        _addRoom();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Expandable Import/Export button
  Widget _buildExpandableImportExportButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main import/export button
        IconButton(
          icon: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _animationController,
            color: Colors.green,
          ),
          onPressed: () {
            setState(() {
              _isExportButtonExpanded = !_isExportButtonExpanded;
              _isRoomButtonExpanded = false; // Close other expandable

              if (_isExportButtonExpanded) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            });
          },
          tooltip: 'Importar/Exportar',
        ),

        // Expandable menu
        if (_isExportButtonExpanded)
          Positioned(
            bottom: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Export button
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: IconButton(
                      icon: const Icon(Icons.file_download,
                          color: Colors.green, size: 30),
                      tooltip: 'Exportar Inspeção',
                      onPressed: () {
                        setState(() {
                          _isExportButtonExpanded = false;
                          _animationController.reverse();
                        });
                        _exportInspection();
                      },
                    ),
                  ),

                  // Import button
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: IconButton(
                      icon: const Icon(Icons.file_upload,
                          color: Colors.blue, size: 30),
                      tooltip: 'Importar Inspeção',
                      onPressed: () {
                        setState(() {
                          _isExportButtonExpanded = false;
                          _animationController.reverse();
                        });
                        _importInspection();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

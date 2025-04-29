// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;


  const InspectionDetailScreen({
    super.key,
    required this.inspectionId
  });

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  double _completionPercentage = 0.0;

  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
    _loadInspection();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) || 
                      connectivityResult.contains(ConnectivityResult.mobile);
        });

        // Se voltamos a ficar online e temos um template pendente para aplicar
        if (_isOnline && _inspection != null && 
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
      final inspection = await _inspectionService.getInspection(widget.inspectionId);

      if (!mounted) return;

      if (inspection != null) {
        setState(() {
          _inspection = inspection;
        });

        // Carregar as salas da inspeção
        await _loadRooms();
        
        // Calcular o percentual de conclusão
        await _calculateCompletionPercentage();

        // Verificar se existe template para aplicar
        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
            // Template ainda não foi aplicado
            await _checkAndApplyTemplate();
          } else {
            print('Inspeção já tem template aplicado: ${inspection.templateId}');
          }
        }
      } else {
        _showErrorSnackBar('Inspeção não encontrada.');
      }
    } catch (e) {
      print("Erro em _loadInspection: $e");
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _calculateCompletionPercentage() async {
    try {
      final percentage = await _inspectionService.calculateCompletionPercentage(widget.inspectionId);
      if (mounted) {
        setState(() {
          _completionPercentage = percentage;
        });
      }
    } catch (e) {
      print('Erro ao calcular porcentagem de conclusão: $e');
    }
  }

// Snippet para InspectionDetailScreen - método _checkAndApplyTemplate corrigido
Future<void> _checkAndApplyTemplate() async {
  if (_inspection == null) return;

  // Verifica se a inspeção tem um template associado que ainda não foi aplicado
  if (_inspection!.isTemplated != true && _inspection!.templateId != null) {
    if (mounted) {
      setState(() => _isApplyingTemplate = true);
    }

    try {
      // Mostrar mensagem de carregamento
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplicando template à inspeção...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Log para diagnóstico
      print('Iniciando aplicação do template para inspeção: ${_inspection!.id}');
      print('Template ID: ${_inspection!.templateId}');
      print('Status atual de aplicação: ${_inspection!.isTemplated}');

      // Aplicar template
      final success = await _inspectionService.applyTemplateToInspection(
          _inspection!.id, _inspection!.templateId!);

      print('Resultado da aplicação do template: ${success ? 'SUCESSO' : 'FALHA'}');

      if (success) {
        // Atualizar o status da inspeção localmente
        final updatedInspection = _inspection!.copyWith(
          isTemplated: true,
          status: 'in_progress',
          updatedAt: DateTime.now(),
        );
        
        if (mounted) {
          setState(() {
            _inspection = updatedInspection;
          });
        }
        
        // Recarregar a inspeção com o template aplicado
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
              backgroundColor: Colors.orange,
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

// Método para aplicação manual do template
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
          style: TextButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: const Text('Aplicar Template'),
        ),
      ],
    ),
  ) ?? false;
  
  if (shouldApply) {
    setState(() => _isApplyingTemplate = true);
    
    try {
      // Mostrar mensagem de carregamento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplicando template à inspeção...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Forçar a configuração de template para false para permitir uma nova aplicação
      if (_inspection!.isTemplated) {
        await _firestore.collection('inspections').doc(_inspection!.id).update({
          'is_templated': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Atualizar a instância local
        setState(() {
          _inspection = _inspection!.copyWith(
            isTemplated: false,
            updatedAt: DateTime.now(),
          );
        });
      }
      
      // Aplicar o template
      await _checkAndApplyTemplate();
      
    } catch (e) {
      print('Erro na aplicação manual do template: $e');
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
      print('Erro em _addRoom: $e');
    }
  }
  
  Future<void> _duplicateRoom(Room room) async {
    setState(() => _isLoading = true);
    
    try {
      await _inspectionService.isRoomDuplicate(widget.inspectionId, room.roomName);
      
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
    final confirmed = await _importExportService.showExportConfirmationDialog(context);
    if (!confirmed) return;
    
    setState(() => _isSyncing = true);
    
    try {
      final filePath = await _importExportService.exportInspection(widget.inspectionId);
      
      if (mounted) {
        _importExportService.showSuccessMessage(
          context, 
          'Inspeção exportada com sucesso para:\n$filePath'
        );
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
          context, 
          'Erro ao exportar inspeção: $e'
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
  
  Future<void> _importInspection() async {
    final confirmed = await _importExportService.showImportConfirmationDialog(context);
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
        widget.inspectionId, 
        jsonData
      );
      
      if (success) {
        // Reload data
        await _loadInspection();
        
        if (mounted) {
          _importExportService.showSuccessMessage(
            context, 
            'Dados da inspeção importados com sucesso'
          );
        }
      } else {
        if (mounted) {
          _importExportService.showErrorMessage(
            context, 
            'Falha ao importar dados da inspeção'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
          context, 
          'Erro ao importar inspeção: $e'
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspeção'),
        actions: [
          // Sync status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOnline ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.signal_wifi_4_bar: Icons.wifi,
                  size: 12,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
          // Template apply button
          if (_isOnline && _inspection != null && _inspection!.templateId != null)
            IconButton(
              icon: const Icon(Icons.architecture),
              tooltip: _inspection!.isTemplated 
                  ? 'Reaplicar Template' 
                  : 'Aplicar Template',
              onPressed: _isApplyingTemplate ? null : _manuallyApplyTemplate,
            ),
            
          // Loading indicator
          if (_isSyncing || _isApplyingTemplate)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          
          // Menu button
          if (!(_isSyncing || _isApplyingTemplate))
            PopupMenuButton<String>(
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
                  value: 'nonConformities',
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber),
                      SizedBox(width: 8),
                      Text('Não-Conformidades'),
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
      body: _buildBody(isLandscape),
      floatingActionButton: !_isLoading && _rooms.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addRoom,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
      bottomSheet: !_isOnline
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Modo offline - Alterações serão sincronizadas quando online',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // Método para construir o corpo da tela
  Widget _buildBody(bool isLandscape) {
    if (_isLoading) {
      return LoadingState(
        isDownloading: false, 
        isApplyingTemplate: _isApplyingTemplate
      );
    }
    
    return Column(
      children: [
        // Inspection header with status and progress
        if (_inspection != null)
          InspectionHeader(
            inspection: _inspection!.toJson(),
            completionPercentage: _completionPercentage,
            isOffline: !_isOnline,
          ),

        // Main content area
        Expanded(
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
                  : RoomsList(
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
                        inspectionId: widget.inspectionId,  // Adicionar este parâmetro
                    ),
        ),
      ],
    );
  }
}
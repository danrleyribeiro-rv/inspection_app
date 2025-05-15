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
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:inspection_app/services/checkpoint_dialog_service.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_info_dialog.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  // Serviços
  final _inspectionService = FirebaseInspectionService();
  final _connectivityService = Connectivity();
  final _importExportService = ImportExportService();
  final _firestore = FirebaseFirestore.instance;
  final _checkpointService = InspectionCheckpointService();
  late CheckpointDialogService _checkpointDialogService;

  // Estados
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  bool _isRestoringCheckpoint = false;
  Inspection? _inspection;
  List<Room> _rooms = [];
  int _expandedRoomIndex = -1;

  // Estados para visualização em paisagem
  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();

    // Inicializar o serviço de diálogos de checkpoint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkpointDialogService = CheckpointDialogService(
        context,
        _checkpointService,
        _loadInspection, // Callback para recarregar dados após restauração
      );
    });

    _loadInspection();
  }

  // Monitora o estado de conectividade e reage às mudanças
  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });

        // Se estiver online e tiver um template pendente
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

  // Exibe o diálogo para criar um novo checkpoint
  void _showCreateCheckpointDialog() {
    _checkpointDialogService.showCreateCheckpointDialog(widget.inspectionId);
  }

  // Exibe o diálogo com o histórico de checkpoints
  void _showCheckpointHistory() {
    _checkpointDialogService.showCheckpointHistory(widget.inspectionId);
  }

  // Carrega os dados da inspeção
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

        // Carrega as salas da inspeção
        await _loadRooms();

        // Verifica se há um template para aplicar
        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
            // Se o template não foi aplicado ainda
            await _checkAndApplyTemplate();
          }
        }
      } else {
        _showErrorSnackBar('Inspeção não encontrada.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Verifica e aplica o template automaticamente, se necessário
  Future<void> _checkAndApplyTemplate() async {
    if (_inspection == null) return;

    // Só prossegue se a inspeção tiver um ID de template e não tiver sido aplicada ainda
    if (_inspection!.templateId != null && _inspection!.isTemplated != true) {
      setState(() => _isApplyingTemplate = true);

      try {
        // Mostra mensagem de carregamento
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplicando template à inspeção...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Aplica o template
        final success = await _inspectionService.applyTemplateToInspection(
            _inspection!.id, _inspection!.templateId!);

        if (success) {
          // Atualiza o status da inspeção localmente E no Firestore
          await _firestore
              .collection('inspections')
              .doc(_inspection!.id)
              .update({
            'is_templated': true,
            'status': 'in_progress',
            'updated_at': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            // Atualiza o estado
            final updatedInspection = _inspection!.copyWith(
              isTemplated: true,
              status: 'in_progress',
              updatedAt: DateTime.now(),
            );

            setState(() {
              _inspection = updatedInspection;
            });
          }

          // Recarrega os dados da inspeção para obter a estrutura atualizada
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
    }
  }

  // Função para aplicação manual de template (para o botão da UI)
  Future<void> _manuallyApplyTemplate() async {
    if (_inspection == null || !_isOnline || _isApplyingTemplate) return;

    // Mostrar diálogo de confirmação
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
        // Mostrar mensagem de carregamento
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplicando template à inspeção...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Forçar redefinição da flag de template no Firestore
        await _firestore.collection('inspections').doc(_inspection!.id).update({
          'is_templated': false,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Atualizar instância local
        setState(() {
          _inspection = _inspection!.copyWith(
            isTemplated: false,
            updatedAt: DateTime.now(),
          );
        });

        // Aplicar o template
        await _checkAndApplyTemplate();
      } catch (e) {
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

  // Carrega as salas da inspeção
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

        // Resetar estado de seleção
        _selectedRoomIndex = -1;
        _selectedItemIndex = -1;
        _selectedRoomItems = [];
        _selectedItemDetails = [];
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar salas: $e');
      }
    }
  }

  // Exibe mensagem de erro como SnackBar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Adiciona uma nova sala/tópico à inspeção
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

        // Expande a sala recém-adicionada
        if (_rooms.isNotEmpty) {
          setState(() {
            _expandedRoomIndex = _rooms.length - 1;
          });
        }

        // Atualiza o status da inspeção para in_progress se estava pendente
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
      // Error handling
    }
  }

  // Duplica uma sala existente
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

  // Atualiza uma sala existente
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar sala: $e')),
        );
      }
    }
  }

  // Remove uma sala existente
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

  // Métodos para visualização em paisagem
  // Seleciona uma sala e carrega seus itens
  Future<void> _handleRoomSelected(int index) async {
    if (index < 0 || index >= _rooms.length) return;

    setState(() {
      _selectedRoomIndex = index;
      _selectedItemIndex = -1;
      _selectedRoomItems = [];
      _selectedItemDetails = [];
    });

    // Carrega os itens da sala selecionada
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
      // Error handling
    }
  }

  // Seleciona um item e carrega seus detalhes
  Future<void> _handleItemSelected(int index) async {
    if (index < 0 || index >= _selectedRoomItems.length) return;

    setState(() {
      _selectedItemIndex = index;
      _selectedItemDetails = [];
    });

    // Carrega os detalhes do item selecionado
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
      // Error handling
    }
  }

  // Exporta a inspeção para um arquivo JSON
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

  // Importa a inspeção de um arquivo JSON
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
        // Recarrega os dados
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

  // Navega para a tela de galeria de mídia
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
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspeção'),
        actions: [
          // Botão de checkpoint
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 22),
            tooltip: 'Criar Checkpoint',
            onPressed: _showCreateCheckpointDialog,
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.compact,
          ),

          // Botão de aplicar template
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

          // Indicador de carregamento
          if (_isSyncing || _isApplyingTemplate || _isRestoringCheckpoint)
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

          // Botão de menu
          if (!(_isSyncing || _isApplyingTemplate || _isRestoringCheckpoint))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(8),
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: (value) async {
                switch (value) {
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
                  case 'checkpointHistory':
                    _showCheckpointHistory();
                    break;
                  case 'refresh':
                    await _loadInspection();
                    break;
                  case 'info':
                    if (_inspection != null) {
                      final inspectionId = _inspection!.id;
                      final inspectionService = FirebaseInspectionService();
                      int totalRooms = _rooms.length;
                      int totalItems = 0;
                      int totalDetails = 0;
                      int totalMedia = 0;
                      for (final room in _rooms) {
                        final items = await inspectionService.getItems(
                            inspectionId, room.id!);
                        totalItems += items.length;
                        for (final item in items) {
                          final details = await inspectionService.getDetails(
                              inspectionId, room.id!, item.id!);
                          totalDetails += details.length;
                        }
                      }
                      // Buscar mídias diretamente do Firestore
                      final doc = await FirebaseFirestore.instance
                          .collection('inspections')
                          .doc(inspectionId)
                          .get();
                      final mediaList =
                          (doc.data()?['media'] as List<dynamic>? ?? []);
                      totalMedia = mediaList.length;
                      showDialog(
                        context: context,
                        builder: (context) => InspectionInfoDialog(
                          inspection: _inspection!,
                          totalRooms: totalRooms,
                          totalItems: totalItems,
                          totalDetails: totalDetails,
                          totalMedia: totalMedia,
                        ),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
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
                // Item para histórico de checkpoints
                const PopupMenuItem(
                  value: 'checkpointHistory',
                  child: Row(
                    children: [
                      Icon(Icons.history),
                      SizedBox(width: 8),
                      Text('Histórico de Checkpoints'),
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
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Informações'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: _buildBody(isLandscape, screenSize),
      ),
    );
  }

  // Constrói o corpo principal da tela
  Widget _buildBody(bool isLandscape, Size screenSize) {
    if (_isLoading) {
      return LoadingState(
          isDownloading: false, isApplyingTemplate: _isApplyingTemplate);
    }

    if (_isRestoringCheckpoint) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 24),
            Text(
              'Restaurando checkpoint...',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Por favor, aguarde enquanto a inspeção é restaurada.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calcula a altura disponível
    final double availableHeight = screenSize.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        // Área de conteúdo principal
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

        // Espaçamento inferior
        const SizedBox(height: 2),

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
              ],
            ),
          ),
      ],
    );
  }

  // Constrói um botão de atalho para a barra inferior
  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          width: double.infinity,
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
    );
  }
}

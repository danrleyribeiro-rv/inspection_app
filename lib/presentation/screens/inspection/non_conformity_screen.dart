// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/connectivity_service.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_form.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_list.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';

class NonConformityScreen extends StatefulWidget {
  final String inspectionId;
  final dynamic preSelectedRoom; // Aceita String ou int
  final dynamic preSelectedItem; // Aceita String ou int
  final dynamic preSelectedDetail; // Aceita String ou int

  const NonConformityScreen({
    super.key,
    required this.inspectionId,
    this.preSelectedRoom,
    this.preSelectedItem,
    this.preSelectedDetail,
  });

  @override
  State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
    with SingleTickerProviderStateMixin {
  final _inspectionService = FirebaseInspectionService();
  final _connectivityService = ConnectivityService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isOffline = false;
  List<Room> _rooms = [];
  List<Item> _items = [];
  List<Detail> _details = [];
  List<Map<String, dynamic>> _nonConformities = [];

  Room? _selectedRoom;
  Item? _selectedItem;
  Detail? _selectedDetail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connectivityService.checkConnectivity().then((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load rooms
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      setState(() => _rooms = rooms);

      // Se houver pré-seleção, localizar a sala correspondente
      if (widget.preSelectedRoom != null) {
        // Procurar sala pelo ID usando toString() para comparação segura
        Room? selectedRoom;
        for (var room in _rooms) {
          if (room.id != null && room.id.toString() == widget.preSelectedRoom.toString()) {
            selectedRoom = room;
            break;
          }
        }

        // Se encontrou a sala pré-selecionada, carregá-la
        if (selectedRoom != null) {
          await _roomSelected(selectedRoom);
        } else if (_rooms.isNotEmpty) {
          // Senão, carrega a primeira sala disponível
          await _roomSelected(_rooms.first);
        }

        // Se tiver item pré-selecionado e tiver itens carregados
        if (widget.preSelectedItem != null && _items.isNotEmpty) {
          // Procurar item pelo ID
          Item? selectedItem;
          for (var item in _items) {
            if (item.id != null && item.id.toString() == widget.preSelectedItem.toString()) {
              selectedItem = item;
              break;
            }
          }

          // Se encontrou o item pré-selecionado, carregá-lo
          if (selectedItem != null) {
            await _itemSelected(selectedItem);
          } else if (_items.isNotEmpty) {
            // Senão, carrega o primeiro item disponível
            await _itemSelected(_items.first);
          }

          // Se tiver detalhe pré-selecionado e tiver detalhes carregados
          if (widget.preSelectedDetail != null && _details.isNotEmpty) {
            // Procurar detalhe pelo ID
            Detail? selectedDetail;
            for (var detail in _details) {
              if (detail.id != null && detail.id.toString() == widget.preSelectedDetail.toString()) {
                selectedDetail = detail;
                break;
              }
            }

            // Se encontrou o detalhe pré-selecionado, selecioná-lo
            if (selectedDetail != null) {
              _detailSelected(selectedDetail);
            } else if (_details.isNotEmpty) {
              // Senão, seleciona o primeiro detalhe disponível
              _detailSelected(_details.first);
            }
          }
        }
      }

      // Carregar não conformidades existentes
      await _loadNonConformities();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Erro ao carregar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNonConformities() async {
    try {
      final nonConformities = await _inspectionService.getNonConformitiesByInspection(widget.inspectionId);

      if (mounted) {
        setState(() {
          _nonConformities = nonConformities;
        });
      }
    } catch (e) {
      print('Erro ao carregar não conformidades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar não conformidades: $e')),
        );
      }
    }
  }

  Future<void> _roomSelected(Room room) async {
    setState(() {
      _selectedRoom = room;
      _selectedItem = null;
      _selectedDetail = null;
      _items = [];
      _details = [];
    });

    if (room.id != null) {
      try {
        final items = await _inspectionService.getItems(widget.inspectionId, room.id!);
        setState(() => _items = items);
      } catch (e) {
        print('Erro ao carregar itens: $e');
      }
    }
  }

  Future<void> _itemSelected(Item item) async {
    setState(() {
      _selectedItem = item;
      _selectedDetail = null;
      _details = [];
    });

    if (item.id != null && item.roomId != null) {
      try {
        final details = await _inspectionService.getDetails(
            widget.inspectionId, item.roomId!, item.id!);
        setState(() => _details = details);
      } catch (e) {
        print('Erro ao carregar detalhes: $e');
      }
    }
  }

  void _detailSelected(Detail detail) {
    setState(() => _selectedDetail = detail);
  }

  Future<void> _updateNonConformityStatus(String id, String newStatus) async {
    try {
      await _inspectionService.updateNonConformityStatus(id, newStatus);

      // Reload list
      await _loadNonConformities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  void _onNonConformitySaved() {
    // Reload the list of non-conformities
    _loadNonConformities();

    // Switch to the list tab
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Não Conformidades'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Registrar Nova'),
            Tab(text: 'Não Conformidades Existentes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                NonConformityForm(
                  rooms: _rooms,
                  items: _items,
                  details: _details,
                  selectedRoom: _selectedRoom,
                  selectedItem: _selectedItem,
                  selectedDetail: _selectedDetail,
                  inspectionId: widget.inspectionId,
                  isOffline: _isOffline,
                  onRoomSelected: _roomSelected,
                  onItemSelected: _itemSelected,
                  onDetailSelected: _detailSelected,
                  onNonConformitySaved: _onNonConformitySaved,
                ),
                NonConformityList(
                  nonConformities: _nonConformities,
                  inspectionId: widget.inspectionId,
                  onStatusUpdate: _updateNonConformityStatus,
                ),
              ],
            ),
    );
  }
}
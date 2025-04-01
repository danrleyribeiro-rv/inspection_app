// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/room_widget.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final int inspectionId;

  const InspectionDetailScreen({
    Key? key,
    required this.inspectionId,
  }) : super(key: key);

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _inspection;
  List<Room> _rooms = [];
  int _expandedRoomIndex = -1;
  
  // Para o modo paisagem
  int _selectedRoomIndex = -1;
  int _selectedItemIndex = -1;
  List<Item> _selectedRoomItems = [];
  List<Detail> _selectedItemDetails = [];

  @override
  void initState() {
    super.initState();
    _loadInspection();
  }

  Future<void> _loadInspection() async {
    setState(() => _isLoading = true);

    try {
      // Carregar dados da inspeção
      final inspectionData = await _supabase
          .from('inspections')
          .select('*')
          .eq('id', widget.inspectionId)
          .single();
      
      _inspection = inspectionData;
      
      // Carregar rooms
      await _loadRooms();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Erro ao carregar inspeção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar inspeção: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      setState(() {
        _rooms = rooms;
      });
    } catch (e) {
      print('Erro ao carregar ambientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ambientes: $e')),
        );
      }
    }
  }

  Future<void> _loadItemsForRoom(int roomIndex) async {
    if (roomIndex < 0 || roomIndex >= _rooms.length) return;
    
    final roomId = _rooms[roomIndex].id;
    if (roomId == null) return;
    
    try {
      final items = await _inspectionService.getItems(widget.inspectionId, roomId);
      setState(() {
        _selectedRoomItems = items;
        _selectedRoomIndex = roomIndex;
        _selectedItemIndex = -1; // Resetar seleção de item
        _selectedItemDetails = [];
      });
    } catch (e) {
      print('Erro ao carregar itens: $e');
    }
  }

  Future<void> _loadDetailsForItem(int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= _selectedRoomItems.length) return;
    
    final item = _selectedRoomItems[itemIndex];
    if (item.id == null || item.roomId == null) return;
    
    try {
      final details = await _inspectionService.getDetails(
        widget.inspectionId,
        item.roomId!,
        item.id!
      );
      
      setState(() {
        _selectedItemDetails = details;
        _selectedItemIndex = itemIndex;
      });
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
    }
  }

  // Adicionar um novo ambiente
  Future<void> _addRoom() async {
    final name = await _showTextInputDialog('Adicionar Ambiente', 'Nome do ambiente');
    if (name == null || name.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final newRoom = await _inspectionService.addRoom(
        widget.inspectionId,
        name,
      );
      
      await _loadRooms();
      
      // Expandir o novo ambiente
      setState(() {
        _expandedRoomIndex = _rooms.indexWhere((r) => r.id == newRoom.id);
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao adicionar ambiente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar ambiente: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Método para salvar alterações na inspeção
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
      if (_inspection?['status'] == 'pending') {
        await _supabase
            .from('inspections')
            .update({'status': 'in_progress', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', widget.inspectionId);
        
        _inspection?['status'] = 'in_progress';
      }
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeção salva com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar inspeção: $e')),
        );
      }
    }
  }

  // Método para finalizar a inspeção
  Future<void> _completeInspection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Inspeção'),
        content: const Text('Tem certeza que deseja finalizar esta inspeção?\n\nApós finalizada, não será possível realizar mais alterações.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Finalizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('inspections')
          .update({
            'status': 'completed',
            'finished_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.inspectionId);
      
      _inspection?['status'] = 'completed';
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção finalizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Voltar para a tela anterior
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao finalizar inspeção: $e')),
        );
      }
    }
  }

  // Helper para mostrar input dialog
  Future<String?> _showTextInputDialog(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result;
  }

  // Ir para tela de não conformidades
  void _navigateToNonConformities() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NonConformityScreen(inspectionId: widget.inspectionId),
      ),
    );
  }

  void _handleRoomUpdate(Room updatedRoom) {
    setState(() {
      final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
      if (index >= 0) {
        _rooms[index] = updatedRoom;
      }
    });
    
    _inspectionService.updateRoom(updatedRoom);
  }

  Future<void> _handleRoomDelete(int roomId) async {
    try {
      await _inspectionService.deleteRoom(widget.inspectionId, roomId);
      
      await _loadRooms();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ambiente removido com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover ambiente: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar se a inspeção está completa
    final bool isCompleted = _inspection?['status'] == 'completed';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_inspection?['title'] ?? 'Inspeção'),
        actions: [
          if (!isCompleted) // Apenas mostrar botão se não estiver completa
            IconButton(
              icon: const Icon(Icons.report_problem),
              tooltip: 'Não Conformidades',
              onPressed: _navigateToNonConformities,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading || isCompleted ? null : _saveInspection,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return _buildLandscapeLayout();
                } else {
                  return _buildPortraitLayout();
                }
              },
            ),
      floatingActionButton: isCompleted 
          ? null // Sem FAB para inspeções completas
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _addRoom,
                  heroTag: 'addRoom',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  onPressed: _completeInspection,
                  heroTag: 'complete',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
              ],
            ),
    );
  }

  Widget _buildPortraitLayout() {
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum ambiente adicionado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clique no botão + para adicionar ambientes',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addRoom,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Ambiente'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        
        return RoomWidget(
          room: room,
          onRoomUpdated: _handleRoomUpdate,
          onRoomDeleted: _handleRoomDelete,
          isExpanded: index == _expandedRoomIndex,
          onExpansionChanged: () {
            setState(() {
              _expandedRoomIndex = _expandedRoomIndex == index ? -1 : index;
            });
          },
        );
      },
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Coluna de ambientes
        Expanded(
          flex: 2,
          child: _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_work_outlined, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Nenhum ambiente'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addRoom,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return ListTile(
                      title: Text(room.roomName),
                      selected: _selectedRoomIndex == index,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                      onTap: () => _loadItemsForRoom(index),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          if (room.id != null) {
                            await _handleRoomDelete(room.id!);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),

        // Divisor vertical
        VerticalDivider(thickness: 1, width: 1, color: Colors.grey[300]),

        // Coluna de itens
        Expanded(
          flex: 3,
          child: _selectedRoomIndex < 0
              ? const Center(child: Text('Selecione um ambiente'))
              : Column(
                  children: [
                    // Cabeçalho com botão de adicionar item
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Itens - ${_rooms[_selectedRoomIndex].roomName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () async {
                              // Lógica para adicionar item
                              if (_selectedRoomIndex >= 0 && _rooms[_selectedRoomIndex].id != null) {
                                final name = await _showTextInputDialog('Adicionar Item', 'Nome do item');
                                if (name != null && name.isNotEmpty) {
                                  await _inspectionService.addItem(
                                    widget.inspectionId,
                                    _rooms[_selectedRoomIndex].id!,
                                    name,
                                  );
                                  await _loadItemsForRoom(_selectedRoomIndex);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de itens
                    Expanded(
                      child: _selectedRoomItems.isEmpty
                          ? const Center(child: Text('Nenhum item neste ambiente'))
                          : ListView.builder(
                              itemCount: _selectedRoomItems.length,
                              itemBuilder: (context, index) {
                                final item = _selectedRoomItems[index];
                                return ListTile(
                                  title: Text(item.itemName),
                                  selected: _selectedItemIndex == index,
                                  selectedTileColor: Colors.blue.withOpacity(0.1),
                                  onTap: () => _loadDetailsForItem(index),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      // Lógica para excluir item
                                      if (item.id != null && item.roomId != null) {
                                        await _inspectionService.deleteItem(
                                          widget.inspectionId,
                                          item.roomId!,
                                          item.id!,
                                        );
                                        await _loadItemsForRoom(_selectedRoomIndex);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),

        // Divisor vertical
        VerticalDivider(thickness: 1, width: 1, color: Colors.grey[300]),

        // Coluna de detalhes
        Expanded(
          flex: 5,
          child: _selectedItemIndex < 0
              ? const Center(child: Text('Selecione um item'))
              : Column(
                  children: [
                    // Cabeçalho com botão de adicionar detalhe
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Detalhes - ${_selectedRoomItems[_selectedItemIndex].itemName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () async {
                              // Lógica para adicionar detalhe
                              if (_selectedItemIndex >= 0) {
                                final item = _selectedRoomItems[_selectedItemIndex];
                                if (item.id != null && item.roomId != null) {
                                  final name = await _showTextInputDialog('Adicionar Detalhe', 'Nome do detalhe');
                                  if (name != null && name.isNotEmpty) {
                                    await _inspectionService.addDetail(
                                      widget.inspectionId,
                                      item.roomId!,
                                      item.id!,
                                      name,
                                    );
                                    await _loadDetailsForItem(_selectedItemIndex);
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de detalhes
                    Expanded(
                      child: _selectedItemDetails.isEmpty
                          ? const Center(child: Text('Nenhum detalhe neste item'))
                          : ListView.builder(
                              itemCount: _selectedItemDetails.length,
                              itemBuilder: (context, index) {
                                final detail = _selectedItemDetails[index];
                                return Card(
                                  margin: const EdgeInsets.all(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                detail.detailName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () async {
                                                // Lógica para excluir detalhe
                                                if (detail.id != null && detail.roomId != null && detail.itemId != null) {
                                                  await _inspectionService.deleteDetail(
                                                    widget.inspectionId,
                                                    detail.roomId!,
                                                    detail.itemId!,
                                                    detail.id!,
                                                  );
                                                  await _loadDetailsForItem(_selectedItemIndex);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Checkbox para "Danificado"
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: detail.isDamaged ?? false,
                                              onChanged: (value) async {
                                                // Atualizar o detalhe
                                                final updatedDetail = detail.copyWith(
                                                  isDamaged: value,
                                                  updatedAt: DateTime.now(),
                                                );
                                                await _inspectionService.updateDetail(updatedDetail);
                                                await _loadDetailsForItem(_selectedItemIndex);
                                              },
                                            ),
                                            const Text('Danificado'),
                                          ],
                                        ),
                                        
                                        // Campo de valor
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          initialValue: detail.detailValue,
                                          decoration: const InputDecoration(
                                            labelText: 'Valor',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) async {
                                            // Atualizar o detalhe após um delay
                                            final updatedDetail = detail.copyWith(
                                              detailValue: value,
                                              updatedAt: DateTime.now(),
                                            );
                                            await _inspectionService.updateDetail(updatedDetail);
                                          },
                                        ),
                                        
                                        // Campo de observação
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          initialValue: detail.observation,
                                          decoration: const InputDecoration(
                                            labelText: 'Observação',
                                            border: OutlineInputBorder(),
                                          ),
                                          maxLines: 3,
                                          onChanged: (value) async {
                                            // Atualizar o detalhe após um delay
                                            final updatedDetail = detail.copyWith(
                                              observation: value,
                                              updatedAt: DateTime.now(),
                                            );
                                            await _inspectionService.updateDetail(updatedDetail);
                                          },
                                        ),
                                        
                                        // Botão para adicionar não conformidade
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            // Navegar para tela de não conformidade com este detalhe pré-selecionado
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => NonConformityScreen(
                                                  inspectionId: widget.inspectionId,
                                                  preSelectedRoom: detail.roomId,
                                                  preSelectedItem: detail.itemId,
                                                  preSelectedDetail: detail.id,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.report_problem),
                                          label: const Text('Adicionar Não Conformidade'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
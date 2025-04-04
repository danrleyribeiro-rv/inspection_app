// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/inspection_service.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/widgets/non_conformity_media_widget.dart';

class NonConformityScreen extends StatefulWidget {
  final int inspectionId;
  final int? preSelectedRoom;
  final int? preSelectedItem;
  final int? preSelectedDetail;

  const NonConformityScreen({
    Key? key,
    required this.inspectionId,
    this.preSelectedRoom,
    this.preSelectedItem,
    this.preSelectedDetail,
  }) : super(key: key);

  @override
  State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  final _descriptionController = TextEditingController();
  final _correctiveActionController = TextEditingController();

  late TabController _tabController;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isOffline = false;
  DateTime? _deadline;
  String _severity = 'Média'; // Default value

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
    _checkConnectivity();
    _loadData();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Carregar ambientes
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      setState(() => _rooms = rooms);

      // Se tiver pré-seleção, carregar itens e detalhes correspondentes
      if (widget.preSelectedRoom != null) {
        final preRoom = _rooms.firstWhere(
          (r) => r.id == widget.preSelectedRoom,
          orElse: () => _rooms.first,
        );
        await _roomSelected(preRoom);

        if (widget.preSelectedItem != null && _items.isNotEmpty) {
          final preItem = _items.firstWhere(
            (i) => i.id == widget.preSelectedItem,
            orElse: () => _items.first,
          );
          await _itemSelected(preItem);

          if (widget.preSelectedDetail != null && _details.isNotEmpty) {
            final preDetail = _details.firstWhere(
              (d) => d.id == widget.preSelectedDetail,
              orElse: () => _details.first,
            );
            _detailSelected(preDetail);
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
      if (_isOffline) {
        // Carregar não conformidades do armazenamento local
        final localNCs =
            await LocalDatabaseService.getNonConformitiesByInspection(
                widget.inspectionId);

        // Converter para o formato esperado
        List<Map<String, dynamic>> formattedNCs = [];
        for (var nc in localNCs) {
          // Buscar dados de ambiente, item e detalhe
          Room? room = await LocalDatabaseService.getRoomById(nc['room_id']);
          Item? item = await LocalDatabaseService.getItemById(nc['item_id']);
          Detail? detail =
              await LocalDatabaseService.getDetailById(nc['detail_id']);

          if (room != null && item != null && detail != null) {
            formattedNCs.add({
              ...nc,
              'rooms': {
                'room_name': room.roomName,
                'id': room.id,
              },
              'room_items': {
                'item_name': item.itemName,
                'id': item.id,
              },
              'item_details': {
                'detail_name': detail.detailName,
                'id': detail.id,
              },
            });
          }
        }

        setState(() {
          _nonConformities = formattedNCs;
        });
      } else {
        // Carregar do Supabase
        final data = await _supabase
            .from('non_conformities')
            .select(
                '*, rooms!inner(*), room_items!inner(*), item_details!inner(*)')
            .eq('inspection_id', widget.inspectionId)
            .order('created_at', ascending: false);

        setState(() {
          _nonConformities = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Erro ao carregar não conformidades: $e');
      // Tentar carregar do local em caso de erro
      try {
        final localNCs =
            await LocalDatabaseService.getNonConformitiesByInspection(
                widget.inspectionId);
        setState(() {
          _nonConformities = localNCs;
        });
      } catch (localError) {
        print('Erro ao carregar não conformidades locais: $localError');
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
        final items =
            await _inspectionService.getItems(widget.inspectionId, room.id!);
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

  Future<void> _saveNonConformity() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null ||
        _selectedItem == null ||
        _selectedDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um ambiente, item e detalhe')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Preparar dados da não conformidade
      final nonConformityData = {
        'inspection_id': widget.inspectionId,
        'room_id': _selectedRoom!.id,
        'item_id': _selectedItem!.id,
        'detail_id': _selectedDetail!.id,
        'description': _descriptionController.text,
        'severity': _severity,
        'corrective_action': _correctiveActionController.text.isEmpty
            ? null
            : _correctiveActionController.text,
        'deadline': _deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      };

      int ncId;

      if (!_isOffline) {
        // Salvar online no Supabase
        try {
          final result = await _supabase
              .from('non_conformities')
              .insert(nonConformityData)
              .select('id')
              .single();

          ncId = result['id'];

          // Atualizar a lista
          await _loadNonConformities();
        } catch (e) {
          print('Erro ao salvar não conformidade no Supabase: $e');
          // Continuar para salvamento local
          ncId = -DateTime.now().millisecondsSinceEpoch;
          nonConformityData['id'] = ncId;

          // Salvar localmente
          await LocalDatabaseService.saveNonConformity(nonConformityData);
        }
      } else {
        // Salvar apenas localmente
        ncId = -DateTime.now().millisecondsSinceEpoch;
        nonConformityData['id'] = ncId;

        await LocalDatabaseService.saveNonConformity(nonConformityData);

        // Atualizar a lista
        await _loadNonConformities();
      }

      // Limpar formulário
      _descriptionController.clear();
      _correctiveActionController.clear();
      setState(() {
        _deadline = null;
        _severity = 'Média';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Mudar para a aba de visualização
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar não conformidade: $e')),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _updateNonConformityStatus(int id, String newStatus) async {
    try {
      if (!_isOffline) {
        // Atualizar no Supabase
        try {
          await _supabase.from('non_conformities').update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        } catch (e) {
          print('Erro ao atualizar status no Supabase: $e');
          // Continuar para atualização local
        }
      }

      // Atualizar localmente
      await LocalDatabaseService.updateNonConformityStatus(id, newStatus);

      // Recarregar lista
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

  Future<void> _pickDeadlineDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  void _handleMediaAdded(String path) {
    // Callback para quando uma mídia é adicionada
    // Pode ser usado para atualizar a UI ou fazer operações adicionais
    print('Mídia adicionada: $path');
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'Alta':
        return Colors.red;
      case 'Média':
        return Colors.orange;
      case 'Baixa':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
                _buildCreateForm(),
                _buildExistingList(),
              ],
            ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status de conexão
            if (_isOffline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Você está offline. As não conformidades serão sincronizadas quando você estiver online novamente.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // Seção de seleção
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Localização da Não Conformidade',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de Ambiente
                    DropdownButtonFormField<Room>(
                      decoration: const InputDecoration(
                        labelText: 'Ambiente',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedRoom,
                      items: _rooms.map((room) {
                        return DropdownMenuItem<Room>(
                          value: room,
                          child: Text(room.roomName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _roomSelected(value);
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Selecione um ambiente' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de Item
                    DropdownButtonFormField<Item>(
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedItem,
                      items: _items.map((item) {
                        return DropdownMenuItem<Item>(
                          value: item,
                          child: Text(item.itemName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _itemSelected(value);
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Selecione um item' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de Detalhe
                    DropdownButtonFormField<Detail>(
                      decoration: const InputDecoration(
                        labelText: 'Detalhe',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDetail,
                      items: _details.map((detail) {
                        return DropdownMenuItem<Detail>(
                          value: detail,
                          child: Text(detail.detailName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _detailSelected(value);
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Selecione um detalhe' : null,
                    ),
                  ],
                ),
              ),
            ),

            // Seção de detalhes da não conformidade
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalhes da Não Conformidade',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Descrição da Não Conformidade
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição da Não Conformidade',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Descreva a não conformidade';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Severidade
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Severidade',
                        border: OutlineInputBorder(),
                      ),
                      value: _severity,
                      items: const [
                        DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                        DropdownMenuItem(value: 'Média', child: Text('Média')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _severity = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Data Limite
                    InkWell(
                      onTap: _pickDeadlineDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data Limite para Correção',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _deadline == null
                              ? 'Selecione uma data'
                              : DateFormat('dd/MM/yyyy').format(_deadline!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ação Corretiva
                    TextFormField(
                      controller: _correctiveActionController,
                      decoration: const InputDecoration(
                        labelText: 'Ação Corretiva Sugerida (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            // Botão de registro
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _saveNonConformity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrar Não Conformidade'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nonConformities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text('Nenhuma não conformidade registrada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Registre uma nova não conformidade na outra aba'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _nonConformities.length,
      itemBuilder: (context, index) {
        final item = _nonConformities[index];

        // Extrair dados com segurança, considerando que podem ser nulos
        final room = item['rooms'] is Map
            ? item['rooms']
            : {'room_name': 'Ambiente não especificado'};
        final roomItem = item['room_items'] is Map
            ? item['room_items']
            : {'item_name': 'Item não especificado'};
        final detail = item['item_details'] is Map
            ? item['item_details']
            : {'detail_name': 'Detalhe não especificado'};

        // Obter cor do card baseado na severidade
        Color cardColor;
        switch (item['severity']) {
          case 'Alta':
            cardColor = Colors.red.shade50;
            break;
          case 'Média':
            cardColor = Colors.orange.shade50;
            break;
          case 'Baixa':
            cardColor = Colors.blue.shade50;
            break;
          default:
            cardColor = Colors.grey.shade50;
        }

        // Obter cor do status
        Color statusColor;
        switch (item['status']) {
          case 'pendente':
            statusColor = Colors.red;
            break;
          case 'em_andamento':
            statusColor = Colors.orange;
            break;
          case 'resolvido':
            statusColor = Colors.green;
            break;
          default:
            statusColor = Colors.grey;
        }

        String statusText;
        switch (item['status']) {
          case 'pendente':
            statusText = 'Pendente';
            break;
          case 'em_andamento':
            statusText = 'Em Andamento';
            break;
          case 'resolvido':
            statusText = 'Resolvido';
            break;
          default:
            statusText = item['status'] ?? 'Desconhecido';
        }

        // Verificar se a data de criação é válida
        DateTime? createdAt;
        try {
          createdAt = item['created_at'] != null
              ? DateTime.parse(item['created_at'])
              : null;
        } catch (e) {
          print('Erro ao converter data: ${item['created_at']}');
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(item['severity'])
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _getSeverityColor(item['severity'])),
                      ),
                      child: Text(
                        item['severity'] ?? 'Média',
                        style: TextStyle(
                          color: _getSeverityColor(item['severity']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ID: ${item['id']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Localização
                Text(
                  'Localização:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 4),
                Text(
                    '${room['room_name'] ?? "Sem nome"} > ${roomItem['item_name'] ?? "Sem nome"} > ${detail['detail_name'] ?? "Sem nome"}'),
                const SizedBox(height: 16),

                // Descrição
                Text(
                  'Descrição:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 4),
                Text(item['description'] ?? "Sem descrição"),

                // Ação corretiva se houver
                if (item['corrective_action'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Ação Corretiva:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 4),
                  Text(item['corrective_action']),
                ],

                // Data limite se houver
                if (item['deadline'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Data Limite:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy')
                      .format(DateTime.parse(item['deadline']))),
                ],

                const SizedBox(height: 16),

                // Widget de Mídia para a não conformidade
                NonConformityMediaWidget(
                  nonConformityId: item['id'],
                  inspectionId: widget.inspectionId,
                  isReadOnly: item['status'] == 'resolvido',
                  onMediaAdded: _handleMediaAdded,
                ),

                const SizedBox(height: 8),

                if (createdAt != null)
                  Text(
                    'Criado em: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),

                // Botões de ação
                if (item['status'] != 'resolvido') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item['status'] == 'pendente')
                        ElevatedButton(
                          onPressed: () => _updateNonConformityStatus(
                              item['id'], 'em_andamento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Iniciar Correção'),
                        ),
                      if (item['status'] == 'em_andamento') ...[
                        ElevatedButton(
                          onPressed: () => _updateNonConformityStatus(
                              item['id'], 'resolvido'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Marcar como Resolvido'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

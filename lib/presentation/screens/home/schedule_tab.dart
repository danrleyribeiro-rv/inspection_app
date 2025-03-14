// lib/presentation/screens/home/schedule_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _scheduledInspections = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadScheduledInspections();
  }

  Future<void> _loadScheduledInspections() async {
    try {
      setState(() => _isLoading = true);

      // Obter ID do inspetor associado ao usuário atual
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final inspectorData = await _supabase
          .from('inspectors')
          .select('id')
          .eq('user_id', userId)
          .single();

      final inspectorId = inspectorData['id'];

      // Buscar vistorias agendadas para o inspetor
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate =
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final data = await _supabase
          .from('inspections')
          .select('*')
          .eq('inspector_id', inspectorId)
          .gte('scheduled_date', startDate.toIso8601String())
          .lte('scheduled_date', endDate.toIso8601String())
          .filter('deleted_at', 'is', null) // Correct null check
          .order('scheduled_date', ascending: true);

      setState(() {
        _scheduledInspections = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar agenda: $e')),
        );
      }
    }
  }

  // Agrupamento das inspeções por data
  Map<DateTime, List<Map<String, dynamic>>> _groupInspectionsByDate() {
    final grouped = <DateTime, List<Map<String, dynamic>>>{};

    for (final inspection in _scheduledInspections) {
      if (inspection['scheduled_date'] != null) {
        try {
          final date = DateTime.parse(inspection['scheduled_date']).toLocal();
          final dateOnly = DateTime(date.year, date.month, date.day);

          if (grouped[dateOnly] == null) {
            grouped[dateOnly] = [];
          }

          grouped[dateOnly]!.add(inspection);
        } catch (e) {
          // Ignorar datas inválidas
        }
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedInspections = _groupInspectionsByDate();
    final sortedDates = groupedInspections.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScheduledInspections,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: groupedInspections.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma vistoria agendada neste mês',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final inspections = groupedInspections[date]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          '${date.day}/${date.month}/${date.year}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getWeekdayName(date.weekday),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...inspections.map((inspection) => Card(
                                      margin: const EdgeInsets.only(
                                          bottom: 12, left: 8, right: 8),
                                      child: InkWell(
                                        onTap: () {
                                          // Navegue para a tela de detalhes da vistoria
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                inspection['title'] ??
                                                    'Sem título',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _formatAddress(inspection),
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _buildStatusChip(
                                                      inspection['status']),
                                                  if (inspection['status'] ==
                                                      'pending')
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        // Iniciar vistoria
                                                      },
                                                      child:
                                                          const Text('Iniciar'),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )),
                                const Divider(),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, 1);
        _loadScheduledInspections();
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    return weekdays[weekday - 1];
  }

  // Formata o endereço
  String _formatAddress(Map<String, dynamic> inspection) {
    final street = inspection['street'] ?? '';
    final number = inspection['number'] ?? '';
    final neighborhood = inspection['neighborhood'] ?? '';
    final city = inspection['city'] ?? '';
    final state = inspection['state'] ?? '';

    return '$street, $number - $neighborhood, $city - $state';
  }

  // Constrói o chip de status
  Widget _buildStatusChip(String? status) {
    String label;
    Color color;

    switch (status) {
      case 'pending':
        label = 'Pendente';
        color = Colors.orange;
        break;
      case 'in_progress':
        label = 'Em andamento';
        color = Colors.blue;
        break;
      case 'completed':
        label = 'Concluída';
        color = Colors.green;
        break;
      case 'cancelled':
        label = 'Cancelada';
        color = Colors.red;
        break;
      default:
        label = 'Desconhecido';
        color = Colors.grey;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }
}

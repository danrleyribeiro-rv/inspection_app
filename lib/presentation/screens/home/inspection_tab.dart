// lib/presentation/screens/home/inspections_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart';

class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});

  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _inspections = [];

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
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

      // Buscar vistorias atribuídas ao inspetor
      final data = await _supabase
          .from('inspections')
          .select('*, rooms(count)')
          .eq('inspector_id', inspectorId)
          .filter('deleted_at', 'is', null) // Use .filter with 'is' for null checks
          .order('scheduled_date', ascending: true);

      setState(() {
        _inspections = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar vistorias: $e')),
        );
      }
    }
  }

  String _formatAddress(Map<String, dynamic> inspection) {
    final street = inspection['street'] ?? '';
    final number = inspection['number'] ?? '';
    final neighborhood = inspection['neighborhood'] ?? '';
    final city = inspection['city'] ?? '';
    final state = inspection['state'] ?? '';

    return '$street, $number - $neighborhood, $city - $state';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Data não definida';

    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data inválida';
    }
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String label;

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background color
      appBar: AppBar(
        title: const Text('Minhas Vistorias'),
        backgroundColor: const Color(0xFF1E293B), // Slate app bar color
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInspections,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inspections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma vistoria encontrada',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadInspections,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInspections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = _inspections[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.grey[850],
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => InspectionDetailScreen(
                                    inspectionId: inspection['id']),
                              ),
                            ).then((_) => _loadInspections());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inspection['title'] ?? 'Sem título',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildStatusChip(inspection['status']),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Endereço: ${_formatAddress(inspection)}',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Data: ${_formatDate(inspection['scheduled_date'])}',
                                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (inspection['status'] == 'pending' ||
                                        inspection['status'] == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  InspectionDetailScreen(
                                                      inspectionId:
                                                          inspection['id']),
                                            ),
                                          ).then((_) => _loadInspections());
                                        },
                                        child: Text(
                                          inspection['status'] == 'pending'
                                              ? 'Iniciar'
                                              : 'Continuar',
                                        ),
                                      ),
                                    if (inspection['status'] == 'in_progress')
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Finalizar vistoria
                                            try {
                                              await _supabase
                                                  .from('inspections')
                                                  .update({
                                                'status': 'completed',
                                                'finished_at': DateTime.now().toIso8601String()
                                              })
                                                  .eq('id', inspection['id']);

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Vistoria finalizada com sucesso!')),
                                                );
                                                _loadInspections();
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Erro ao finalizar vistoria: $e')),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          child: const Text('Finalizar'),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
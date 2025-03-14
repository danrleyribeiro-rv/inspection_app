// lib/presentation/screens/home/inspections_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart'; // Import the new screen

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
    // ... (rest of the _loadInspections method remains the same)
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

  // Calcula o progresso da vistoria com base nos dados
  double _calculateProgress(Map<String, dynamic> inspection) {
    // Implementação básica - pode ser aprimorada com dados reais
    // Aqui você pode implementar a lógica para calcular o progresso
    // com base nos itens completados vs total de itens no template
    return 0.3; // Valor de exemplo (30% concluído)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Vistorias'),
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
              ? const Center(
                  child: Text(
                    'Nenhuma vistoria encontrada',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInspections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = _inspections[index];
                      final progress = _calculateProgress(inspection);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            // Navegue para a tela de detalhes da vistoria
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => InspectionDetailScreen(
                                    inspectionId: inspection['id']),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inspection['title'] ?? 'Sem título',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
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
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Data: ${_formatDate(inspection['scheduled_date'])}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Progresso:',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (inspection['status'] == 'pending' ||
                                        inspection['status'] == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () {
                                          // Iniciar ou continuar vistoria
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  InspectionDetailScreen(
                                                      inspectionId:
                                                          inspection['id']),
                                            ),
                                          );
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
                                          onPressed: () {
                                            // Finalizar vistoria.  Implement this!
                                            _finalizeInspection(
                                                inspection['id']);
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

  Future<void> _finalizeInspection(int inspectionId) async {
    try {
      await _supabase
          .from('inspections')
          .update({
        'status': 'completed',
        'finished_at': DateTime.now().toIso8601String()
      })
          .eq('id', inspectionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vistoria finalizada com sucesso!')),
        );
        _loadInspections(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao finalizar vistoria: $e')),
        );
      }
    }
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

  // Formata a data
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Data não definida';

    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data inválida';
    }
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



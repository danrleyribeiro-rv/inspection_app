// lib/presentation/screens/inspection/components/non_conformity_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/widgets/non_conformity_media_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';

class NonConformityList extends StatelessWidget {
  final List<Map<String, dynamic>> nonConformities;
  final String inspectionId;
  final Function(String, String) onStatusUpdate;
  final Function(String) onDeleteNonConformity;
  final Function(Map<String, dynamic>) onEditNonConformity;

  const NonConformityList({
    super.key,
    required this.nonConformities,
    required this.inspectionId,
    required this.onStatusUpdate,
    required this.onDeleteNonConformity,
    required this.onEditNonConformity,
  });

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
    if (nonConformities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text('Nenhuma não conformidade registrada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Cadastre uma nova não conformidade na outra aba'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nonConformities.length,
      itemBuilder: (context, index) {
        return _buildNonConformityCard(context, nonConformities[index]);
      },
    );
  }

  Widget _buildNonConformityCard(
      BuildContext context, Map<String, dynamic> item) {
    // Extract location data
    final topic = item['topics'] is Map
        ? item['topics']
        : {'topic_name': 'Tópico não especificado'};
    final topicItem = item['topic_items'] is Map
        ? item['topic_items']
        : {'item_name': 'Item não especificado'};
    final detail = item['item_details'] is Map
        ? item['item_details']
        : {'detail_name': 'Detalhe não especificado'};

    // Get card color based on severity
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

    // Get status color
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

    // Get status text
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

    // Parse created date
    DateTime? createdAt;
    try {
      if (item['created_at'] != null) {
        if (item['created_at'] is String) {
          createdAt = DateTime.parse(item['created_at']);
        } else if (item['created_at']?.toDate != null) {
          // Handle Timestamp
          createdAt = item['created_at'].toDate();
        }
      }
    } catch (e) {
      print('Error parsing date: ${item['created_at']}');
    }

    // Generate a composite ID for the non-conformity if it doesn't have one
    String nonConformityId = item['id'] ?? '';

    // If not already in composite format, create it
    if (!nonConformityId.contains('-')) {
      nonConformityId =
          '${inspectionId}-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
    }

    // Extrair índices do nonConformityId
    final parts = nonConformityId.split('-');
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with actions
            Row(
              children: [
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Severity chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(item['severity']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: _getSeverityColor(item['severity'])),
                  ),
                  child: Text(
                    item['severity'] ?? 'Média',
                    style: TextStyle(
                      color: _getSeverityColor(item['severity']),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

                const Spacer(),

                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  onPressed: () => _showEditDialog(context, item),
                  tooltip: 'Editar não conformidade',
                  visualDensity: VisualDensity.compact,
                ),

                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  onPressed: () => _confirmDelete(context, item),
                  tooltip: 'Excluir não conformidade',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Location
            Text(
              'Localização:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${topic['topic_name'] ?? "N/A"} > ${topicItem['item_name'] ?? "N/A"} > ${detail['detail_name'] ?? "N/A"}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              'Descrição:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item['description'] ?? "Sem descrição",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),

            // Corrective action if available
            if (item['corrective_action'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Ação Corretiva:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item['corrective_action'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],

            // Deadline if available
            if (item['deadline'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Prazo:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd/MM/yyyy')
                    .format(DateTime.parse(item['deadline'])),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Media widget - using composite ID for non-conformity
            NonConformityMediaWidget(
              inspectionId: inspectionId,
              topicIndex: topicIndex!,
              itemIndex: itemIndex!,
              detailIndex: detailIndex!,
              ncIndex: ncIndex!,
              isReadOnly: item['status'] == 'resolvido',
              onMediaAdded: (_) {},
            ),

            // Created date
            if (createdAt != null)
              Text(
                'Criado em: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

            // Action buttons
            if (item['status'] != 'resolvido') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item['status'] == 'pendente')
                    ElevatedButton(
                      onPressed: () =>
                          onStatusUpdate(nonConformityId, 'em_andamento'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Iniciar Correção'),
                    ),
                  if (item['status'] == 'em_andamento') ...[
                    ElevatedButton(
                      onPressed: () =>
                          onStatusUpdate(nonConformityId, 'resolvido'),
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
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return NonConformityEditDialog(
          nonConformity: item,
          onSave: (updatedData) {
            onEditNonConformity(updatedData);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    String nonConformityId = item['id'] ?? '';

    // If not already in composite format, create it
    if (!nonConformityId.contains('-')) {
      nonConformityId =
          '${inspectionId}-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Excluir Não Conformidade'),
          content: const Text(
              'Tem certeza que deseja excluir esta não conformidade? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                onDeleteNonConformity(nonConformityId);
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }
}

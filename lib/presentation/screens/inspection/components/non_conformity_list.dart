// lib/presentation/screens/inspection/components/non_conformity_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/widgets/non_conformity_media_widget.dart';

class NonConformityList extends StatelessWidget {
  final List<Map<String, dynamic>> nonConformities;
  final String inspectionId;
  final Function(String, String) onStatusUpdate;

  const NonConformityList({
    super.key,
    required this.nonConformities,
    required this.inspectionId,
    required this.onStatusUpdate,
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
            Text('No non-conformities registered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Register a new non-conformity on the other tab'),
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
    final room = item['rooms'] is Map
        ? item['rooms']
        : {'room_name': 'Room not specified'};
    final roomItem = item['room_items'] is Map
        ? item['room_items']
        : {'item_name': 'Item not specified'};
    final detail = item['item_details'] is Map
        ? item['item_details']
        : {'detail_name': 'Detail not specified'};

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
        statusText = 'Pending';
        break;
      case 'em_andamento':
        statusText = 'In Progress';
        break;
      case 'resolvido':
        statusText = 'Resolved';
        break;
      default:
        statusText = item['status'] ?? 'Unknown';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                // Severity chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(item['severity']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: _getSeverityColor(item['severity'])),
                  ),
                  child: Text(
                    item['severity'] ?? 'Medium',
                    style: TextStyle(
                      color: _getSeverityColor(item['severity']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),

                // ID display
                Text(
                  'ID: ${item['id']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            Text(
              'Location:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            Text(
                '${room['room_name'] ?? "N/A"} > ${roomItem['item_name'] ?? "N/A"} > ${detail['detail_name'] ?? "N/A"}'),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            Text(item['description'] ?? "No description"),

            // Corrective action if available
            if (item['corrective_action'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Corrective Action:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              Text(item['corrective_action']),
            ],

            // Deadline if available
            if (item['deadline'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Deadline:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('dd/MM/yyyy')
                  .format(DateTime.parse(item['deadline']))),
            ],

            const SizedBox(height: 16),

            // Media widget
            NonConformityMediaWidget(
              nonConformityId: item['id'],
              inspectionId: inspectionId,
              isReadOnly: item['status'] == 'resolvido',
              onMediaAdded: (_) {},
            ),

            // Created date
            if (createdAt != null)
              Text(
                'Created on: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
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
                          onStatusUpdate(item['id'], 'em_andamento'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Correction'),
                    ),
                  if (item['status'] == 'em_andamento') ...[
                    ElevatedButton(
                      onPressed: () => onStatusUpdate(item['id'], 'resolvido'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Mark as Resolved'),
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
}
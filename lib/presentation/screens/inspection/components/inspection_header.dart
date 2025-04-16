// lib/presentation/screens/inspection/components/inspection_header.dart
import 'package:flutter/material.dart';

class InspectionHeader extends StatelessWidget {
  final Map<String, dynamic> inspection;
  final double completionPercentage;
  final bool isOffline;

  const InspectionHeader({
    Key? key,
    required this.inspection,
    required this.completionPercentage,
    required this.isOffline,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and sync indicators
          Row(
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(inspection['status']),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(inspection['status']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sync status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOffline ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isOffline ? 'Offline' : 'Online',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (inspection['scheduled_date'] != null)
                Text(
                  'Date: ${_formatDate(DateTime.parse(inspection['scheduled_date']))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          LinearProgressIndicator(
            value: completionPercentage,
            backgroundColor: Colors.grey[300],
            minHeight: 10,
          ),
          const SizedBox(height: 4),
          Text(
            'Progress: ${(completionPercentage * 100).toInt()}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          // Address if available
          if (inspection['street'] != null && inspection['street'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${inspection['street']}, ${inspection['city'] ?? ''} ${inspection['state'] ?? ''}',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
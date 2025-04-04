// lib/presentation/screens/inspection/components/status_indicator.dart
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final String status;
  final bool isOffline;
  final double completionPercentage;
  final DateTime? scheduledDate;
  final String? address;

  const StatusIndicator({
    Key? key,
    required this.status,
    required this.isOffline,
    required this.completionPercentage,
    this.scheduledDate,
    this.address,
  }) : super(key: key);

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sync status
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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
              if (scheduledDate != null)
                Text(
                  'Date: ${_formatDate(scheduledDate!)}',
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
          if (address != null && address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                address!,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
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
}
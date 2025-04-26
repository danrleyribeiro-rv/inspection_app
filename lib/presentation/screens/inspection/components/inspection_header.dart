// lib/presentation/screens/inspection/components/inspection_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InspectionHeader extends StatelessWidget {
  final Map<String, dynamic> inspection;
  final double completionPercentage;
  final bool isOffline;

  const InspectionHeader({
    super.key,
    required this.inspection,
    required this.completionPercentage,
    required this.isOffline,
  });

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
        return 'Pendente';
      case 'in_progress':
        return 'Em Progresso';
      case 'completed':
        return 'Concluída';
      default:
        return 'Desconhecido';
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Data não definida';
    
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Data inválida';
      }
      
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Data inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTemplate = inspection['template_id'] != null;
    final bool isTemplated = inspection['is_templated'] == true;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicators row
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
                    fontSize: 12,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Template status
              if (hasTemplate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTemplated ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isTemplated ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTemplated ? Icons.check_circle_outline : Icons.architecture,
                        size: 12,
                        color: isTemplated ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTemplated ? 'Template Aplicado' : 'Template Pendente',
                        style: TextStyle(
                          color: isTemplated ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(width: 8),
              
              const Spacer(),
              
              // Scheduled date if available
              if (inspection['scheduled_date'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Data Agendada:',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _formatDate(inspection['scheduled_date']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress label
          Row(
            children: [
              const Text(
                'Progresso:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                '${(completionPercentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Progress bar
          LinearProgressIndicator(
            value: completionPercentage,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(completionPercentage),
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          
          // Address if available
          if (_hasAddress())
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined, 
                    color: Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatAddress(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  bool _hasAddress() {
    return inspection['street'] != null && 
           inspection['street'].toString().isNotEmpty;
  }
  
  String _formatAddress() {
    final street = inspection['street'] ?? '';
    final city = inspection['city'] ?? '';
    final state = inspection['state'] ?? '';
    
    String address = street;
    
    if (city.isNotEmpty) {
      address += city.isNotEmpty ? ', $city' : '';
    }
    
    if (state.isNotEmpty) {
      address += ' - $state';
    }
    
    return address;
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage <= 0.3) {
      return Colors.red;
    } else if (percentage <= 0.7) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // Pixel 2 is 411, but handle smaller too
    
    return Container(
      width: screenWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicators row optimized for small screens
          Wrap(
            spacing: 6, // Smaller gap between chips 
            runSpacing: 6, // Smaller gap between rows
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(inspection['status']),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(inspection['status']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              
              // Template status
              if (hasTemplate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTemplated ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTemplated ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTemplated ? Icons.check_circle_outline : Icons.architecture,
                        size: 10,
                        color: isTemplated ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isTemplated ? 'Template Aplicado' : 'Template Pendente',
                        style: TextStyle(
                          color: isTemplated ? Colors.green : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Scheduled date if available
              if (inspection['scheduled_date'] != null)
                Container(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Data Agendada:',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        _formatDate(inspection['scheduled_date']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Address if available
          if (_hasAddress())
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined, 
                    color: Colors.grey,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatAddress(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: isSmallScreen ? 1 : 2,
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
    
    return address.isEmpty ? 'No address' : address;
  }
}
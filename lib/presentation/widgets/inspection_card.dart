// lib/presentation/widgets/inspection_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/widgets/map_location_card.dart';
import 'dart:developer'; // Import log for potential debugging

class InspectionCard extends StatelessWidget {
  final Map<String, dynamic> inspection;
  final Function() onViewDetails;
  final Function()? onComplete;
  final String googleMapsApiKey; // <<< Add this parameter

  const InspectionCard({
    super.key,
    required this.inspection,
    required this.onViewDetails,
    this.onComplete,
    required this.googleMapsApiKey, // <<< Make it required in the constructor
  });

  @override
  Widget build(BuildContext context) {
    // Extract location data
    final title = inspection['title'] ?? 'Untitled Inspection';
    final status = inspection['status'] ?? 'pending';
    final scheduledDate = _formatDate(inspection['scheduled_date']);

    // --- Address Extraction Logic (Keep Existing) ---
    String address = '';
    // Check if address object is available
    if (inspection['address'] is Map<String, dynamic> ||
        inspection['address'] is Map) {
      final addressData = inspection['address'] as Map;
      final street = addressData['street'] ?? '';
      final number = addressData['number'] ?? '';
      final neighborhood = addressData['neighborhood'] ?? '';
      final city = addressData['city'] ?? '';
      final state = addressData['state'] ?? '';
      final cep = addressData['cep'] ?? '';
      address = _formatAddressFromComponents(
          street, number, neighborhood, city, state, cep);
    } else if (inspection['address_string'] != null &&
        inspection['address_string'].toString().isNotEmpty) {
      // Fallback to address_string if available
      address = inspection['address_string'];
    } else {
      // Final fallback to individual fields at the root level
      final street = inspection['street'] ?? '';
      final neighborhood = inspection['neighborhood'] ?? '';
      final city = inspection['city'] ?? '';
      final state = inspection['state'] ?? '';
      final zipCode = inspection['zip_code'] ?? '';
      address = _formatAddress(street, neighborhood, city, state, zipCode);
    }
    // --- End Address Extraction ---

    // Get coordinates for map (if available)
    final double? latitude = inspection['latitude'] is num
        ? (inspection['latitude'] as num).toDouble()
        : null;
    final double? longitude = inspection['longitude'] is num
        ? (inspection['longitude'] as num).toDouble()
        : null;

    log('[InspectionCard build] Title: $title, Address: "$address", Lat: $latitude, Lng: $longitude');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[850],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status row
              Row(
                // ... (Title and Status Chip code remains the same) ...
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1, // Adjust if needed
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(status),
                ],
              ),

              // Date
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Data: $scheduledDate', // Changed 'Date' to 'Data'
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),

              // --- Map card ---
              // Pass the required googleMapsApiKey received by InspectionCard
              MapLocationCard(
                address: address,
                latitude: latitude,
                longitude: longitude,
                googleMapsApiKey: googleMapsApiKey, // <<< Pass the key down
              ),
              // --- End Map card ---

              // Action buttons
              Row(
                // ... (Button logic remains the same) ...
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Continue button (only for pending or in_progress)
                  if (status == 'pending' || status == 'in_progress')
                    ElevatedButton(
                      onPressed: onViewDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        status == 'pending' ? 'Iniciar' : 'Continuar',
                      ),
                    ),

                  // Complete button (only for in_progress)
                  if (status == 'in_progress' && onComplete != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton(
                        onPressed: onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Completar'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Functions (Keep Existing) ---
  String _formatAddressFromComponents(String street, String number,
      String neighborhood, String city, String state, String cep) {
    // ... (implementation unchanged) ...
    String address = '';
    if (street.isNotEmpty) {
      address = street;
      if (number.isNotEmpty) {
        address += ', $number';
      }
    }
    if (neighborhood.isNotEmpty) {
      address += address.isNotEmpty ? ' - $neighborhood' : neighborhood;
    }
    if (city.isNotEmpty) {
      address += address.isNotEmpty ? ', $city' : city;
      if (state.isNotEmpty) {
        address += '/$state';
      }
    } else if (state.isNotEmpty) {
      address += address.isNotEmpty ? ', $state' : state;
    }
    if (cep.isNotEmpty) {
      address += address.isNotEmpty ? ' - $cep' : cep;
    }
    return address.isEmpty
        ? 'Endereço não disponível'
        : address; // Changed fallback message
  }

  String _formatAddress(String street, String neighborhood, String city,
      String state, String zipCode) {
    // ... (implementation unchanged) ...
    String address = street;
    if (neighborhood.isNotEmpty) {
      address += address.isNotEmpty ? ' - $neighborhood' : neighborhood;
    }
    if (city.isNotEmpty) {
      address += address.isNotEmpty ? ', $city' : city;
    }
    if (state.isNotEmpty) {
      address += address.isNotEmpty ? '/$state' : state; // Use / for state
    }
    if (zipCode.isNotEmpty) {
      address += address.isNotEmpty ? ' - $zipCode' : zipCode;
    }
    return address.isEmpty
        ? 'Endereço não disponível'
        : address; // Changed fallback message
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Data não definida';

    try {
      DateTime date;
      if (dateValue is Map<String, dynamic>) {
        // Handle Firestore Timestamp Map format
        if (dateValue.containsKey('seconds') &&
            dateValue.containsKey('nanoseconds')) {
          // New Firestore Timestamp format
          final seconds = dateValue['seconds'] as int;
          final nanoseconds = dateValue['nanoseconds'] as int;
          date = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          ).toLocal();
        } else if (dateValue.containsKey('_seconds')) {
          // Legacy format support
          final seconds = dateValue['_seconds'] as int;
          final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
          date = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          ).toLocal();
        } else {
          log('[_formatDate] Invalid Timestamp map format: $dateValue');
          return 'Data inválida (Formato)';
        }
      } else if (dateValue is int) {
        // Handle timestamp as int (milliseconds)
        date = DateTime.fromMillisecondsSinceEpoch(dateValue).toLocal();
      } else if (dateValue is String) {
        // Handle ISO 8601 String
        date = DateTime.parse(dateValue).toLocal();
      } else if (dateValue.runtimeType.toString().contains('Timestamp')) {
        // Handle actual Firestore Timestamp object
        try {
          // Use dynamic invocation for Timestamp.toDate()
          final toDateMethod = (dateValue as dynamic).toDate;
          if (toDateMethod != null) {
            date = toDateMethod().toLocal();
          } else {
            throw Exception('Invalid Timestamp object: missing toDate method');
          }
        } catch (e) {
          log('[_formatDate] Error calling toDate() on Timestamp: $dateValue',
              error: e);
          return 'Data inválida (TS)';
        }
      } else {
        log('[_formatDate] Unhandled date type: ${dateValue.runtimeType}');
        return 'Data inválida (Tipo)';
      }

      // Format to Brazilian standard with time
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e, s) {
      log('[_formatDate] Error formatting date: $dateValue',
          error: e, stackTrace: s);
      return 'Data inválida (Erro)';
    }
  }

  Widget _buildStatusChip(String status) {
    // ... (implementation unchanged, using Portuguese labels) ...
    String label;
    Color color;

    switch (status) {
      case 'pending':
        label = 'Pendente';
        color = Colors.orange;
        break;
      case 'in_progress':
        label = 'Em Progresso';
        color = Colors.blue;
        break;
      case 'completed':
        label = 'Concluído';
        color = Colors.green;
        break;
      case 'cancelled':
        label = 'Cancelado';
        color = Colors.red;
        break;
      default:
        label =
            status.isNotEmpty ? status : 'Desconhecido'; // Changed 'Unknown'
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
  // --- End Helper Functions ---
}

// lib/presentation/widgets/inspection_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/widgets/common/map_location_card.dart';
import 'dart:developer'; // Import log for potential debugging

class InspectionCard extends StatelessWidget {
  final Map<String, dynamic> inspection;
  final Function() onViewDetails;
  final Function()? onComplete;
  final Function()? onSync;
  final Function()? onDownload;
  final Function()? onSyncImages; // Callback para sincronizar imagens
  final int? pendingImagesCount; // Contador de imagens pendentes
  final String googleMapsApiKey; // <<< Add this parameter
  final bool isFullyDownloaded; // Status de download completo
  final double downloadProgress; // Progresso de download (0.0 a 1.0)
  final bool needsSync; // Se a inspeção tem mudanças que precisam ser sincronizadas

  const InspectionCard({
    super.key,
    required this.inspection,
    required this.onViewDetails,
    this.onComplete,
    this.onSync,
    this.onDownload,
    this.onSyncImages,
    this.pendingImagesCount,
    required this.googleMapsApiKey, // <<< Make it required in the constructor
    this.isFullyDownloaded = false,
    this.downloadProgress = 0.0,
    this.needsSync = false,
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
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[850],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1, // Adjust if needed
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSyncIndicator(),
                  const SizedBox(width: 4),
                  _buildStatusChip(status),
                ],
              ),

              // Date
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Text(
                  'Data: $scheduledDate', // Changed 'Date' to 'Data'
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
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

              // Download progress indicator (if downloading)
              if (downloadProgress > 0.0 && downloadProgress < 1.0) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Baixando...',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                        Text(
                          '${(downloadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: Colors.grey[700],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 3,
                    ),
                  ],
                ),
              ],
              
              
              const SizedBox(height: 8),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side buttons (Sync and Download)
                  Flexible(
                    flex: 1,
                    child: Row(
                      children: [
                        // Sync button - only show if inspection has been downloaded and needs sync
                        if (onSync != null && isFullyDownloaded && needsSync)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Call both sync functions if they exist
                                if (onSync != null) {
                                  await onSync!();
                                }
                                if (onSyncImages != null) {
                                  await onSyncImages!();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                              ),
                              icon: pendingImagesCount != null && pendingImagesCount! > 0
                                ? Badge(
                                    label: Text('${pendingImagesCount!}'),
                                    child: const Icon(Icons.cloud_upload, size: 12),
                                  )
                                : const Icon(Icons.cloud_upload, size: 12),
                              label: const Text('Sincronizar', style: TextStyle(fontSize: 10)),
                            ),
                          ),
                        
                        if (onSync != null && isFullyDownloaded && needsSync && onDownload != null) const SizedBox(width: 4),
                        
                        // Download button - only show if inspection is not fully downloaded
                        if (onDownload != null && !isFullyDownloaded)
                          Expanded(
                            child: downloadProgress > 0 && downloadProgress < 1 
                              ? Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.green, width: 1),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.cloud_download, size: 10, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Baixando ${(downloadProgress * 100).toInt()}%',
                                            style: const TextStyle(fontSize: 9, color: Colors.green),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      LinearProgressIndicator(
                                        value: downloadProgress,
                                        backgroundColor: Colors.grey[600],
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                        minHeight: 2,
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: onDownload,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.cloud_download, size: 12),
                                  label: const Text('Baixar', style: TextStyle(fontSize: 10)),
                                ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Right side buttons
                  Flexible(
                    flex: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Continue/View button - only show if downloaded
                        if (isFullyDownloaded && (status == 'pending' || status == 'in_progress' || status == 'completed'))
                          ElevatedButton(
                            onPressed: onViewDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6F4B99),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            ),
                            child: Text(
                              status == 'pending' ? 'Iniciar' : status == 'completed' ? 'Visualizar' : 'Continuar',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                        // Complete button (only for in_progress and if fully downloaded)
                        if (status == 'in_progress' && onComplete != null && isFullyDownloaded) ...[
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: onComplete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            ),
                            child: const Text('Completar', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
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

      // Format to Brazilian standard without time
      return DateFormat('dd/MM/yyyy').format(date);
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
        color = Color(0xFF6F4B99);
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
        color: color.withAlpha((255 * 0.2).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    // Use the needsSync property directly
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: needsSync ? Colors.orange.withAlpha(51) : Colors.green.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsSync ? Colors.orange : Colors.green,
          width: 1,
        ),
      ),
      child: Icon(
        needsSync ? Icons.cloud_sync : Icons.cloud_done,
        size: 12,
        color: needsSync ? Colors.orange : Colors.green,
      ),
    );
  }
  // --- End Helper Functions ---
}

// lib/presentation/widgets/inspection_card.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/presentation/widgets/common/map_location_card.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

class InspectionCard extends StatelessWidget {
  final Map<String, dynamic> inspection;
  final Function() onViewDetails;
  final Function()? onSync;
  final Function()? onDownload;
  final Function()? onSyncImages; // Callback para sincronizar imagens
  final Function()? onRemove; // Callback para remover inspeção
  final Function()? onCancelSync; // Callback para cancelar sincronização
  final int? pendingImagesCount; // Contador de imagens pendentes
  final String googleMapsApiKey;
  final bool isFullyDownloaded; // Status de download completo
  final double downloadProgress; // Progresso de download (0.0 a 1.0)
  final bool hasConflicts; // Se a inspeção tem conflitos com a versão na nuvem
  final bool isSyncing; // Se está sincronizando no momento
  final bool isVerified; // Se foi verificado na nuvem
  final DateTime? lastSyncDate; // Data da última sincronização

  const InspectionCard({
    super.key,
    required this.inspection,
    required this.onViewDetails,
    this.onSync,
    this.onDownload,
    this.onSyncImages,
    this.onRemove,
    this.onCancelSync,
    this.pendingImagesCount,
    required this.googleMapsApiKey, // <<< Make it required in the constructor
    this.isFullyDownloaded = false,
    this.downloadProgress = 0.0,
    this.hasConflicts = false,
    this.isSyncing = false,
    this.isVerified = false,
    this.lastSyncDate,
  });

  @override
  Widget build(BuildContext context) {
    // Extract location data
    final title = inspection['title'] ?? 'Untitled Inspection';
    final cod = inspection['cod'] ?? '';
    final scheduledDate = DateFormatter.formatDate(inspection['scheduled_date']);

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


    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF4A148C),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: isSyncing ? null : onViewDetails,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (cod.isNotEmpty)
                          Text(
                            cod,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasConflicts)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepOrange, width: 1),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        size: 12,
                        color: Colors.deepOrange,
                      ),
                    ),
                  // Remove button in top-right corner
                  if (onRemove != null && isFullyDownloaded) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: IconButton(
                        onPressed: () => _showRemoveDialog(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        tooltip: 'Remover inspeção',
                      ),
                    ),
                  ],
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

              // Last sync date
              if (lastSyncDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sync,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Última sincronização: ${DateFormatter.formatDateTime(lastSyncDate)}',
                        style: const TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ],
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
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: Colors.grey[700],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.green),
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
                        // Sync button - always show if inspection has been downloaded (always sync all data)
                        if (onSync != null && isFullyDownloaded)
                          Expanded(
                            child: _buildSyncButton(),
                          ),

                        if (onSync != null &&
                            isFullyDownloaded &&
                            onDownload != null)
                          const SizedBox(width: 4),

                        // Download button - only show if inspection is not fully downloaded
                        if (onDownload != null && !isFullyDownloaded)
                          Expanded(
                            child: downloadProgress > 0 && downloadProgress < 1
                                ? Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.green, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.cloud_download,
                                                size: 10, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Baixando ${(downloadProgress * 100).toInt()}%',
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.green),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        LinearProgressIndicator(
                                          value: downloadProgress,
                                          backgroundColor: Colors.grey[600],
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Colors.green),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.cloud_download,
                                        size: 12),
                                    label: const Text('Baixar',
                                        style: TextStyle(fontSize: 10)),
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
                        // Continue button - always show if downloaded, but disabled during sync
                        if (isFullyDownloaded)
                          ElevatedButton(
                            onPressed: isSyncing ? null : onViewDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6F4B99),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              disabledBackgroundColor: Colors.grey,
                              disabledForegroundColor: Colors.white70,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: isSyncing ? Colors.white70 : Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  isSyncing ? 'Aguarde...' : 'Editar',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
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

  // --- Sync Button Builders ---

  Widget _buildSyncButton() {
    
    return ElevatedButton(
      onPressed: isSyncing ? null : () async {
        // Show conflict warning if there are conflicts
        if (hasConflicts) {
          // This will be handled by the parent widget
          await onSync!();
        } else {
          // Call both sync functions if they exist
          if (onSync != null) {
            await onSync!();
          }
          if (onSyncImages != null) {
            await onSyncImages!();
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isVerified 
            ? Colors.green 
            : (isSyncing ? Colors.orange.withValues(alpha: 0.7) : Colors.orange),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: isSyncing ? 1 : 2,
        disabledBackgroundColor: Colors.orange.withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: isSyncing
          ? Builder(
              builder: (context) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Sincronizando...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Cancel button
                    InkWell(
                      onTap: onCancelSync,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          : Builder(
              builder: (context) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSyncIcon(),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _getSyncButtonText(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSyncIcon() {
    if (isVerified) {
      return const Icon(Icons.cloud_done, size: 16);
    }
    
    if (pendingImagesCount != null && pendingImagesCount! > 0) {
      return Badge(
        label: Text('$pendingImagesCount'),
        child: const Icon(Icons.cloud_upload, size: 16),
      );
    }
    
    return const Icon(Icons.cloud_upload, size: 16);
  }

  String _getSyncButtonText() {
    if (isVerified) return 'Verificado';
    return 'Sincronizar';
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

  // --- Remove Dialog ---
  Future<void> _showRemoveDialog(BuildContext context) async {
    final title = inspection['title'] ?? 'Inspeção';
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Remover Inspeção',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tem certeza que deseja remover a inspeção "$title" do dispositivo?',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta ação não pode ser desfeita. Todos os dados locais desta inspeção serão perdidos.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRemove!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  // --- End Helper Functions ---
}

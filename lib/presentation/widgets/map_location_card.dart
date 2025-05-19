// lib/presentation/widgets/map_location_card.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLocationCard extends StatelessWidget {
  final String address;
  final double? latitude;
  final double? longitude;
  final String googleMapsApiKey; // <<< Chave recebida via construtor

  const MapLocationCard({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
    required this.googleMapsApiKey, // <<< Torna a chave obrigatória no construtor
  });

  // _openMap não precisa da chave API estática, então permanece igual
  Future<void> _openMap() async {
    // ... (código _openMap inalterado) ...
    String url;
    final lat = latitude;
    final lon = longitude;

    log('[_openMap] Attempting to open map. Lat: $lat, Lng: $lon, Address: $address');

    if (lat != null && lon != null) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
      log('[_openMap] Using coordinates URL: $url');
    } else if (address.trim().isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(address);
      url = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
      log('[_openMap] Using address URL: $url');
    } else {
      log('[_openMap] Cannot open map: No coordinates and empty address.');
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        log('[_openMap] Launching URL: $uri');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        log('[_openMap] Could not launch $url',
            error: 'canLaunchUrl returned false');
      }
    } catch (e, s) {
      log('[_openMap] Error launching map', error: e, stackTrace: s);
    }
  }

  // Helper para construir a URL do Mapa Estático
  String? _buildStaticMapUrl() {
    const String baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
    const String size = '600x300'; // Tamanho da imagem solicitada
    const String zoom = '15';
    String markerPath;
    String centerPath;

    final lat = latitude;
    final lon = longitude;

    log('[_buildStaticMapUrl] Building URL. Lat: $lat, Lng: $lon, Address: "$address"');

    // Prioriza coordenadas
    if (lat != null && lon != null) {
      centerPath = '$lat,$lon';
      markerPath = 'markers=color:red%7Clabel:L%7C$lat,$lon';
      log('[_buildStaticMapUrl] Using coordinates.');
    } else if (address.trim().isNotEmpty) {
      // Usa endereço se não houver coordenadas
      final encodedAddress = Uri.encodeComponent(address);
      centerPath = encodedAddress;
      markerPath = 'markers=color:red%7Clabel:L%7C$encodedAddress';
      log('[_buildStaticMapUrl] Using address.');
    } else {
      // Impossível gerar URL
      log('[_buildStaticMapUrl] Cannot build URL: No location info.');
      return null;
    }

    // --- VERIFICA A CHAVE RECEBIDA ---
    // Verifica se a chave fornecida não está vazia ou é um placeholder óbvio
    if (googleMapsApiKey.isEmpty || googleMapsApiKey == 'SUA_CHAVE_API_AQUI') {
      log('[_buildStaticMapUrl] ERROR: Google Maps API Key is missing or invalid!',
          error: 'API Key Missing/Invalid in constructor');
      return null; // Não tenta fazer a chamada sem uma chave válida
    }
    // --- FIM DA VERIFICAÇÃO ---

    // Usa a chave API passada via construtor
    final url =
        '$baseUrl?center=$centerPath&zoom=$zoom&size=$size&$markerPath&key=$googleMapsApiKey';
    log('[_buildStaticMapUrl] Generated Static Map URL: $url');
    return url;
  }

  @override
  Widget build(BuildContext context) {
    log('[MapLocationCard build] Addr: "$address", Lat: $latitude, Lng: $longitude');

    // Obtém a URL usando a função helper que agora usa a chave do construtor
    final String? staticMapUrl = _buildStaticMapUrl();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção da Imagem do Mapa
          SizedBox(
            height: 125,
            width: double.infinity,
            child: staticMapUrl != null
                ? Image.network(
                    staticMapUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      log('[MapLocationCard Image.network] Error loading map image.',
                          error: error, stackTrace: stackTrace);
                      return _buildPlaceholderMap(
                          error: true); // Mostra placeholder com erro
                    },
                  )
                : _buildPlaceholderMap(), // Mostra placeholder se a URL não pôde ser criada
          ),

          // Detalhes da Localização (inalterado)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (Ícone e Texto do Endereço inalterados) ...
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address.trim().isNotEmpty
                            ? address
                            : 'Endereço não fornecido',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                // Botão "Abrir no Google Maps" (inalterado)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: (latitude != null && longitude != null) ||
                              address.trim().isNotEmpty
                          ? _openMap
                          : null,
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Abrir no Google Maps'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        disabledForegroundColor: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder (inalterado)
  Widget _buildPlaceholderMap({bool error = false}) {
    log('[MapLocationCard _buildPlaceholderMap] Displaying placeholder. Error loading: $error');
    return Container(
      // ... (código do _buildPlaceholderMap inalterado) ...
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.map_outlined,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            error
                ? 'Não foi possível carregar o mapa'
                : 'Localização indisponível',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

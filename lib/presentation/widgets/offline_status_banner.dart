// lib/presentation/widgets/offline_status_banner.dart - corrigido
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
class OfflineStatusBanner extends StatefulWidget {
  const OfflineStatusBanner({super.key});

  @override
  State<OfflineStatusBanner> createState() => _OfflineStatusBannerState();
}

class _OfflineStatusBannerState extends State<OfflineStatusBanner> {
  final _connectivityService = Connectivity();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    
    // Subscrever para mudanças de conectividade
    _connectivityService.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = results.any((result) => result != ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se estiver online, não mostrar nada
    if (_isOnline) return const SizedBox.shrink();
    
    // Se estiver offline, mostrar o banner
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: Colors.red,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            // Usar Expanded para evitar overflow
            Expanded(
              child: Text(
                'Modo Offline - Mudanças serão sincronizadas quando online',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
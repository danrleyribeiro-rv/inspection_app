// lib/services/connectivity/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Stream controller for connectivity status
  final _connectivity = Connectivity();
  bool _isOffline = false;
  
  // Stream controller for connectivity status
  final _connectivityStreamController = StreamController<bool>.broadcast();
  
  // Stream getter
  Stream<bool> get onConnectivityChanged => _connectivityStreamController.stream;
  
  // Current status getter
  bool get isOffline => _isOffline;
  
  Future<void> initialize() async {
    // Initial check
    _isOffline = await checkConnectivity();
    _connectivityStreamController.add(_isOffline);
    
    // Listen for further changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  Future<bool> checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult == ConnectivityResult.none;
  }
  
  void _updateConnectionStatus(ConnectivityResult result) {
    final isOffline = result == ConnectivityResult.none;
    
    // Only notify if status changed
    if (_isOffline != isOffline) {
      _isOffline = isOffline;
      _connectivityStreamController.add(_isOffline);
    }
  }
  
  void dispose() {
    _connectivityStreamController.close();
  }
}
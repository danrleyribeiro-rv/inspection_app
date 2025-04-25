// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  factory ConnectivityService() {
    return _instance;
  }
  
  ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;
  
  // Initialize and start listening for connectivity changes
  void initialize() {
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    checkConnectivity();
  }
  
  // Check current connectivity
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    final isOnline = result != ConnectivityResult.none;
    _connectivityController.add(isOnline);
    return isOnline;
  }
  
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
    _connectivityController.add(isOnline);
  }
  
  // Dispose resources
  void dispose() {
    _connectivityController.close();
  }
}
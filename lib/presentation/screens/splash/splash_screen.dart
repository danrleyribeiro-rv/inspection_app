// lib/presentation/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/connectivity_service.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final _auth = FirebaseService().auth;
  final _connectivityService = ConnectivityService();
  bool _isOnline = false;
  
  @override
  void initState() {
    super.initState();
    
    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _animationController.forward();
    
    // Check connectivity
    _checkConnectivityAndProceed();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkConnectivityAndProceed() async {
    _isOnline = await _connectivityService.checkConnectivity();
    
    // Slight delay to show animation
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if user is already logged in
    final currentUser = _auth.currentUser;
    
    if (!mounted) return;
    
    if (currentUser != null) {
      // Check if any pending inspections need sync
      if (_isOnline) {
        _tryToSyncPendingData();
      }
      
      // User already logged in, navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // User not logged in, navigate to get started page
      Navigator.of(context).pushReplacementNamed('/get-started');
    }
  }
  
  Future<void> _tryToSyncPendingData() async {
    try {
      final inspectionService = FirebaseInspectionService();
      
      // No need to explicitly call sync functions as Firebase will 
      // handle this automatically when reconnected
      
      // Just log the attempt
      print('Online connection detected. Firebase will automatically sync pending changes.');
    } catch (e) {
      print('Error attempting to sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animation
            FadeTransition(
              opacity: _animation,
              child: Image.asset(
                'assets/images/logo.png',
                height: 150,
                width: 150,
              ),
            ),
            const SizedBox(height: 24),
            
            // App name
            FadeTransition(
              opacity: _animation,
              child: const Text(
                'Inspection App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            
            const SizedBox(height: 24),
            
            // Network status indicator
            FadeTransition(
              opacity: _animation,
              child: StreamBuilder<bool>(
                stream: _connectivityService.onConnectivityChanged,
                initialData: _isOnline,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? false;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// lib/presentation/screens/splash/splash_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/firebase_service.dart'; // Assuming this path is correct
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
  final _connectivityService = Connectivity();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
    _checkConnectivityAndProceed(delaySeconds: 4); // GIF is ~4s, let it play a bit
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivityAndProceed({int delaySeconds = 2}) async {
    final connectivityResult = await _connectivityService.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;

    await Future.delayed(Duration(seconds: delaySeconds));

    if (!mounted) return;

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      if (_isOnline) {
        _tryToSyncPendingData();
      }
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/get-started');
    }
  }

  Future<void> _tryToSyncPendingData() async {
    try {
      print('Conexão online detectada. O Firebase irá sincronizar automaticamente as alterações pendentes.');
    } catch (e) {
      print('Erro ao tentar sincronizar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // For debugging or understanding:
    // final screenWidth = MediaQuery.of(context).size.width;
    // final screenHeight = MediaQuery.of(context).size.height;
    // print("Screen Logical Size: ${screenWidth}w x ${screenHeight}h");

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Black background for the GIF
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _animation,
              child: Image.asset(
                'assets/gifs/demo_lince_splash_screen.gif', // Ensure this path is correct
                width: 720.0, // <<< SETTING WIDTH TO 720 LOGICAL PIXELS
                // Height is intentionally omitted here.
                // BoxFit.contain will use the width and the image's aspect ratio
                // to determine the correct height to display the entire image.
                fit: BoxFit.contain, // Ensures the entire GIF is visible and scaled proportionally
              ),
            ),
            // You might need to adjust the spacing below if the GIF becomes very tall
            const SizedBox(height: 20), // Reduced spacing a bit

            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),

            const SizedBox(height: 16), // Reduced spacing a bit

            FadeTransition(
              opacity: _animation,
              child: StreamBuilder<ConnectivityResult>(
                stream: _connectivityService.onConnectivityChanged.map(
                    (results) => results.firstWhere((r) => true, orElse: () => ConnectivityResult.none)),
                initialData: _isOnline ? ConnectivityResult.wifi : ConnectivityResult.none,
                builder: (context, snapshot) {
                  final currentConnectivity = snapshot.data;
                  final isOnlineNow = currentConnectivity != ConnectivityResult.none;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOnlineNow ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnlineNow ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnlineNow ? 'Online' : 'Offline',
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
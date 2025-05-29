// lib/presentation/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
  with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ServiceFactory _serviceFactory = ServiceFactory();

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

    Future.delayed(const Duration(seconds: 4), _proceedToNextScreen);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _proceedToNextScreen() async {
    if (!mounted) return;

    final currentUser = _serviceFactory.authService.currentUser;
    if (currentUser != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/get-started');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                fit: BoxFit
                    .contain, // Ensures the entire GIF is visible and scaled proportionally
              ),
            ),
            // You might need to adjust the spacing below if the GIF becomes very tall
            const SizedBox(height: 20), // Reduced spacing a bit

            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),

            const SizedBox(height: 16), // Reduced spacing a bit
          ],
        ),
      ),
    );
  }
}

// lib/presentation/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  // Duração total do splash
  static const Duration _totalSplashDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    // Agenda a navegação para a próxima tela após a duração total
    Timer(_totalSplashDuration, _proceedToNextScreen);
  }

  Future<void> _proceedToNextScreen() async {
    if (!mounted) return;

    try {
      final currentUser = _serviceFactory.authService.currentUser;
      if (mounted) {
        if (currentUser != null) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/get-started');
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar usuário: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/get-started');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF6F4B99), // Cor de fundo roxa especificada
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo reduzido
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            // Loading spinner
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3.0,
            ),
          ],
        ),
      ),
    );
  }
}

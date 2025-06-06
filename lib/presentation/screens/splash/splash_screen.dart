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
    with TickerProviderStateMixin {
  late AnimationController _firstImageController;
  late Animation<double> _firstImageAnimation;

  late AnimationController _secondImageController;
  late Animation<double> _secondImageAnimation;

  final ServiceFactory _serviceFactory = ServiceFactory();

  // Duração total do splash
  static const Duration _totalSplashDuration = Duration(seconds: 4);
  // Duração da transição (fade in) de cada imagem
  static const Duration _fadeDuration = Duration(milliseconds: 1000);
  // Ponto no tempo em que a segunda imagem começa a aparecer
  static const Duration _secondImageStartTime = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    // Controller para a primeira imagem
    _firstImageController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _firstImageAnimation = CurvedAnimation(
      parent: _firstImageController,
      curve: Curves.easeIn,
    );

    // Controller para a segunda imagem
    _secondImageController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _secondImageAnimation = CurvedAnimation(
      parent: _secondImageController,
      curve: Curves.easeIn,
    );

    // Inicia a animação da primeira imagem
    _firstImageController.forward();

    // Agenda o início da animação da segunda imagem
    Timer(_secondImageStartTime, () {
      if (mounted) {
        _secondImageController.forward();
      }
    });

    // Agenda a navegação para a próxima tela após a duração total
    Timer(_totalSplashDuration, _proceedToNextScreen);
  }

  @override
  void dispose() {
    _firstImageController.dispose();
    _secondImageController.dispose();
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
      backgroundColor: Colors.black, // Fundo de segurança
      body: Stack(
        fit: StackFit.expand, // Faz o Stack preencher a tela
        children: [
          // Imagem 1 (fundo)
          FadeTransition(
            opacity: _firstImageAnimation,
            child: Image.asset(
              'assets/splash_screen/imagem_01.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Imagem 2 (frente)
          FadeTransition(
            opacity: _secondImageAnimation,
            child: Image.asset(
              'assets/splash_screen/imagem_02.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // A CORREÇÃO: Adicionando o indicador de loading
          Positioned(
            // Posiciona o loading na parte inferior da tela
            bottom: MediaQuery.of(context).size.height *
                0.15, // 15% da altura da tela a partir de baixo
            // Centraliza horizontalmente
            left: 0,
            right: 0,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3.0, // Deixa a linha um pouco mais grossa
              ),
            ),
          ),
        ],
      ),
    );
  }
}

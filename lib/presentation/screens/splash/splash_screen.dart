// lib/presentation/screens/splash/splash_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/firebase_service.dart';
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
    
    // Configurar animação
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _animationController.forward();
    
    // Verificar conectividade
    _checkConnectivityAndProceed();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkConnectivityAndProceed() async {
    final connectivityResult = await _connectivityService.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
    
    // Pequeno atraso para mostrar animação
    await Future.delayed(const Duration(seconds: 2));
    
    // Verificar se o usuário já está logado
    final currentUser = _auth.currentUser;
    
    if (!mounted) return;
    
    if (currentUser != null) {
      // Verificar se há inspeções pendentes que precisam de sincronização
      if (_isOnline) {
        _tryToSyncPendingData();
      }
      
      // Usuário já está logado, navegar para a home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Usuário não está logado, navegar para a tela de início
      Navigator.of(context).pushReplacementNamed('/get-started');
    }
  }
  
  Future<void> _tryToSyncPendingData() async {
    try {
      // FirebaseInspectionService is not explicitly used here, as Firebase handles synchronization automatically.
      
      // Não é necessário chamar funções de sincronização explicitamente, pois o Firebase
      // fará isso automaticamente ao reconectar
      
      // Apenas registrar a tentativa
      print('Conexão online detectada. O Firebase irá sincronizar automaticamente as alterações pendentes.');
    } catch (e) {
      print('Erro ao tentar sincronizar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Cor de fundo Slate
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animação do logo
            FadeTransition(
              opacity: _animation,
              child: Image.asset(
                'assets/images/logo.png',
                height: 150,
                width: 150,
              ),
            ),
            const SizedBox(height: 24),
            
            // Nome do aplicativo
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
            
            // Indicador de carregamento
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            
            const SizedBox(height: 24),
            
            // Indicador de status de rede
            FadeTransition(
              opacity: _animation,
              child: StreamBuilder<bool>(
                stream: _connectivityService.onConnectivityChanged.map(
                  (results) => results.any((result) => result != ConnectivityResult.none),
                ),
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
// lib/presentation/screens/splash/splash_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/services/local_database_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Primeiro verifica a conectividade antes de qualquer operação
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult == ConnectivityResult.none;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (isFirstTime) {
        await prefs.setBool('isFirstTime', false);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/get-started');
        }
        return;
      }

      // Se estiver offline, vá direto para verificação de dados locais
      if (isOffline) {
        _handleOfflineNavigation();
        return;
      }

      // Check for deep links from password reset flow
      final uri = Uri.base;
      if (uri.toString().contains('type=recovery')) {
        // Handle password reset flow
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/reset-password');
        }
        return;
      }

      // Se online, tenta verificar a sessão
      try {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // Se session existe, vá para home
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // Sem sessão ativa, ir para login
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } catch (e) {
        // Se houver erro de conexão, trate como offline
        print('Erro de autenticação: $e');
        _handleOfflineNavigation();
      }
    } catch (e) {
      // Em caso de erro, verifique se é um problema de rede
      if (e is SocketException || e.toString().contains('SocketException') || isOffline) {
        _handleOfflineNavigation();
      } else {
        print('Erro durante inicialização: $e');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  // Método específico para lidar com navegação em modo offline
  Future<void> _handleOfflineNavigation() async {
    // Verificar se há dados locais
    final hasLocalData = await _hasLocalData();
    
    if (hasLocalData) {
      if (mounted) {
        // Ir para home com mensagem de modo offline
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo offline ativado. Seus dados estão disponíveis localmente.'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      // Sem dados locais, mostrar tela de erro de conexão
      if (mounted) {
        _showOfflineLoginError();
      }
    }
  }

  // Check if there's any local data (inspections)
  Future<bool> _hasLocalData() async {
    try {
      final inspections = await LocalDatabaseService.getAllInspections();
      return inspections.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar dados locais: $e');
      return false;
    }
  }

  // Show error message when trying to login offline
  void _showOfflineLoginError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sem conexão'),
        content: const Text(
          'Você está offline e ainda não tem dados salvos localmente. '
          'Conecte-se à internet para fazer login pela primeira vez.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Verificar conectividade novamente
              Connectivity().checkConnectivity().then((result) {
                if (result != ConnectivityResult.none) {
                  // Se voltar online, continue para login
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  // Ainda offline, tentar novamente
                  Navigator.of(context).pop();
                  _navigateToNext();
                }
              });
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a237e), // Azul escuro
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
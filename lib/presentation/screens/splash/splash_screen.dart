// lib/presentation/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/get-started');
      }
    } else {
      // Check for deep links from password reset flow
      final uri = Uri.base;
      if (uri.toString().contains('type=recovery')) {
        // Handle password reset flow
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/reset-password');
          return;
        }
      }

      // Verifica se há uma sessão ativa (usuário já logado)
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Check if session is still valid
        try {
          // If the session is expired, refreshSession() will renew it
          if (session.isExpired) {
            await Supabase.instance.client.auth.refreshSession();
          }
          
          // Attempt to make a simple request to verify the session
          await Supabase.instance.client.from('inspectors').select('id').limit(1);

          // If no error, session is valid, go to home screen
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } catch (e) {
          // Session is likely expired or invalid, sign out and go to login
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        // No active session, go to login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
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
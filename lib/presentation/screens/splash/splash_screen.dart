// lib/presentation/screens/splash/splash_screen.dart
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

    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/get-started');
      }
      return;
    }

    // Check for deep links from password reset flow
    final uri = Uri.base;
    if (uri.toString().contains('type=recovery')) {
      // Handle password reset flow
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/reset-password');
        return;
      }
    }

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult == ConnectivityResult.none;

    if (isOffline) {
      // Offline mode - check if there's a locally stored active session
      final hasLocalInspections = await _hasLocalData();
      if (hasLocalInspections) {
        // There are local inspections, allow offline access
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }
    }

    // Online mode or no local data
    // Verifica se há uma sessão ativa (usuário já logado)
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Check if session is still valid
        try {
          // If the session is expired, refreshSession() will renew it
          if (session.isExpired) {
            await Supabase.instance.client.auth.refreshSession();
          }
          
          // If we're offline, don't try to verify with server
          if (!isOffline) {
            // Attempt to make a simple request to verify the session
            await Supabase.instance.client.from('inspectors').select('id').limit(1);
          }

          // If no error, session is valid, go to home screen
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } catch (e) {
          // Session is likely expired or invalid
          // If offline with invalid session, show a specific message
          if (isOffline) {
            if (mounted) {
              _showOfflineLoginError();
            }
            return;
          }
          
          // If online with invalid session, sign out and go to login
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        // No active session, go to login
        if (mounted) {
          if (isOffline) {
            // Can't login when offline without a session
            _showOfflineLoginError();
          } else {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      }
    } catch (e) {
      // Handle any errors during the auth check
      if (mounted) {
        if (isOffline) {
          _showOfflineLoginError();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking authentication: $e')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  // Check if there's any local data (inspections)
  Future<bool> _hasLocalData() async {
    try {
      final inspections = await LocalDatabaseService.getAllInspections();
      return inspections.isNotEmpty;
    } catch (e) {
      print('Error checking local data: $e');
      return false;
    }
  }

  // Show error message when trying to login offline
  void _showOfflineLoginError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Login Offline'),
        content: const Text(
          'You are currently offline and do not have an active session. '
          'Please connect to the internet to log in.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Check connectivity again
              Connectivity().checkConnectivity().then((result) {
                if (result != ConnectivityResult.none) {
                  // If back online, continue to login
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  // Still offline, exit app
                  Navigator.of(context).pop();
                  // In a real app, you might use SystemNavigator.pop() to exit
                  // but for this example, just go back to login
                  Navigator.pushReplacementNamed(context, '/login');
                }
              });
            },
            child: const Text('Try Again'),
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
// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/home/inspection_tab.dart';
import 'package:inspection_app/presentation/screens/home/schedule_tab.dart';
import 'package:inspection_app/presentation/screens/home/profile_tab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Import Timer
import 'package:connectivity_plus/connectivity_plus.dart'; // Import Connectivity
import 'package:inspection_app/services/inspection_service.dart'; // Assuming this import is correct for your project

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;

  final List<Widget> _tabs = [
    const InspectionTab(),
    const ScheduleTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Add to HomeScreen initState
    // Set up periodic sync
    Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) {
        _syncPendingInspections();
      }
    });
  }

  Future<void> _syncPendingInspections() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final inspectionService = InspectionService();
        await inspectionService.syncAllPending();
      }
    } catch (e) {
      print('Error during background sync: $e');
    }
  }

  void _checkAuth() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: 'Vistorias',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

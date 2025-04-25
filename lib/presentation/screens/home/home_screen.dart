// lib/presentation/screens/home/home_screen.dart (simplified)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/home/inspection_tab.dart';
import 'package:inspection_app/presentation/screens/home/profile_tab.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/firebase_auth_service.dart';
import 'package:inspection_app/services/connectivity_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _auth = FirebaseService().auth;
  final _authService = FirebaseAuthService();
  final _connectivityService = ConnectivityService();
  bool _isOnline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  final List<Widget> _tabs = [
    const InspectionsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivityService.initialize();
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });
    
    _connectivityService.checkConnectivity().then((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });
  }

  void _checkAuth() {
    final user = _auth.currentUser;
    if (user == null) {
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: 'Inspections',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      // Show an offline indicator when device is offline
      bottomSheet: !_isOnline ? Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Offline mode - Changes will sync when online',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ) : null,
    );
  }
}
// lib/presentation/screens/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/home/inspection_tab.dart';
import 'package:inspection_app/presentation/screens/home/profile_tab.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _auth = FirebaseService().auth;
  final _connectivityService = Connectivity();
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((connectivityResult) {
      setState(() {
        _isOnline = connectivityResult != ConnectivityResult.none;
      });
    });
    
    _connectivityService.checkConnectivity().then((connectivityResult) {
      setState(() {
        _isOnline = connectivityResult != ConnectivityResult.none;
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: 'Inspeções',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
      // Show an offline indicator when device is offline
      bottomSheet: !_isOnline ? SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: Colors.red,
          child: Row(
            mainAxisSize: MainAxisSize.min, // Evita overflow horizontal
            children: const [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded( // Expanded para que o texto possa quebrar linhas
                child: Text(
                  'Modo Offline - As mudanças serão sincronizadas quando estiver online',
                  style: TextStyle(color: Colors.white),
                  overflow: TextOverflow.visible, // Permite quebra de texto
                ),
              ),
            ],
          ),
        ),
      ) : null,
    );
  }
}
// lib/presentation/screens/home/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/home/inspection_tab.dart';
import 'package:inspection_app/presentation/screens/home/profile_tab.dart';
import 'package:inspection_app/presentation/screens/chat/chats_screen.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _auth = FirebaseService().auth;
  final _chatService = ChatService();
  StreamSubscription<int>? _unreadCountSubscription;
  int _unreadMessagesCount = 0;



  final List<Widget> _tabs = [
    const InspectionsTab(),
    const ChatsScreen(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadUnreadMessagesCount();
    _setupUnreadMessagesListener();
  }

  @override
  void dispose() {
    _unreadCountSubscription?.cancel(); 
    super.dispose();
  }

  void _checkAuth() {
    final user = _auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

    void _loadUnreadMessagesCount() async {
    try {
      final count = await _chatService.getUnreadMessagesCount();
      if (mounted) {
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    } catch (e) {
      print('Erro ao carregar contagem de mensagens não lidas: $e');
    }
  }

    void _setupUnreadMessagesListener() {
    _unreadCountSubscription = _chatService.getUnreadMessagesCountStream().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    });
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
            label: 'Inspeções',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat),
                if (_unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadMessagesCount > 99 ? '99+' : _unreadMessagesCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Conversas',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
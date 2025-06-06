// lib/presentation/screens/home/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/screens/home/inspection_tab.dart';
import 'package:inspection_app/presentation/screens/home/profile_tab.dart';
import 'package:inspection_app/presentation/screens/chat/chats_screen.dart';
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/features/chat_service.dart';

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
      debugPrint('Erro ao carregar contagem de mensagens não lidas: $e');
    }
  }

  void _setupUnreadMessagesListener() {
    _unreadCountSubscription =
        _chatService.getUnreadMessagesCountStream().listen((count) {
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.15).round()),
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(23),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: _currentIndex == 0
                      ? BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha((255 * 0.12).round()),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: const Icon(Icons.check_box),
                ),
                label: 'Inspeções',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: _currentIndex == 1
                          ? BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((255 * 0.12).round()),
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      child: const Icon(Icons.chat),
                    ),
                    if (_unreadMessagesCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadMessagesCount > 99
                                ? '99+'
                                : _unreadMessagesCount.toString(),
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
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _currentIndex == 2
                      ? BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha((255 * 0.12).round()),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: const Icon(Icons.person),
                ),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

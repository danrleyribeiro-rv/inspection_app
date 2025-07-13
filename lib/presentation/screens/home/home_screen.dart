// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/presentation/screens/home/inspection_tab.dart';
import 'package:lince_inspecoes/presentation/screens/home/profile_tab.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/presentation/widgets/permissions/notification_permission_dialog.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _auth = FirebaseService().auth;

  final List<Widget> _tabs = [
    const InspectionsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _checkNotificationPermissions();
  }

  void _checkAuth() {
    final user = _auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  void _checkNotificationPermissions() async {
    // Aguarda um pouco para garantir que a tela esteja totalmente carregada
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    // Verifica se as notificações já estão habilitadas
    final areEnabled = await SimpleNotificationService.instance.areNotificationsEnabled();
    
    if (!areEnabled) {
      // Mostra o diálogo de permissão
      final granted = await NotificationPermissionDialog.show(context);
      
      if (granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificações habilitadas! Você receberá atualizações sobre sincronizações.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF312456),
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
            selectedItemColor: const Color(0xFFBB8FEB),
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: _currentIndex == 0
                      ? BoxDecoration(
                          color: const Color(0xFFBB8FEB)
                              .withAlpha((255 * 0.12).round()),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: const Icon(Icons.check_box),
                ),
                label: 'Inspeções',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _currentIndex == 1
                      ? BoxDecoration(
                          color: const Color(0xFFBB8FEB)
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

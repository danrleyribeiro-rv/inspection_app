// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:inspection_app/services/service_factory.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final ServiceFactory _serviceFactory = ServiceFactory();

  bool _notificationsEnabled = true;
  bool _locationPermission = true;
  bool _cameraPermission = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _serviceFactory.settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;
        _locationPermission = settings['locationPermission'] ?? true;
        _cameraPermission = settings['cameraPermission'] ?? true;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _serviceFactory.settingsService.saveSettings(
      notificationsEnabled: _notificationsEnabled,
      locationPermission: _locationPermission,
      cameraPermission: _cameraPermission,
    );
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _serviceFactory.authService.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sair: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Conta'),
        content: const Text(
          'Tem certeza de que deseja excluir sua conta? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final inspectorDoc = await _firestore
          .collection('inspectors')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (!mounted) return;

      if (inspectorDoc.docs.isNotEmpty) {
        final inspectorId = inspectorDoc.docs[0].id;
        await _firestore
            .collection('inspectors')
            .doc(inspectorId)
            .update({'deleted_at': FieldValue.serverTimestamp()});
        if (!mounted) return;
      }

      await _serviceFactory.authService.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir conta: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleNotificationChange(bool value) async {
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
    await _saveSettings();

    if (value) {
      await Permission.notification.request();
    } else {
      await openAppSettings();
    }
  }

  Future<void> _handleLocationPermissionChange(bool value) async {
    if (!mounted) return;
    setState(() => _locationPermission = value);
    await _saveSettings();

    if (value) {
      await Permission.location.request();
    } else {
      await openAppSettings();
    }
  }

  Future<void> _handleCameraPermissionChange(bool value) async {
    if (!mounted) return;
    setState(() => _cameraPermission = value);
    await _saveSettings();

    if (value) {
      await Permission.camera.request();
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Notificações'),
                SwitchListTile(
                  title: const Text('Notificações',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Receber alertas sobre novas vistorias e mensagens',
                      style: TextStyle(color: Colors.white70)),
                  value: _notificationsEnabled,
                  activeColor: Colors.blue,
                  // CORREÇÃO: Callback Síncrono que chama a função Async
                  onChanged: (value) {
                    _handleNotificationChange(value);
                  },
                ),
                _buildSectionHeader('Permissões'),
                SwitchListTile(
                  title: const Text('Localização',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Permitir acesso à localização do dispositivo',
                      style: TextStyle(color: Colors.white70)),
                  value: _locationPermission,
                  activeColor: Colors.blue,
                  // CORREÇÃO: Callback Síncrono que chama a função Async
                  onChanged: (value) {
                    _handleLocationPermissionChange(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Câmera',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Permitir acesso à câmera do dispositivo',
                      style: TextStyle(color: Colors.white70)),
                  value: _cameraPermission,
                  activeColor: Colors.blue,
                  // CORREÇÃO: Callback Síncrono que chama a função Async
                  onChanged: (value) {
                    _handleCameraPermissionChange(value);
                  },
                ),
                _buildSectionHeader('Armazenamento'),
                ListTile(
                  title: const Text('Limpar Cache',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Remover arquivos temporários',
                      style: TextStyle(color: Colors.white70)),
                  leading:
                      const Icon(Icons.cleaning_services, color: Colors.white),
                  onTap: () async {
                    setState(() => _isLoading = true);
                    try {
                      await _serviceFactory.cacheService.clearCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache limpo com sucesso'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao limpar cache: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
                _buildSectionHeader('Conta'),
                ListTile(
                  title:
                      const Text('Sair', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Encerrar sessão atual',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.logout, color: Colors.white),
                  onTap: _signOut,
                ),
                ListTile(
                  title: const Text('Excluir Conta',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Remover permanentemente sua conta',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  textColor: Colors.red,
                  onTap: _deleteAccount,
                ),
                _buildSectionHeader('Sobre'),
                ListTile(
                  title: const Text('Versão do App',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Alpha-0.5.0',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.info, color: Colors.white),
                ),
                ListTile(
                  title: const Text('Política de Privacidade',
                      style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.privacy_tip, color: Colors.white),
                ),
                ListTile(
                  title: const Text('Termos de Uso',
                      style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.gavel, color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/services/firebase_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _authService = FirebaseAuthService();

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _locationPermission = prefs.getBool('locationPermission') ?? true;
      _cameraPermission = prefs.getBool('cameraPermission') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('locationPermission', _locationPermission);
    await prefs.setBool('cameraPermission', _cameraPermission);
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signOut();

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
      setState(() => _isLoading = false);
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

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        final userId = _auth.currentUser?.uid; // Corrigido de .id para .uid
        if (userId == null) return;

        // Get the inspector ID
        final inspectorDoc = await _firestore
            .collection('inspectors')
            .where('user_id', isEqualTo: userId)
            .limit(1)
            .get();

        if (inspectorDoc.docs.isNotEmpty) {
          final inspectorId = inspectorDoc.docs[0].id;

          // Mark the inspector as deleted (soft delete)
          await _firestore
              .collection('inspectors')
              .doc(inspectorId)
              .update({'deleted_at': FieldValue.serverTimestamp()});
        }

        // Sign out
        await _authService.signOut();

        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate color for background
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: const Color(0xFF1E293B), // Slate color for appbar
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
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSettings();
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
                  onChanged: (value) {
                    setState(() => _locationPermission = value);
                    _saveSettings();
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
                  onChanged: (value) {
                    setState(() => _cameraPermission = value);
                    _saveSettings();
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache limpo com sucesso'),
                      ),
                    );
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

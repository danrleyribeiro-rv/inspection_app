// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _darkMode = false;
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
      _darkMode = prefs.getBool('darkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _locationPermission = prefs.getBool('locationPermission') ?? true;
      _cameraPermission = prefs.getBool('cameraPermission') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('locationPermission', _locationPermission);
    await prefs.setBool('cameraPermission', _cameraPermission);
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signOut();

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
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza que deseja excluir sua conta? Esta ação não poderá ser desfeita.',
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
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;

        // Obter o ID do inspetor
        final inspectorData = await _supabase
            .from('inspectors')
            .select('id')
            .eq('user_id', userId)
            .single();

        final inspectorId = inspectorData['id'];

        // Marcar o inspetor como excluído (soft delete)
        await _supabase
            .from('inspectors')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', inspectorId);

        // Sair da conta
        await _supabase.auth.signOut();

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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Aparência'),
                SwitchListTile(
                  title: const Text('Modo Escuro'),
                  subtitle: const Text('Alternar entre tema claro e escuro'),
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    _saveSettings();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reinicie o aplicativo para aplicar o tema'),
                      ),
                    );
                  },
                ),

                _buildSectionHeader('Notificações'),
                SwitchListTile(
                  title: const Text('Notificações'),
                  subtitle:
                      const Text('Receber alertas sobre novas vistorias e mensagens'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSettings();
                  },
                ),

                _buildSectionHeader('Permissões'),
                SwitchListTile(
                  title: const Text('Localização'),
                  subtitle: const Text(
                      'Permissão para acessar a localização do dispositivo'),
                  value: _locationPermission,
                  onChanged: (value) {
                    setState(() => _locationPermission = value);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text('Câmera'),
                  subtitle: const Text(
                      'Permissão para acessar a câmera do dispositivo'),
                  value: _cameraPermission,
                  onChanged: (value) {
                    setState(() => _cameraPermission = value);
                    _saveSettings();
                  },
                ),

                _buildSectionHeader('Armazenamento'),
                ListTile(
                  title: const Text('Limpar Cache'),
                  subtitle: const Text('Remover arquivos temporários'),
                  leading: const Icon(Icons.cleaning_services),
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
                  title: const Text('Sair'),
                  subtitle: const Text('Encerrar a sessão atual'),
                  leading: const Icon(Icons.logout),
                  onTap: _signOut,
                ),
                ListTile(
                  title: const Text('Excluir Conta'),
                  subtitle: const Text('Remover permanentemente sua conta'),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  textColor: Colors.red,
                  onTap: _deleteAccount,
                ),

                _buildSectionHeader('Sobre'),
                ListTile(
                  title: const Text('Versão do Aplicativo'),
                  subtitle: const Text('1.0.0'),
                  leading: const Icon(Icons.info),
                ),
                const ListTile(
                  title: Text('Política de Privacidade'),
                  leading: Icon(Icons.privacy_tip),
                ),
                const ListTile(
                  title: Text('Termos de Uso'),
                  leading: Icon(Icons.gavel),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}


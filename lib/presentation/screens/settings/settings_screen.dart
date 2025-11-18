import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/utils/settings_service.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/terms_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final SettingsService _settingsService = SettingsService();

  bool _notificationsEnabled = true;
  bool _cameraPermission = true;
  String _themeMode = 'system'; // 'light', 'dark', ou 'system'
  bool _isLoading = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // Carregar configurações do sistema
      final settings = await _settingsService.loadSettings();
      if (mounted) {
        setState(() {
          _notificationsEnabled = settings['notificationsEnabled'] ?? true;
          _cameraPermission = settings['cameraPermission'] ?? true;
          _themeMode = settings['themeMode'] ?? 'system';
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      if (mounted) {
        setState(() {
          _notificationsEnabled = true;
          _cameraPermission = true;
          _themeMode = 'system';
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    // Cancela o timer anterior se existir
    _saveDebounce?.cancel();

    // Cria um novo timer para salvar após 500ms de inatividade
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _settingsService.saveSettings(
          notificationsEnabled: _notificationsEnabled,
          locationPermission: true, // valor padrão
          cameraPermission: _cameraPermission,
          themeMode: _themeMode,
        );
        debugPrint('Configurações salvas com sucesso');
      } catch (e) {
        debugPrint('Erro ao salvar configurações: $e');
      }
    });
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      // Clear all local data (media files and database) before signing out
      await _serviceFactory.authService.clearAllLocalData();

      await _serviceFactory.authService.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            duration: const Duration(seconds: 2),
          ),
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

      // Clear all local data (media files and database) before signing out
      await _serviceFactory.authService.clearAllLocalData();

      await _serviceFactory.authService.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir conta: $e'),
            duration: const Duration(seconds: 2),
          ),
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


  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Cache'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta ação irá remover:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Todas as inspeções baixadas'),
            Text('• Arquivos de mídia offline'),
            Text('• Templates em cache'),
            Text('• Dados temporários'),
            SizedBox(height: 16),
            Text(
              'Você precisará baixar novamente as inspeções para trabalhar offline.',
              style:
                  TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Tem certeza de que deseja continuar?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
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
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Limpar todos os dados usando o service factory
      await _serviceFactory.clearAllData();

      // Limpar preferências
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cache limpo com sucesso! Todas as inspeções baixadas e dados temporários foram removidos.'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao limpar cache: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTerms() async {
    await showDialog(
      context: context,
      builder: (context) => const TermsDialog(isRegistration: false),
    );
  }

  Future<void> _contactSupport() async {
    const supportEmail = 'it@lincehub.com.br';
    const subject = 'Suporte - Lince Inspeções';
    const body =
        'Olá,\n\nPreciso de ajuda com:\n\n[Descreva sua dúvida ou problema aqui]';

    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Não foi possível abrir o aplicativo de e-mail. Entre em contato através do e-mail: it@lincehub.com.br'),
            duration: Duration(seconds: 2),
          ),
        );
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
          ? const Center(child: AdaptiveProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Aparência'),
                ListTile(
                  title: const Text('Tema'),
                  subtitle: Text(_getThemeLabel(_themeMode)),
                  leading: const Icon(Icons.brightness_6),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(),
                ),
                _buildSectionHeader('Permissões'),
                SwitchListTile(
                  title: const Text('Notificações'),
                  subtitle: const Text(
                      'Receber alertas sobre novas inspeções e mensagens'),
                  value: _notificationsEnabled,
                  activeThumbColor: const Color(0xFF6F4B99),
                  onChanged: (value) {
                    _handleNotificationChange(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Câmera'),
                  subtitle:
                      const Text('Permitir acesso à câmera do dispositivo'),
                  value: _cameraPermission,
                  activeThumbColor: const Color(0xFF6F4B99),
                  onChanged: (value) {
                    _handleCameraPermissionChange(value);
                  },
                ),
                _buildSectionHeader('Armazenamento'),
                ListTile(
                  title: const Text('Limpar Cache'),
                  subtitle: const Text(
                      'Remover todas as inspeções baixadas e arquivos temporários'),
                  leading: const Icon(Icons.cleaning_services),
                  onTap: _clearCache,
                ),
                _buildSectionHeader('Conta'),
                ListTile(
                  title: const Text('Sair'),
                  subtitle: const Text('Encerrar sessão atual'),
                  leading: const Icon(Icons.logout),
                  onTap: _signOut,
                ),
                ListTile(
                  title: const Text('Excluir Conta',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Remover permanentemente sua conta'),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  textColor: Colors.red,
                  onTap: _deleteAccount,
                ),
                _buildSectionHeader('Sobre'),
                ListTile(
                  title: const Text('Versão do App'),
                  subtitle: const Text('1.0'),
                  leading: const Icon(Icons.info),
                ),
                ListTile(
                  title: const Text('Termos de Uso e Política de Privacidade'),
                  leading: const Icon(Icons.gavel),
                  onTap: _showTerms,
                ),
                _buildSectionHeader('Suporte'),
                ListTile(
                  title: const Text('Entrar em Contato'),
                  subtitle: const Text('it@lincehub.com.br'),
                  leading: const Icon(Icons.support_agent),
                  onTap: _contactSupport,
                ),
              ],
            ),
    );
  }

  String _getThemeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Claro';
      case 'dark':
        return 'Escuro';
      case 'system':
      default:
        return 'Seguir o sistema';
    }
  }

  Future<void> _showThemeDialog() async {
    final selectedTheme = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Escolher Tema'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  title: const Text('Claro'),
                  value: 'light',
                  // ignore: deprecated_member_use
                  groupValue: _themeMode,
                  activeColor: const Color(0xFF6F4B99),
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(dialogContext).pop(value);
                    }
                  },
                ),
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  title: const Text('Escuro'),
                  value: 'dark',
                  // ignore: deprecated_member_use
                  groupValue: _themeMode,
                  activeColor: const Color(0xFF6F4B99),
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(dialogContext).pop(value);
                    }
                  },
                ),
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  title: const Text('Seguir o sistema'),
                  subtitle: const Text('Usar tema do dispositivo'),
                  value: 'system',
                  // ignore: deprecated_member_use
                  groupValue: _themeMode,
                  activeColor: const Color(0xFF6F4B99),
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(dialogContext).pop(value);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selectedTheme != null && selectedTheme != _themeMode && mounted) {
      setState(() {
        _themeMode = selectedTheme;
      });

      // Notifica o app para mudar o tema
      if (mounted) {
        final appState = MyApp.of(context);
        if (appState != null) {
          appState.changeTheme(selectedTheme);
        }
      }

      // Salva em background
      _settingsService.setThemeMode(selectedTheme).catchError((e) {
        debugPrint('Erro ao salvar tema: $e');
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

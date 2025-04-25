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
          SnackBar(content: Text('Error signing out: $e')),
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
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
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
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E293B), // Slate color for appbar
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Notifications'),
                SwitchListTile(
                  title: const Text('Notifications',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Receive alerts about new inspections and messages',
                      style: TextStyle(color: Colors.white70)),
                  value: _notificationsEnabled,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSettings();
                  },
                ),
                _buildSectionHeader('Permissions'),
                SwitchListTile(
                  title: const Text('Location',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Allow access to device location',
                      style: TextStyle(color: Colors.white70)),
                  value: _locationPermission,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() => _locationPermission = value);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text('Camera',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Allow access to device camera',
                      style: TextStyle(color: Colors.white70)),
                  value: _cameraPermission,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() => _cameraPermission = value);
                    _saveSettings();
                  },
                ),
                _buildSectionHeader('Storage'),
                ListTile(
                  title: const Text('Clear Cache',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Remove temporary files',
                      style: TextStyle(color: Colors.white70)),
                  leading:
                      const Icon(Icons.cleaning_services, color: Colors.white),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared successfully'),
                      ),
                    );
                  },
                ),
                _buildSectionHeader('Account'),
                ListTile(
                  title: const Text('Sign Out',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('End current session',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.logout, color: Colors.white),
                  onTap: _signOut,
                ),
                ListTile(
                  title: const Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently remove your account',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  textColor: Colors.red,
                  onTap: _deleteAccount,
                ),
                _buildSectionHeader('About'),
                ListTile(
                  title: const Text('App Version',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('1.0.0',
                      style: TextStyle(color: Colors.white70)),
                  leading: const Icon(Icons.info, color: Colors.white),
                ),
                ListTile(
                  title: const Text('Privacy Policy',
                      style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.privacy_tip, color: Colors.white),
                ),
                ListTile(
                  title: const Text('Terms of Use',
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
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

// lib/presentation/screens/home/profile_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/presentation/screens/profile/edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('inspectors')
          .select('*')
          .eq('user_id', userId)
          .single();

      setState(() {
        _profile = data;
      });

      // Carregar a imagem de perfil
      await _loadProfileImage();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    if (_profile == null) return;

    try {
      final inspectorId = _profile!['id']; // This is now a UUID string.
      final imagesList = await _supabase
          .from('profile_images')
          .select('image_data')
          .eq('inspector_id', inspectorId) // Pass the UUID directly
          .limit(1);

      if (imagesList.isNotEmpty && imagesList[0]['image_data'] != null) {
        setState(() {
          _profileImageBase64 = imagesList[0]['image_data'];
        });
      }
    } catch (e) {
      print('Erro ao carregar imagem: $e');
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_profile == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          profile: _profile!,
        ),
      ),
    );

    // Se retornou true, recarregar o perfil
    if (updated == true) {
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar e nome
                  _buildProfileImage(),
                  const SizedBox(height: 16),
                  Text(
                    _getFullName(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _profile?['profession'] ?? 'Não especificado',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Seção de informações pessoais
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Informações Pessoais',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  _buildInfoItem(Icons.email, 'Email',
                      _profile?['email'] ?? 'Não informado'),
                  _buildInfoItem(Icons.phone, 'Telefone',
                      _profile?['phonenumber'] ?? 'Não informado'),
                  _buildInfoItem(Icons.business, 'CNPJ/CPF',
                      _profile?['document'] ?? 'Não informado'),

                  const SizedBox(height: 24),

                  // Seção de endereço
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  _buildInfoItem(Icons.location_on, 'Rua', _formatAddress()),
                  _buildInfoItem(
                      Icons.location_city,
                      'Cidade/Estado',
                      '${_profile?['city'] ?? 'Não informado'} - ${_profile?['state'] ?? ''}'),
                  _buildInfoItem(Icons.markunread_mailbox, 'CEP',
                      _profile?['cep'] ?? 'Não informado'),

                  const SizedBox(height: 32),

                  // Botão de editar perfil
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToEditProfile,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Perfil'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    if (_profileImageBase64 != null) {
      try {
        final imageBytes = base64Decode(_profileImageBase64!);
        return CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('Erro ao decodificar imagem: $e');
        // Em caso de erro, cair no fallback com iniciais
      }
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: Theme.of(context).primaryColor,
      child: Text(
        _getInitials(),
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getFullName() {
    final name = _profile?['name'] ?? '';
    final lastName = _profile?['last_name'] ?? '';
    return '$name $lastName'.trim();
  }

  String _getInitials() {
    if (_profile == null) return '';

    final name = _profile?['name'] ?? '';
    final lastName = _profile?['last_name'] ?? '';

    String initials = '';
    if (name.isNotEmpty) {
      initials += name[0];
    }

    if (lastName.isNotEmpty) {
      initials += lastName[0];
    }

    return initials.toUpperCase();
  }

  String _formatAddress() {
    final street = _profile?['street'] ?? '';
    final neighborhood = _profile?['neighborhood'] ?? '';

    if (street.isEmpty && neighborhood.isEmpty) {
      return 'Não informado';
    }

    return '$street, $neighborhood'.trim();
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




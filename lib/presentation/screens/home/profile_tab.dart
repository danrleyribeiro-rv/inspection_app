// lib/presentation/screens/home/profile_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/presentation/screens/profile/edit_profile_screen.dart';
// QR CODE CREDENTIALS - IMPORT COMENTADO PARA OCULTAR FUNCIONALIDADE
// import 'package:lince_inspecoes/presentation/widgets/profile/qr_code_credentials_dialog.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

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

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('inspectors').doc(userId).get();

      if (doc.exists) {
        setState(() {
          _profile = {
            'id': doc.id,
            ...doc.data() ?? {},
          };
        });

        await _loadProfileImage();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    if (_profile == null) return;

    try {
      if (_profile!.containsKey('profileImageUrl') &&
          _profile!['profileImageUrl'] != null) {
        setState(() {
          _profileImageBase64 = _profile!['profileImageUrl'];
        });
        return;
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final imagesCollection = await _firestore
          .collection('profile_images')
          .where('inspector_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (imagesCollection.docs.isNotEmpty &&
          imagesCollection.docs[0].data()['image_data'] != null) {
        setState(() {
          _profileImageBase64 = imagesCollection.docs[0].data()['image_data'];
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar imagem: $e');
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_profile == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: _profile!),
      ),
    );

    if (updated == true) {
      _loadProfile();
    }
  }

  // QR CODE CREDENTIALS - COMENTADO PARA OCULTAR FUNCIONALIDADE
  // void _showQrCredentials() {
  //   if (_profile == null) return;

  //   showDialog(
  //     context: context,
  //     builder: (context) => QrCodeCredentialsDialog(
  //       inspectorId: _profile!['id'],
  //       profile: _profile!,
  //     ),
  //   );
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF312456),
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: const Color(0xFF312456),
        elevation: 0,
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
                  // Avatar and name
                  _buildProfileImage(),
                  const SizedBox(height: 16),

                  // QR CODE CREDENTIALS BUTTON - COMENTADO PARA OCULTAR FUNCIONALIDADE
                  // ElevatedButton.icon(
                  //   onPressed: _showQrCredentials,
                  //   icon: const Icon(Icons.qr_code, size: 20),
                  //   label: const Text('Credenciais'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: const Color(0xFF6F4B99),
                  //     foregroundColor: Colors.white,
                  //     padding: const EdgeInsets.symmetric(
                  //         horizontal: 24, vertical: 12),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //   ),
                  // ),

                  const SizedBox(height: 16),

                  Text(
                    _getFullName(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _profile?['profession'] ?? 'Not specified',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal Information section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Informações Pessoais',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  _buildInfoItem(Icons.email, 'Email',
                      _profile?['email'] ?? 'Não fornecido'),
                  _buildInfoItem(Icons.phone, 'Telefone',
                      _profile?['phonenumber'] ?? 'Não fornecido'),
                  _buildInfoItem(Icons.business, 'CNPJ/CPF',
                      _profile?['document'] ?? 'Não fornecido'),

                  const SizedBox(height: 24),

                  // Address section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  _buildInfoItem(Icons.location_on, 'Rua', _formatAddress()),
                  _buildInfoItem(Icons.location_city, 'Cidade/Estado',
                      '${_profile?['city'] ?? 'Não fornecido'} - ${_profile?['state'] ?? 'Não fornecido'}'),
                  _buildInfoItem(Icons.markunread_mailbox, 'CEP',
                      _profile?['cep'] ?? 'Não fornecido'),

                  const SizedBox(height: 32),

                  // Edit profile button
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
      if (_profileImageBase64!.startsWith('http')) {
        return CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(_profileImageBase64!),
          onBackgroundImageError: (e, stackTrace) {
            debugPrint('Erro ao carregar imagem de perfil: $e');
          },
        );
      } else {
        try {
          final imageBytes = base64Decode(_profileImageBase64!);
          return CircleAvatar(
            radius: 50,
            backgroundImage: MemoryImage(imageBytes),
          );
        } catch (e) {
          debugPrint('Erro ao decodificar imagem: $e');
        }
      }
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: Theme.of(context).primaryColor,
      child: Text(
        _getInitials(),
        style: const TextStyle(
          fontSize: 24,
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
      return 'Não fornecido';
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
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
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

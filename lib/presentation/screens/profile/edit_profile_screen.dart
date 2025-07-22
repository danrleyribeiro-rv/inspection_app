// lib/presentation/screens/profile/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:brasil_fields/brasil_fields.dart';
import 'package:lince_inspecoes/utils/constants.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  // final _serviceFactory = EnhancedOfflineServiceFactory.instance; // Removed - not used

  bool _isLoading = false;
  bool _isCepLoading = false;
  File? _profileImage;
  String? _profileImageUrl;
  bool _hasProfileImage = false;

  // Controllers for form fields
  late final TextEditingController _nameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _documentController;
  late final TextEditingController _cepController;
  late final TextEditingController _streetController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  String? _selectedProfession;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _checkProfileImage();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.profile['name'] ?? '');
    _lastNameController =
        TextEditingController(text: widget.profile['last_name'] ?? '');
    _emailController =
        TextEditingController(text: widget.profile['email'] ?? '');
    _phoneController =
        TextEditingController(text: widget.profile['phonenumber'] ?? '');
    _documentController =
        TextEditingController(text: widget.profile['document'] ?? '');
    _cepController = TextEditingController(text: widget.profile['cep'] ?? '');
    _streetController =
        TextEditingController(text: widget.profile['street'] ?? '');
    _neighborhoodController =
        TextEditingController(text: widget.profile['neighborhood'] ?? '');
    _cityController = TextEditingController(text: widget.profile['city'] ?? '');
    _stateController =
        TextEditingController(text: widget.profile['state'] ?? '');
    _selectedProfession = widget.profile['profession'];
    _profileImageUrl = widget.profile['profileImageUrl'];
  }

  Future<void> _checkProfileImage() async {
    try {
      setState(() {
        _hasProfileImage = _profileImageUrl != null;
      });

      if (!_hasProfileImage && widget.profile['id'] != null) {
        final imagesSnapshot = await _firestore
            .collection('profile_images')
            .where('inspector_id', isEqualTo: widget.profile['id'])
            .limit(1)
            .get();

        if (mounted) {
          setState(() {
            _hasProfileImage = imagesSnapshot.docs.isNotEmpty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking profile image: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _fetchCepData(String cep) async {
    final cepDigits = cep.replaceAll(RegExp(r'\D'), '');
    if (cepDigits.length != 8) return;

    setState(() => _isCepLoading = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cepDigits/json/');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro') && data['erro'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CEP não encontrado'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endereço preenchido automaticamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar CEP: ${response.statusCode}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar CEP: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCepLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final profileData = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'profession': _selectedProfession,
        'phonenumber': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        'document': _documentController.text.replaceAll(RegExp(r'\D'), ''),
        'cep': _cepController.text.replaceAll(RegExp(r'\D'), ''),
        'street': _streetController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim().toUpperCase(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('inspectors').doc(userId).update(profileData);

      // Upload profile image if selected
      if (_profileImage != null) {
        try {
          final mediaService =
              EnhancedOfflineServiceFactory.instance.mediaService;
          await mediaService.uploadProfileImage(_profileImage!.path, userId);
        } catch (e) {
          debugPrint('Error uploading profile image: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar perfil: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF312456),
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFF312456),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
            tooltip: 'Salvar alterações',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image section with improved design
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF6F4B99), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6F4B99)
                                  .withAlpha((255 * 0.3).round()),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[800],
                              child: _profileImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(60),
                                      child: Image.file(
                                        _profileImage!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _profileImageUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(60),
                                          child: Image.network(
                                            _profileImageUrl!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Text(
                                              _getInitials(),
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _getInitials(),
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6F4B99),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withAlpha((255 * 0.3).round()),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Personal Information Section
                    _buildSectionHeader('Informações Pessoais', Icons.person),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nameController,
                            label: 'Primeiro Nome',
                            icon: Icons.person_outline,
                            validator: (value) => value?.trim().isEmpty == true
                                ? 'Campo obrigatório'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            label: 'Sobrenome',
                            icon: Icons.person_outline,
                            validator: (value) => value?.trim().isEmpty == true
                                ? 'Campo obrigatório'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      readOnly: true,
                      suffixIcon:
                          const Icon(Icons.lock_outline, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TelefoneInputFormatter(),
                      ],
                      hintText: '(99) 99999-9999',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _documentController,
                      label: 'CNPJ/CPF',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CpfOuCnpjFormatter(),
                      ],
                      hintText: 'Digite o CNPJ ou CPF',
                    ),

                    const SizedBox(height: 32),

                    // Address Section
                    _buildSectionHeader('Endereço', Icons.location_on),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _cepController,
                      label: 'CEP',
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CepInputFormatter(),
                      ],
                      hintText: '00.000-000',
                      suffixIcon: _isCepLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                final cep = _cepController.text;
                                if (cep.isNotEmpty) {
                                  _fetchCepData(cep);
                                }
                              },
                              tooltip: 'Buscar endereço',
                            ),
                      onChanged: (value) {
                        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length == 8) {
                          _fetchCepData(digitsOnly);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _streetController,
                      label: 'Rua',
                      icon: Icons.location_city_outlined,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _neighborhoodController,
                      label: 'Bairro',
                      icon: Icons.location_city_outlined,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'Cidade',
                            icon: Icons.location_city,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'UF',
                            icon: Icons.map_outlined,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(2),
                            ],
                            hintText: 'UF',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Save button with improved design
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6F4B99),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFF6F4B99)
                              .withAlpha((255 * 0.3).round()),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Salvar Alterações',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6F4B99).withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF6F4B99).withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6F4B99), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6F4B99),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF6F4B99)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF6F4B99), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[800] : Colors.grey[850],
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintStyle: TextStyle(color: Colors.grey),
      ),
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedProfession,
      decoration: InputDecoration(
        labelText: 'Profissão',
        prefixIcon: Icon(Icons.work_outline, color: Color(0xFF6F4B99)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF6F4B99), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[850],
        labelStyle: TextStyle(color: Colors.grey[400]),
      ),
      style: const TextStyle(color: Colors.white),
      dropdownColor: Colors.grey[800],
      items: Constants.professions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedProfession = newValue);
      },
      validator: (value) => value == null ? 'Selecione uma profissão' : null,
    );
  }

  String _getInitials() {
    final name = _nameController.text;
    final lastName = _lastNameController.text;

    String initials = '';
    if (name.isNotEmpty) initials += name[0];
    if (lastName.isNotEmpty) initials += lastName[0];

    return initials.toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _documentController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}

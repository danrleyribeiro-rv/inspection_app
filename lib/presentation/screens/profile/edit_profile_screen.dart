// lib/presentation/screens/profile/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:brasil_fields/brasil_fields.dart';

import 'package:inspection_app/utils/constants.dart'; // Import Constants

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
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  File? _profileImage;
  String? _profileImageUrl;
  bool _hasProfileImage = false;

  // Controllers para os campos do formulário
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
    _emailController = TextEditingController(text: widget.profile['email'] ?? '');
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
  }

  // Verificar se há imagem de perfil no banco de dados
  Future<void> _checkProfileImage() async {
    try {
      final inspectorId = widget.profile['id'];

      final images = await _supabase
          .from('profile_images')
          .select('id')
          .eq('inspector_id', inspectorId)
          .limit(1);

      setState(() {
        _hasProfileImage = images.isNotEmpty;
      });
    } catch (e) {
      print('Erro ao verificar imagem de perfil: $e');
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

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar imagem: $e')),
      );
    }
  }

  Future<void> _fetchCepData(String cep) async {
    // Garantir que estamos trabalhando apenas com dígitos
    final cepDigits = cep.replaceAll(RegExp(r'\D'), '');
    if (cepDigits.length != 8) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cepDigits/json/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CEP não encontrado')),
            );
          }
          return;
        }
        if (mounted) {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao buscar o CEP')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final inspectorId = widget.profile['id'];

      // 1. Atualizar dados do perfil
      await _supabase
          .from('inspectors')
          .update({
        'name': _nameController.text,
        'last_name': _lastNameController.text,
        'profession': _selectedProfession,
        'phonenumber': _phoneController.text,
        'document': _documentController.text,
        'cep': _cepController.text,
        'street': _streetController.text,
        'neighborhood': _neighborhoodController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', inspectorId);

      // 2. Processar imagem de perfil se selecionada
      if (_profileImage != null) {
        // Abordagem alternativa: armazenar a imagem como base64 na tabela
        final bytes = await _profileImage!.readAsBytes();
        final base64Image = base64Encode(bytes);

        // Verificar se já existe uma imagem para este inspetor
        if (_hasProfileImage) {
          // Atualizar registro existente
          await _supabase
              .from('profile_images')
              .update({
            'image_data': base64Image,
            'updated_at': DateTime.now().toIso8601String(),
          })
              .eq('inspector_id', inspectorId);
        } else {
          // Inserir novo registro
          await _supabase.from('profile_images').insert({
            'inspector_id': inspectorId,
            'image_data': base64Image,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
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
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
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
                  children: [
                    // Imagem de perfil
                    Center(
                      child: Stack(
                        children: [
                          // Avatar ou imagem selecionada
                          CircleAvatar(
                            radius: 60,
                            backgroundColor:
                                Theme.of(context).primaryColor.withOpacity(0.2),
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
                                : Text(
                                    _getInitials(),
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                          ),
                          // Botão para editar
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dados pessoais
                    const Text(
                      'Dados Pessoais',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Campo obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Sobrenome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Campo obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedProfession,
                      decoration: const InputDecoration(
                        labelText: 'Profissão',
                        border: OutlineInputBorder(),
                      ),
                      items: Constants.professions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() => _selectedProfession = newValue);
                      },
                      validator: (value) => value == null
                          ? 'Selecione uma profissão'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true, // Email não pode ser alterado
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        border: OutlineInputBorder(),
                        hintText: '(99) 99999-9999',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TelefoneInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _documentController,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ/CPF',
                        border: OutlineInputBorder(),
                        hintText: 'Digite CNPJ ou CPF',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CpfOuCnpjFormatter(),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Endereço
                    const Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cepController,
                      decoration: const InputDecoration(
                        labelText: 'CEP',
                        border: OutlineInputBorder(),
                        hintText: '00.000-000',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CepInputFormatter(),
                      ],
                      onChanged: (value) {
                        // Removendo a formatação para usar apenas os dígitos
                        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length == 8) {
                          _fetchCepData(digitsOnly);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Rua',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Botão de salvar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Salvar Alterações'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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

  String _getInitials() {
    final name = _nameController.text;
    final lastName = _lastNameController.text;

    String initials = '';
    if (name.isNotEmpty) {
      initials += name[0];
    }

    if (lastName.isNotEmpty) {
      initials += lastName[0];
    }

    return initials.toUpperCase();
  }
}


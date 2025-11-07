// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lince_inspecoes/utils/constants.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';
import 'package:lince_inspecoes/services/core/auth_service.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/terms_dialog.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart' as cpf_validator;
import 'package:cpf_cnpj_validator/cnpj_validator.dart' as cnpj_validator;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _documentController = TextEditingController();
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  String? _selectedProfession;
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isCepLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao buscar CEP: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCepLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final documentValue = _documentController.text;
    final documentDigits = documentValue.replaceAll(RegExp(r'\D'), '');
    bool isDocumentValid = false;
    if (documentDigits.isNotEmpty) {
      if (documentDigits.length == 11) {
        isDocumentValid = cpf_validator.CPFValidator.isValid(documentValue);
        if (!isDocumentValid) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('O CPF informado é inválido'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2)));
          return;
        }
      } else if (documentDigits.length == 14) {
        isDocumentValid = cnpj_validator.CNPJValidator.isValid(documentValue);
        if (!isDocumentValid) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('O CNPJ informado é inválido'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2)));
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'O documento deve ser um CPF (11 dígitos) ou CNPJ (14 dígitos)'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2)));
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, insira seu CPF ou CNPJ'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'profession': _selectedProfession,
        'document': documentDigits,
        'cep': _cepController.text.replaceAll(RegExp(r'\D'), ''),
        'street': _streetController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'phonenumber': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
      };

      // Show terms dialog BEFORE creating account
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const TermsDialog(isRegistration: true),
      );

      if (!mounted) return;

      if (accepted != true) {
        // User rejected terms - don't create account
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessário aceitar os termos para criar uma conta.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Only create account if terms were accepted
      final userCredential = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        userData,
      );

      if (!mounted) return;

      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
        
        // Accept terms immediately after account creation
        await _authService.acceptTerms(userCredential.user!.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Registro bem-sucedido! Por favor, verifique seu e-mail para confirmar seu endereço.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Registro concluído, mas os dados do usuário estão indisponíveis. Por favor, tente fazer login.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Registro falhou.';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Este endereço de e-mail já está registrado.';
          break;
        case 'weak-password':
          message = 'A senha fornecida é muito fraca.';
          break;
        case 'invalid-email':
          message = 'O formato do endereço de e-mail é inválido.';
          break;
        default:
          debugPrint(
              'FirebaseAuthException code: ${e.code}, message: ${e.message}');
          message =
              'Ocorreu um erro inesperado durante o registro. Por favor, tente novamente.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erro inesperado durante o registro: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro inesperado: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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
        title: const Text(
          'Registrar',
        ),
        backgroundColor: const Color(0xFF312456),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              _buildSectionHeader('Informações Pessoais', Icons.person),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _nameController,
                      label: 'Nome',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Por favor, insira seu primeiro nome'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Sobrenome',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Por favor, insira seu sobrenome'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildDropdownField(),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu número de telefone';
                  }
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10 || digits.length > 11) {
                    return 'Insira um número de telefone válido (10 ou 11 dígitos)';
                  }
                  return null;
                },
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu CNPJ ou CPF';
                  }
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length != 11 && digits.length != 14) {
                    return 'Insira 11 dígitos para CPF ou 14 para CNPJ';
                  }
                  return null;
                },
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
                        child: AdaptiveProgressIndicator(radius: 8.0),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          final cep = _cepController.text;
                          if (cep.isNotEmpty) {
                            _fetchCepData(cep);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Por favor, insira um CEP primeiro'),
                                  duration: Duration(seconds: 2)),
                            );
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu CEP';
                  }
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length != 8) {
                    return 'O CEP deve ter 8 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _streetController,
                label: 'Rua',
                icon: Icons.location_city_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira o endereço'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _neighborhoodController,
                label: 'Bairro',
                icon: Icons.location_city_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira o bairro'
                    : null,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'Cidade',
                      icon: Icons.location_city,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Por favor, insira a cidade'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira o estado';
                        }
                        if (value.trim().length != 2) {
                          return 'Por favor, use 2 letras para o UF';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Account Security Section
              _buildSectionHeader('Segurança da Conta', Icons.security),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira seu email';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Por favor, insira um endereço de email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: 'Senha',
                icon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira uma senha';
                  }
                  if (value.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar Senha',
                icon: Icons.lock_outline,
                obscureText: !_isConfirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirme sua senha';
                  }
                  if (value != _passwordController.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: AdaptiveProgressIndicator(
                            radius: 10.0,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Criar Conta',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Espaço para garantir que o botão fique acima da barra de navegação
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
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
            style: const TextStyle(
              fontSize: 12,
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
    bool obscureText = false,
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
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6F4B99), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        filled: true,
        fillColor: Colors.white10,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField() {
    if (PlatformUtils.isIOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profissão',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          AdaptiveDropdown<String>(
            value: _selectedProfession,
            items: Constants.professions,
            itemLabel: (profession) => profession,
            onChanged: (String? newValue) {
              setState(() => _selectedProfession = newValue);
            },
            hint: 'Selecione uma profissão',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedProfession,
      decoration: InputDecoration(
        labelText: 'Profissão',
        prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF6F4B99)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6F4B99), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        filled: true,
        fillColor: Colors.white10,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      dropdownColor: Colors.grey[800],
      items: Constants.professions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedProfession = newValue);
      },
      validator: (value) => value == null ? 'Selecione uma profissão' : null,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

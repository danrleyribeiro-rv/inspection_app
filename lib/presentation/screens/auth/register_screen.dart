// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inspection_app/utils/constants.dart';
import 'package:inspection_app/services/firebase_auth_service.dart';
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
  final _documentController = TextEditingController(); // For CNPJ/CPF
  final _cepController = TextEditingController(); // For CEP
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  String? _selectedProfession; // For profession dropdown
  final _authService = FirebaseAuthService();
  bool _isLoading = false;

  Future<void> _fetchCepData(String cep) async {
    final cepDigits = cep.replaceAll(RegExp(r'\D'), '');
    if (cepDigits.length != 8) return;

    setState(() => _isLoading =
        true); // Consider showing a smaller indicator for just CEP lookup

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cepDigits/json/');
      final response = await http.get(url);

      if (!mounted) return; // Check mounted after await

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro') && data['erro'] == true) {
          // More robust check for 'erro' key
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('CEP not found'), backgroundColor: Colors.orange),
          );
          // Clear fields if CEP is not found? Optional.
          // _streetController.clear();
          // _neighborhoodController.clear();
          // _cityController.clear();
          // _stateController.clear();
        } else {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar CEP: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return; // Check mounted in catch block
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar CEP: $e')),
      );
    } finally {
      if (mounted) {
        // Check mounted in finally
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    // 1. Run basic form validation first
    if (!_formKey.currentState!.validate()) return;

    // 2. Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('As senhas não coincidem'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // 3. Validate CPF/CNPJ *before* starting the loading indicator for registration
    final documentValue = _documentController.text;
    final documentDigits = documentValue.replaceAll(RegExp(r'\D'), '');
    bool isDocumentValid = false;

    if (documentDigits.isNotEmpty) {
      // Only validate if not empty
      if (documentDigits.length == 11) {
        isDocumentValid = cpf_validator.CPFValidator.isValid(documentValue);
        if (!isDocumentValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('O CPF informado é inválido'),
                backgroundColor: Colors.red),
          );
          return; // Stop if invalid
        }
      } else if (documentDigits.length == 14) {
        isDocumentValid = cnpj_validator.CNPJValidator.isValid(documentValue);
        if (!isDocumentValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('O CNPJ informado é inválido'),
                backgroundColor: Colors.red),
          );
          return; // Stop if invalid
        }
      } else {
        // Neither CPF nor CNPJ length
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'O documento deve ser um CPF (11 dígitos) ou CNPJ (14 dígitos)'),
              backgroundColor: Colors.red),
        );
        return; // Stop if invalid length
      }
    } else {
      // Handle case where document might be optional or required
      // If required, the basic form validator should catch it.
      // If optional, we can proceed. For now, assume it's required by validator.
      // If it *can* be empty, set isDocumentValid = true here or adjust logic.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, insira seu CPF ou CNPJ'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // If all checks passed, proceed with registration
    setState(() => _isLoading = true);

    try {
      // Prepare user data for registration
      final userData = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'profession': _selectedProfession,
        // Use the stripped digits or the formatted value? Depends on Firestore needs.
        // Using stripped digits is often cleaner for storage/querying.
        'document': documentDigits,
        'cep': _cepController.text
            .replaceAll(RegExp(r'\D'), ''), // Store digits only
        'street': _streetController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'phonenumber': _phoneController.text
            .replaceAll(RegExp(r'\D'), ''), // Store digits only
      };

      // Register user with the new method that creates user and inspector
      final userCredential = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        userData,
      );

      // Check mounted before proceeding after await
      if (!mounted) return;

      // Send email verification (null check user just in case)
      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registro bem-sucedido! Por favor, verifique seu e-mail para confirmar seu endereço.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5), // Show longer
          ),
        );
        // Navigate to login or a verification pending screen
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        // Handle unexpected case where user is null after successful registration
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registro concluído, mas os dados do usuário estão indisponíveis. Por favor, tente fazer login.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; // Check mounted in catch
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
          // Log the error for debugging
          debugPrint(
              'FirebaseAuthException code: ${e.code}, message: ${e.message}');
          message =
              'Ocorreu um erro inesperado durante o registro. Por favor, tente novamente.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                message), // Removed 'Registration error: ' for cleaner message
            backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return; // Check mounted in catch
      // Log the error for debugging
      debugPrint('Erro inesperado durante o registro: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Ocorreu um erro inesperado: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        // Check mounted in finally
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align labels better
            children: [
              // Personal Information Section
              const Text('Informações Pessoais',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Primeiro Nome', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira seu primeiro nome'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                    labelText: 'Sobrenome', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira seu sobrenome'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProfession,
                decoration: const InputDecoration(
                    labelText: 'Profession', border: OutlineInputBorder()),
                items: Constants.professions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedProfession = newValue);
                },
                validator: (value) =>
                    value == null ? 'Por favor, selecione uma profissão' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentController,
                decoration: const InputDecoration(
                  labelText: 'CNPJ ou CPF', // Updated label
                  border: OutlineInputBorder(),
                  hintText: 'Insira o número do CNPJ ou CPF', // Updated hint
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CpfOuCnpjFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu CNPJ ou CPF';
                  }
                  // Basic length check (more specific validation happens in _signUp)
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length != 11 && digits.length != 14) {
                    return 'Insira 11 dígitos para CPF ou 14 para CNPJ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Telefone',
                    border: OutlineInputBorder(),
                    hintText: '(00) 00000-0000',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TelefoneInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      // Changed '|' to '||'
                      return 'Por favor, insira seu número de telefone';
                    }
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    // Basic length check for common Brazilian mobile/landline formats
                    if (digits.length < 10 || digits.length > 11) {
                      return 'Insira um número de telefone válido (10 ou 11 dígitos)';
                    }
                    return null;
                  }),

              const SizedBox(height: 24),

              // Address Section
              const Text('Endereço',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _cepController,
                  decoration: InputDecoration(
                    // Use InputDecoration for suffixIcon
                    labelText: 'CEP',
                    border: const OutlineInputBorder(),
                    hintText: '00000-000', // Corrected hint format
                    suffixIcon: IconButton(
                      // Add button to trigger search
                      icon: const Icon(Icons.search),
                      tooltip: 'Buscar Endereço pelo CEP',
                      onPressed: () {
                        final cep = _cepController.text;
                        if (cep.isNotEmpty) {
                          _fetchCepData(cep);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Por favor, insira um CEP primeiro')),
                          );
                        }
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CepInputFormatter(),
                  ],
                  onChanged: (value) {
                    // Auto-fetch when 8 digits are entered
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length == 8) {
                      _fetchCepData(digitsOnly);
                    } else {
                      // Clear fields if CEP becomes invalid? Optional.
                      // _streetController.clear();
                      // _neighborhoodController.clear();
                      // _cityController.clear();
                      // _stateController.clear();
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
                  }),
              const SizedBox(height: 16),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira o endereço'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _neighborhoodController,
                decoration: const InputDecoration(
                  labelText: 'Bairro',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, insira o bairro'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align validation messages
                children: [
                  Expanded(
                    flex: 3, // Give City more space
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Por favor, insira a cidade'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1, // State needs less space
                    child: TextFormField(
                      controller: _stateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        hintText: 'UF', // Add hint for abbreviation
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(2), // Limit to 2 chars
                      ],
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
              const SizedBox(height: 24),

              // Account Security Section
              const Text('Segurança da Conta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira seu email';
                  }
                  // Basic email format check
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Por favor, insira um endereço de email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: 'Senha', border: OutlineInputBorder()),
                obscureText: true,
                autocorrect: false,
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
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                    labelText: 'Confirmar Senha', border: OutlineInputBorder()),
                obscureText: true,
                autocorrect: false,
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
              const SizedBox(height: 30), // More space before button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16), // Larger text
                  ),
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          // Constrain indicator size
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : const Text('Criar Conta'),
                ),
              ),
              const SizedBox(height: 20), // Space at the bottom
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

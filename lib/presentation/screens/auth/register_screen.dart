// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inspection_app/utils/constants.dart';
import 'package:inspection_app/services/firebase_auth_service.dart';

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
              const SnackBar(content: Text('CEP not found')),
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
            const SnackBar(content: Text('Error fetching CEP')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare user data for registration
      final userData = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'profession': _selectedProfession,
        'document': _documentController.text.trim(),
        'cep': _cepController.text.trim(),
        'street': _streetController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
      };

      // Register user with the new method that creates user and inspector
      final userCredential = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        userData,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registration successful! Please verify your email address.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';
      
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email address is already in use.';
          break;
        case 'weak-password':
          message = 'The password is too weak.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'An unknown error occurred.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Registration error: $message'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Personal Information
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'First Name', border: OutlineInputBorder()),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your first name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                    labelText: 'Last Name', border: OutlineInputBorder()),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your last name' : null,
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
                    value == null ? 'Please select a profession' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
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
                  hintText: 'Enter CNPJ or CPF',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CpfOuCnpjFormatter(),
                ],
              ),

              const SizedBox(height: 24),

              // Address
              const Text(
                'Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cepController,
                decoration: const InputDecoration(
                  labelText: 'ZIP Code',
                  border: OutlineInputBorder(),
                  hintText: '00.000-000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CepInputFormatter(),
                ],
                onChanged: (value) {
                  // Remove formatting to use only digits
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
                  labelText: 'Street',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _neighborhoodController,
                decoration: const InputDecoration(
                  labelText: 'Neighborhood',
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
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter a password';
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                    labelText: 'Confirm Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty) return 'Please confirm your password';
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
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
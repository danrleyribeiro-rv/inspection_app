// lib/presentation/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inspection_app/services/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkDeepLink();
  }

  Future<void> _checkDeepLink() async {
    try {
      // Check if we're returning from a password reset flow
      final user = _authService.currentUser;
      if (user != null) {
        // Verify if the user has the inspector role
        final isInspector = await _authService.isUserInspector(user.uid);
        
        if (mounted) {
          if (isInspector) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            // If not an inspector, sign out
            await _authService.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apenas vistoriadores podem acessar este aplicativo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Erro ao verificar o link profundo: $e');
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Sign in with Firebase Auth
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // The AuthService already checks if the user is an inspector
      // If we reach here, login was successful
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth Exceptions
      String message = 'Ocorreu um erro durante o login.';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'Nenhum usuário encontrado com este endereço de e-mail.';
          break;
        case 'wrong-password':
          message = 'Senha incorreta.';
          break;
        case 'invalid-email':
          message = 'O endereço de e-mail não é válido.';
          break;
        case 'user-disabled':
          message = 'Este usuário foi desativado.';
          break;
        case 'unauthorized-role':
          message = 'Apenas vistoriadores podem acessar este aplicativo.';
          break;
        default:
          message = e.message ?? 'Ocorreu um erro desconhecido.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Handle other exceptions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ocorreu um erro inesperado: $e'),
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 200,
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira seu e-mail';
                            }
                            if (!value.contains('@')) {
                              return 'Por favor, insira um e-mail válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
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
                          ),
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira sua senha';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: const Text('Esqueceu a senha?'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Não tem uma conta?"),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, '/register');
                              },
                              child: const Text('Registrar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
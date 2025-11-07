// lib/presentation/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lince_inspecoes/services/core/auth_service.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/terms_dialog.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // It's better to not make initState async.
    // Use a post-frame callback to do async work safely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkDeepLink();
      }
    });
  }

  Future<void> _checkDeepLink() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // First async gap
        final isInspector = await _authService.isUserInspector(user.uid);

        // This outer `mounted` check is crucial.
        if (mounted) {
          if (isInspector) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            // Second async gap
            await _authService.signOut();

            // THE FIX: Check for `mounted` AGAIN after the second async gap.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Apenas vistoriadores podem acessar este aplicativo.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar o link profundo: $e');
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
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
        case 'terms-not-accepted':
          // Show terms dialog and handle acceptance
          await _handleTermsNotAccepted();
          return; // Don't show error message, handled in method
        default:
          message = e.message ?? 'Ocorreu um erro desconhecido.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocorreu um erro inesperado: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Check mounted here as well, as the widget could be disposed
      // while the sign-in was in progress.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleTermsNotAccepted() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TermsDialog(isRegistration: true),
    );

    if (!mounted) return;

    if (accepted == true) {
      // Try to sign in again after accepting terms
      try {
        // First, we need to get the current user's ID
        // We'll try to sign in with Firebase directly to get the user
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (credential.user != null) {
          // Accept terms for this user
          await _authService.acceptTerms(credential.user!.uid);
          
          // Now try the full sign in process again
          await _authService.signOut(); // Sign out first
          await _authService.signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Termos aceitos com sucesso! Bem-vindo!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aceitar termos: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // User rejected terms
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessário aceitar os termos para acessar o aplicativo.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
                        Theme.of(context).brightness == Brightness.light
                            ? Image.asset(
                                'assets/images/LINCE_Marca-Roxa.png',
                                height: MediaQuery.of(context).size.height *
                                    0.6 *
                                    0.15,
                              )
                            : SvgPicture.asset(
                                'assets/images/logo.svg',
                                height: MediaQuery.of(context).size.height *
                                    0.6 *
                                    0.15,
                              ),
                        const SizedBox(height: 43),
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
                            labelText: 'Senha',
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
                                ? const AdaptiveProgressIndicator(
                                    color: Color(0xFFFFFFFF),
                                    radius: 10.0)
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

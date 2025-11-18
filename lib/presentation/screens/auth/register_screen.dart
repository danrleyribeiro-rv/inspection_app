// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lince_inspecoes/utils/constants.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';
import 'package:lince_inspecoes/services/core/auth_service.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/terms_dialog.dart';

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

  String? _selectedProfession;
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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

    setState(() => _isLoading = true);

    try {
      final userData = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'profession': _selectedProfession,
        'document': '',
        'cep': '',
        'street': '',
        'neighborhood': '',
        'city': '',
        'state': '',
        'phonenumber': '',
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF312456) : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Registrar',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF312456) : Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
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

              const SizedBox(height: 24),

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
        color: Theme.of(context).primaryColor.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).primaryColor.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.white10 : Colors.grey[100],
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black87,
          fontSize: 12,
        ),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 12,
      ),
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
    );
  }

  Widget _buildDropdownField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (PlatformUtils.isIOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profissão',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
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
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedProfession,
      decoration: InputDecoration(
        labelText: 'Profissão',
        prefixIcon: Icon(Icons.work_outline, color: theme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.white10 : Colors.grey[100],
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black87,
          fontSize: 12,
        ),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 12,
      ),
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
      items: Constants.professions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 12,
            ),
          ),
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
    super.dispose();
  }
}

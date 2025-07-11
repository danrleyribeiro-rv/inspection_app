// lib/presentation/screens/get_started/get_started_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6F4B99), // Cor de fundo especificada
      body: Stack(
        children: [
          // Background SVG image - 50% da tela, posicionado no canto superior esquerdo
          Positioned(
            top: 25,
            left: 0,
            width: MediaQuery.of(context).size.width * 0.914,
            height: MediaQuery.of(context).size.height * 0.914,
            child: SvgPicture.asset(
              'assets/images/LINCE_POS1.svg',
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
            ),
          ),
          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Spacer(),
                  // Texto principal
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Bem-vindo\nao Inspeções.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                        fontFamily: 'BricolageGrotesque',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtítulo
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Realize suas inspeções de forma simples, rápida e eficiente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botões
                  SizedBox(
                    width: double.infinity,
                    height: 67,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        shadowColor: Colors.black.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 67,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6F4B99),
                        elevation: 5,
                        shadowColor: Colors.black.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cadastro',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

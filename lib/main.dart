// lib/main.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/screens/splash/splash_screen.dart';
import 'package:inspection_app/presentation/screens/get_started/get_started_screen.dart';
import 'package:inspection_app/presentation/screens/auth/login_screen.dart';
import 'package:inspection_app/presentation/screens/auth/register_screen.dart';
import 'package:inspection_app/presentation/screens/auth/forgot_password_screen.dart';
import 'package:inspection_app/presentation/screens/auth/reset_password_screen.dart';
import 'package:inspection_app/presentation/screens/home/home_screen.dart';
import 'package:inspection_app/presentation/screens/settings/settings_screen.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/gemini_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar o estilo da barra de navegação para evitar sobreposição
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black, // Cor da barra de navegação
      systemNavigationBarIconBrightness: Brightness.light, // Ícones claros
    ),
  );

  // Habilitar o novo callback de retorno do Android 14+
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  await dotenv.load(fileName: ".env");

  await GeminiService.initialize();

  try {
    await FirebaseService.initialize();

    if (!kIsWeb) {
      print('Configurando persistência offline do Firestore...');
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        print('Configurações do Firestore com persistência offline aplicadas.');
      } catch (e) {
        print('Erro ao configurar persistência offline do Firestore: $e');
      }
    } else {
      print('Persistência offline não suportada na Web.');
    }
  } catch (e) {
    print('Erro ao inicializar Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor:
            const Color(0xFF1E293B), // Slate background color
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.orange,
          surface: Color(0xFF1E293B),
          error: Colors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          fillColor: Colors.white10,
          filled: true,
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        cardTheme: CardTheme(
          color: Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        fontFamily: 'Roboto',
        dividerTheme: DividerThemeData(
          color: Colors.grey[700],
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/get-started': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/media-gallery': (context) {
          // Recuperar o parâmetro inspectionId dos argumentos
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final inspectionId = args?['inspectionId'] as String?;

          if (inspectionId == null) {
            // Redirecionar para home se não houver inspectionId
            Future.microtask(
                () => Navigator.pushReplacementNamed(context, '/home'));
            return const SizedBox
                .shrink(); // Widget temporário até o redirecionamento
          }

          return MediaGalleryScreen(inspectionId: inspectionId);
        },
      },
    );
  }
}

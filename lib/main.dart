// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/screens/splash/splash_screen.dart';
import 'package:inspection_app/presentation/screens/get_started/get_started_screen.dart';
import 'package:inspection_app/presentation/screens/auth/login_screen.dart';
import 'package:inspection_app/presentation/screens/auth/register_screen.dart';
import 'package:inspection_app/presentation/screens/auth/forgot_password_screen.dart';
import 'package:inspection_app/presentation/screens/auth/reset_password_screen.dart';
import 'package:inspection_app/presentation/screens/home/home_screen.dart';
import 'package:inspection_app/presentation/screens/settings/settings_screen.dart';
import 'package:inspection_app/presentation/screens/chat/chat_detail_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inspection_app/services/service_locator.dart';
import 'package:inspection_app/models/chat.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize services
<<<<<<< HEAD
  await ServiceLocator.initialize();
=======
  final serviceLocator = ServiceLocator();
  await serviceLocator.initialize();
>>>>>>> de0814d (Mudanças de arquiterura)

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  await dotenv.load(fileName: ".env");

  // Request initial permissions
  await _requestInitialPermissions();

  runApp(const MyApp());
}

Future<void> _requestInitialPermissions() async {
  await [
    Permission.camera,
    Permission.storage,
    Permission.location,
    Permission.notification,
  ].request();
}

// Rest of the code remains the same...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
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
        fontFamily: 'Inter',
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
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final inspectionId = args?['inspectionId'] as String?;

          if (inspectionId == null) {
            Future.microtask(
                () => Navigator.pushReplacementNamed(context, '/home'));
            return const SizedBox.shrink();
          }

          return MediaGalleryScreen(inspectionId: inspectionId);
        },
        '/chat-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final chatId = args?['chatId'] as String?;

          if (chatId == null) {
            return const Scaffold(
              backgroundColor: Color(0xFF1E293B),
              body: Center(
                child: Text(
                  'Chat não encontrado',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return FutureBuilder<Chat?>(
            future: _getChatById(chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1E293B),
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.data == null) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1E293B),
                  body: Center(
                    child: Text(
                      'Chat não encontrado',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }

              return ChatDetailScreen(chat: snapshot.data!);
            },
          );
        },
      },
    );
  }
}

Future<Chat?> _getChatById(String chatId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (doc.exists) {
      return Chat.fromFirestore(doc);
    }
  } catch (e) {
    print('Erro ao buscar chat: $e');
  }
  return null;
}
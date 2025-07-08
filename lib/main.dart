import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:inspection_app/services/core/firebase_service.dart';
import 'package:inspection_app/services/utils/cache_service.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inspection_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa dependências de plataforma/pacotes externos
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");

  // 2. Inicializa serviços de base que não dependem de outros (são estáticos)
  await CacheService.initialize(); // Prepara o Hive e registra adapters
  await FirebaseService.initialize();

  // 3. Inicializa todos os serviços da aplicação através do ServiceFactory
  //    Esta única chamada agora cria todas as instâncias e resolve as dependências.
  await ServiceFactory().initialize();

  // Configuração da UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primaryColor: const Color(0xFF6F4B99),
        scaffoldBackgroundColor: const Color(0xFF312456),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6F4B99),
          secondary: Colors.orange,
          surface: Color(0xFF312456),
          error: Colors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF312456),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F4B99),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6F4B99),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6F4B99), width: 2),
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
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF312456),
          headerBackgroundColor: const Color(0xFF312456),
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          headerHelpStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          weekdayStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dayStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          yearStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          dayOverlayColor: WidgetStateProperty.all(const Color(0xFF6F4B99).withValues(alpha: 0.1)),
          todayBackgroundColor: WidgetStateProperty.all(const Color(0xFF6F4B99).withValues(alpha: 0.3)),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF6F4B99);
            }
            return Colors.transparent;
          }),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
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

          // THE FIX: Instead of navigating during the build, we return a widget
          // that handles the redirection logic safely.
          if (inspectionId == null) {
            // Return a widget that will redirect safely after it's built.
            return const _Redirect(targetRoute: '/home');
          }

          return MediaGalleryScreen(inspectionId: inspectionId);
        },
      },
    );
  }
}

class _Redirect extends StatefulWidget {
  final String targetRoute;
  const _Redirect({required this.targetRoute});

  @override
  State<_Redirect> createState() => _RedirectState();
}

class _RedirectState extends State<_Redirect> {
  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to schedule the navigation for after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Because we are now in a State object, we can safely check `mounted`.
      if (mounted) {
        Navigator.pushReplacementNamed(context, widget.targetRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return a placeholder widget while the redirection is being scheduled.
    return const Scaffold(
      backgroundColor: Color(0xFF312456),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}


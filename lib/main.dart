import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/screens/splash/splash_screen.dart';
import 'package:lince_inspecoes/presentation/screens/get_started/get_started_screen.dart';
import 'package:lince_inspecoes/presentation/screens/auth/login_screen.dart';
import 'package:lince_inspecoes/presentation/screens/auth/register_screen.dart';
import 'package:lince_inspecoes/presentation/screens/auth/forgot_password_screen.dart';
import 'package:lince_inspecoes/presentation/screens/auth/reset_password_screen.dart';
import 'package:lince_inspecoes/presentation/screens/home/home_screen.dart';
import 'package:lince_inspecoes/presentation/screens/settings/settings_screen.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/native_sync_service.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lince_inspecoes/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa dependências de plataforma/pacotes externos
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found, using default values');
  }

  // 2. Inicializa serviços de base que não dependem de outros (são estáticos)
  await FirebaseService.initialize();

  // 3. Inicializa o novo sistema offline SQLite com Enhanced Service Factory
  await EnhancedOfflineServiceFactory.instance.initialize();

  // 4. Inicializa serviços de notificação
  await SimpleNotificationService.instance.initialize();
  await NativeSyncService.instance.initialize();

  debugPrint('Main: All services initialized successfully');

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

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
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
        fontFamily: 'Inter', // Fonte padrão para o corpo do texto
        textTheme: const TextTheme(
          // Títulos usarão BricolageGrotesque
          displayLarge: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          displayMedium: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          displaySmall: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          titleLarge: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              fontFamily: 'BricolageGrotesque',
              color: Colors.white,
              fontWeight: FontWeight.w600),

          // O corpo do texto e outros usarão Inter por herança
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white70),
          labelSmall: TextStyle(color: Colors.white),
        ),
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
          titleTextStyle: TextStyle(
            fontFamily: 'BricolageGrotesque',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
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
        cardTheme: CardThemeData(
          color: Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey[700],
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF312456),
          headerBackgroundColor: const Color(0xFF312456),
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: const TextStyle(
            fontFamily: 'BricolageGrotesque',
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
          dayOverlayColor: WidgetStateProperty.all(
              const Color(0xFF6F4B99).withValues(alpha: 0.1)),
          todayBackgroundColor: WidgetStateProperty.all(
              const Color(0xFF6F4B99).withValues(alpha: 0.3)),
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

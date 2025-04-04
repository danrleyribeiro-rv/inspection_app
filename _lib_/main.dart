// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// BLOCs
import 'package:inspection_app/blocs/auth/auth_bloc.dart';
import 'package:inspection_app/blocs/inspection/inspection_bloc.dart';
import 'package:inspection_app/blocs/nonconformity/nonconformity_bloc.dart';
import 'package:inspection_app/blocs/settings/settings_bloc.dart';

// Repositories
import 'package:inspection_app/data/repositories/auth_repository_impl.dart';
import 'package:inspection_app/data/repositories/inspection_repository_impl.dart';
import 'package:inspection_app/data/repositories/nonconformity_repository_impl.dart';
import 'package:inspection_app/data/repositories/settings_repository_impl.dart';

// Services
import 'package:inspection_app/services/connectivity/connectivity_service.dart';
import 'package:inspection_app/services/storage/media_storage_service.dart';
import 'package:inspection_app/services/sync/sync_service.dart';
import 'package:inspection_app/services/local_database_service.dart';

// Screens
import 'package:inspection_app/presentation/screens/splash/splash_screen.dart';
import 'package:inspection_app/presentation/screens/get_started/get_started_screen.dart';
import 'package:inspection_app/presentation/screens/auth/login_screen.dart';
import 'package:inspection_app/presentation/screens/auth/register_screen.dart';
import 'package:inspection_app/presentation/screens/auth/forgot_password_screen.dart';
import 'package:inspection_app/presentation/screens/auth/reset_password_screen.dart';
import 'package:inspection_app/presentation/screens/home/home_screen.dart';
import 'package:inspection_app/presentation/screens/settings/settings_screen.dart';

// Utils
import 'package:inspection_app/utils/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local database
  await LocalDatabaseService.initialize();
  
  // Initialize connectivity service
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase if online
  if (!connectivityService.isOffline) {
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? AppConfig.supabaseUrl,
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? AppConfig.supabaseAnonKey,
        debug: false,
      );
    } catch (e) {
      print('Failed to initialize Supabase: $e');
    }
  }
  
  runApp(MyApp(connectivityService: connectivityService));
}

class MyApp extends StatelessWidget {
  final ConnectivityService connectivityService;
  
  const MyApp({Key? key, required this.connectivityService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ConnectivityService>(
          create: (context) => connectivityService,
        ),
        RepositoryProvider<AuthRepositoryImpl>(
          create: (context) => AuthRepositoryImpl(
            connectivityService: connectivityService,
          ),
        ),
        RepositoryProvider<InspectionRepositoryImpl>(
          create: (context) => InspectionRepositoryImpl(
            localDatabaseService: LocalDatabaseService(),
            syncService: SyncService(),
          ),
        ),
        RepositoryProvider<NonConformityRepositoryImpl>(
          create: (context) => NonConformityRepositoryImpl(
            localDatabaseService: LocalDatabaseService(),
            connectivityService: connectivityService,
          ),
        ),
        RepositoryProvider<SettingsRepositoryImpl>(
          create: (context) => SettingsRepositoryImpl(),
        ),
        RepositoryProvider<MediaStorageService>(
          create: (context) => MediaStorageService(),
        ),
        RepositoryProvider<SyncService>(
          create: (context) => SyncService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepositoryImpl>(),
              connectivityService: context.read<ConnectivityService>(),
            )..add(CheckAuthStatus()),
          ),
          BlocProvider<SettingsBloc>(
            create: (context) => SettingsBloc(
              settingsRepository: context.read<SettingsRepositoryImpl>(),
            )..add(LoadSettings()),
          ),
          BlocProvider<InspectionBloc>(
            create: (context) => InspectionBloc(
              inspectionRepository: context.read<InspectionRepositoryImpl>(),
            ),
          ),
          BlocProvider<NonConformityBloc>(
            create: (context) => NonConformityBloc(
              nonConformityRepository: context.read<NonConformityRepositoryImpl>(),
              connectivityService: context.read<ConnectivityService>(),
            ),
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            // Get dark mode setting
            bool darkMode = false;
            if (state is SettingsLoaded) {
              darkMode = state.darkMode;
            }
            
            return MaterialApp(
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primaryColor: AppConfig.primaryColor,
                scaffoldBackgroundColor: Colors.white,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppConfig.primaryColor,
                  brightness: Brightness.light,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  elevation: 0,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppConfig.primaryColor,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppConfig.primaryColor, width: 2),
                  ),
                ),
                fontFamily: 'Roboto',
              ),
              darkTheme: ThemeData(
                primaryColor: AppConfig.primaryColor,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppConfig.primaryColor,
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  elevation: 0,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.lightBlueAccent,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
                fontFamily: 'Roboto',
              ),
              themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
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
              },
            );
                  },
                ),
              ),
            );
          }
        }
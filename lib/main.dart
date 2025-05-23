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
import 'package:inspection_app/services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inspection_app/services/cache_service.dart';
import 'package:inspection_app/models/chat.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();

 // Initialize Firebase
 await Firebase.initializeApp();
 
 // Initialize Firebase Service
 await FirebaseService.initialize();
 
 // Initialize Cache Service
 await CacheService.initialize();

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

 try {
   await FirebaseService.initialize();
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
       '/chat-detail': (context) {
         final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
         
         // Buscar o chat pelo ID e navegar
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

// Função auxiliar para buscar chat
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
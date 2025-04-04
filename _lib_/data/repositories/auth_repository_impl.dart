// lib/data/repositories/auth_repository_impl.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/data/models/user.dart';
import 'package:inspection_app/data/repositories/auth_repository.dart';
import 'package:inspection_app/services/connectivity/connectivity_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final _supabase = Supabase.instance.client;
  final ConnectivityService _connectivityService;

  AuthRepositoryImpl({required ConnectivityService connectivityService}) 
    : _connectivityService = connectivityService;

  @override
  Future<User?> getCurrentUser() async {
    try {
      final supabaseUser = _supabase.auth.currentUser;
      
      if (supabaseUser != null) {
        // Get user profile based on role
        final email = supabaseUser.email ?? '';
        final userId = supabaseUser.id;
        
        try {
          // Check if user is an inspector
          final inspectorData = await _supabase
              .from('inspectors')
              .select('name, last_name, profession')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (inspectorData != null) {
            return User(
              id: userId,
              email: email,
              name: inspectorData['name'],
              lastName: inspectorData['last_name'],
              role: 'inspector',
              profession: inspectorData['profession'],
            );
          }
          
          // Check other roles as needed...
          
        } catch (e) {
          print('Error fetching user profile: $e');
        }
        
        // Default user if no specific profile is found
        return User(
          id: userId,
          email: email,
          role: 'user',
        );
      }
      
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  @override
  Future<User?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final supabaseUser = response.user;
      if (supabaseUser == null) return null;
      
      // Get user profile based on role (inspectors table for now)
      try {
        final inspectorData = await _supabase
            .from('inspectors')
            .select('id, name, last_name, profession')
            .eq('user_id', supabaseUser.id)
            .maybeSingle();
        
        if (inspectorData != null) {
          final user = User(
            id: supabaseUser.id,
            email: email,
            name: inspectorData['name'],
            lastName: inspectorData['last_name'],
            role: 'inspector',
            profession: inspectorData['profession'],
            inspectorId: inspectorData['id'],
          );
          
          // Save user locally for offline login
          await saveLocalUser(user, password);
          
          return user;
        }
        
        // Handle other user types...
      } catch (e) {
        print('Error fetching user profile: $e');
      }
      
      return null;
    } on AuthException catch (e) {
      print('Authentication error: ${e.message}');
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Logout error: $e');
      throw Exception('Failed to log out: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      String redirectUrl = 'io.supabase.flutter://reset-callback/';
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      print('Password reset error: $e');
      throw Exception('Failed to send password reset: $e');
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: password),
      );
    } catch (e) {
      print('Password update error: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  @override
  Future<void> register(Map<String, dynamic> userData) async {
    try {
      // Register the user with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: userData['email'],
        password: userData['password'],
      );
      
      if (authResponse.user != null) {
        final userId = authResponse.user!.id;
        
        // Create inspector profile
        await _supabase.from('inspectors').insert({
          'user_id': userId,
          'name': userData['name'],
          'last_name': userData['last_name'],
          'email': userData['email'],
          'profession': userData['profession'],
          'document': userData['document'],
          'cep': userData['cep'],
          'street': userData['street'],
          'neighborhood': userData['neighborhood'],
          'city': userData['city'],
          'state': userData['state'],
          'phonenumber': userData['phonenumber'],
        });
        
        // Assign inspector role
        await _supabase.from('role_users').insert({
          'user_id': userId,
          'role_id': 11, // inspector role ID
        });
      }
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Failed to register: $e');
    }
  }

  @override
  Future<String?> getUserRole(String userId) async {
    try {
      // Check if user is offline
      if (_connectivityService.isOffline) {
        final prefs = await SharedPreferences.getInstance();
        final localUserJson = prefs.getString('local_user');
        
        if (localUserJson != null) {
          final Map<String, dynamic> userData = jsonDecode(localUserJson);
          return userData['role'];
        }
        
        return null;
      }
      
      // Check roles in order of importance
      try {
        // Check if user is an admin
        final adminData = await _supabase
            .from('admins')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
            
        if (adminData != null) return 'admin';
        
        // Check if user is a manager
        final managerData = await _supabase
            .from('managers')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
            
        if (managerData != null) return 'manager';
        
        // Check if user is an inspector
        final inspectorData = await _supabase
            .from('inspectors')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
            
        if (inspectorData != null) return 'inspector';
        
        // Check if user is a client
        final clientData = await _supabase
            .from('clients')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
            
        if (clientData != null) return 'client';
      } catch (e) {
        print('Error fetching user role: $e');
      }
      
      return 'user'; // Default role
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  @override
  Future<User?> getLocalUser(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUserJson = prefs.getString('local_user');
      
      if (localUserJson != null) {
        final Map<String, dynamic> userData = jsonDecode(localUserJson);
        
        if (userData['email'] == email) {
          return User(
            id: userData['id'],
            email: userData['email'],
            name: userData['name'],
            lastName: userData['lastName'],
            role: userData['role'],
            profession: userData['profession'],
            inspectorId: userData['inspectorId'],
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting local user: $e');
      return null;
    }
  }

  @override
  Future<bool> validateLocalPassword(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPasswordHash = prefs.getString('local_password_hash');
      
      if (localPasswordHash != null) {
        // Hash the provided password
        final passwordHash = sha256.convert(utf8.encode(password)).toString();
        
        // Compare with stored hash
        return passwordHash == localPasswordHash;
      }
      
      return false;
    } catch (e) {
      print('Error validating local password: $e');
      return false;
    }
  }

  @override
  Future<void> saveLocalUser(User user, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save user data
      await prefs.setString('local_user', jsonEncode({
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'lastName': user.lastName,
        'role': user.role,
        'profession': user.profession,
        'inspectorId': user.inspectorId,
      }));
      
      // Save password hash
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      await prefs.setString('local_password_hash', passwordHash);
    } catch (e) {
      print('Error saving local user: $e');
    }
  }
}
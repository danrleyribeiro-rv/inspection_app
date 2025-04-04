// lib/data/repositories/auth_repository.dart
import 'package:inspection_app/data/models/user.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User?> login(String email, String password);
  Future<void> logout();
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String password);
  Future<void> register(Map<String, dynamic> userData);
  Future<String?> getUserRole(String userId);
  
  // Local authentication methods
  Future<User?> getLocalUser(String email);
  Future<bool> validateLocalPassword(String email, String password);
  Future<void> saveLocalUser(User user, String password);
}
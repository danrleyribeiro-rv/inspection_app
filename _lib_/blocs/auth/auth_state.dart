// lib/blocs/auth/auth_state.dart
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String userId;
  final String userEmail;
  final String? userRole;
  final bool isOffline;

  const Authenticated({
    required this.userId, 
    required this.userEmail, 
    this.userRole,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [userId, userEmail, userRole, isOffline];
  
  Authenticated copyWith({
    String? userId,
    String? userEmail,
    String? userRole,
    bool? isOffline,
  }) {
    return Authenticated(
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

class PasswordResetSent extends AuthState {}

class RegistrationSuccess extends AuthState {}
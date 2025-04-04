// lib/blocs/auth/auth_event.dart
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class PasswordResetRequested extends AuthEvent {
  final String email;

  const PasswordResetRequested({required this.email});

  @override
  List<Object> get props => [email];
}

class UpdatePassword extends AuthEvent {
  final String password;

  const UpdatePassword({required this.password});

  @override
  List<Object> get props => [password];
}

class RegisterRequested extends AuthEvent {
  final Map<String, dynamic> userData;

  const RegisterRequested({required this.userData});

  @override
  List<Object> get props => [userData];
}
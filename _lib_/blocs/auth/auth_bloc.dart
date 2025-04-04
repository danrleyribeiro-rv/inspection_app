// lib/blocs/auth/auth_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inspection_app/blocs/auth/auth_event.dart';
import 'package:inspection_app/blocs/auth/auth_state.dart';
import 'package:inspection_app/data/repositories/auth_repository.dart';
import 'package:inspection_app/services/connectivity/connectivity_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final ConnectivityService connectivityService;
  late StreamSubscription _connectivitySubscription;

  AuthBloc({
    required this.authRepository, 
    required this.connectivityService,
  }) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
    on<UpdatePassword>(_onUpdatePassword);
    on<RegisterRequested>(_onRegisterRequested);
    
    // Listen for connectivity changes
    _connectivitySubscription = connectivityService.onConnectivityChanged.listen(
      (isOffline) {
        if (state is Authenticated) {
          final currentState = state as Authenticated;
          emit(currentState.copyWith(isOffline: isOffline));
        }
      },
    );
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      final currentUser = await authRepository.getCurrentUser();
      
      if (currentUser != null) {
        // Get user role
        final userRole = await authRepository.getUserRole(currentUser.id);
        
        emit(Authenticated(
          userId: currentUser.id,
          userEmail: currentUser.email,
          userRole: userRole,
          isOffline: connectivityService.isOffline,
        ));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError('Failed to check authentication status: $e'));
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      if (connectivityService.isOffline) {
        // Check if user exists in local database
        final localUser = await authRepository.getLocalUser(event.email);
        
        if (localUser != null) {
          // Validate password locally
          final isValid = await authRepository.validateLocalPassword(
            event.email, 
            event.password
          );
          
          if (isValid) {
            emit(Authenticated(
              userId: localUser.id,
              userEmail: localUser.email,
              userRole: localUser.role,
              isOffline: true,
            ));
          } else {
            emit(const AuthError('Invalid credentials'));
          }
        } else {
          emit(const AuthError('Cannot login while offline. Please connect to the internet.'));
        }
      } else {
        // Online login
        final user = await authRepository.login(event.email, event.password);
        
        if (user != null) {
          // Get user role
          final userRole = await authRepository.getUserRole(user.id);
          
          emit(Authenticated(
            userId: user.id,
            userEmail: user.email,
            userRole: userRole,
            isOffline: false,
          ));
        } else {
          emit(const AuthError('Invalid credentials'));
        }
      }
    } catch (e) {
      emit(AuthError('Login failed: $e'));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      await authRepository.logout();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError('Logout failed: $e'));
    }
  }

  Future<void> _onPasswordResetRequested(PasswordResetRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      if (connectivityService.isOffline) {
        emit(const AuthError('Cannot request password reset while offline'));
        return;
      }
      
      await authRepository.resetPassword(event.email);
      emit(PasswordResetSent());
    } catch (e) {
      emit(AuthError('Password reset failed: $e'));
    }
  }

  Future<void> _onUpdatePassword(UpdatePassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      if (connectivityService.isOffline) {
        emit(const AuthError('Cannot update password while offline'));
        return;
      }
      
      await authRepository.updatePassword(event.password);
      emit(const AuthError('Password updated successfully'));
    } catch (e) {
      emit(AuthError('Password update failed: $e'));
    }
  }

  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      if (connectivityService.isOffline) {
        emit(const AuthError('Cannot register while offline'));
        return;
      }
      
      await authRepository.register(event.userData);
      emit(RegistrationSuccess());
    } catch (e) {
      emit(AuthError('Registration failed: $e'));
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
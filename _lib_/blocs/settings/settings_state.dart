// lib/blocs/settings/settings_state.dart
import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
  
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final bool darkMode;
  final bool notificationsEnabled;
  final bool locationPermission;
  final bool cameraPermission;

  const SettingsLoaded({
    required this.darkMode,
    required this.notificationsEnabled,
    required this.locationPermission,
    required this.cameraPermission,
  });

  @override
  List<Object> get props => [
    darkMode, 
    notificationsEnabled, 
    locationPermission, 
    cameraPermission
  ];
  
  SettingsLoaded copyWith({
    bool? darkMode,
    bool? notificationsEnabled,
    bool? locationPermission,
    bool? cameraPermission,
  }) {
    return SettingsLoaded(
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationPermission: locationPermission ?? this.locationPermission,
      cameraPermission: cameraPermission ?? this.cameraPermission,
    );
  }
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object> get props => [message];
}

class CacheCleared extends SettingsState {}
// lib/blocs/settings/settings_event.dart
import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class UpdateDarkMode extends SettingsEvent {
  final bool darkMode;

  const UpdateDarkMode(this.darkMode);

  @override
  List<Object> get props => [darkMode];
}

class UpdateNotifications extends SettingsEvent {
  final bool enabled;

  const UpdateNotifications(this.enabled);

  @override
  List<Object> get props => [enabled];
}

class UpdateLocationPermission extends SettingsEvent {
  final bool enabled;

  const UpdateLocationPermission(this.enabled);

  @override
  List<Object> get props => [enabled];
}

class UpdateCameraPermission extends SettingsEvent {
  final bool enabled;

  const UpdateCameraPermission(this.enabled);

  @override
  List<Object> get props => [enabled];
}

class ClearCache extends SettingsEvent {}
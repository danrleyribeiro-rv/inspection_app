// lib/blocs/settings/settings_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inspection_app/blocs/settings/settings_event.dart';
import 'package:inspection_app/blocs/settings/settings_state.dart';
import 'package:inspection_app/data/repositories/settings_repository.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository settingsRepository;

  SettingsBloc({required this.settingsRepository}) : super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateDarkMode>(_onUpdateDarkMode);
    on<UpdateNotifications>(_onUpdateNotifications);
    on<UpdateLocationPermission>(_onUpdateLocationPermission);
    on<UpdateCameraPermission>(_onUpdateCameraPermission);
    on<ClearCache>(_onClearCache);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    
    try {
      final settings = await settingsRepository.getSettings();
      
      emit(SettingsLoaded(
        darkMode: settings['darkMode'] ?? false,
        notificationsEnabled: settings['notificationsEnabled'] ?? true,
        locationPermission: settings['locationPermission'] ?? true,
        cameraPermission: settings['cameraPermission'] ?? true,
      ));
    } catch (e) {
      emit(SettingsError('Failed to load settings: $e'));
    }
  }

  Future<void> _onUpdateDarkMode(UpdateDarkMode event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      try {
        await settingsRepository.saveSettings({
          'darkMode': event.darkMode,
          'notificationsEnabled': currentState.notificationsEnabled,
          'locationPermission': currentState.locationPermission,
          'cameraPermission': currentState.cameraPermission,
        });
        
        emit(currentState.copyWith(darkMode: event.darkMode));
      } catch (e) {
        emit(SettingsError('Failed to update dark mode: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onUpdateNotifications(UpdateNotifications event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      try {
        await settingsRepository.saveSettings({
          'darkMode': currentState.darkMode,
          'notificationsEnabled': event.enabled,
          'locationPermission': currentState.locationPermission,
          'cameraPermission': currentState.cameraPermission,
        });
        
        emit(currentState.copyWith(notificationsEnabled: event.enabled));
      } catch (e) {
        emit(SettingsError('Failed to update notifications: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onUpdateLocationPermission(UpdateLocationPermission event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      try {
        await settingsRepository.saveSettings({
          'darkMode': currentState.darkMode,
          'notificationsEnabled': currentState.notificationsEnabled,
          'locationPermission': event.enabled,
          'cameraPermission': currentState.cameraPermission,
        });
        
        emit(currentState.copyWith(locationPermission: event.enabled));
      } catch (e) {
        emit(SettingsError('Failed to update location permission: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onUpdateCameraPermission(UpdateCameraPermission event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      try {
        await settingsRepository.saveSettings({
          'darkMode': currentState.darkMode,
          'notificationsEnabled': currentState.notificationsEnabled,
          'locationPermission': currentState.locationPermission,
          'cameraPermission': event.enabled,
        });
        
        emit(currentState.copyWith(cameraPermission: event.enabled));
      } catch (e) {
        emit(SettingsError('Failed to update camera permission: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onClearCache(ClearCache event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      try {
        await settingsRepository.clearCache();
        emit(CacheCleared());
        emit(currentState); // Restore current settings after clearing cache
      } catch (e) {
        emit(SettingsError('Failed to clear cache: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }
}
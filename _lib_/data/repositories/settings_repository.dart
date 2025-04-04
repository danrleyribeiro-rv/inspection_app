// lib/data/repositories/settings_repository.dart
abstract class SettingsRepository {
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<void> clearCache();
}
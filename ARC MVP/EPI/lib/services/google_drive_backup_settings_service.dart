// lib/services/google_drive_backup_settings_service.dart
// Persistent storage for Google Drive backup configuration

import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveBackupSettingsService {
  static final GoogleDriveBackupSettingsService _instance = GoogleDriveBackupSettingsService._internal();
  factory GoogleDriveBackupSettingsService() => _instance;
  GoogleDriveBackupSettingsService._internal();

  static GoogleDriveBackupSettingsService get instance => _instance;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if Google Drive backup is enabled
  Future<bool> isEnabled() async {
    await initialize();
    return _prefs!.getBool('google_drive_enabled') ?? false;
  }

  /// Enable/disable Google Drive backup
  Future<void> setEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool('google_drive_enabled', enabled);
  }

  /// Get selected folder ID
  Future<String?> getFolderId() async {
    await initialize();
    return _prefs!.getString('google_drive_folder_id');
  }

  /// Set selected folder ID
  Future<void> setFolderId(String? folderId) async {
    await initialize();
    if (folderId == null) {
      await _prefs!.remove('google_drive_folder_id');
    } else {
      await _prefs!.setString('google_drive_folder_id', folderId);
    }
  }

  /// Get backup format ('mcp' or 'arcx')
  Future<String> getBackupFormat() async {
    await initialize();
    return _prefs!.getString('google_drive_backup_format') ?? 'arcx';
  }

  /// Set backup format
  Future<void> setBackupFormat(String format) async {
    await initialize();
    if (format != 'mcp' && format != 'arcx') {
      throw ArgumentError('Format must be "mcp" or "arcx"');
    }
    await _prefs!.setString('google_drive_backup_format', format);
  }

  /// Check if scheduled backups are enabled
  Future<bool> isScheduleEnabled() async {
    await initialize();
    return _prefs!.getBool('google_drive_schedule_enabled') ?? false;
  }

  /// Enable/disable scheduled backups
  Future<void> setScheduleEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool('google_drive_schedule_enabled', enabled);
  }

  /// Get schedule frequency ('daily', 'weekly', 'monthly')
  Future<String> getScheduleFrequency() async {
    await initialize();
    return _prefs!.getString('google_drive_schedule_frequency') ?? 'daily';
  }

  /// Set schedule frequency
  Future<void> setScheduleFrequency(String frequency) async {
    await initialize();
    if (!['daily', 'weekly', 'monthly'].contains(frequency)) {
      throw ArgumentError('Frequency must be "daily", "weekly", or "monthly"');
    }
    await _prefs!.setString('google_drive_schedule_frequency', frequency);
  }

  /// Get schedule time (HH:mm format)
  Future<String> getScheduleTime() async {
    await initialize();
    return _prefs!.getString('google_drive_schedule_time') ?? '02:00';
  }

  /// Set schedule time
  Future<void> setScheduleTime(String time) async {
    await initialize();
    // Validate HH:mm format
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(time)) {
      throw ArgumentError('Time must be in HH:mm format');
    }
    await _prefs!.setString('google_drive_schedule_time', time);
  }

  /// Get last backup timestamp
  Future<DateTime?> getLastBackup() async {
    await initialize();
    final timestamp = _prefs!.getString('google_drive_last_backup');
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  /// Set last backup timestamp
  Future<void> setLastBackup(DateTime timestamp) async {
    await initialize();
    await _prefs!.setString('google_drive_last_backup', timestamp.toIso8601String());
  }

  /// Clear all Google Drive backup settings
  Future<void> clearAll() async {
    await initialize();
    await _prefs!.remove('google_drive_enabled');
    await _prefs!.remove('google_drive_folder_id');
    await _prefs!.remove('google_drive_backup_format');
    await _prefs!.remove('google_drive_schedule_enabled');
    await _prefs!.remove('google_drive_schedule_frequency');
    await _prefs!.remove('google_drive_schedule_time');
    await _prefs!.remove('google_drive_last_backup');
  }
}


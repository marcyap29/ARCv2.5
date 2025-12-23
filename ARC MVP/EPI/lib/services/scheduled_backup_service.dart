// lib/services/scheduled_backup_service.dart
// Scheduled backup service for periodic Google Drive backups

import 'dart:async';
import 'package:my_app/services/google_drive_backup_settings_service.dart';
import 'package:my_app/services/backup_upload_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/services/phase_regime_service.dart';

/// Scheduled backup service
class ScheduledBackupService {
  static final ScheduledBackupService _instance = ScheduledBackupService._internal();
  factory ScheduledBackupService() => _instance;
  ScheduledBackupService._internal();

  static ScheduledBackupService get instance => _instance;

  final GoogleDriveBackupSettingsService _settingsService = GoogleDriveBackupSettingsService.instance;
  final BackupUploadService _uploadService = BackupUploadService.instance;

  Timer? _scheduleTimer;
  bool _isRunning = false;

  /// Start the scheduled backup service
  Future<void> start({
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    if (_isRunning) {
      print('Scheduled Backup Service: Already running');
      return;
    }

    _isRunning = true;

    // Check schedule every minute
    _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndRunBackup(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
    });

    // Do initial check
    _checkAndRunBackup(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
      phaseRegimeService: phaseRegimeService,
    );

    print('Scheduled Backup Service: Started');
  }

  /// Stop the scheduled backup service
  void stop() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    _isRunning = false;
    print('Scheduled Backup Service: Stopped');
  }

  /// Check if backup should run and execute if needed
  Future<void> _checkAndRunBackup({
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    try {
      // Check if scheduled backups are enabled
      final isEnabled = await _settingsService.isEnabled();
      if (!isEnabled) {
        return;
      }

      final isScheduleEnabled = await _settingsService.isScheduleEnabled();
      if (!isScheduleEnabled) {
        return;
      }

      // Check if it's time to run backup
      final shouldRun = await _shouldRunBackup();
      if (!shouldRun) {
        return;
      }

      print('Scheduled Backup Service: Time to run backup');

      // Run backup
      await _uploadService.createAndUploadBackup(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );

      // Backup completed
    } catch (e) {
      print('Scheduled Backup Service: Error checking backup schedule: $e');
    }
  }

  /// Check if backup should run based on schedule
  Future<bool> _shouldRunBackup() async {
    try {
      final lastBackup = await _settingsService.getLastBackup();
      final frequency = await _settingsService.getScheduleFrequency();
      final scheduleTime = await _settingsService.getScheduleTime();

      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);

      // Parse schedule time
      final timeParts = scheduleTime.split(':');
      final scheduleHour = int.parse(timeParts[0]);
      final scheduleMinute = int.parse(timeParts[1]);
      final scheduleTimeOfDay = TimeOfDay(hour: scheduleHour, minute: scheduleMinute);

      // Check if we're within the scheduled time window (within 1 minute)
      final isWithinTimeWindow = currentTime.hour == scheduleTimeOfDay.hour &&
          currentTime.minute == scheduleTimeOfDay.minute;

      if (!isWithinTimeWindow) {
        return false;
      }

      // Check if we already ran a backup today
      if (lastBackup != null) {
        final lastBackupDate = DateTime(lastBackup.year, lastBackup.month, lastBackup.day);
        final today = DateTime(now.year, now.month, now.day);

        switch (frequency) {
          case 'daily':
            // Run if last backup was not today
            return lastBackupDate.isBefore(today);
          case 'weekly':
            // Run if last backup was more than 7 days ago
            final daysSinceLastBackup = today.difference(lastBackupDate).inDays;
            return daysSinceLastBackup >= 7;
          case 'monthly':
            // Run if last backup was more than 30 days ago
            final daysSinceLastBackup = today.difference(lastBackupDate).inDays;
            return daysSinceLastBackup >= 30;
          default:
            return false;
        }
      }

      // No previous backup, should run
      return true;
    } catch (e) {
      print('Scheduled Backup Service: Error checking schedule: $e');
      return false;
    }
  }

  /// Check if service is running
  bool get isRunning => _isRunning;
}

/// TimeOfDay helper class
class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});

  factory TimeOfDay.fromDateTime(DateTime dateTime) {
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }
}


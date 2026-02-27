// lib/services/health_data_refresh_service.dart
// Automatic daily health data refresh service

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/main/bootstrap.dart';

/// TimeOfDay helper class for health refresh time
class HealthRefreshTimeOfDay {
  final int hour;
  final int minute;

  HealthRefreshTimeOfDay({required this.hour, required this.minute});

  factory HealthRefreshTimeOfDay.fromString(String timeString) {
    final parts = timeString.split(':');
    return HealthRefreshTimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  bool isSameTime(DateTime dateTime) {
    return dateTime.hour == hour && dateTime.minute == minute;
  }
}

/// Service for managing automatic health data refresh
class HealthDataRefreshService {
  static final HealthDataRefreshService _instance = HealthDataRefreshService._internal();
  factory HealthDataRefreshService() => _instance;
  HealthDataRefreshService._internal();

  static HealthDataRefreshService get instance => _instance;

  final HealthDataService _healthDataService = HealthDataService.instance;
  SharedPreferences? _prefs;

  Timer? _refreshTimer;
  bool _isRefreshing = false;

  // SharedPreferences keys
  static const String _keyAutoRefreshEnabled = 'health_auto_refresh_enabled';
  static const String _keyRefreshTime = 'health_refresh_time';
  static const String _keyLastRefreshTime = 'health_last_refresh_time';

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Start scheduled refresh service
  Future<void> startScheduledRefresh() async {
    await initialize();

    final isEnabled = await isAutoRefreshEnabled();
    if (!isEnabled) {
      logger.d('Health Data Refresh: Auto-refresh not enabled');
      return;
    }

    // Stop existing timer if any
    stopScheduledRefresh();

    // Check every hour for scheduled refresh time
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndRunRefresh();
    });

    // Also check immediately
    _checkAndRunRefresh();

    logger.d('Health Data Refresh: Scheduled refresh service started');
  }

  /// Stop scheduled refresh service
  void stopScheduledRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    logger.d('Health Data Refresh: Scheduled refresh service stopped');
  }

  /// Check if refresh should run and execute if needed
  Future<void> _checkAndRunRefresh() async {
    try {
      await initialize();

      final isEnabled = await isAutoRefreshEnabled();
      if (!isEnabled) {
        return;
      }

      // Check if refresh is already in progress
      if (_isRefreshing) {
        return;
      }

      final timeString = await getRefreshTime();
      final refreshTime = HealthRefreshTimeOfDay.fromString(timeString);
      final now = DateTime.now();

      // Check if it's the scheduled time
      if (!refreshTime.isSameTime(now)) {
        return;
      }

      // Check if already refreshed today
      final lastRefresh = await getLastRefreshTime();
      if (lastRefresh != null) {
        final lastRefreshDate = DateTime(lastRefresh.year, lastRefresh.month, lastRefresh.day);
        final today = DateTime(now.year, now.month, now.day);

        if (lastRefreshDate == today) {
          // Already refreshed today
          return;
        }
      }

      // Run refresh
      logger.d('Health Data Refresh: Starting scheduled refresh...');
      await _performRefresh();
    } catch (e) {
      logger.w('Health Data Refresh: Error checking refresh schedule: $e');
    }
  }

  /// Check if data is stale and refresh if needed
  Future<void> checkAndRefreshIfNeeded({bool force = false}) async {
    try {
      await initialize();

      if (!force) {
        final stale = await isDataStale();
        if (!stale) {
          // Check if app just resumed after >1 hour pause
          final lastRefresh = await getLastRefreshTime();
          if (lastRefresh != null) {
            final hoursSinceRefresh = DateTime.now().difference(lastRefresh).inHours;
            if (hoursSinceRefresh < 1) {
              // Refreshed less than 1 hour ago, skip
              logger.d('Health Data Refresh: Data is fresh, skipping refresh');
              return;
            }
          } else {
            // Never refreshed, but not stale yet (less than 24 hours)
            // Only refresh if forced
            return;
          }
        }
      }

      await _performRefresh();
    } catch (e) {
      logger.w('Health Data Refresh: Error checking and refreshing: $e');
      rethrow;
    }
  }

  /// Force immediate refresh (manual)
  Future<void> forceRefresh() async {
    await _performRefresh();
  }

  /// Perform the actual refresh
  Future<void> _performRefresh() async {
    if (_isRefreshing) {
      logger.d('Health Data Refresh: Refresh already in progress');
      return;
    }

    _isRefreshing = true;
    try {
      logger.d('Health Data Refresh: Refreshing health data...');

      // Get auto-detected health data
      final autoHealthData = await _healthDataService.getAutoDetectedHealthData();

      // Update health data service with auto-detected values
      await _healthDataService.updateHealthData(
        sleepQuality: autoHealthData.sleepQuality,
        energyLevel: autoHealthData.energyLevel,
      );

      // Update last refresh timestamp
      await setLastRefreshTime(DateTime.now());

      logger.i('Health Data Refresh: Health data refreshed successfully');
    } catch (e) {
      logger.e('Health Data Refresh: Failed to refresh health data: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Check if data is stale (>24 hours old)
  Future<bool> isDataStale() async {
    await initialize();
    final lastRefresh = await getLastRefreshTime();
    if (lastRefresh == null) return true; // Never refreshed, consider stale
    
    final hoursSinceRefresh = DateTime.now().difference(lastRefresh).inHours;
    return hoursSinceRefresh >= 24;
  }

  /// Get last refresh timestamp
  Future<DateTime?> getLastRefreshTime() async {
    await initialize();
    final timeString = _prefs!.getString(_keyLastRefreshTime);
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }

  /// Set last refresh timestamp
  Future<void> setLastRefreshTime(DateTime time) async {
    await initialize();
    await _prefs!.setString(_keyLastRefreshTime, time.toIso8601String());
    await _healthDataService.setLastAutoRefreshTime(time);
  }

  /// Get refresh time preference (default: "08:00")
  Future<String> getRefreshTime() async {
    await initialize();
    return _prefs!.getString(_keyRefreshTime) ?? '08:00';
  }

  /// Set refresh time preference ("HH:mm" format)
  Future<void> setRefreshTime(String time) async {
    await initialize();
    await _prefs!.setString(_keyRefreshTime, time);
    
    // Restart scheduled refresh with new time
    final isEnabled = await isAutoRefreshEnabled();
    if (isEnabled) {
      await startScheduledRefresh();
    }
  }

  /// Get auto-refresh enabled preference (default: true)
  Future<bool> isAutoRefreshEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyAutoRefreshEnabled) ?? true;
  }

  /// Set auto-refresh enabled preference
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keyAutoRefreshEnabled, enabled);
    
    if (enabled) {
      await startScheduledRefresh();
    } else {
      stopScheduledRefresh();
    }
  }
}


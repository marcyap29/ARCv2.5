import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable cadence for automatic CHRONICLE synthesis.
enum ChronicleScheduleCadence {
  daily,
  weekly,
  monthly,
}

extension ChronicleScheduleCadenceExtension on ChronicleScheduleCadence {
  String get label {
    switch (this) {
      case ChronicleScheduleCadence.daily:
        return 'Daily';
      case ChronicleScheduleCadence.weekly:
        return 'Weekly';
      case ChronicleScheduleCadence.monthly:
        return 'Monthly';
    }
  }

  String get description {
    switch (this) {
      case ChronicleScheduleCadence.daily:
        return 'Check and synthesize every day';
      case ChronicleScheduleCadence.weekly:
        return 'Check and synthesize every week';
      case ChronicleScheduleCadence.monthly:
        return 'Check and synthesize every month';
    }
  }

  Duration get interval {
    switch (this) {
      case ChronicleScheduleCadence.daily:
        return const Duration(days: 1);
      case ChronicleScheduleCadence.weekly:
        return const Duration(days: 7);
      case ChronicleScheduleCadence.monthly:
        return const Duration(days: 30);
    }
  }
}

const String _kChronicleScheduleCadenceKey = 'chronicle_schedule_cadence';

/// Persists and reads the user's chosen synthesis schedule cadence.
class ChronicleSchedulePreferences {
  static ChronicleScheduleCadence _defaultCadence = ChronicleScheduleCadence.daily;

  /// Get stored cadence (defaults to daily).
  static Future<ChronicleScheduleCadence> getCadence() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kChronicleScheduleCadenceKey);
    if (value == null) return _defaultCadence;
    switch (value) {
      case 'daily':
        return ChronicleScheduleCadence.daily;
      case 'weekly':
        return ChronicleScheduleCadence.weekly;
      case 'monthly':
        return ChronicleScheduleCadence.monthly;
      default:
        return _defaultCadence;
    }
  }

  /// Save cadence.
  static Future<void> setCadence(ChronicleScheduleCadence cadence) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kChronicleScheduleCadenceKey,
      cadence.name,
    );
  }
}

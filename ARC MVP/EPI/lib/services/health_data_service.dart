// lib/services/health_data_service.dart
// Service to persist and provide health data for LUMARA control state

import 'package:shared_preferences/shared_preferences.dart';

/// Health data that influences LUMARA's behavior
class HealthData {
  final double sleepQuality; // 0.0 - 1.0
  final double energyLevel; // 0.0 - 1.0
  final bool? medicationStatus; // true = taken, false = missed, null = not tracking
  final DateTime? lastUpdated;

  const HealthData({
    required this.sleepQuality,
    required this.energyLevel,
    this.medicationStatus,
    this.lastUpdated,
  });

  /// Default health values (moderate/neutral)
  static const HealthData defaults = HealthData(
    sleepQuality: 0.7,
    energyLevel: 0.7,
    medicationStatus: null,
    lastUpdated: null,
  );

  /// Check if data is stale (older than 24 hours)
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!).inHours > 24;
  }

  /// Get effective values (use defaults if stale)
  HealthData get effective {
    if (isStale) return defaults;
    return this;
  }

  Map<String, dynamic> toJson() => {
    'sleepQuality': sleepQuality,
    'energyLevel': energyLevel,
    'medicationStatus': medicationStatus,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      sleepQuality: (json['sleepQuality'] as num?)?.toDouble() ?? 0.7,
      energyLevel: (json['energyLevel'] as num?)?.toDouble() ?? 0.7,
      medicationStatus: json['medicationStatus'] as bool?,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }
}

/// Service for managing health data persistence and retrieval
class HealthDataService {
  static HealthDataService? _instance;
  static HealthDataService get instance {
    _instance ??= HealthDataService._();
    return _instance!;
  }

  HealthDataService._();

  SharedPreferences? _prefs;

  // Keys for SharedPreferences
  static const String _keySleepQuality = 'health_sleep_quality';
  static const String _keyEnergyLevel = 'health_energy_level';
  static const String _keyMedicationStatus = 'health_medication_status';
  static const String _keyLastUpdated = 'health_last_updated';

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get current health data
  Future<HealthData> getHealthData() async {
    await initialize();
    
    final sleepQuality = _prefs!.getDouble(_keySleepQuality) ?? 0.7;
    final energyLevel = _prefs!.getDouble(_keyEnergyLevel) ?? 0.7;
    final medicationStatusInt = _prefs!.getInt(_keyMedicationStatus);
    final lastUpdatedStr = _prefs!.getString(_keyLastUpdated);

    bool? medicationStatus;
    if (medicationStatusInt != null) {
      medicationStatus = medicationStatusInt == 1;
    }

    DateTime? lastUpdated;
    if (lastUpdatedStr != null) {
      lastUpdated = DateTime.tryParse(lastUpdatedStr);
    }

    return HealthData(
      sleepQuality: sleepQuality,
      energyLevel: energyLevel,
      medicationStatus: medicationStatus,
      lastUpdated: lastUpdated,
    );
  }

  /// Get effective health data (returns defaults if stale)
  Future<HealthData> getEffectiveHealthData() async {
    final data = await getHealthData();
    return data.effective;
  }

  /// Update sleep quality (0.0 - 1.0)
  Future<void> setSleepQuality(double value) async {
    await initialize();
    await _prefs!.setDouble(_keySleepQuality, value.clamp(0.0, 1.0));
    await _updateTimestamp();
  }

  /// Update energy level (0.0 - 1.0)
  Future<void> setEnergyLevel(double value) async {
    await initialize();
    await _prefs!.setDouble(_keyEnergyLevel, value.clamp(0.0, 1.0));
    await _updateTimestamp();
  }

  /// Update medication status
  Future<void> setMedicationStatus(bool? status) async {
    await initialize();
    if (status == null) {
      await _prefs!.remove(_keyMedicationStatus);
    } else {
      await _prefs!.setInt(_keyMedicationStatus, status ? 1 : 0);
    }
    await _updateTimestamp();
  }

  /// Update all health data at once
  Future<void> updateHealthData({
    double? sleepQuality,
    double? energyLevel,
    bool? medicationStatus,
  }) async {
    await initialize();
    
    if (sleepQuality != null) {
      await _prefs!.setDouble(_keySleepQuality, sleepQuality.clamp(0.0, 1.0));
    }
    if (energyLevel != null) {
      await _prefs!.setDouble(_keyEnergyLevel, energyLevel.clamp(0.0, 1.0));
    }
    if (medicationStatus != null) {
      await _prefs!.setInt(_keyMedicationStatus, medicationStatus ? 1 : 0);
    }
    
    await _updateTimestamp();
  }

  /// Update the last updated timestamp
  Future<void> _updateTimestamp() async {
    await _prefs!.setString(_keyLastUpdated, DateTime.now().toIso8601String());
  }

  /// Clear all health data
  Future<void> clearHealthData() async {
    await initialize();
    await _prefs!.remove(_keySleepQuality);
    await _prefs!.remove(_keyEnergyLevel);
    await _prefs!.remove(_keyMedicationStatus);
    await _prefs!.remove(_keyLastUpdated);
  }
}


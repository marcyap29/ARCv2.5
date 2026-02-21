// lib/services/health_data_service.dart
// Service to persist and provide health data for LUMARA control state

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';
import 'package:my_app/prism/models/health_daily.dart';

/// Health data that influences LUMARA's behavior
class HealthData {
  final double sleepQuality; // 0.0 - 1.0
  final double energyLevel; // 0.0 - 1.0
  final bool? medicationStatus; // true = taken, false = missed, null = not tracking
  final DateTime? lastUpdated;
  
  // Additional health factors
  final double? fitnessScore; // 0.0-1.0 (from VO2 Max)
  final double? recoveryScore; // 0.0-1.0 (from HR recovery)
  final double? weightTrendScore; // 0.0-1.0 (from weight changes)

  const HealthData({
    required this.sleepQuality,
    required this.energyLevel,
    this.medicationStatus,
    this.lastUpdated,
    this.fitnessScore,
    this.recoveryScore,
    this.weightTrendScore,
  });

  /// Default health values (moderate/neutral)
  static const HealthData defaults = HealthData(
    sleepQuality: 0.7,
    energyLevel: 0.7,
    medicationStatus: null,
    lastUpdated: null,
    fitnessScore: null,
    recoveryScore: null,
    weightTrendScore: null,
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
    'fitnessScore': fitnessScore,
    'recoveryScore': recoveryScore,
    'weightTrendScore': weightTrendScore,
  };

  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      sleepQuality: (json['sleepQuality'] as num?)?.toDouble() ?? 0.7,
      energyLevel: (json['energyLevel'] as num?)?.toDouble() ?? 0.7,
      medicationStatus: json['medicationStatus'] as bool?,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
      fitnessScore: (json['fitnessScore'] as num?)?.toDouble(),
      recoveryScore: (json['recoveryScore'] as num?)?.toDouble(),
      weightTrendScore: (json['weightTrendScore'] as num?)?.toDouble(),
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
  static const String _keyLastAutoRefreshTime = 'health_last_auto_refresh_time';

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
    await _prefs!.remove(_keyLastAutoRefreshTime);
  }

  /// Set last auto-refresh timestamp
  Future<void> setLastAutoRefreshTime(DateTime time) async {
    await initialize();
    await _prefs!.setString(_keyLastAutoRefreshTime, time.toIso8601String());
  }

  /// Get last auto-refresh timestamp
  Future<DateTime?> getLastAutoRefreshTime() async {
    await initialize();
    final timeString = _prefs!.getString(_keyLastAutoRefreshTime);
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }

  /// Calculate sleep quality (0.0 - 1.0) from health metrics
  /// 
  /// Uses sleep duration, HRV, and resting heart rate to determine sleep quality.
  /// Higher values indicate better sleep quality.
  static double calculateSleepQuality({
    required int sleepMin,        // Total sleep minutes
    double? hrvSdnn,              // Heart rate variability (higher = better recovery)
    double? restingHr,            // Resting heart rate (elevated = poor recovery)
  }) {
    // Base score from sleep duration
    double baseScore;
    if (sleepMin >= 480) {        // 8+ hours
      baseScore = 0.9;
    } else if (sleepMin >= 360) { // 6-8 hours
      baseScore = 0.7;
    } else if (sleepMin >= 240) { // 4-6 hours
      baseScore = 0.4;
    } else {                       // <4 hours
      baseScore = 0.2;
    }
    
    // HRV adjustment (+/- 10%)
    if (hrvSdnn != null) {
      // Normal HRV range: 20-60ms (adjust based on user baseline)
      // High HRV (>50ms) indicates good recovery
      // Low HRV (<30ms) indicates poor recovery
      if (hrvSdnn > 50) {
        baseScore += 0.1;
      } else if (hrvSdnn < 30) {
        baseScore -= 0.1;
      }
    }
    
    // Resting HR adjustment (-10% if elevated)
    if (restingHr != null) {
      // Elevated = >10% above baseline (assume 60-70 bpm baseline)
      // Resting HR > 75 bpm suggests poor recovery
      if (restingHr > 75) {
        baseScore -= 0.1;
      }
    }
    
    return baseScore.clamp(0.0, 1.0);
  }

  /// Calculate energy level (0.0 - 1.0) from health metrics
  /// 
  /// Uses steps, exercise time, and active calories to determine energy level.
  /// Higher values indicate higher energy/activity.
  static double calculateEnergyLevel({
    required int steps,           // Daily steps
    double? activeKcal,          // Active calories burned
    int? exerciseMin,            // Exercise minutes
  }) {
    // Base score from steps
    double baseScore;
    if (steps >= 10000) {
      baseScore = 0.8;
    } else if (steps >= 5000) {
      baseScore = 0.6;
    } else if (steps >= 2500) {
      baseScore = 0.4;
    } else {
      baseScore = 0.3;
    }
    
    // Exercise bonus (+15% if 30+ min)
    if (exerciseMin != null && exerciseMin >= 30) {
      baseScore += 0.15;
    }
    
    // Active calories adjustment
    if (activeKcal != null) {
      if (activeKcal > 500) {
        baseScore += 0.05;
      } else if (activeKcal < 200) {
        baseScore -= 0.05;
      }
    }
    
    return baseScore.clamp(0.0, 1.0);
  }

  /// Calculate fitness score (0.0-1.0) from VO2 Max
  /// Higher VO2 Max = better fitness = higher score
  static double? calculateFitnessScore(double? vo2Max) {
    if (vo2Max == null) return null;
    
    // VO2 Max ranges (ml/(kg·min)):
    // Excellent: >55 (men), >45 (women) - use 50 as good threshold
    // Good: 45-55 (men), 35-45 (women) - use 40 as moderate
    // Fair: 35-45 (men), 25-35 (women) - use 30 as fair
    // Poor: <35 (men), <25 (women) - use 25 as poor
    
    // Using gender-neutral approximation
    if (vo2Max >= 50) return 0.9; // Excellent
    if (vo2Max >= 40) return 0.75; // Good
    if (vo2Max >= 30) return 0.6; // Fair
    if (vo2Max >= 25) return 0.4; // Below average
    return 0.2; // Poor
  }

  /// Calculate recovery score (0.0-1.0) from heart rate recovery
  /// HR recovery = bpm drop after 1 minute post-exercise
  /// Higher drop = better recovery = higher score
  static double? calculateRecoveryScore(double? hrRecovery1Min) {
    if (hrRecovery1Min == null) return null;
    
    // HR Recovery 1-min ranges (bpm drop):
    // Excellent: >30 bpm drop
    // Good: 20-30 bpm drop
    // Fair: 15-20 bpm drop
    // Poor: <15 bpm drop
    
    if (hrRecovery1Min > 30) return 0.9; // Excellent
    if (hrRecovery1Min >= 20) return 0.75; // Good
    if (hrRecovery1Min >= 15) return 0.6; // Fair
    return 0.3; // Poor
  }

  /// Calculate weight trend score (0.0-1.0) from weight changes
  /// Compares current weight to recent average (last 7 days)
  /// Stable or healthy trend = higher score
  static double? calculateWeightTrendScore({
    required double? currentWeight,
    required List<double> recentWeights, // Last 7-14 days
  }) {
    if (currentWeight == null || recentWeights.isEmpty) return null;
    
    // Need at least 3 data points for trend analysis
    if (recentWeights.length < 3) return null;
    
    // Calculate average of recent weights (excluding current)
    final avgWeight = recentWeights.reduce((a, b) => a + b) / recentWeights.length;
    
    // Calculate percentage change
    final percentChange = ((currentWeight - avgWeight) / avgWeight) * 100;
    
    // Score based on weight change:
    // Stable (within ±2%): 0.8-1.0
    // Slight loss (2-5%): 0.7-0.9 (healthy if intentional)
    // Slight gain (2-5%): 0.6-0.8
    // Moderate loss (>5%): 0.4-0.6 (concerning)
    // Moderate gain (>5%): 0.3-0.5 (concerning)
    
    if (percentChange.abs() <= 2) {
      return 0.9; // Stable weight
    } else if (percentChange < -5) {
      // Significant weight loss (concerning)
      return 0.4;
    } else if (percentChange > 5) {
      // Significant weight gain (concerning)
      return 0.5;
    } else if (percentChange < 0) {
      // Slight loss (2-5%)
      return 0.75;
    } else {
      // Slight gain (2-5%)
      return 0.65;
    }
  }

  /// Get auto-detected health data from imported Apple Health data
  /// 
  /// Reads the latest health day from imported health files and calculates
  /// sleep quality and energy level automatically.
  /// Returns defaults if no health data is available.
  Future<HealthData> getAutoDetectedHealthData() async {
    try {
      // Get today's and yesterday's date keys (YYYY-MM-DD)
      final now = DateTime.now().toUtc();
      final todayKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayKey = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      
      // Try today first, then yesterday
      HealthDaily? healthDay;
      for (final dayKey in [todayKey, yesterdayKey]) {
        healthDay = await _getHealthDayFromFiles(dayKey);
        if (healthDay != null) break;
      }
      
      if (healthDay == null) {
        // No health data available, return defaults
        return HealthData.defaults;
      }
      
      // Calculate sleep quality
      final sleepQuality = calculateSleepQuality(
        sleepMin: healthDay.sleepMin,
        hrvSdnn: healthDay.hrvSdnn,
        restingHr: healthDay.restingHr,
      );
      
      // Calculate energy level
      final energyLevel = calculateEnergyLevel(
        steps: healthDay.steps,
        activeKcal: healthDay.activeKcal,
        exerciseMin: healthDay.exerciseMin,
      );
      
      // Calculate fitness score from VO2 Max
      final fitnessScore = calculateFitnessScore(healthDay.vo2Max);
      
      // Calculate recovery score from HR recovery
      final recoveryScore = calculateRecoveryScore(healthDay.cardioRecovery1Min);
      
      // Calculate weight trend score (need to get recent weights)
      double? weightTrendScore;
      if (healthDay.weightKg != null) {
        final recentWeights = await _getRecentWeights(now, 14); // Last 14 days
        if (recentWeights.isNotEmpty) {
          weightTrendScore = calculateWeightTrendScore(
            currentWeight: healthDay.weightKg,
            recentWeights: recentWeights,
          );
        }
      }
      
      return HealthData(
        sleepQuality: sleepQuality,
        energyLevel: energyLevel,
        medicationStatus: null, // TODO: Extract from healthDay.medications if needed
        lastUpdated: DateTime.now(),
        fitnessScore: fitnessScore,
        recoveryScore: recoveryScore,
        weightTrendScore: weightTrendScore,
      );
    } catch (e) {
      // If any error occurs, return defaults
      return HealthData.defaults;
    }
  }

  /// Get health day data from imported files for a specific date key (YYYY-MM-DD)
  Future<HealthDaily?> _getHealthDayFromFiles(String dayKey) async {
    try {
      // Extract month key (YYYY-MM) from day key
      final monthKey = dayKey.substring(0, 7);
      final file = await McpFs.healthMonth(monthKey);
      
      if (!await file.exists()) {
        return null;
      }
      
      // Read file and find matching day
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          if (obj['type'] != 'health.timeslice.daily') continue;
          
          final startIso = (obj['timeslice']?['start'] as String?) ?? '';
          if (startIso.isEmpty) continue;
          
          // Extract day key from ISO string
          final day = DateTime.parse(startIso).toUtc();
          final objDayKey = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          
          if (objDayKey == dayKey) {
            // Found matching day, parse into HealthDaily
            return _parseHealthDailyFromJson(obj);
          }
        } catch (_) {
          // Skip malformed lines
          continue;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse HealthDaily from JSON object
  HealthDaily _parseHealthDailyFromJson(Map<String, dynamic> obj) {
    final startIso = (obj['timeslice']?['start'] as String?) ?? '';
    final day = DateTime.parse(startIso).toUtc();
    final dayKey = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    
    final healthDay = HealthDaily(dayKey);
    
    // Extract metrics from the metrics object (or data object for backward compatibility)
    final metrics = obj['metrics'] as Map<String, dynamic>? ?? obj['data'] as Map<String, dynamic>? ?? {};
    
    // Parse simple values
    if (metrics['steps'] is Map) {
      healthDay.steps = ((metrics['steps'] as Map)['value'] as num?)?.toInt() ?? 0;
    } else {
      healthDay.steps = (metrics['steps'] as num?)?.toInt() ?? 0;
    }
    
    if (metrics['active_energy'] is Map) {
      healthDay.activeKcal = ((metrics['active_energy'] as Map)['value'] as num?)?.toDouble() ?? 0.0;
    } else {
      healthDay.activeKcal = (metrics['active_energy'] as num?)?.toDouble() ?? 
                             (metrics['active_energy_kcal'] as num?)?.toDouble() ?? 0.0;
    }
    
    if (metrics['resting_energy'] is Map) {
      healthDay.basalKcal = ((metrics['resting_energy'] as Map)['value'] as num?)?.toDouble() ?? 0.0;
    } else {
      healthDay.basalKcal = (metrics['resting_energy'] as num?)?.toDouble() ?? 
                            (metrics['basal_energy_kcal'] as num?)?.toDouble() ?? 0.0;
    }
    
    if (metrics['exercise_minutes'] is Map) {
      healthDay.exerciseMin = ((metrics['exercise_minutes'] as Map)['value'] as num?)?.toInt() ?? 0;
    } else {
      healthDay.exerciseMin = (metrics['exercise_minutes'] as num?)?.toInt() ?? 
                              (metrics['exercise_min'] as num?)?.toInt() ?? 0;
    }
    
    healthDay.sleepMin = (metrics['sleep_total_minutes'] as num?)?.toInt() ?? 
                         (metrics['sleep_min'] as num?)?.toInt() ?? 0;
    
    if (metrics['resting_hr'] is Map) {
      healthDay.restingHr = ((metrics['resting_hr'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.restingHr = (metrics['resting_hr'] as num?)?.toDouble();
    }
    
    if (metrics['hrv_sdnn'] is Map) {
      healthDay.hrvSdnn = ((metrics['hrv_sdnn'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.hrvSdnn = (metrics['hrv_sdnn'] as num?)?.toDouble();
    }
    
    if (metrics['avg_hr'] is Map) {
      healthDay.avgHr = ((metrics['avg_hr'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.avgHr = (metrics['avg_hr'] as num?)?.toDouble();
    }
    
    if (metrics['weight'] is Map) {
      healthDay.weightKg = ((metrics['weight'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.weightKg = (metrics['weight'] as num?)?.toDouble() ?? 
                           (metrics['weight_kg'] as num?)?.toDouble();
    }
    
    if (metrics['cardio_recovery_1min'] is Map) {
      healthDay.cardioRecovery1Min = ((metrics['cardio_recovery_1min'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.cardioRecovery1Min = (metrics['cardio_recovery_1min'] as num?)?.toDouble();
    }
    
    if (metrics['vo2_max'] is Map) {
      healthDay.vo2Max = ((metrics['vo2_max'] as Map)['value'] as num?)?.toDouble();
    } else {
      healthDay.vo2Max = (metrics['vo2_max'] as num?)?.toDouble();
    }
    
    if (metrics['distance_walk_run'] is Map) {
      healthDay.distanceM = ((metrics['distance_walk_run'] as Map)['value'] as num?)?.toDouble() ?? 0.0;
    } else {
      healthDay.distanceM = (metrics['distance_walk_run'] as num?)?.toDouble() ?? 
                            (metrics['distance_m'] as num?)?.toDouble() ?? 0.0;
    }
    
    // Parse workouts if present
    final workouts = metrics['workouts'] as List<dynamic>?;
    if (workouts != null) {
      healthDay.workouts.addAll(workouts.cast<Map<String, dynamic>>());
    }
    
    return healthDay;
  }

  /// Get recent weight values for trend analysis
  Future<List<double>> _getRecentWeights(DateTime referenceDate, int daysBack) async {
    final weights = <double>[];
    try {
      for (int i = 1; i <= daysBack; i++) {
        final date = referenceDate.subtract(Duration(days: i));
        final dayKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final healthDay = await _getHealthDayFromFiles(dayKey);
        if (healthDay?.weightKg != null) {
          weights.add(healthDay!.weightKg!);
        }
      }
    } catch (e) {
      // If error occurs, return what we have
    }
    return weights;
  }
}


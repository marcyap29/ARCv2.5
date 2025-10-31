import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import 'package:my_app/prism/models/health_daily.dart';
import 'package:my_app/prism/models/health_summary.dart';
import 'package:my_app/mcp/mcp_fs.dart';

class HealthService {
  static const MethodChannel _channel = MethodChannel('epi.healthkit/bridge');
  final Health _health = Health();

  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.RESTING_HEART_RATE,
    ];
    final permissions = List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
    return await _health.requestAuthorization(types, permissions: permissions);
  }

  Future<Map<String, dynamic>> readToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    final hr = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startTime: start,
      endTime: now,
    );
    final latestHR = hr.isEmpty ? null : hr.last.value;
    return { 'steps': steps, 'latest_heart_rate': latestHR };
  }

  Future<void> openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
  }

  Future<bool> hasPermissions() async {
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.RESTING_HEART_RATE,
    ];
    final permissions = List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
    final has = await _health.hasPermissions(types, permissions: permissions);
    return has ?? false;
  }

  Future<HealthSummary?> fetchDailySummary({required DateTime day, required bool canShowInChat, required bool canShowValues}) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WEIGHT,
      HealthDataType.WORKOUT,
    ];
    // Debug: Log the health data fetch attempt
    debugPrint('🔍 HealthIngest Debug - Fetching health data from HealthKit');
    debugPrint('🔍 HealthIngest Debug - Date range: ${start.toString()} to ${end.toString()}');
    debugPrint('🔍 HealthIngest Debug - Types requested: ${types.map((t) => t.name).join(', ')}');

    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: end,
    );

    // Debug: Log the HealthKit response
    debugPrint('🔍 HealthIngest Debug - HealthKit returned ${points.length} data points');
    if (points.isEmpty) {
      debugPrint('❌ HealthIngest Debug - HealthKit returned ZERO data points!');
      debugPrint('❌ Possible causes:');
      debugPrint('❌ 1. Running on iOS Simulator (HealthKit unavailable)');
      debugPrint('❌ 2. No health data exists in Apple Health for this date range');
      debugPrint('❌ 3. Permissions not actually granted for these data types');
      debugPrint('❌ 4. Health app needs to be opened first to populate data');
    } else {
      debugPrint('✅ HealthIngest Debug - Processing ${points.length} health data points');
      final typesCounts = <String, int>{};
      for (final p in points) {
        typesCounts[p.type.name] = (typesCounts[p.type.name] ?? 0) + 1;
      }
      typesCounts.forEach((type, count) {
        debugPrint('✅ HealthIngest Debug - $type: $count points');
      });
    }
    int steps = 0;
    int exerciseMin = 0;
    double? activeKcal;
    double? basalKcal;
    double? restingHr;
    double? hrvRmssd; // not available; we keep null when only SDNN is present
    double? weightKg;
    int sleepMin = 0;
    final workouts = <Map<String, dynamic>>[];

    for (final p in points) {
      switch (p.type) {
        case HealthDataType.STEPS:
          steps += (p.value as num).toInt();
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeKcal = ((activeKcal ?? 0) + (p.value as num).toDouble());
          break;
        case HealthDataType.BASAL_ENERGY_BURNED:
          basalKcal = ((basalKcal ?? 0) + (p.value as num).toDouble());
          break;
        case HealthDataType.EXERCISE_TIME:
          exerciseMin += ((p.value as num).toDouble() / 60.0).round();
          break;
        case HealthDataType.RESTING_HEART_RATE:
          restingHr = (p.value as num).toDouble();
          break;
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          // Keep RMSSD null; SDNN available but not requested for RMSSD metric
          break;
        case HealthDataType.SLEEP_ASLEEP:
          sleepMin += p.dateTo.difference(p.dateFrom).inMinutes;
          break;
        case HealthDataType.WEIGHT:
          weightKg = (p.value as num).toDouble();
          break;
        case HealthDataType.WORKOUT:
          workouts.add(HealthIngest._encodeWorkout(p));
          break;
        default:
          break;
      }
    }

    final metrics = HealthMetrics(
      sleep: SleepMetrics(totalMinutes: sleepMin, asleepMinutes: sleepMin),
      restingHrBpm: restingHr,
      hrvRmssdMs: hrvRmssd,
      steps: steps,
      exerciseMinutes: exerciseMin,
      activeEnergyKcal: activeKcal,
      restingEnergyKcal: basalKcal,
      weightKg: weightKg,
      workouts: workouts,
    );

    final features = HealthFeatures(flags: []);
    final visibility = HealthVisibility(
      canShowInChat: canShowInChat,
      canShowValuesInChat: canShowValues,
    );

    final source = Platform.isIOS ? "apple_healthkit" : (Platform.isAndroid ? "android_health_connect" : "unknown");
    return HealthSummary(
      startIso: start.toUtc(),
      endIso: end.toUtc(),
      metrics: metrics,
      features: features,
      visibility: visibility,
      source: source,
    );
  }
}



extension _Iso on DateTime {
  String get dayKey => '${year.toString().padLeft(4,'0')}-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
}

class HealthIngest {
  final Health _health;
  HealthIngest(this._health);

  Future<List<Map<String, dynamic>>> importDays({
    required int daysBack, // 30, 60, 90
    required String uid,
    String tz = 'UTC',
  }) async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day).subtract(Duration(days: daysBack - 1));
    final end = now;

    // Request only types available on iOS/Apple Health
    // DISTANCE_DELTA is not available on iOS, distance will be 0 if not captured from workouts
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.WEIGHT,
      HealthDataType.WORKOUT,
    ];

    // Get health data, catching errors for unavailable types
    List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: start,
        endTime: end,
      );
    } catch (e) {
      // If some types fail, try with a minimal set
      print('⚠️ Health import: Some types failed, trying minimal set: $e');
      final minimalTypes = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
      ];
      points = await _health.getHealthDataFromTypes(
        types: minimalTypes,
        startTime: start,
        endTime: end,
      );
    }

    final byDay = <String, HealthDaily>{};
    HealthDaily bucketFor(DateTime d) => byDay.putIfAbsent(
      d.toUtc().dayKey, () => HealthDaily(d.toUtc().dayKey));

    for (final p in points) {
      final b = bucketFor(p.dateFrom);
      final val = _getNumericValue(p);
      if (val == null) continue;
      
      switch (p.type) {
        case HealthDataType.STEPS:
          b.steps += val.toInt();
          break;
        // DISTANCE_DELTA not available on iOS; distance captured from workouts instead
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          b.activeKcal += val.toDouble();
          break;
        case HealthDataType.BASAL_ENERGY_BURNED:
          b.basalKcal += val.toDouble();
          break;
        case HealthDataType.EXERCISE_TIME:
          b.exerciseMin += (val.toDouble() / 60.0).round();
          break;
        case HealthDataType.RESTING_HEART_RATE:
          b.restingHr = val.toDouble();
          break;
        case HealthDataType.HEART_RATE:
          final hr = val.toDouble();
          b.avgHr = _avg(hr, b.avgHr);
          break;
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          b.hrvSdnn = val.toDouble();
          break;
        case HealthDataType.SLEEP_ASLEEP:
          b.sleepMin += p.dateTo.difference(p.dateFrom).inMinutes;
          break;
        case HealthDataType.SLEEP_AWAKE:
        case HealthDataType.SLEEP_IN_BED:
          break;
        case HealthDataType.WEIGHT:
          b.weightKg = val.toDouble();
          break;
        case HealthDataType.WORKOUT:
          final workout = _encodeWorkout(p);
          b.workouts.add(workout);
          // Extract distance from workout if available
          final workoutDistance = (workout['distance_m'] as num?);
          if (workoutDistance != null && workoutDistance > 0) {
            b.distanceM += workoutDistance.toDouble();
          }
          break;
        default:
          break;
      }
    }

    final lines = byDay.values.sortedBy((b) => b.dayKey).map((b) => _toMcp(uid, tz, b)).toList();
    return lines;
  }

  static double? _avg(double x, double? accum) {
    if (accum == null) return x;
    return (accum + x) / 2.0;
  }

  /// Safely extract numeric value from HealthDataPoint
  /// Handles both num and NumericHealthValue types
  static num? _getNumericValue(HealthDataPoint p) {
    final value = p.value;

    // Debug: Log what we're trying to extract
    debugPrint('🔍 _getNumericValue Debug - Type: ${p.type}, Value: $value (${value.runtimeType})');

    if (value == null) {
      debugPrint('❌ _getNumericValue Debug - Value is null');
      return null;
    }

    // Try direct num cast first
    try {
      if (value is int || value is double) {
        debugPrint('✅ _getNumericValue Debug - Direct cast successful: $value');
        return value as num;
      }
    } catch (e) {
      debugPrint('❌ _getNumericValue Debug - Direct cast failed: $e');
    }

    // Handle NumericHealthValue wrapper - parse from toString() format
    // Format: "NumericHealthValue - numericValue: 877.0"
    try {
      final str = value.toString().trim();
      debugPrint('🔍 _getNumericValue Debug - toString(): "$str"');
      if (str.isEmpty) {
        debugPrint('❌ _getNumericValue Debug - Empty string after toString()');
        return null;
      }

      // Try direct parse first (for backward compatibility)
      final directParsed = double.tryParse(str);
      if (directParsed != null) {
        debugPrint('✅ _getNumericValue Debug - Direct parsed: $directParsed');
        return directParsed;
      }

      // Parse NumericHealthValue format: "NumericHealthValue - numericValue: 877.0"
      final numericValueMatch = RegExp(r'numericValue:\s*([\d.-]+)').firstMatch(str);
      if (numericValueMatch != null) {
        final numericStr = numericValueMatch.group(1);
        if (numericStr != null) {
          final parsed = double.tryParse(numericStr);
          if (parsed != null) {
            debugPrint('✅ _getNumericValue Debug - Extracted from NumericHealthValue: $parsed');
            return parsed;
          }
        }
      }

      debugPrint('❌ _getNumericValue Debug - Failed to parse: "$str"');
    } catch (e) {
      debugPrint('❌ _getNumericValue Debug - toString() parsing failed: $e');
    }

    // Try dynamic access to numericValue property
    try {
      final dynamicValue = value as dynamic;
      if (_hasProperty(dynamicValue, 'numericValue')) {
        final numericVal = dynamicValue.numericValue;
        debugPrint('🔍 _getNumericValue Debug - Found numericValue property: $numericVal');
        if (numericVal != null) {
          if (numericVal is num) {
            debugPrint('✅ _getNumericValue Debug - numericValue is num: $numericVal');
            return numericVal;
          }
          final str = numericVal.toString();
          final result = double.tryParse(str);
          debugPrint('🔍 _getNumericValue Debug - Parsed numericValue toString: $result');
          return result;
        }
      } else {
        debugPrint('❌ _getNumericValue Debug - No numericValue property found');
      }
    } catch (e) {
      debugPrint('❌ _getNumericValue Debug - Dynamic access failed: $e');
    }

    debugPrint('❌ _getNumericValue Debug - ALL EXTRACTION METHODS FAILED for ${p.type}');
    return null;
  }
  
  // Helper to check if dynamic object has a property
  static bool _hasProperty(dynamic obj, String prop) {
    try {
      final _ = (obj as dynamic)[prop];
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _encodeWorkout(HealthDataPoint p) {
    return {
      "start": p.dateFrom.toUtc().toIso8601String(),
      "end": p.dateTo.toUtc().toIso8601String(),
      "type": p.value.toString(),
      "duration_min": p.dateTo.difference(p.dateFrom).inMinutes,
      "energy_kcal": null,
      "distance_m": null,
      "avg_hr": null,
    };
  }

  static Map<String, dynamic> _toMcp(String uid, String tz, HealthDaily d) {
    final startIso = '${d.dayKey}T00:00:00Z';
    final endIso   = '${d.dayKey}T23:59:59Z';

    return {
      "mcp_version": "1.0",
      "type": "health.timeslice.daily",
      "source": {"system":"healthkit","platform":"ios","collected_at": DateTime.now().toUtc().toIso8601String()},
      "subject": {"user_id": uid},
      "timeslice": {"start": startIso, "end": endIso, "timezone_of_record": tz},
      "metrics": {
        "steps": {"value": d.steps, "unit": "count"},
        "distance_walk_run": {"value": d.distanceM, "unit": "m"},
        "active_energy": {"value": d.activeKcal, "unit": "kcal"},
        "resting_energy": {"value": d.basalKcal, "unit": "kcal"},
        "exercise_minutes": {"value": d.exerciseMin, "unit": "min"},
        "resting_hr": {"value": d.restingHr, "unit": "bpm"},
        "avg_hr": {"value": d.avgHr, "unit": "bpm"},
        "hrv_sdnn": {"value": d.hrvSdnn, "unit": "ms"},
        "cardio_recovery_1min": {"value": d.cardioRecovery1Min, "unit": "bpm"},
        "sleep_total_minutes": d.sleepMin,
        "weight": {"value": d.weightKg, "unit": "kg"},
        "workouts": d.workouts
      },
      "fusion_keys": {"day_key": d.dayKey, "tags":["health","daily"]},
      "provenance": {"granularity":"daily","aggregation":"sum/avg","confidence":0.97}
    };
  }
}

Future<void> writeHealthStream({
  required List<Map<String, dynamic>> lines
}) async {
  if (lines.isEmpty) return;
  final first = (lines.first['timeslice'] as Map)['start'] as String;
  final monthKey = first.substring(0,7);
  final file = await McpFs.healthMonth(monthKey);
  final sink = file.openWrite(mode: FileMode.append);
  for (final m in lines) { sink.writeln(jsonEncode(m)); }
  await sink.close();
}


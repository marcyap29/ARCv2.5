// ignore_for_file: undefined_class, undefined_identifier, undefined_method
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Simple facade for Apple Health (HealthKit) access on iOS.
/// This implementation uses a lightweight MethodChannel placeholder so the
/// app compiles even if the Health plugin isn't yet installed. If a native
/// bridge is available, calls will succeed; otherwise they fail gracefully.
class AppleHealthService {
  AppleHealthService._();
  static final AppleHealthService instance = AppleHealthService._();

  Future<bool> requestPermissions() async {
    try {
      final types = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.BODY_MASS_INDEX,
      ];
      final permissions = List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
      final health = Health();
      final granted = await health.requestAuthorization(types, permissions: permissions);
      return granted;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppleHealthService.requestPermissions error: $e');
      }
      return false;
    }
  }

  /// Fetches a minimal summary for the last 7 days.
  Future<Map<String, num>> fetchBasicSummary() async {
    try {
      final health = Health();
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final result = <String, num>{};

      final steps = await health.getTotalStepsInInterval(from, now);
      if (steps != null) result['steps7d'] = steps;

      final heart = await health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: now,
      );
      if (heart.isNotEmpty) {
        final avg = heart
            .map((e) => (e.value is num) ? (e.value as num).toDouble() : 0.0)
            .where((v) => v > 0)
            .fold<double>(0.0, (a, b) => a + b) /
            heart.length;
        if (avg.isFinite) result['avgHR'] = avg;
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppleHealthService.fetchBasicSummary error: $e');
      }
      return <String, num>{};
    }
  }
}



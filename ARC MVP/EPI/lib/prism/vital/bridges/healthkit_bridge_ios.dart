import 'dart:async';
import 'package:flutter/services.dart';
import '../models/vital_metrics.dart';

class HealthKitBridgeIOS {
  static const MethodChannel _channel = MethodChannel('prism_vital/healthkit');

  Future<bool> requestPermissions({
    bool heartRate = true,
    bool hrv = true,
    bool steps = true,
    bool sleep = true,
  }) async {
    final result = await _channel.invokeMethod<bool>('requestPermissions', {
      'heartRate': heartRate,
      'hrv': hrv,
      'steps': steps,
      'sleep': sleep,
    });
    return result ?? false;
  }

  Future<void> enableBackgroundDelivery() async {
    await _channel.invokeMethod('enableBackgroundDelivery');
  }

  Future<List<VitalSample>> fetchSamples({
    required DateTime from,
    required DateTime to,
    required List<String> metrics,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('fetchSamples', {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'metrics': metrics,
    });
    final list = raw ?? const [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return VitalSample(
        metric: m['metric'] as String,
        start: DateTime.parse(m['start'] as String).toUtc(),
        end: DateTime.parse(m['end'] as String).toUtc(),
        value: (m['value'] as num).toDouble(),
      );
    }).toList();
  }
}



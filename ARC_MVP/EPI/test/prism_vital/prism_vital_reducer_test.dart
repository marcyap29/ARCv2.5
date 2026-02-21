import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/prism/vital/reducers/health_window_aggregator.dart';
import 'package:my_app/prism/vital/models/vital_metrics.dart';

void main() {
  test('aggregates samples into hourly windows', () async {
    final agg = HealthWindowAggregator();
    final from = DateTime.utc(2025, 1, 1, 0, 0, 0);
    final to = DateTime.utc(2025, 1, 1, 3, 0, 0);
    final samples = <VitalSample>[
      VitalSample(metric: 'heart_rate', start: from, end: from, value: 60),
      VitalSample(metric: 'heart_rate', start: from.add(const Duration(minutes: 30)), end: from.add(const Duration(minutes: 30)), value: 70),
      VitalSample(metric: 'steps', start: from, end: from, value: 100),
    ];
    final windows = agg.aggregate(samples: samples, windowSize: const Duration(hours: 1), from: from, to: to);
    expect(windows.length, 3);
  });
}



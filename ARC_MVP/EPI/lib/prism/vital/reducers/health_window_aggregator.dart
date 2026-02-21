import '../models/vital_metrics.dart';
import '../models/vital_window.dart';

class HealthWindowAggregator {
  List<ReducedWindow> aggregate({
    required List<VitalSample> samples,
    required Duration windowSize,
    required DateTime from,
    required DateTime to,
  }) {
    final windows = <ReducedWindow>[];
    DateTime cursor = DateTime.utc(from.year, from.month, from.day, from.hour, from.minute, from.second);
    while (cursor.isBefore(to)) {
      final end = cursor.add(windowSize);
      final bucket = samples.where((s) => !(s.end.isBefore(cursor) || s.start.isAfter(end))).toList();
      windows.add(_reduce(cursor, end, bucket));
      cursor = end;
    }
    return windows;
  }

  ReducedWindow _reduce(DateTime start, DateTime end, List<VitalSample> bucket) {
    final hr = bucket.where((s) => s.metric == 'heart_rate').map((s) => s.value).toList();
    hr.sort();
    final hrv = bucket.where((s) => s.metric == 'hrv').map((s) => s.value).toList();
    hrv.sort();
    final steps = bucket.where((s) => s.metric == 'steps').map((s) => s.value.toInt()).toList();
    final sleepEff = bucket.where((s) => s.metric == 'sleep_efficiency').map((s) => s.value).toList();
    final deepRatio = bucket.where((s) => s.metric == 'sleep_deep_ratio').map((s) => s.value).toList();

    double? avg(List<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    double? median(List<double> xs) {
      if (xs.isEmpty) return null;
      final mid = xs.length ~/ 2;
      return xs.length.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2.0;
    }

    final reduced = ReducedVitals(
      avgHr: avg(hr),
      minHr: hr.isEmpty ? null : hr.first,
      maxHr: hr.isEmpty ? null : hr.last,
      hrvMedian: median(hrv),
      stepsSum: steps.isEmpty ? null : steps.reduce((a, b) => a + b),
      sleepEfficiency: avg(sleepEff),
      deepSleepRatio: avg(deepRatio),
    );

    return ReducedWindow(start: start.toUtc(), end: end.toUtc(), reduced: reduced);
  }
}

class ReducedWindow {
  final DateTime start;
  final DateTime end;
  final ReducedVitals reduced;
  const ReducedWindow({required this.start, required this.end, required this.reduced});
}



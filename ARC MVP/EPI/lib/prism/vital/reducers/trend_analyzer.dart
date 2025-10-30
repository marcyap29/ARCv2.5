import 'health_window_aggregator.dart';

class TrendAnalyzer {
  List<String> analyze(List<ReducedWindow> windows) {
    if (windows.length < 3) return const [];
    final tags = <String>[];

    double? _seriesAvg(List<double?> xs) {
      final vs = xs.whereType<double>().toList();
      if (vs.isEmpty) return null;
      return vs.reduce((a, b) => a + b) / vs.length;
    }

    final last3 = windows.sublist(windows.length - 3);
    final hrAvg = _seriesAvg(last3.map((w) => w.reduced.avgHr).toList());
    final hrvAvg = _seriesAvg(last3.map((w) => w.reduced.hrvMedian).toList());
    final sleepEffAvg = _seriesAvg(last3.map((w) => w.reduced.sleepEfficiency).toList());

    if (sleepEffAvg != null) {
      if (sleepEffAvg >= 0.9) tags.add('sleep_high_efficiency');
      if (sleepEffAvg < 0.75) tags.add('sleep_low_efficiency');
    }
    if (hrvAvg != null) {
      if (hrvAvg >= 60) tags.add('recovery_strong');
      if (hrvAvg < 30) tags.add('recovery_low');
    }
    if (hrAvg != null) {
      if (hrAvg < 55) tags.add('resting_hr_low');
      if (hrAvg > 80) tags.add('resting_hr_elevated');
    }
    return tags;
  }
}



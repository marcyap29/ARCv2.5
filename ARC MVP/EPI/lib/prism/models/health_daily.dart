import 'package:my_app/prism/models/health_summary.dart';

class HealthDaily {
  final String dayKey; // YYYY-MM-DD (UTC)
  int steps = 0;
  double distanceM = 0;
  double activeKcal = 0;
  double basalKcal = 0;
  int exerciseMin = 0;
  double? restingHr;
  double? hrvSdnn;
  double? cardioRecovery1Min; // bpm drop after 1 min
  int sleepMin = 0;
  double? weightKg;
  double? avgHr; // average HR during the day (from samples)

  final List<Map<String, dynamic>> workouts = []; // 11e encoder
  final List<Medication> medications = []; // medications taken on this day

  HealthDaily(this.dayKey);
}



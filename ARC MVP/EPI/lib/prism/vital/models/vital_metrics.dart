class VitalSample {
  final String metric; // "heart_rate", "hrv", "steps", "sleep_stage"
  final DateTime start;
  final DateTime end;
  final double value;
  const VitalSample({
    required this.metric,
    required this.start,
    required this.end,
    required this.value,
  });
}



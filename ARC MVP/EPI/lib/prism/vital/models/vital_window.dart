class ReducedVitals {
  final double? avgHr;
  final double? minHr;
  final double? maxHr;
  final double? hrvMedian;
  final int? stepsSum;
  final double? sleepEfficiency;
  final double? deepSleepRatio;
  const ReducedVitals({
    this.avgHr,
    this.minHr,
    this.maxHr,
    this.hrvMedian,
    this.stepsSum,
    this.sleepEfficiency,
    this.deepSleepRatio,
  });

  Map<String, dynamic> toJson() => {
        if (avgHr != null) 'avg_hr': avgHr,
        if (minHr != null) 'min_hr': minHr,
        if (maxHr != null) 'max_hr': maxHr,
        if (hrvMedian != null) 'hrv_median': hrvMedian,
        if (stepsSum != null) 'steps_sum': stepsSum,
        if (sleepEfficiency != null) 'sleep_efficiency': sleepEfficiency,
        if (deepSleepRatio != null) 'deep_sleep_ratio': deepSleepRatio,
      };
}



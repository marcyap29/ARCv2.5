/// Tunable Sentinel configuration
class SentinelConfig {
  // Temporal windows (days)
  static const WINDOW_1_DAY = 1;
  static const WINDOW_3_DAY = 3;
  static const WINDOW_7_DAY = 7;
  static const WINDOW_30_DAY = 30;
  
  // Frequency thresholds (entries per window for max score)
  static const FREQ_THRESHOLD_1DAY = 3.0;
  static const FREQ_THRESHOLD_3DAY = 5.0;
  static const FREQ_THRESHOLD_7DAY = 8.0;
  static const FREQ_THRESHOLD_30DAY = 15.0;
  
  // Temporal weighting
  static const WEIGHT_1DAY = 1.0;   // 100%
  static const WEIGHT_3DAY = 0.7;   // 70%
  static const WEIGHT_7DAY = 0.4;   // 40%
  static const WEIGHT_30DAY = 0.1;  // 10%
  
  // Alert threshold
  static const ALERT_THRESHOLD = 0.7;
  
  // Minimum intensity to count as crisis-related
  static const MIN_CRISIS_INTENSITY = 0.3;
  
  // Crisis mode cooldown (hours)
  static const CRISIS_COOLDOWN_HOURS = 48;
}


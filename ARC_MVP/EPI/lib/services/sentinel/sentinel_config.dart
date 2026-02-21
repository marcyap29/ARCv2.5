/// Word count normalization methods
enum WordCountNormalization {
  linear,    // divide by word_count
  sqrt,      // divide by sqrt(word_count)
  log,       // divide by log(word_count)
}

/// Tunable Sentinel configuration
class SentinelConfig {
  // Temporal windows (days) - static constants for backward compatibility
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

  // Adaptive configuration parameters
  final double emotionalIntensityWeight;
  final double emotionalDiversityWeight;
  final double thematicCoherenceWeight;
  final double temporalDynamicsWeight;
  final double emotionalConcentrationWeight;
  
  final double explicitEmotionMultiplierMin;
  final double explicitEmotionMultiplierMax;
  
  final WordCountNormalization normalizationMethod;
  final int normalizationFloor;
  
  final double temporalDecayFactor;
  
  final double highIntensityThreshold;
  final int minWordsForFullScore;

  SentinelConfig({
    this.emotionalIntensityWeight = 0.25,
    this.emotionalDiversityWeight = 0.25,
    this.thematicCoherenceWeight = 0.25,
    this.temporalDynamicsWeight = 0.25,
    this.emotionalConcentrationWeight = 0.0,
    this.explicitEmotionMultiplierMin = 1.0,
    this.explicitEmotionMultiplierMax = 1.0,
    this.normalizationMethod = WordCountNormalization.linear,
    this.normalizationFloor = 50,
    this.temporalDecayFactor = 0.95,
    this.highIntensityThreshold = 0.7,
    this.minWordsForFullScore = 100,
  });

  /// Power user configuration (current baseline)
  factory SentinelConfig.powerUser() {
    return SentinelConfig(
      emotionalIntensityWeight: 0.25,
      emotionalDiversityWeight: 0.25,
      thematicCoherenceWeight: 0.25,
      temporalDynamicsWeight: 0.25,
      emotionalConcentrationWeight: 0.0,
      explicitEmotionMultiplierMin: 1.0,
      explicitEmotionMultiplierMax: 1.0,
      normalizationMethod: WordCountNormalization.linear,
      normalizationFloor: 50,
      temporalDecayFactor: 0.95,
      highIntensityThreshold: 0.7,
      minWordsForFullScore: 100,
    );
  }

  /// Frequent user configuration
  factory SentinelConfig.frequent() {
    return SentinelConfig(
      emotionalIntensityWeight: 0.30,
      emotionalDiversityWeight: 0.20,
      thematicCoherenceWeight: 0.20,
      temporalDynamicsWeight: 0.20,
      emotionalConcentrationWeight: 0.10,
      explicitEmotionMultiplierMin: 1.0,
      explicitEmotionMultiplierMax: 1.3,
      normalizationMethod: WordCountNormalization.sqrt,
      normalizationFloor: 50,
      temporalDecayFactor: 0.97,
      highIntensityThreshold: 0.7,
      minWordsForFullScore: 100,
    );
  }

  /// Weekly user configuration
  factory SentinelConfig.weekly() {
    return SentinelConfig(
      emotionalIntensityWeight: 0.35,
      emotionalDiversityWeight: 0.15,
      thematicCoherenceWeight: 0.15,
      temporalDynamicsWeight: 0.15,
      emotionalConcentrationWeight: 0.20,
      explicitEmotionMultiplierMin: 1.0,
      explicitEmotionMultiplierMax: 1.5,
      normalizationMethod: WordCountNormalization.sqrt,
      normalizationFloor: 50,
      temporalDecayFactor: 0.98,
      highIntensityThreshold: 0.65,
      minWordsForFullScore: 75,
    );
  }

  /// Sporadic user configuration
  factory SentinelConfig.sporadic() {
    return SentinelConfig(
      emotionalIntensityWeight: 0.40,
      emotionalDiversityWeight: 0.10,
      thematicCoherenceWeight: 0.10,
      temporalDynamicsWeight: 0.15,
      emotionalConcentrationWeight: 0.25,
      explicitEmotionMultiplierMin: 1.0,
      explicitEmotionMultiplierMax: 1.5,
      normalizationMethod: WordCountNormalization.sqrt,
      normalizationFloor: 40,
      temporalDecayFactor: 0.99,
      highIntensityThreshold: 0.6,
      minWordsForFullScore: 50,
    );
  }
}


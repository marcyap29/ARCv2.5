/// Adaptive RIVET configuration
class RivetConfig {
  // Stability windows (in days)
  final int minStabilityDays;
  final int maxStabilityDays;

  // Entry requirements
  final int minEntriesForDetection;
  final int minEntriesInWindow;

  // Confidence thresholds
  final double phaseConfidenceThreshold;
  final double transitionConfidenceThreshold;

  // Temporal decay
  final double temporalDecayFactor;

  // Phase intensity thresholds
  final double minIntensityForEmerging;
  final double minIntensityForEstablished;

  // Transition velocity
  final double minTransitionVelocity;
  final double maxTransitionVelocity;

  RivetConfig({
    required this.minStabilityDays,
    required this.maxStabilityDays,
    required this.minEntriesForDetection,
    required this.minEntriesInWindow,
    required this.phaseConfidenceThreshold,
    required this.transitionConfidenceThreshold,
    required this.temporalDecayFactor,
    required this.minIntensityForEmerging,
    required this.minIntensityForEstablished,
    required this.minTransitionVelocity,
    required this.maxTransitionVelocity,
  });

  /// Power user configuration (current baseline)
  factory RivetConfig.powerUser() {
    return RivetConfig(
      minStabilityDays: 7,
      maxStabilityDays: 14,
      minEntriesForDetection: 7,
      minEntriesInWindow: 5,
      phaseConfidenceThreshold: 0.65,
      transitionConfidenceThreshold: 0.60,
      temporalDecayFactor: 0.95,
      minIntensityForEmerging: 0.70,
      minIntensityForEstablished: 0.80,
      minTransitionVelocity: 0.15,
      maxTransitionVelocity: 0.40,
    );
  }

  /// Frequent user configuration
  factory RivetConfig.frequent() {
    return RivetConfig(
      minStabilityDays: 14,
      maxStabilityDays: 28,
      minEntriesForDetection: 7,
      minEntriesInWindow: 5,
      phaseConfidenceThreshold: 0.60,
      transitionConfidenceThreshold: 0.55,
      temporalDecayFactor: 0.97,
      minIntensityForEmerging: 0.65,
      minIntensityForEstablished: 0.75,
      minTransitionVelocity: 0.15,
      maxTransitionVelocity: 0.40,
    );
  }

  /// Weekly user configuration
  factory RivetConfig.weekly() {
    return RivetConfig(
      minStabilityDays: 28,
      maxStabilityDays: 56,
      minEntriesForDetection: 6,
      minEntriesInWindow: 4,
      phaseConfidenceThreshold: 0.55,
      transitionConfidenceThreshold: 0.50,
      temporalDecayFactor: 0.98,
      minIntensityForEmerging: 0.60,
      minIntensityForEstablished: 0.70,
      minTransitionVelocity: 0.12,
      maxTransitionVelocity: 0.35,
    );
  }

  /// Sporadic user configuration
  factory RivetConfig.sporadic() {
    return RivetConfig(
      minStabilityDays: 42,
      maxStabilityDays: 84,
      minEntriesForDetection: 5,
      minEntriesInWindow: 4,
      phaseConfidenceThreshold: 0.50,
      transitionConfidenceThreshold: 0.45,
      temporalDecayFactor: 0.99,
      minIntensityForEmerging: 0.55,
      minIntensityForEstablished: 0.65,
      minTransitionVelocity: 0.10,
      maxTransitionVelocity: 0.30,
    );
  }
}


/// Phase rating ranges for military operational readiness (10-100 scale)
/// Lower scores indicate need for rest/recovery; higher scores indicate readiness for duty
class PhaseRatingRanges {
  // Rating ranges for each phase
  static const Map<String, Range> _ranges = {
    'recovery': Range(10, 25),
    'transition': Range(35, 50),
    'discovery': Range(50, 65),
    'reflection': Range(55, 70),
    'consolidation': Range(70, 85),
    'breakthrough': Range(85, 100),
  };

  /// Get the rating range for a phase
  static Range getRange(String phaseName) {
    return _ranges[phaseName.toLowerCase()] ?? const Range(55, 70); // Default to reflection range
  }

  /// Get minimum rating for a phase
  static int getMin(String phaseName) {
    return getRange(phaseName).min;
  }

  /// Get maximum rating for a phase
  static int getMax(String phaseName) {
    return getRange(phaseName).max;
  }

  /// Calculate base rating within phase range based on confidence (0.0-1.0)
  /// Maps confidence to the phase's range
  static int getRating(String phaseName, double confidence) {
    final range = getRange(phaseName);
    final normalizedConfidence = confidence.clamp(0.0, 1.0);
    final rating = range.min + ((range.max - range.min) * normalizedConfidence);
    return rating.round().clamp(range.min, range.max);
  }

  /// Get all available phases with their ranges
  static Map<String, Range> getAllRanges() {
    return Map.unmodifiable(_ranges);
  }
}

/// Represents a rating range
class Range {
  final int min;
  final int max;

  const Range(this.min, this.max);

  int get width => max - min;
}


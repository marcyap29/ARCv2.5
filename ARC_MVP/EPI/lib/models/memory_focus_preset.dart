/// Memory Focus Preset System
/// 
/// Simplifies memory retrieval settings by providing presets that combine
/// lookback years, similarity threshold, and max matches into intuitive options.

enum MemoryFocusPreset {
  focused,        // 30 days, 0.7 precision, 10 entries - for direct questions
  balanced,       // 90 days, 0.55 precision, 20 entries - default, recommended
  comprehensive,  // 365 days, 0.4 precision, 50 entries - deep analysis
  custom,         // User-defined values
}

extension MemoryFocusPresetExtension on MemoryFocusPreset {
  String get displayName {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 'Focused';
      case MemoryFocusPreset.balanced:
        return 'Balanced';
      case MemoryFocusPreset.comprehensive:
        return 'Comprehensive';
      case MemoryFocusPreset.custom:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 'Concise, on-topic responses. Best for direct questions. (30 days, 10 entries)';
      case MemoryFocusPreset.balanced:
        return 'Good context without overwhelming. Recommended for most users. (90 days, 20 entries)';
      case MemoryFocusPreset.comprehensive:
        return 'Deep historical context. Best for long-term pattern analysis. (365 days, 50 entries)';
      case MemoryFocusPreset.custom:
        return 'Fine-tune memory settings manually.';
    }
  }

  /// Get the time window in days for this preset
  int get timeWindowDays {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 30;
      case MemoryFocusPreset.balanced:
        return 90;
      case MemoryFocusPreset.comprehensive:
        return 365;
      case MemoryFocusPreset.custom:
        return 90; // Default, will be overridden by user settings
    }
  }
  
  /// Get the lookback years for this preset (for backward compatibility)
  @Deprecated('Use timeWindowDays instead')
  int get lookbackYears {
    return (timeWindowDays / 365).round().clamp(1, 10);
  }

  /// Get the similarity threshold for this preset
  double get similarityThreshold {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 0.7; // High precision
      case MemoryFocusPreset.balanced:
        return 0.55; // Medium precision
      case MemoryFocusPreset.comprehensive:
        return 0.4; // Lower precision, more matches
      case MemoryFocusPreset.custom:
        return 0.55; // Default, will be overridden by user settings
    }
  }

  /// Get the max entries for this preset
  int get maxEntries {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 10;
      case MemoryFocusPreset.balanced:
        return 20;
      case MemoryFocusPreset.comprehensive:
        return 50;
      case MemoryFocusPreset.custom:
        return 20; // Default, will be overridden by user settings
    }
  }
  
  /// Get the max matches for this preset (for backward compatibility)
  @Deprecated('Use maxEntries instead')
  int get maxMatches {
    return maxEntries;
  }

  /// Convert to string for JSON serialization
  String toJson() => toString();
}

/// Utility functions for MemoryFocusPreset
class MemoryFocusPresetUtils {
  /// Create from string for JSON deserialization
  static MemoryFocusPreset fromJson(String value) {
    return MemoryFocusPreset.values.firstWhere(
      (preset) => preset.toString() == value,
      orElse: () => MemoryFocusPreset.balanced,
    );
  }

  /// Detect which preset matches given values (for migration)
  static MemoryFocusPreset detectPreset({
    required int lookbackYears,
    required double similarityThreshold,
    required int maxMatches,
  }) {
    // Check if values match a preset exactly
    for (final preset in MemoryFocusPreset.values) {
      if (preset == MemoryFocusPreset.custom) continue;
      
      if (preset.lookbackYears == lookbackYears &&
          preset.similarityThreshold == similarityThreshold &&
          preset.maxMatches == maxMatches) {
        return preset;
      }
    }

    // If no exact match, find closest preset
    // Use balanced as default
    return MemoryFocusPreset.balanced;
  }
}


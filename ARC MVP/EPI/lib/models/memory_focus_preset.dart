/// Memory Focus Preset System
/// 
/// Simplifies memory retrieval settings by providing presets that combine
/// lookback years, similarity threshold, and max matches into intuitive options.

enum MemoryFocusPreset {
  focused,        // 2 years, 0.7 precision, 3 entries - for direct questions
  balanced,       // 5 years, 0.55 precision, 5 entries - default, recommended
  comprehensive,  // 10 years, 0.4 precision, 10 entries - deep analysis
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
        return 'Concise, on-topic responses. Best for direct questions.';
      case MemoryFocusPreset.balanced:
        return 'Good context without overwhelming. Recommended for most users.';
      case MemoryFocusPreset.comprehensive:
        return 'Deep historical context. Best for long-term pattern analysis.';
      case MemoryFocusPreset.custom:
        return 'Fine-tune memory settings manually.';
    }
  }

  /// Get the lookback years for this preset
  int get lookbackYears {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 2;
      case MemoryFocusPreset.balanced:
        return 5;
      case MemoryFocusPreset.comprehensive:
        return 10;
      case MemoryFocusPreset.custom:
        return 5; // Default, will be overridden by user settings
    }
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

  /// Get the max matches for this preset
  int get maxMatches {
    switch (this) {
      case MemoryFocusPreset.focused:
        return 3;
      case MemoryFocusPreset.balanced:
        return 5;
      case MemoryFocusPreset.comprehensive:
        return 10;
      case MemoryFocusPreset.custom:
        return 5; // Default, will be overridden by user settings
    }
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


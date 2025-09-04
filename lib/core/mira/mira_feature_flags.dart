/// Feature flags for MIRA functionality
class MiraFeatureFlags {
  /// Whether MIRA is enabled
  /// Can be controlled by build configuration or runtime settings
  static bool get miraEnabled {
    // For now, always enable MIRA
    // TODO: Implement runtime feature flag system
    return true;
  }

  /// Whether to show debug information in MIRA
  static bool get showDebugInfo {
    return true; // Always show debug info for now
  }

  /// Whether to enable verbose logging
  static bool get verboseLogging {
    return true; // Always enable verbose logging for now
  }

  /// Whether to enable performance monitoring
  static bool get performanceMonitoring {
    return true; // Always enable performance monitoring for now
  }

  /// Whether to enable synthetic data seeding
  static bool get enableSeeding {
    return true; // Always enable seeding for now
  }

  /// Whether to show MIRA statistics in UI
  static bool get showStats {
    return true; // Always show stats for now
  }

  /// Whether to enable MIRA insights cards
  static bool get enableInsightsCards {
    return miraEnabled;
  }

  /// Whether to enable RIVET integration
  static bool get enableRivetIntegration {
    return miraEnabled;
  }

  /// Whether to enable MIRA persistence
  static bool get enablePersistence {
    return miraEnabled;
  }

  /// Whether to enable MIRA background processing
  static bool get enableBackgroundProcessing {
    return miraEnabled;
  }

  /// Get all feature flags as a map
  static Map<String, bool> getAllFlags() {
    return {
      'miraEnabled': miraEnabled,
      'showDebugInfo': showDebugInfo,
      'verboseLogging': verboseLogging,
      'performanceMonitoring': performanceMonitoring,
      'enableSeeding': enableSeeding,
      'showStats': showStats,
      'enableInsightsCards': enableInsightsCards,
      'enableRivetIntegration': enableRivetIntegration,
      'enablePersistence': enablePersistence,
      'enableBackgroundProcessing': enableBackgroundProcessing,
    };
  }

  /// Check if a specific feature is enabled
  static bool isEnabled(String featureName) {
    switch (featureName) {
      case 'miraEnabled':
        return miraEnabled;
      case 'showDebugInfo':
        return showDebugInfo;
      case 'verboseLogging':
        return verboseLogging;
      case 'performanceMonitoring':
        return performanceMonitoring;
      case 'enableSeeding':
        return enableSeeding;
      case 'showStats':
        return showStats;
      case 'enableInsightsCards':
        return enableInsightsCards;
      case 'enableRivetIntegration':
        return enableRivetIntegration;
      case 'enablePersistence':
        return enablePersistence;
      case 'enableBackgroundProcessing':
        return enableBackgroundProcessing;
      default:
        return false;
    }
  }
}

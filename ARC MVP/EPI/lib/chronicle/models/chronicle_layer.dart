/// CHRONICLE Layer Enumeration
/// 
/// Represents the hierarchical temporal layers in the CHRONICLE architecture:
/// - Layer0: Raw journal entries (30-90 day retention)
/// - Monthly: Layer 1 aggregations (monthly summaries)
/// - Yearly: Layer 2 aggregations (yearly summaries)
/// - MultiYear: Layer 3 aggregations (multi-year summaries)

enum ChronicleLayer {
  layer0,    // Raw entries
  monthly,   // Layer 1: Monthly aggregations
  yearly,     // Layer 2: Yearly aggregations
  multiyear, // Layer 3: Multi-year aggregations
}

/// Extension for ChronicleLayer enum
extension ChronicleLayerExtension on ChronicleLayer {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case ChronicleLayer.layer0:
        return 'Raw Entries';
      case ChronicleLayer.monthly:
        return 'Monthly';
      case ChronicleLayer.yearly:
        return 'Yearly';
      case ChronicleLayer.multiyear:
        return 'Multi-Year';
    }
  }

  /// Description for UI
  String get description {
    switch (this) {
      case ChronicleLayer.layer0:
        return 'Raw journal entries with full content and analysis data';
      case ChronicleLayer.monthly:
        return 'Monthly aggregations synthesizing ~28 entries into themes and patterns';
      case ChronicleLayer.yearly:
        return 'Yearly aggregations synthesizing 12 monthly summaries into chapters';
      case ChronicleLayer.multiyear:
        return 'Multi-year aggregations synthesizing life chapters and meta-patterns';
    }
  }

  /// Target compression ratio for this layer
  double get targetCompressionRatio {
    switch (this) {
      case ChronicleLayer.layer0:
        return 1.0; // No compression (raw)
      case ChronicleLayer.monthly:
        return 0.15; // 10-20% of original
      case ChronicleLayer.yearly:
        return 0.075; // 5-10% of yearly total
      case ChronicleLayer.multiyear:
        return 0.015; // 1-2% of multi-year total
    }
  }

  /// Convert to string for JSON serialization
  String toJson() => name;
}

/// Helper functions for ChronicleLayer
extension ChronicleLayerHelpers on ChronicleLayer {
  /// Create from string for JSON deserialization
  static ChronicleLayer fromJson(String value) {
    return ChronicleLayer.values.firstWhere(
      (layer) => layer.name == value,
      orElse: () => ChronicleLayer.layer0,
    );
  }
}

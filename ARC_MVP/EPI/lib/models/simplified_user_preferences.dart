/// Simplified User Preferences for Companion-First LUMARA
///
/// REMOVED FROM USER CONTROL:
/// - Manual persona selection (backend-only now)
/// - Therapeutic depth (auto-detected based on distress)
/// - Response length (smart word limits per entry type)
/// - Complex engagement modes (simplified to backend logic)
///
/// KEPT FOR USER CONTROL:
/// - Memory focus (maps to ContextScope: minimal/moderate/full)
/// - Web access (important privacy setting)
/// - Cross-modal/media analysis (capability toggle)
/// - Lookback years (in advanced settings)
library;

import 'package:hive/hive.dart';

@HiveType(typeId: 10) // Use a new typeId to avoid conflicts
class SimplifiedUserPreferences extends HiveObject {

  /// Memory Focus - Core setting that maps to ContextScope
  /// Controls how much historical context LUMARA uses
  @HiveField(0)
  final String memoryFocus; // 'focused', 'balanced', 'comprehensive'

  /// Web Access - Privacy setting for real-time information
  @HiveField(1)
  final bool webAccessEnabled;

  /// Cross-modal Analysis - Include media in reflections
  @HiveField(2)
  final bool crossModalEnabled;

  /// Memory Lookback - Advanced setting (years to search back)
  @HiveField(3)
  final int lookbackYears; // 1, 2, 5, 10, or 0 for "all"

  /// Debug Mode - Show classification information
  @HiveField(4)
  final bool showDebugInfo;

  SimplifiedUserPreferences({
    this.memoryFocus = 'balanced',
    this.webAccessEnabled = false,
    this.crossModalEnabled = true,
    this.lookbackYears = 2,
    this.showDebugInfo = false,
  });

  /// Create from Firebase/SharedPreferences data
  factory SimplifiedUserPreferences.fromMap(Map<String, dynamic> data) {
    return SimplifiedUserPreferences(
      memoryFocus: data['memoryFocus'] as String? ?? 'balanced',
      webAccessEnabled: data['webAccessEnabled'] as bool? ?? false,
      crossModalEnabled: data['crossModalEnabled'] as bool? ?? true,
      lookbackYears: data['lookbackYears'] as int? ?? 2,
      showDebugInfo: data['showDebugInfo'] as bool? ?? false,
    );
  }

  /// Convert to map for Firebase/SharedPreferences storage
  Map<String, dynamic> toMap() {
    return {
      'memoryFocus': memoryFocus,
      'webAccessEnabled': webAccessEnabled,
      'crossModalEnabled': crossModalEnabled,
      'lookbackYears': lookbackYears,
      'showDebugInfo': showDebugInfo,
    };
  }

  /// Copy with modifications
  SimplifiedUserPreferences copyWith({
    String? memoryFocus,
    bool? webAccessEnabled,
    bool? crossModalEnabled,
    int? lookbackYears,
    bool? showDebugInfo,
  }) {
    return SimplifiedUserPreferences(
      memoryFocus: memoryFocus ?? this.memoryFocus,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
      crossModalEnabled: crossModalEnabled ?? this.crossModalEnabled,
      lookbackYears: lookbackYears ?? this.lookbackYears,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
    );
  }

  /// Get memory focus description for UI
  String get memoryFocusDescription {
    switch (memoryFocus) {
      case 'focused':
        return 'Concise, on-topic responses. Best for direct questions.';
      case 'comprehensive':
        return 'Full context and connections. Best for pattern recognition.';
      case 'balanced':
      default:
        return 'Moderate context. Good for most situations.';
    }
  }

  /// Convert memory focus to ContextScope strategy
  String get contextScopeStrategy {
    switch (memoryFocus) {
      case 'focused':
        return 'minimal';
      case 'comprehensive':
        return 'full';
      case 'balanced':
      default:
        return 'moderate';
    }
  }

  /// Validation
  bool get isValid {
    return ['focused', 'balanced', 'comprehensive'].contains(memoryFocus) &&
           lookbackYears >= 0 &&
           lookbackYears <= 10;
  }

  @override
  String toString() {
    return 'SimplifiedUserPreferences(memoryFocus: $memoryFocus, webAccess: $webAccessEnabled, crossModal: $crossModalEnabled, lookback: $lookbackYears years)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimplifiedUserPreferences &&
           other.memoryFocus == memoryFocus &&
           other.webAccessEnabled == webAccessEnabled &&
           other.crossModalEnabled == crossModalEnabled &&
           other.lookbackYears == lookbackYears &&
           other.showDebugInfo == showDebugInfo;
  }

  @override
  int get hashCode {
    return Object.hash(
      memoryFocus,
      webAccessEnabled,
      crossModalEnabled,
      lookbackYears,
      showDebugInfo,
    );
  }
}

// Hive type adapter for persistence
class SimplifiedUserPreferencesAdapter extends TypeAdapter<SimplifiedUserPreferences> {
  @override
  final int typeId = 10;

  @override
  SimplifiedUserPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SimplifiedUserPreferences(
      memoryFocus: fields[0] as String? ?? 'balanced',
      webAccessEnabled: fields[1] as bool? ?? false,
      crossModalEnabled: fields[2] as bool? ?? true,
      lookbackYears: fields[3] as int? ?? 2,
      showDebugInfo: fields[4] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SimplifiedUserPreferences obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.memoryFocus)
      ..writeByte(1)
      ..write(obj.webAccessEnabled)
      ..writeByte(2)
      ..write(obj.crossModalEnabled)
      ..writeByte(3)
      ..write(obj.lookbackYears)
      ..writeByte(4)
      ..write(obj.showDebugInfo);
  }
}
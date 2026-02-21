// lib/arc/arcform/share/arcform_share_caption_templates.dart
// Caption templates for different share modes

import 'arcform_share_models.dart';

/// Caption templates for Arcform sharing
class ArcformShareCaptionTemplates {
  /// Get caption templates for reflective mode
  static List<String> getReflectiveTemplates(String phaseName) {
    return [
      'Entered $phaseName phase',
      'This is what my last 30 days look like',
      'Current phase: $phaseName',
      'Visualizing my growth journey',
      'Tracking patterns I couldn\'t see day-to-day',
    ];
  }

  /// Get caption templates for signal mode
  static List<String> getSignalTemplates({
    required String phaseName,
    String? previousPhase,
    int? durationDays,
  }) {
    final templates = <String>[];
    
    if (previousPhase != null && durationDays != null) {
      templates.add(
        'Entered $phaseName after $durationDays days in $previousPhase',
      );
    }
    
    templates.addAll([
      'Tracking cognitive states over 90 days revealed patterns I couldn\'t see day-to-day',
      'The value isn\'t in the journal entries - it\'s in seeing the phases between them',
      'Visualizing personal growth patterns instead of summarizing them',
      'Meta-awareness: seeing the structure of my development, not just the content',
    ]);
    
    return templates;
  }

  /// Get default template for a mode and phase
  static String? getDefaultTemplate(
    ArcShareMode mode,
    String phaseName, {
    String? previousPhase,
    int? durationDays,
  }) {
    switch (mode) {
      case ArcShareMode.quiet:
        return null; // No caption for quiet mode
      case ArcShareMode.reflective:
        return getReflectiveTemplates(phaseName).first;
      case ArcShareMode.signal:
        return getSignalTemplates(
          phaseName: phaseName,
          previousPhase: previousPhase,
          durationDays: durationDays,
        ).first;
    }
  }

  /// Format phase name for display
  static String formatPhaseName(String phase) {
    // Capitalize first letter
    if (phase.isEmpty) return phase;
    return phase[0].toUpperCase() + phase.substring(1);
  }

  /// Get ordinal suffix for phase count
  static String getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }
}


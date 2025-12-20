// lib/arc/chat/services/theme_analysis_service.dart
// Longitudinal theme tracking and frequency analysis

import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';

/// Theme frequency data
class ThemeFrequency {
  final String theme;
  final int count;
  final double intensity;

  ThemeFrequency({
    required this.theme,
    required this.count,
    required this.intensity,
  });
}

/// Service for analyzing theme frequencies over time
class ThemeAnalysisService {
  ThemeAnalysisService();

  /// Compute theme frequencies for a list of entries
  Map<String, ThemeFrequency> computeThemeFrequencies(List<JournalEntry> entries) {
    final themeMap = <String, int>{};
    final intensityMap = <String, double>{};
    
    for (final entry in entries) {
      final keywords = entry.keywords;
      for (final keyword in keywords) {
        final theme = keyword.toLowerCase();
        themeMap[theme] = (themeMap[theme] ?? 0) + 1;
        
        // Compute intensity (based on entry length and emotional content)
        final intensity = _computeIntensity(entry);
        intensityMap[theme] = (intensityMap[theme] ?? 0.0) + intensity;
      }
    }
    
    return themeMap.map((theme, count) => MapEntry(
      theme,
      ThemeFrequency(
        theme: theme,
        count: count,
        intensity: intensityMap[theme] ?? 0.0,
      ),
    ));
  }

  /// Compute emotional intensity for an entry
  double _computeIntensity(JournalEntry entry) {
    // Base intensity from entry length (normalized)
    double intensity = entry.content.length / 1000.0;
    
    // Boost intensity for entries with SAGE annotations (more reflective)
    if (entry.sageAnnotation != null) {
      intensity *= 1.5;
    }
    
    // Check for emotional keywords
    final content = entry.content.toLowerCase();
    final highIntensityKeywords = ['overwhelmed', 'devastated', 'ecstatic', 
                                   'terrified', 'euphoric', 'desperate'];
    if (highIntensityKeywords.any((kw) => content.contains(kw))) {
      intensity *= 2.0;
    }
    
    return intensity.clamp(0.0, 10.0);
  }

  /// Compare theme frequencies between two time periods
  Map<String, double> compareThemeFrequencies({
    required Map<String, ThemeFrequency> past,
    required Map<String, ThemeFrequency> recent,
  }) {
    final deltas = <String, double>{};
    
    // Find themes that decreased
    for (final theme in past.keys) {
      final pastFreq = past[theme]!;
      final recentFreq = recent[theme] ?? ThemeFrequency(
        theme: theme,
        count: 0,
        intensity: 0.0,
      );
      
      if (pastFreq.count > recentFreq.count) {
        final delta = pastFreq.intensity - recentFreq.intensity;
        deltas[theme] = delta;
      }
    }
    
    return deltas;
  }
}


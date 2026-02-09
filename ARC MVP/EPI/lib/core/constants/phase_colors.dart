/// Phase Colors
///
/// Centralized phase color definitions used across the unified feed,
/// timeline, and card borders. Consistent with ATLAS phase labels.

import 'package:flutter/material.dart';

class PhaseColors {
  PhaseColors._();

  static const Map<String, Color> phaseColors = {
    'Recovery': Color(0xFFFF6B6B),      // Warm orange/red
    'Transition': Color(0xFF9B59B6),    // Purple/violet
    'Breakthrough': Color(0xFFFFC107),  // Bright yellow/gold
    'Discovery': Color(0xFF42A5F5),     // Light blue/cyan
    'Expansion': Color(0xFF26A69A),     // Green/teal
    'Consolidation': Color(0xFF1565C0), // Deep blue/navy
  };

  /// Get the color for a phase label (case-insensitive).
  static Color getPhaseColor(String? phase) {
    if (phase == null) return Colors.grey;
    // Try exact match first
    final exact = phaseColors[phase];
    if (exact != null) return exact;
    // Try case-insensitive
    final lower = phase.toLowerCase();
    for (final entry in phaseColors.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return Colors.grey;
  }

  /// Phase description for display in expanded views.
  static String getPhaseDescription(String phase) {
    const descriptions = {
      'Recovery': 'Healing and regrouping',
      'Transition': 'Between states, exploring',
      'Breakthrough': 'Moment of clarity and change',
      'Discovery': 'Learning and finding new paths',
      'Expansion': 'Growth and momentum building',
      'Consolidation': 'Stabilizing and integrating',
    };
    return descriptions[phase] ?? '';
  }
}

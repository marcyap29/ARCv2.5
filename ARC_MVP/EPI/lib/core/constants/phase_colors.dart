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

  /// Phase description for display in expanded views (body only; UI prepends "Phase Name: ").
  static String getPhaseDescription(String phase) {
    const descriptions = {
      'Recovery':
          'A time of emotional exhaustion and protective withdrawal; rest and healing are central. '
          'Energy is low and focus often turns to what has drained you. '
          'Language of depletion, overwhelm, and needing space is common.',
      'Transition':
          'Identity and direction are in question; you are between states with liminal uncertainty. '
          'Energy and mood can be mixed. '
          'Themes of change, leaving, moving between, not knowing, and becoming show up often.',
      'Breakthrough':
          'A genuine shift in perspective or reframe, with real integration—not just a passing insight. '
          'It involves clear before/after thinking and connecting dots or seeing patterns. '
          'Meta-cognitive clarity that helps explain why things are the way they are.',
      'Discovery':
          'Active exploration and openness to new experiences, with energized curiosity. '
          'Energy is high and orientation is toward the future and possibilities. '
          'Language of wonder, learning, trying, exploring, and new beginnings.',
      'Expansion':
          'Confidence and capacity are growing; there is forward momentum. '
          'Energy is high and focus is on growth and scaling. '
          'Themes of reaching, building, growing, and amplifying capability.',
      'Consolidation':
          'Integration and pattern recognition; grounding a new sense of self into habits and routine. '
          'Energy is moderate and stable; focus is on stability in the present. '
          'Language of weaving together, organizing, establishing routine, and making things lasting.',
    };
    return descriptions[phase] ?? '';
  }
}

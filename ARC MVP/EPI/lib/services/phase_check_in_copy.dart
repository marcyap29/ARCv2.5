// Phase Check-in copy: confirmation blurbs and diagnostic options.
// Descriptions are the canonical phase descriptions from phase_help_screen / UserPhaseService.

/// Copy for the monthly Phase Check-in flow (confirmation step and diagnostic).
abstract final class PhaseCheckInCopy {
  PhaseCheckInCopy._();

  /// Confirmation step: one-sentence blurb per phase (from repo phase_help_screen style).
  static String confirmationBlurb(String phaseName) {
    switch (phaseName.toLowerCase()) {
      case 'discovery':
        return 'A period of exploration, learning, and asking questions about yourself and your goals.';
      case 'expansion':
        return 'A time of growth, building momentum, and taking action on your discoveries.';
      case 'transition':
        return 'A phase of change, decision-making, and adapting to new circumstances.';
      case 'consolidation':
        return 'A period of refining, organizing, and strengthening your foundations.';
      case 'recovery':
        return 'A time of rest, healing, and regaining energy after intense periods.';
      case 'breakthrough':
        return 'A phase of clarity, major insights, and significant forward movement.';
      default:
        return 'Your current phase in the journey.';
    }
  }

  /// Q1: "In the past month, your primary focus has been..."
  static const Map<String, String> q1Options = {
    'recovering': 'Recovering capacity / rebuilding foundation',
    'exploring': 'Finding new direction / exploring possibilities',
    'building': 'Building momentum toward something specific',
    'breakthrough': 'Major breakthrough / significant change happening',
    'integrating': 'Integrating growth / refining what works',
    'maintaining': 'Sustaining routine / maintaining what\'s working',
  };

  /// Q2: "The work you're doing right now feels..."
  static const Map<String, String> q2Options = {
    'healing': 'Healing/restorative',
    'exploratory': 'Exploratory/undefined',
    'building': 'Building/creating toward a vision',
    'transformative': 'Transformative/breakthrough',
    'expansive': 'Expansive/growing',
    'maintenance': 'Stable/maintenance',
  };

  /// Q3: "Your energy and ambition are..."
  static const Map<String, String> q3Options = {
    'limited': 'Limited—I\'m in recovery mode',
    'scattered': 'Scattered—exploring without clear direction',
    'focused': 'Focused—grinding on something specific',
    'surging': 'Surging—breakthrough momentum',
    'steady': 'Strong and steady—expanding capacity',
    'calm': 'Calm and consistent—maintaining rhythm',
  };
}

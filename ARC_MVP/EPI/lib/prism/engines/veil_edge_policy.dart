class VeilEdgePolicy {
  static Map<String, dynamic> planDay(
      Map<String, dynamic> fused, Map<String, dynamic> atlas) {
    final f = (fused['features'] as Map<String, dynamic>? ?? {});
    final stress = (f['stress_hint'] ?? 0.3) as num;
    final readiness = (f['readiness_hint'] ?? 0.6) as num;
    final sleepDebt = (f['sleep_debt_min'] ?? 0) as int;

    int readinessScore = (readiness * 100).round().clamp(0, 100);
    String cadence = readinessScore >= 70
        ? 'light'
        : readinessScore >= 45
            ? 'standard'
            : 'reflective';

    double empathy = (0.35 + (stress - 0.5) * 0.3).clamp(0.2, 0.6);
    double depth = (0.4 + (sleepDebt.abs() > 60 ? -0.1 : 0.0)).clamp(0.2, 0.6);
    double agency =
        (0.35 + (readiness - 0.5) * 0.4 - (stress - 0.5) * 0.2).clamp(0.15, 0.55);

    final sum = empathy + depth + agency;
    empathy /= sum;
    depth /= sum;
    agency /= sum;

    final nudges = <String>[
      if (sleepDebt < -60) 'evening-winddown',
      if (stress > 0.6) 'box-breathing-2min',
      if (readinessScore >= 60) 'light-cardio',
    ];

    final safety = {
      'defer_heavy_goals': stress > 0.7 || sleepDebt < -120,
    };

    return {
      'readiness': readinessScore,
      'journal_cadence': cadence,
      'prompt_weights': {
        'empathy': double.parse(empathy.toStringAsFixed(2)),
        'depth': double.parse(depth.toStringAsFixed(2)),
        'agency': double.parse(agency.toStringAsFixed(2)),
      },
      'quiet_hours': {'start': '22:00', 'end': '07:00'},
      'coach_nudges': nudges,
      'safety': safety,
    };
  }
}



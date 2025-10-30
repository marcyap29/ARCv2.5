class AtlasEngine {
  /// Lightweight heuristic placeholder (replace with your FFT model later).
  static Map<String, dynamic> analyzeDay(Map<String, dynamic> fused) {
    final h = (fused['health'] as Map<String, dynamic>? ?? {});
    final f = (fused['features'] as Map<String, dynamic>? ?? {});

    final steps = (h['steps'] ?? 0) as num;
    final readiness = (f['readiness_hint'] ?? 0.5) as num;
    final stress = (f['stress_hint'] ?? 0.3) as num;

    String phase;
    if (readiness > 0.7 && steps > 8000) {
      phase = 'Breakthrough';
    } else if (readiness > 0.55 && stress < 0.5) {
      phase = 'Expansion';
    } else if (stress >= 0.6) {
      phase = 'Recovery';
    } else {
      phase = 'Consolidation';
    }

    final band = (steps > 9000 || readiness > 0.75)
        ? 'high'
        : (steps < 3000 && stress > 0.6)
            ? 'low'
            : 'mid';

    final conf = (0.55 + 0.45 * (readiness - 0.5).abs()).clamp(0.5, 0.95);

    return {
      'phase': phase,
      'confidence': double.parse(conf.toStringAsFixed(2)),
      'transition': {
        '$phase→Transition': phase == 'Breakthrough' ? 0.22 : 0.15,
        '$phase→Consolidation': phase == 'Expansion' ? 0.12 : 0.18,
      },
      'spectral_band': band,
      'notes': null,
    };
  }
}



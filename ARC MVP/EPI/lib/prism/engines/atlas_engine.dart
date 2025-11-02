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

    // Calculate phase transition probabilities with detailed metrics
    final transitionProbs = _calculateTransitionProbabilities(
      currentPhase: phase,
      readiness: readiness.toDouble(),
      stress: stress.toDouble(),
      steps: steps.toDouble(),
    );

    // Generate phase-approaching insights
    final phaseInsights = _generatePhaseApproachingInsights(
      currentPhase: phase,
      readiness: readiness.toDouble(),
      stress: stress.toDouble(),
      steps: steps.toDouble(),
      transitionProbs: transitionProbs,
    );

    return {
      'phase': phase,
      'confidence': double.parse(conf.toStringAsFixed(2)),
      'transition': transitionProbs,
      'spectral_band': band,
      'notes': null,
      'phase_insights': phaseInsights, // New: detailed phase-approaching information
    };
  }

  /// Calculate transition probabilities to other phases with detailed metrics
  static Map<String, double> _calculateTransitionProbabilities({
    required String currentPhase,
    required double readiness,
    required double stress,
    required double steps,
  }) {
    final transitions = <String, double>{};
    
    // Calculate likelihood of transitioning to each phase
    final allPhases = ['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'];
    
    for (final targetPhase in allPhases) {
      if (targetPhase == currentPhase) continue;
      
      double prob = 0.0;
      
      switch (targetPhase) {
        case 'Expansion':
          prob = readiness > 0.6 && stress < 0.4 ? (readiness - 0.5) * 0.5 : 0.0;
          break;
        case 'Breakthrough':
          prob = readiness > 0.7 && steps > 7000 ? (readiness - 0.6) * 0.3 : 0.0;
          break;
        case 'Recovery':
          prob = stress > 0.6 ? (stress - 0.5) * 0.4 : 0.0;
          break;
        case 'Consolidation':
          prob = readiness > 0.4 && readiness < 0.7 && stress < 0.5 ? 0.2 : 0.0;
          break;
        case 'Transition':
          prob = stress > 0.5 && readiness < 0.6 ? (stress + (1 - readiness)) * 0.15 : 0.0;
          break;
        case 'Discovery':
          prob = readiness < 0.5 && stress < 0.4 ? (1 - readiness) * 0.2 : 0.0;
          break;
      }
      
      if (prob > 0.01) {
        transitions['$currentPhase→$targetPhase'] = prob.clamp(0.0, 1.0);
      }
    }
    
    return transitions;
  }

  /// Generate detailed phase-approaching insights
  static Map<String, dynamic> _generatePhaseApproachingInsights({
    required String currentPhase,
    required double readiness,
    required double stress,
    required double steps,
    required Map<String, double> transitionProbs,
  }) {
    // Find most likely approaching phase
    String? approachingPhase;
    double maxProb = 0.0;
    
    for (final entry in transitionProbs.entries) {
      if (entry.value > maxProb) {
        maxProb = entry.value;
        // Extract target phase from "Current→Target" format
        final parts = entry.key.split('→');
        if (parts.length == 2) {
          approachingPhase = parts[1];
        }
      }
    }

    // Calculate shift percentage based on metrics
    double shiftPercentage = 0.0;
    final measurableSigns = <String>[];
    final contributingMetrics = <String, double>{};

    if (approachingPhase != null && maxProb > 0.1) {
      // Calculate shift percentage
      shiftPercentage = (maxProb * 100).clamp(0.0, 100.0);
      
      // Generate measurable signs
      switch (approachingPhase) {
        case 'Expansion':
          if (readiness > 0.6) {
            final readinessPercent = (readiness * 100).toStringAsFixed(0);
            measurableSigns.add('Your readiness signals have increased to $readinessPercent%, indicating growth momentum.');
          }
          if (stress < 0.4) {
            measurableSigns.add('Stress levels have decreased, creating space for expansion.');
          }
          break;
        case 'Breakthrough':
          if (steps > 7000) {
            final stepPercent = ((steps / 10000) * 100).clamp(0, 100).toStringAsFixed(0);
            measurableSigns.add('Activity levels show $stepPercent% engagement toward breakthrough patterns.');
          }
          if (readiness > 0.7) {
            measurableSigns.add('High readiness ($readiness%%) suggests breakthrough readiness.');
          }
          break;
        case 'Recovery':
          if (stress > 0.6) {
            final stressPercent = (stress * 100).toStringAsFixed(0);
            measurableSigns.add('Elevated stress ($stressPercent%%) signals the need for recovery.');
          }
          break;
        case 'Consolidation':
          measurableSigns.add('Balanced indicators suggest integration and consolidation patterns.');
          break;
      }
      
      // Add generic shift sign
      measurableSigns.add('Your reflection patterns have shifted ${shiftPercentage.toStringAsFixed(0)}% toward $approachingPhase.');
      
      // Contributing metrics
      contributingMetrics['readiness'] = readiness;
      contributingMetrics['stress'] = stress;
      contributingMetrics['activity'] = (steps / 10000).clamp(0.0, 1.0);
      contributingMetrics['transition_probability'] = maxProb;
    }

    return {
      'current_phase': currentPhase,
      'approaching_phase': approachingPhase,
      'shift_percentage': shiftPercentage,
      'transition_confidence': maxProb,
      'measurable_signs': measurableSigns,
      'contributing_metrics': contributingMetrics,
    };
  }
}



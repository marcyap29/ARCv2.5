/// ATLAS Phase Integration for ECHO
///
/// Provides phase-aware response generation that adapts LUMARA's voice
/// to the user's current developmental phase while maintaining dignity
library;

import 'package:my_app/prism/atlas/phase/pattern_analysis_service.dart';
import '../voice/lumara_voice_controller.dart';
import 'package:my_app/arc/core/journal_repository.dart';

class AtlasPhaseIntegration {
  /// Current detected ATLAS phase
  String? _currentPhase;

  /// Phase transition detection
  bool _isInTransition = false;

  /// Phase stability score (0.0 - 1.0)
  double _phaseStability = 1.0;

  /// Get current ATLAS phase with fallback
  String getCurrentPhase() {
    return _currentPhase ?? 'Discovery';
  }

  /// Update phase detection from ATLAS system
  Future<void> updatePhaseDetection() async {
    try {
      // Integrate with existing ATLAS pattern analysis
      final patternService = PatternAnalysisService(JournalRepository());

      // Get latest phase analysis
      final (nodes, edges) = patternService.analyzePatterns();

      // Process the pattern analysis results
      if (nodes.isNotEmpty) {
        // For now, use a simple phase detection based on keyword patterns
        final phase = _detectPhaseFromPatterns(nodes, edges);
        if (phase != null && phase != _currentPhase) {
          _handlePhaseTransition(_currentPhase, phase);
          _currentPhase = phase;
          _phaseStability = 0.8; // Default stability
          _isInTransition = false; // Simplified for now
        }
      }
    } catch (e) {
      // Graceful fallback to Discovery phase
      _currentPhase ??= 'Discovery';
      _phaseStability = 1.0;
      _isInTransition = false;
    }
  }

  /// Handle phase transitions with appropriate voice adaptation
  void _handlePhaseTransition(String? fromPhase, String toPhase) {
    _isInTransition = true;

    // Log transition for MIRA memory integration
    print('ATLAS Phase Transition: ${fromPhase ?? 'Unknown'} → $toPhase');
  }

  /// Get phase-specific response generation parameters
  Map<String, dynamic> getPhaseResponseParameters() {
    final phase = getCurrentPhase();
    final baseRules = LumaraVoiceController.getPhaseVoiceRules(phase);

    // Adapt for transition states
    if (_isInTransition) {
      return {
        ...baseRules,
        'transition_mode': true,
        'stability_score': _phaseStability,
        'tone_adjustment': 'gentle, orienting, normalizing',
        'pacing_adjustment': 'slower, more supportive',
      };
    }

    return {
      ...baseRules,
      'transition_mode': false,
      'stability_score': _phaseStability,
      'phase_confidence': _phaseStability > 0.8 ? 'high' : 'moderate',
    };
  }

  /// Generate phase-aware emotional resonance
  String getPhaseEmotionalResonance(Map<String, double> emotionVector) {
    final phase = getCurrentPhase();

    switch (phase) {
      case 'Discovery':
        return _generateDiscoveryResonance(emotionVector);
      case 'Expansion':
        return _generateExpansionResonance(emotionVector);
      case 'Transition':
        return _generateTransitionResonance(emotionVector);
      case 'Consolidation':
        return _generateConsolidationResonance(emotionVector);
      case 'Recovery':
        return _generateRecoveryResonance(emotionVector);
      case 'Breakthrough':
        return _generateBreakthroughResonance(emotionVector);
      default:
        return _generateDiscoveryResonance(emotionVector);
    }
  }

  /// Discovery phase emotional resonance
  String _generateDiscoveryResonance(Map<String, double> emotions) {
    final curiosity = emotions['curiosity'] ?? 0.0;
    final uncertainty = emotions['uncertainty'] ?? 0.0;

    if (curiosity > 0.6) {
      return 'I sense a wonderful openness in you - that willingness to explore and discover. What feels most interesting to explore right now?';
    } else if (uncertainty > 0.7) {
      return 'Uncertainty can feel unsettling, and also like fertile ground. What wants to emerge from this not-knowing?';
    } else {
      return 'There\'s something beginning here. I\'m curious what wants to unfold.';
    }
  }

  /// Expansion phase emotional resonance
  String _generateExpansionResonance(Map<String, double> emotions) {
    final energy = emotions['energy'] ?? 0.0;
    final excitement = emotions['excitement'] ?? 0.0;

    if (energy > 0.7 && excitement > 0.6) {
      return 'I can feel the momentum building! This expansion energy wants to move - what feels ready to be built or created?';
    } else if (energy > 0.5) {
      return 'There\'s forward movement here. What concrete step wants to be taken next?';
    } else {
      return 'Even in quiet expansion, seeds are growing. What\'s developing beneath the surface?';
    }
  }

  /// Transition phase emotional resonance
  String _generateTransitionResonance(Map<String, double> emotions) {
    final ambiguity = emotions['ambiguity'] ?? 0.0;
    final discomfort = emotions['discomfort'] ?? 0.0;

    if (ambiguity > 0.7 || discomfort > 0.6) {
      return 'Transitions rarely feel comfortable - they\'re meant to be in-between spaces. You don\'t have to know where you\'re going yet.';
    } else {
      return 'Something is shifting. These threshold moments hold their own wisdom.';
    }
  }

  /// Consolidation phase emotional resonance
  String _generateConsolidationResonance(Map<String, double> emotions) {
    final focus = emotions['focus'] ?? 0.0;
    final clarity = emotions['clarity'] ?? 0.0;

    if (focus > 0.6 && clarity > 0.5) {
      return 'There\'s a beautiful clarity here - things are coming into focus. What wants to be organized or structured?';
    } else {
      return 'This is a time for gathering what matters. What feels most important to hold onto?';
    }
  }

  /// Recovery phase emotional resonance
  String _generateRecoveryResonance(Map<String, double> emotions) {
    final exhaustion = emotions['exhaustion'] ?? 0.0;
    final overwhelm = emotions['overwhelm'] ?? 0.0;

    if (exhaustion > 0.7 || overwhelm > 0.6) {
      return 'Your system is asking for rest, and that asking deserves to be honored. What would true restoration look like right now?';
    } else {
      return 'Recovery isn\'t just about rest - it\'s about returning to yourself. What helps you feel most at home in your own skin?';
    }
  }

  /// Breakthrough phase emotional resonance
  String _generateBreakthroughResonance(Map<String, double> emotions) {
    final joy = emotions['joy'] ?? 0.0;
    final integration = emotions['integration'] ?? 0.0;

    if (joy > 0.6 && integration > 0.5) {
      return 'Something significant has shifted! I can sense both the joy and the depth of integration happening. How do you want to honor this breakthrough?';
    } else {
      return 'Breakthroughs don\'t always feel dramatic - sometimes they\'re quiet knowings that change everything. What feels different now?';
    }
  }

  /// Check if response should be adjusted for phase transition
  bool isInTransition() => _isInTransition;

  /// Get phase stability score
  double getPhaseStability() => _phaseStability;

  /// Generate phase-appropriate memory retrieval context
  String getPhaseMemoryContext() {
    final phase = getCurrentPhase();

    switch (phase) {
      case 'Discovery':
        return 'Look for patterns of curiosity, exploration, and beginning experiences';
      case 'Expansion':
        return 'Focus on growth, building, achievement, and forward momentum';
      case 'Transition':
        return 'Emphasize change experiences, uncertainty, and navigation moments';
      case 'Consolidation':
        return 'Highlight integration, organization, and solidification experiences';
      case 'Recovery':
        return 'Prioritize rest, healing, restoration, and self-care experiences';
      case 'Breakthrough':
        return 'Surface transformation, insight, and significant shift experiences';
      default:
        return 'General life pattern and emotional resonance experiences';
    }
  }

  /// Detect phase from pattern analysis results
  String? _detectPhaseFromPatterns(List<dynamic> nodes, List<dynamic> edges) {
    // Simple phase detection based on keyword patterns
    // This is a placeholder implementation
    if (nodes.isEmpty) return null;
    
    // For now, return a default phase
    return 'Discovery';
  }
}
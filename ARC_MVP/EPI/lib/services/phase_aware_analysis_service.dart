
import 'dignified_text_service.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/phase_rating_ranges.dart';

enum UserPhase {
  recovery,
  discovery,
  breakthrough,
  consolidation,
  reflection,
  transition
}

class PhaseContext {
  final UserPhase primaryPhase;
  final double confidence;
  final List<String> indicators;
  final Map<String, dynamic> emotionalState;
  final Map<String, dynamic> physicalState;
  final Map<String, dynamic> socialState;
  final HealthData? healthData;
  final int operationalReadinessScore; // 10-100 rating for military readiness

  PhaseContext({
    required this.primaryPhase,
    required this.confidence,
    required this.indicators,
    required this.emotionalState,
    required this.physicalState,
    required this.socialState,
    this.healthData,
    required this.operationalReadinessScore,
  });
}

class PhaseAwareAnalysisService {
  static final PhaseAwareAnalysisService _instance = PhaseAwareAnalysisService._internal();
  factory PhaseAwareAnalysisService() => _instance;
  PhaseAwareAnalysisService._internal();

  // Phase detection keywords and patterns
  static const Map<UserPhase, List<String>> _phaseIndicators = {
    UserPhase.recovery: [
      'healing', 'recovering', 'getting better', 'feeling stronger', 'progress',
      'therapy', 'treatment', 'medication', 'rehab', 'rehabilitation',
      'slowly', 'gradually', 'step by step', 'one day at a time'
    ],
    UserPhase.discovery: [
      'learning', 'exploring', 'trying new', 'experimenting', 'curious',
      'wondering', 'questioning', 'seeking', 'finding out', 'discovering',
      'research', 'study', 'investigation', 'exploration'
    ],
    UserPhase.breakthrough: [
      'breakthrough', 'eureka', 'suddenly', 'realized', 'understood',
      'success', 'achievement', 'accomplished', 'victory', 'won',
      'amazing', 'incredible', 'fantastic', 'brilliant', 'genius'
    ],
    UserPhase.consolidation: [
      'consolidating', 'integrating', 'building on', 'expanding', 'growing',
      'stable', 'steady', 'consistent', 'reliable', 'solid',
      'routine', 'habit', 'practice', 'maintaining'
    ],
    UserPhase.reflection: [
      'thinking', 'reflecting', 'considering', 'pondering', 'meditating',
      'looking back', 'remembering', 'analyzing', 'evaluating',
      'insight', 'understanding', 'wisdom', 'perspective'
    ],
    UserPhase.transition: [
      'transition', 'changing', 'shifting', 'between', 'in-between',
      'uncertain', 'ambiguous', 'not sure', 'threshold', 'liminal',
      'transforming', 'adapting', 'navigating', 'adjusting', 'uncomfortable',
      'discomfort', 'letting go', 'grief', 'confusion'
    ]
  };

  // Emotional state indicators
  static const Map<String, List<String>> _emotionalIndicators = {
    'positive': ['happy', 'joyful', 'excited', 'grateful', 'content', 'peaceful', 'hopeful'],
    'negative': ['sad', 'angry', 'frustrated', 'anxious', 'worried', 'scared', 'depressed'],
    'neutral': ['calm', 'focused', 'balanced', 'stable', 'centered', 'grounded'],
    'intense': ['overwhelmed', 'intense', 'powerful', 'strong', 'intense', 'extreme'],
    'mild': ['slightly', 'somewhat', 'a bit', 'kind of', 'sort of', 'mildly']
  };

  // Physical state indicators
  static const Map<String, List<String>> _physicalIndicators = {
    'exhausted': ['tired', 'exhausted', 'drained', 'fatigued', 'worn out', 'burned out'],
    'energetic': ['energetic', 'vibrant', 'alive', 'pumped', 'energized', 'active'],
    'pain': ['pain', 'hurt', 'ache', 'sore', 'injured', 'wounded'],
    'healthy': ['healthy', 'strong', 'fit', 'well', 'good', 'great']
  };

  // Social state indicators
  static const Map<String, List<String>> _socialIndicators = {
    'isolated': ['alone', 'lonely', 'isolated', 'withdrawn', 'separated'],
    'connected': ['together', 'with', 'friends', 'family', 'loved ones', 'community'],
    'conflict': ['fight', 'argument', 'disagreement', 'tension', 'conflict'],
    'support': ['support', 'help', 'assistance', 'care', 'love', 'understanding']
  };

  /// Analyze journal text to detect user phase and context
  /// 
  /// Optionally accepts health data to influence phase detection and calculate
  /// operational readiness score. If health data is not provided, it will be
  /// fetched automatically if available.
  Future<PhaseContext> analyzePhase(
    String journalText, {
    HealthData? healthData,
  }) async {
    final words = journalText.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();

    // Get health data if not provided
    HealthData? effectiveHealthData = healthData;
    if (effectiveHealthData == null) {
      try {
        effectiveHealthData = await HealthDataService.instance.getAutoDetectedHealthData();
        // Only use if it's not stale/default
        if (effectiveHealthData.isStale) {
          effectiveHealthData = null;
        }
      } catch (e) {
        // Ignore errors, continue without health data
        effectiveHealthData = null;
      }
    }

    // Detect primary phase
    final phaseScores = <UserPhase, double>{};
    for (final phase in UserPhase.values) {
      final indicators = _phaseIndicators[phase] ?? [];
      double score = 0.0;
      for (final word in words) {
        if (indicators.contains(word)) {
          score += 1.0;
        }
      }
      phaseScores[phase] = score;
    }

    // Apply health-based phase adjustments
    if (effectiveHealthData != null) {
      _applyHealthPhaseAdjustments(phaseScores, effectiveHealthData);
    }

    // Find the phase with highest score
    final primaryPhase = phaseScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    final maxScore = phaseScores[primaryPhase] ?? 0.0;
    final totalWords = words.isNotEmpty ? words.length : 1;
    final confidence = (maxScore / totalWords * 100).clamp(0.0, 100.0) / 100.0; // Normalize to 0.0-1.0

    // Extract indicators
    final indicators = <String>[];
    for (final word in words) {
      if (_phaseIndicators[primaryPhase]?.contains(word) == true) {
        indicators.add(word);
      }
    }

    // Analyze emotional state
    final emotionalState = _analyzeEmotionalState(words);
    
    // Analyze physical state
    final physicalState = _analyzePhysicalState(words);
    
    // Analyze social state
    final socialState = _analyzeSocialState(words);

    // Calculate operational readiness score (10-100)
    final operationalReadinessScore = _calculateOperationalReadinessScore(
      phase: primaryPhase,
      confidence: confidence,
      healthData: effectiveHealthData,
    );

    return PhaseContext(
      primaryPhase: primaryPhase,
      confidence: confidence,
      indicators: indicators,
      emotionalState: emotionalState,
      physicalState: physicalState,
      socialState: socialState,
      healthData: effectiveHealthData,
      operationalReadinessScore: operationalReadinessScore,
    );
  }

  /// Apply health-based adjustments to phase scores
  void _applyHealthPhaseAdjustments(
    Map<UserPhase, double> phaseScores,
    HealthData healthData,
  ) {
    final sleepQuality = healthData.sleepQuality;
    final energyLevel = healthData.energyLevel;

    // Recovery phase boost from poor health
    if (sleepQuality < 0.4 || energyLevel < 0.4) {
      final recoveryBoost = sleepQuality < 0.4 && energyLevel < 0.4 ? 0.3 : 0.15;
      phaseScores[UserPhase.recovery] = (phaseScores[UserPhase.recovery] ?? 0.0) + recoveryBoost;
    }

    // Breakthrough phase boost from excellent health
    if (sleepQuality > 0.8 && energyLevel > 0.8) {
      phaseScores[UserPhase.breakthrough] = (phaseScores[UserPhase.breakthrough] ?? 0.0) + 0.1;
    }

    // Consolidation phase slight boost from stable health
    if (sleepQuality >= 0.5 && sleepQuality <= 0.7 && 
        energyLevel >= 0.5 && energyLevel <= 0.7) {
      phaseScores[UserPhase.consolidation] = (phaseScores[UserPhase.consolidation] ?? 0.0) + 0.05;
    }
  }

  /// Calculate operational readiness score (10-100) based on phase and health
  int _calculateOperationalReadinessScore({
    required UserPhase phase,
    required double confidence,
    HealthData? healthData,
  }) {
    // Base rating from phase range + confidence
    final baseRating = PhaseRatingRanges.getRating(phase.name, confidence);
    final range = PhaseRatingRanges.getRange(phase.name);

    // Apply health adjustment if health data is available
    if (healthData != null) {
      // Calculate composite health factor from all available metrics
      final healthFactors = <double>[];
      
      // Core factors (always available)
      healthFactors.add(healthData.sleepQuality);
      healthFactors.add(healthData.energyLevel);
      
      // Additional factors (if available)
      if (healthData.fitnessScore != null) {
        healthFactors.add(healthData.fitnessScore!);
      }
      if (healthData.recoveryScore != null) {
        healthFactors.add(healthData.recoveryScore!);
      }
      if (healthData.weightTrendScore != null) {
        healthFactors.add(healthData.weightTrendScore!);
      }
      
      // Average all available health factors
      final healthFactor = healthFactors.reduce((a, b) => a + b) / healthFactors.length;
      
      int adjustedRating;
      if (healthFactor < 0.4) {
        // Poor health: Reduce rating by up to 20 points
        final reduction = (20 * (0.4 - healthFactor) / 0.4).round();
        adjustedRating = (baseRating - reduction);
      } else if (healthFactor > 0.8) {
        // Excellent health: Boost rating by up to 10 points
        final boost = (10 * (healthFactor - 0.8) / 0.2).round();
        adjustedRating = (baseRating + boost);
      } else {
        // Moderate health: No adjustment
        adjustedRating = baseRating;
      }
      
      // Clamp to phase range to maintain consistency
      adjustedRating = adjustedRating.clamp(range.min, range.max);
      
      // Final clamp to overall 10-100 range
      return adjustedRating.clamp(10, 100);
    }

    // No health data, return base rating
    return baseRating;
  }

  /// Get phase-specific system prompt for AI analysis using ECHO
  Future<String> getPhaseSpecificSystemPrompt(PhaseContext phaseContext) async {
    final dignifiedService = DignifiedTextService();
    await dignifiedService.initialize();
    
    return await dignifiedService.generateDignifiedAnalysis(
      entryText: '', // Will be filled by the calling service
      phase: phaseContext.primaryPhase.name,
      emotionalState: phaseContext.emotionalState,
      physicalState: phaseContext.physicalState,
    );
  }

  /// Get phase-specific AI suggestions using ECHO
  Future<List<String>> getPhaseSpecificSuggestions(PhaseContext phaseContext) async {
    final dignifiedService = DignifiedTextService();
    await dignifiedService.initialize();
    
    return await dignifiedService.generateDignifiedSuggestions(
      entryText: '', // Will be filled by the calling service
      phase: phaseContext.primaryPhase.name,
      emotionalState: phaseContext.emotionalState,
    );
  }

  Map<String, dynamic> _analyzeEmotionalState(List<String> words) {
    final scores = <String, int>{};
    for (final category in _emotionalIndicators.keys) {
      int score = 0;
      for (final word in words) {
        if (_emotionalIndicators[category]?.contains(word) == true) {
          score++;
        }
      }
      scores[category] = score;
    }
    return scores;
  }

  Map<String, dynamic> _analyzePhysicalState(List<String> words) {
    final scores = <String, int>{};
    for (final category in _physicalIndicators.keys) {
      int score = 0;
      for (final word in words) {
        if (_physicalIndicators[category]?.contains(word) == true) {
          score++;
        }
      }
      scores[category] = score;
    }
    return scores;
  }

  Map<String, dynamic> _analyzeSocialState(List<String> words) {
    final scores = <String, int>{};
    for (final category in _socialIndicators.keys) {
      int score = 0;
      for (final word in words) {
        if (_socialIndicators[category]?.contains(word) == true) {
          score++;
        }
      }
      scores[category] = score;
    }
    return scores;
  }





}

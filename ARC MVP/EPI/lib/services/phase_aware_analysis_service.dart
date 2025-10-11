
import 'dignified_text_service.dart';

enum UserPhase {
  recovery,
  discovery,
  breakthrough,
  consolidation,
  reflection,
  planning
}

class PhaseContext {
  final UserPhase primaryPhase;
  final double confidence;
  final List<String> indicators;
  final Map<String, dynamic> emotionalState;
  final Map<String, dynamic> physicalState;
  final Map<String, dynamic> socialState;

  PhaseContext({
    required this.primaryPhase,
    required this.confidence,
    required this.indicators,
    required this.emotionalState,
    required this.physicalState,
    required this.socialState,
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
    UserPhase.planning: [
      'planning', 'preparing', 'organizing', 'scheduling', 'arranging',
      'future', 'next', 'upcoming', 'goals', 'objectives',
      'strategy', 'approach', 'method', 'system'
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
  Future<PhaseContext> analyzePhase(String journalText) async {
    final words = journalText.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();

    // Detect primary phase
    final phaseScores = <UserPhase, int>{};
    for (final phase in UserPhase.values) {
      final indicators = _phaseIndicators[phase] ?? [];
      int score = 0;
      for (final word in words) {
        if (indicators.contains(word)) {
          score++;
        }
      }
      phaseScores[phase] = score;
    }

    // Find the phase with highest score
    final primaryPhase = phaseScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    final maxScore = phaseScores[primaryPhase] ?? 0;
    final confidence = maxScore > 0 ? (maxScore / words.length * 100).clamp(0.0, 100.0) : 0.0;

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

    return PhaseContext(
      primaryPhase: primaryPhase,
      confidence: confidence,
      indicators: indicators,
      emotionalState: emotionalState,
      physicalState: physicalState,
      socialState: socialState,
    );
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

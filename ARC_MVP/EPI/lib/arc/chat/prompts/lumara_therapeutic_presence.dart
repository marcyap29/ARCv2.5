// lib/arc/chat/prompts/lumara_therapeutic_presence.dart
// LUMARA Therapeutic Presence Mode v1.0
// Emotionally intelligent journaling support for complex experiences

import 'dart:math';
import 'archive/lumara_therapeutic_presence_data.dart';
import 'lumara_prompt_encouragement.dart'; // Provides AtlasPhase enum

/// Emotion categories for therapeutic presence mode
enum TherapeuticEmotionCategory {
  anger,
  grief,
  shame,
  fear,
  guilt,
  loneliness,
  confusion,
  hope,
  burnout,
  identityViolation,
}

/// Emotion intensity levels
enum EmotionIntensity {
  low,
  moderate,
  high,
}

/// Tone modes for therapeutic responses
enum TherapeuticToneMode {
  groundedContainment,
  reflectiveEcho,
  restorativeClosure,
  compassionateMirror,
  quietIntegration,
  cognitiveGrounding,
  existentialSteadiness,
  restorativeNeutrality,
}

/// LUMARA Therapeutic Presence Mode
/// Provides emotionally intelligent, professional journaling support
class LumaraTherapeuticPresence {
  static LumaraTherapeuticPresence? _instance;
  static LumaraTherapeuticPresence get instance {
    _instance ??= LumaraTherapeuticPresence._();
    return _instance!;
  }

  LumaraTherapeuticPresence._();

  final Map<String, dynamic> _responseMatrix =
      LumaraTherapeuticPresenceData.responseMatrix;

  /// Generate a therapeutic response based on emotion, intensity, and phase
  Map<String, dynamic> generateTherapeuticResponse({
    required TherapeuticEmotionCategory emotionCategory,
    required EmotionIntensity intensity,
    required AtlasPhase atlasPhase,
    Map<String, dynamic>? contextSignals,
    bool isRecurrentTheme = false,
    bool hasMediaIndicators = false,
  }) {
    // Select appropriate tone mode
    final toneMode = _selectToneMode(
      emotionCategory: emotionCategory,
      intensity: intensity,
      atlasPhase: atlasPhase,
      isRecurrentTheme: isRecurrentTheme,
    );

    // Get tone mode data
    final toneData = _getToneModeData(toneMode);
    final phaseData = _getPhaseModifier(atlasPhase);

    // Select closing based on tone mode
    final closings = toneData['closings'] as List<dynamic>? ?? [];
    final closing = closings.isNotEmpty
        ? closings[Random().nextInt(closings.length)] as String
        : 'Take your time with this.';

    // Get phase-specific prompt suggestions
    final promptSuggestions = phaseData['prompt_suggestions'] as List<dynamic>? ?? [];

    // Build response structure
    return {
      'tone_mode': _toneModeToKey(toneMode),
      'style': toneData['style'] as String? ?? 'reflective, grounded',
      'closing': closing,
      'phase': _phaseToKey(atlasPhase),
      'prompt_suggestions': promptSuggestions.cast<String>(),
      'tone_parameters': _responseMatrix['therapeutic_presence']
          ['response_framework']['tone_parameters'],
      'context_echo': _buildContextEcho(
        isRecurrentTheme: isRecurrentTheme,
        contextSignals: contextSignals,
      ),
    };
  }

  /// Select appropriate tone mode based on emotion, intensity, and phase
  TherapeuticToneMode _selectToneMode({
    required TherapeuticEmotionCategory emotionCategory,
    required EmotionIntensity intensity,
    required AtlasPhase atlasPhase,
    required bool isRecurrentTheme,
  }) {
    // High intensity -> prioritize containment
    if (intensity == EmotionIntensity.high) {
      if ([TherapeuticEmotionCategory.grief, TherapeuticEmotionCategory.anger,
            TherapeuticEmotionCategory.burnout, TherapeuticEmotionCategory.fear]
          .contains(emotionCategory)) {
        return TherapeuticToneMode.groundedContainment;
      }
      return TherapeuticToneMode.restorativeNeutrality;
    }

    // Low intensity + integrative phase -> quiet integration
    if (intensity == EmotionIntensity.low &&
        [AtlasPhase.breakthrough, AtlasPhase.consolidation, AtlasPhase.recovery]
            .contains(atlasPhase)) {
      return TherapeuticToneMode.quietIntegration;
    }

    // Phase-based selection
    if (atlasPhase == AtlasPhase.breakthrough ||
        atlasPhase == AtlasPhase.consolidation) {
      return TherapeuticToneMode.quietIntegration;
    }

    if (atlasPhase == AtlasPhase.recovery) {
      return TherapeuticToneMode.restorativeClosure;
    }

    // Emotion-based selection
    switch (emotionCategory) {
      case TherapeuticEmotionCategory.identityViolation:
        return TherapeuticToneMode.reflectiveEcho;
      case TherapeuticEmotionCategory.shame:
        return TherapeuticToneMode.compassionateMirror;
      case TherapeuticEmotionCategory.loneliness:
      case TherapeuticEmotionCategory.grief:
        return TherapeuticToneMode.existentialSteadiness;
      case TherapeuticEmotionCategory.confusion:
        return TherapeuticToneMode.reflectiveEcho;
      case TherapeuticEmotionCategory.guilt:
        return TherapeuticToneMode.cognitiveGrounding;
      case TherapeuticEmotionCategory.anger:
        return TherapeuticToneMode.restorativeNeutrality;
      default:
        return TherapeuticToneMode.reflectiveEcho;
    }
  }

  /// Get tone mode data from response matrix
  Map<String, dynamic> _getToneModeData(TherapeuticToneMode toneMode) {
    final toneModes = _responseMatrix['therapeutic_presence']['tone_modes']
        as Map<String, dynamic>;
    final key = _toneModeToKey(toneMode);
    return toneModes[key] as Map<String, dynamic>? ?? {};
  }

  /// Get phase modifier data
  Map<String, dynamic> _getPhaseModifier(AtlasPhase phase) {
    final phaseModifiers = _responseMatrix['therapeutic_presence']
        ['phase_modifiers'] as Map<String, dynamic>;
    final key = _phaseToKey(phase);
    return phaseModifiers[key] as Map<String, dynamic>? ?? {};
  }

  /// Build context echo for recurrent themes
  String? _buildContextEcho({
    required bool isRecurrentTheme,
    Map<String, dynamic>? contextSignals,
  }) {
    if (isRecurrentTheme) {
      return 'You\'ve written about this before — it sounds like it still lives somewhere close.';
    }

    if (contextSignals != null) {
      final pastPatterns = contextSignals['past_patterns'] as String?;
      if (pastPatterns != null && pastPatterns.isNotEmpty) {
        return 'This connects to patterns you\'ve explored before.';
      }
    }

    return null;
  }

  /// Get system prompt for therapeutic presence mode
  String getSystemPrompt() {
    return LumaraTherapeuticPresenceData.systemPrompt;
  }

  /// Get response framework structure
  List<String> getResponseFramework() {
    final framework = _responseMatrix['therapeutic_presence']
        ['response_framework'] as Map<String, dynamic>;
    final structure = framework['structure'] as List<dynamic>?;
    return structure?.cast<String>() ?? [];
  }

  /// Get tone parameters
  Map<String, double> getToneParameters() {
    final framework = _responseMatrix['therapeutic_presence']
        ['response_framework'] as Map<String, dynamic>;
    final params = framework['tone_parameters'] as Map<String, dynamic>?;
    if (params == null) return {};

    return params.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }


  /// Convert tone mode to JSON key
  String _toneModeToKey(TherapeuticToneMode mode) {
    switch (mode) {
      case TherapeuticToneMode.groundedContainment:
        return 'grounded_containment';
      case TherapeuticToneMode.reflectiveEcho:
        return 'reflective_echo';
      case TherapeuticToneMode.restorativeClosure:
        return 'restorative_closure';
      case TherapeuticToneMode.compassionateMirror:
        return 'compassionate_mirror';
      case TherapeuticToneMode.quietIntegration:
        return 'quiet_integration';
      case TherapeuticToneMode.cognitiveGrounding:
        return 'cognitive_grounding';
      case TherapeuticToneMode.existentialSteadiness:
        return 'existential_steadiness';
      case TherapeuticToneMode.restorativeNeutrality:
        return 'restorative_neutrality';
    }
  }

  /// Convert AtlasPhase to JSON key
  String _phaseToKey(AtlasPhase phase) {
    return phase.name;
  }

  /// Convert string emotion category to enum
  static TherapeuticEmotionCategory? emotionCategoryFromString(String emotion) {
    try {
      switch (emotion.toLowerCase()) {
        case 'identity_violation':
          return TherapeuticEmotionCategory.identityViolation;
        default:
          return TherapeuticEmotionCategory.values.firstWhere(
            (e) => e.name == emotion.toLowerCase(),
          );
      }
    } catch (e) {
      return null;
    }
  }

  /// Convert string intensity to enum
  static EmotionIntensity? intensityFromString(String intensity) {
    try {
      return EmotionIntensity.values.firstWhere(
        (e) => e.name == intensity.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}


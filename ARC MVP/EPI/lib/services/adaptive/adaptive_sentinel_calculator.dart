import 'dart:math' as math;
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/sentinel/sentinel_config.dart';

/// Emotional concentration calculator
class EmotionalConcentrationCalculator {
  // Semantic families for clustering detection
  static final Map<String, List<String>> EMOTION_FAMILIES = {
    'fear': [
      'afraid', 'scared', 'terrified', 'anxious', 'worried',
      'nervous', 'panicked', 'frightened', 'terror', 'dread'
    ],
    'anger': [
      'angry', 'furious', 'mad', 'irritated', 'frustrated',
      'rage', 'enraged', 'livid', 'annoyed', 'hostile'
    ],
    'sadness': [
      'sad', 'depressed', 'miserable', 'down', 'hopeless',
      'devastated', 'heartbroken', 'dejected', 'gloomy', 'melancholy'
    ],
    'joy': [
      'happy', 'joyful', 'excited', 'elated', 'thrilled',
      'delighted', 'cheerful', 'ecstatic', 'content', 'pleased'
    ],
    'disgust': [
      'disgusted', 'revolted', 'repulsed', 'sickened', 'nauseated'
    ],
    'surprise': [
      'surprised', 'shocked', 'astonished', 'amazed', 'startled',
      'stunned', 'astounded'
    ],
    'shame': [
      'ashamed', 'embarrassed', 'humiliated', 'guilty', 'mortified'
    ],
  };

  /// Calculate emotional concentration score
  double calculateConcentration(
    Map<String, double> emotionalTerms,
    SentinelConfig config,
  ) {
    if (emotionalTerms.isEmpty) return 0.0;

    // Group terms by emotion family
    final Map<String, List<MapEntry<String, double>>> familyGroups = {};

    for (final entry in emotionalTerms.entries) {
      final term = entry.key.toLowerCase();

      for (final family in EMOTION_FAMILIES.entries) {
        if (family.value.contains(term)) {
          familyGroups.putIfAbsent(family.key, () => []);
          familyGroups[family.key]!.add(entry);
          break;
        }
      }
    }

    // Calculate concentration score
    double maxConcentration = 0.0;

    for (final family in familyGroups.entries) {
      if (family.value.length >= 2) {
        // Multiple terms from same family = concentration
        final avgIntensity = family.value
            .map((e) => e.value)
            .reduce((a, b) => a + b) /
            family.value.length;

        // Weight by number of terms and intensity
        final concentration = (family.value.length / emotionalTerms.length) *
            avgIntensity;

        if (concentration > maxConcentration) {
          maxConcentration = concentration;
        }
      }
    }

    return maxConcentration.clamp(0.0, 1.0);
  }
}

/// Explicit emotion detector
class ExplicitEmotionDetector {
  static final List<RegExp> EXPLICIT_PATTERNS = [
    RegExp(r'\bi\s+feel\s+(\w+)', caseSensitive: false),
    RegExp(r'\bi\s+am\s+(\w+)', caseSensitive: false),
    RegExp(r"\bi'm\s+(\w+)", caseSensitive: false),
    RegExp(r"\bi'm\s+so\s+(\w+)", caseSensitive: false),
    RegExp(r"\bi\s+can't\s+(handle|deal|cope)", caseSensitive: false),
    RegExp(r"\bi'm\s+feeling\s+(\w+)", caseSensitive: false),
  ];

  /// Calculate explicit emotion multiplier
  double calculateMultiplier(
    String text,
    SentinelConfig config,
  ) {
    double multiplier = config.explicitEmotionMultiplierMin;
    int matchCount = 0;

    for (final pattern in EXPLICIT_PATTERNS) {
      if (pattern.hasMatch(text)) {
        matchCount++;
      }
    }

    if (matchCount > 0) {
      // Scale multiplier based on number of explicit statements
      final increment = (config.explicitEmotionMultiplierMax -
              config.explicitEmotionMultiplierMin) /
          3;

      multiplier = config.explicitEmotionMultiplierMin +
          (increment * matchCount.clamp(0, 3));
    }

    return multiplier.clamp(
      config.explicitEmotionMultiplierMin,
      config.explicitEmotionMultiplierMax,
    );
  }
}

/// Adaptive word count normalizer
class AdaptiveNormalizer {
  /// Normalize score by word count
  double normalize(
    double rawScore,
    int wordCount,
    SentinelConfig config,
  ) {
    final effectiveCount = math.max(wordCount, config.normalizationFloor);

    switch (config.normalizationMethod) {
      case WordCountNormalization.linear:
        return rawScore / effectiveCount;

      case WordCountNormalization.sqrt:
        return rawScore / math.sqrt(effectiveCount);

      case WordCountNormalization.log:
        return rawScore / math.log(effectiveCount + 1); // +1 to avoid log(0)
    }
  }
}

/// Adaptive Sentinel calculator
class AdaptiveSentinelCalculator {
  final SentinelConfig config;
  final EmotionalConcentrationCalculator concentrationCalc;
  final ExplicitEmotionDetector explicitDetector;
  final AdaptiveNormalizer normalizer;

  AdaptiveSentinelCalculator(this.config)
      : concentrationCalc = EmotionalConcentrationCalculator(),
        explicitDetector = ExplicitEmotionDetector(),
        normalizer = AdaptiveNormalizer();

  /// Calculate emotional density for a journal entry
  double calculateEmotionalDensity(JournalEntry entry) {
    // Extract emotional terms and intensities
    final emotionalTerms = _extractEmotionalTerms(entry.content);

    // Calculate base components
    final emotionalIntensity = _calculateEmotionalIntensity(emotionalTerms);
    final emotionalDiversity = _calculateEmotionalDiversity(emotionalTerms);
    final thematicCoherence = _calculateThematicCoherence(entry.content);
    final temporalDynamics = _calculateTemporalDynamics(entry);

    // NEW: Calculate emotional concentration
    final emotionalConcentration = concentrationCalc.calculateConcentration(
      emotionalTerms,
      config,
    );

    // NEW: Detect explicit emotion statements
    final explicitMultiplier = explicitDetector.calculateMultiplier(
      entry.content,
      config,
    );

    // Weighted combination
    final rawScore = (emotionalIntensity * config.emotionalIntensityWeight) +
        (emotionalDiversity * config.emotionalDiversityWeight) +
        (thematicCoherence * config.thematicCoherenceWeight) +
        (temporalDynamics * config.temporalDynamicsWeight) +
        (emotionalConcentration * config.emotionalConcentrationWeight);

    // Apply explicit emotion multiplier
    final adjustedScore = rawScore * explicitMultiplier;

    // Normalize by word count
    final wordCount = entry.content.split(RegExp(r'\s+')).length;
    final normalizedScore = normalizer.normalize(adjustedScore, wordCount, config);

    return normalizedScore.clamp(0.0, 1.0);
  }

  /// Extract emotional terms from text
  Map<String, double> _extractEmotionalTerms(String text) {
    // TODO: Integrate with existing emotion extraction
    // Placeholder implementation
    final lowerText = text.toLowerCase();
    final terms = <String, double>{};

    // Simple keyword matching for now
    final allEmotions = EmotionalConcentrationCalculator.EMOTION_FAMILIES.values
        .expand((list) => list)
        .toList();

    for (final emotion in allEmotions) {
      if (lowerText.contains(emotion)) {
        terms[emotion] = 1.0; // Default intensity
      }
    }

    return terms;
  }

  /// Calculate emotional intensity
  double _calculateEmotionalIntensity(Map<String, double> terms) {
    if (terms.isEmpty) return 0.0;
    return terms.values.reduce((a, b) => a + b) / terms.length;
  }

  /// Calculate emotional diversity
  double _calculateEmotionalDiversity(Map<String, double> terms) {
    if (terms.isEmpty) return 0.0;
    // Diversity = number of unique emotion families represented
    final families = <String>{};
    for (final term in terms.keys) {
      for (final family in EmotionalConcentrationCalculator.EMOTION_FAMILIES.entries) {
        if (family.value.contains(term.toLowerCase())) {
          families.add(family.key);
          break;
        }
      }
    }
    return (families.length / EmotionalConcentrationCalculator.EMOTION_FAMILIES.length)
        .clamp(0.0, 1.0);
  }

  /// Calculate thematic coherence
  double _calculateThematicCoherence(String text) {
    // TODO: Implement thematic coherence calculation
    // Placeholder: return moderate coherence
    return 0.5;
  }

  /// Calculate temporal dynamics
  double _calculateTemporalDynamics(JournalEntry entry) {
    // TODO: Implement temporal dynamics calculation
    // Requires access to prior entries
    // Placeholder: return moderate dynamics
    return 0.5;
  }
}


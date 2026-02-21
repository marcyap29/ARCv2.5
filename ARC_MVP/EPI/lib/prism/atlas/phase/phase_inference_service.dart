import 'package:my_app/prism/atlas/phase/phase_scoring.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Current version of the phase inference pipeline
/// Increment this when the inference algorithm changes
const int CURRENT_PHASE_INFERENCE_VERSION = 1;

/// Result of phase inference
class PhaseInferenceResult {
  final String phase;
  final double confidence;

  const PhaseInferenceResult({
    required this.phase,
    required this.confidence,
  });
}

/// Phase inference service that provides pure inference ignoring hashtags and legacy tags
/// 
/// This service is the authoritative source for phase detection. It:
/// - Ignores inline #Phase hashtags in content
/// - Ignores legacyPhaseTag field
/// - Uses only content analysis (emotion, reason, text, keywords)
/// - Returns phase and confidence score
class PhaseInferenceService {
  /// Infer phase for an entry based on content analysis
  /// 
  /// This method ignores hashtags and legacy phase tags, using only:
  /// - Entry content (with hashtags stripped for analysis)
  /// - Emotion and emotion reason
  /// - Selected keywords
  /// 
  /// Returns the detected phase and confidence score (0.0-1.0)
  static Future<PhaseInferenceResult> inferPhaseForEntry({
    required String entryContent,
    required String userId,
    required DateTime createdAt,
    required List<JournalEntry> recentEntries,
    String? emotion,
    String? emotionReason,
    List<String>? selectedKeywords,
  }) async {
    // Strip phase hashtags from content for analysis
    final cleanedContent = _stripPhaseHashtags(entryContent);
    
    // Use PhaseScoring to get probability scores
    final phaseScores = PhaseScoring.score(
      emotion: emotion ?? '',
      reason: emotionReason ?? '',
      text: cleanedContent,
      selectedKeywords: selectedKeywords,
    );
    
    // Get the highest scoring phase
    final bestPhase = PhaseScoring.getHighestScoringPhase(phaseScores);
    final bestScore = phaseScores[bestPhase] ?? 0.0;
    
    // Confidence is the best score, normalized to 0.0-1.0
    final confidence = bestScore.clamp(0.0, 1.0);
    
    return PhaseInferenceResult(
      phase: bestPhase,
      confidence: confidence,
    );
  }

  /// Strip phase hashtags from content
  /// Removes hashtags like #discovery, #expansion, etc. from text
  static String _stripPhaseHashtags(String content) {
    // Pattern to match phase hashtags (case-insensitive)
    final phaseHashtagPattern = RegExp(
      r'#(discovery|expansion|transition|consolidation|recovery|breakthrough)\b',
      caseSensitive: false,
    );
    
    // Remove all phase hashtags
    return content.replaceAll(phaseHashtagPattern, '').trim();
  }

  /// Infer phase for an entry (simplified version without recent entries context)
  /// Useful for single-entry inference
  static Future<PhaseInferenceResult> inferPhaseForEntrySimple({
    required String entryContent,
    String? emotion,
    String? emotionReason,
    List<String>? selectedKeywords,
  }) async {
    return inferPhaseForEntry(
      entryContent: entryContent,
      userId: '', // Not needed for simple inference
      createdAt: DateTime.now(),
      recentEntries: [],
      emotion: emotion,
      emotionReason: emotionReason,
      selectedKeywords: selectedKeywords,
    );
  }
}


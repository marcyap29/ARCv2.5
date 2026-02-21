import '../models/reflective_entry_data.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import '../../prism/extractors/sentinel_risk_detector.dart';
import '../../prism/extractors/enhanced_keyword_extractor.dart';

/// Service for analyzing draft journal entries through RIVET and SENTINEL
class DraftAnalysisService {
  static const double _draftConfidence = 0.6; // Lower confidence for drafts

  /// Process a draft entry through RIVET
  static RivetEvent processDraftForRivet({
    required DateTime timestamp,
    required List<String> keywords,
    required String predPhase,
    required String refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent.fromDraftEntry(
      date: timestamp,
      keywords: keywords.toSet(),
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: tolerance,
    );
  }

  /// Process a draft entry through SENTINEL
  static ReflectiveEntryData processDraftForSentinel({
    required DateTime timestamp,
    required List<String> keywords,
    required String phase,
    String? mood,
    String? context,
    Map<String, dynamic> metadata = const {},
  }) {
    return ReflectiveEntryData.fromDraftEntry(
      timestamp: timestamp,
      keywords: keywords,
      phase: phase,
      mood: mood,
      context: context,
      confidence: _draftConfidence,
      metadata: metadata,
    );
  }

  /// Extract keywords from draft content using enhanced keyword extractor
  static List<String> extractKeywordsFromDraft(String content) {
    final response = EnhancedKeywordExtractor.extractKeywords(
      entryText: content,
      currentPhase: 'Transition', // Default phase for drafts
    );
    return response.chips;
  }

  /// Infer phase from draft content and context
  static String inferPhaseFromDraft({
    required String content,
    required List<String> keywords,
    String? previousPhase,
    Map<String, dynamic> context = const {},
  }) {
    // Simple phase inference based on keywords and content patterns
    // This could be enhanced with more sophisticated analysis
    
    final negativeKeywords = keywords.where((kw) => 
      (EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0) > 0.7
    ).length;
    
    final positiveKeywords = keywords.where((kw) => 
      (EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0) < 0.3
    ).length;

    // If mostly negative keywords, likely in a difficult phase
    if (negativeKeywords > positiveKeywords * 2) {
      return 'Recovery'; // Most vulnerable phase
    }
    
    // If mostly positive keywords, likely in a growth phase
    if (positiveKeywords > negativeKeywords * 2) {
      return 'Breakthrough'; // Most positive phase
    }
    
    // If mixed or neutral, maintain previous phase or default to Transition
    return previousPhase ?? 'Transition';
  }

  /// Analyze multiple drafts for patterns
  static Future<SentinelAnalysis> analyzeDraftPatterns({
    required List<Map<String, dynamic>> drafts,
    required TimeWindow timeWindow,
    SentinelConfig config = SentinelConfig.defaultConfig,
  }) async {
    final reflectiveEntries = <ReflectiveEntryData>[];

    for (final draft in drafts) {
      final content = draft['content'] as String? ?? '';
      final timestamp = DateTime.parse(draft['timestamp'] as String);
      final keywords = extractKeywordsFromDraft(content);
      final phase = inferPhaseFromDraft(
        content: content,
        keywords: keywords,
        previousPhase: draft['phase'] as String?,
        context: draft['context'] as Map<String, dynamic>? ?? {},
      );

      final entry = processDraftForSentinel(
        timestamp: timestamp,
        keywords: keywords,
        phase: phase,
        mood: draft['mood'] as String?,
        context: 'draft:${draft['id']}',
        metadata: {
          'draft_id': draft['id'],
          'word_count': content.split(' ').length,
          'character_count': content.length,
        },
      );

      reflectiveEntries.add(entry);
    }

    return SentinelRiskDetector.analyzeRisk(
      entries: reflectiveEntries,
      timeWindow: timeWindow,
      config: config,
    );
  }

  /// Get draft confidence score based on content quality
  static double calculateDraftConfidence({
    required String content,
    required List<String> keywords,
    required DateTime timestamp,
  }) {
    double confidence = _draftConfidence;

    // Adjust based on content length
    final wordCount = content.split(' ').length;
    if (wordCount < 10) {
      confidence *= 0.5; // Very short content
    } else if (wordCount > 100) {
      confidence *= 1.1; // Substantial content
    }

    // Adjust based on keyword density
    final keywordDensity = keywords.length / wordCount;
    if (keywordDensity > 0.1) {
      confidence *= 1.1; // High keyword density
    } else if (keywordDensity < 0.02) {
      confidence *= 0.8; // Low keyword density
    }

    // Adjust based on recency (newer drafts are more relevant)
    final daysSinceCreation = DateTime.now().difference(timestamp).inDays;
    if (daysSinceCreation < 1) {
      confidence *= 1.1; // Very recent
    } else if (daysSinceCreation > 7) {
      confidence *= 0.9; // Older draft
    }

    return confidence.clamp(0.1, 1.0);
  }
}

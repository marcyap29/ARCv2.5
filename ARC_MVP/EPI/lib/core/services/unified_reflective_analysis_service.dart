import '../models/reflective_entry_data.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import '../../prism/extractors/sentinel_risk_detector.dart';

/// Unified service for analyzing all reflective inputs (journal entries, drafts, chats)
/// through RIVET and SENTINEL systems
class UnifiedReflectiveAnalysisService {
  /// Analyze all reflective sources together
  static Future<UnifiedAnalysisResult> analyzeAllSources({
    required List<ReflectiveEntryData> journalEntries,
    required List<ReflectiveEntryData> draftEntries,
    required List<ReflectiveEntryData> chatEntries,
    required TimeWindow timeWindow,
    SentinelConfig config = SentinelConfig.defaultConfig,
  }) async {
    // Combine all entries
    final allEntries = <ReflectiveEntryData>[
      ...journalEntries,
      ...draftEntries,
      ...chatEntries,
    ];

    // Sort by timestamp
    allEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Run SENTINEL analysis on combined data
    final sentinelAnalysis = SentinelRiskDetector.analyzeRisk(
      entries: allEntries,
      timeWindow: timeWindow,
      config: config,
    );

    // Generate source-specific insights
    final sourceInsights = _generateSourceInsights(
      journalEntries: journalEntries,
      draftEntries: draftEntries,
      chatEntries: chatEntries,
    );

    // Generate unified recommendations
    final recommendations = _generateUnifiedRecommendations(
      sentinelAnalysis: sentinelAnalysis,
      sourceInsights: sourceInsights,
    );

    return UnifiedAnalysisResult(
      sentinelAnalysis: sentinelAnalysis,
      sourceInsights: sourceInsights,
      recommendations: recommendations,
      totalEntries: allEntries.length,
      journalCount: journalEntries.length,
      draftCount: draftEntries.length,
      chatCount: chatEntries.length,
    );
  }

  /// Generate insights specific to each source type
  static Map<String, dynamic> _generateSourceInsights({
    required List<ReflectiveEntryData> journalEntries,
    required List<ReflectiveEntryData> draftEntries,
    required List<ReflectiveEntryData> chatEntries,
  }) {
    final insights = <String, dynamic>{};

    // Journal entry insights
    if (journalEntries.isNotEmpty) {
      insights['journal'] = {
        'count': journalEntries.length,
        'avg_confidence': journalEntries.fold<double>(0, (sum, e) => sum + e.effectiveConfidence) / journalEntries.length,
        'high_confidence_ratio': journalEntries.where((e) => e.isHighConfidence).length / journalEntries.length,
        'phase_distribution': _getPhaseDistribution(journalEntries),
        'keyword_density': _getKeywordDensity(journalEntries),
      };
    }

    // Draft entry insights
    if (draftEntries.isNotEmpty) {
      insights['drafts'] = {
        'count': draftEntries.length,
        'avg_confidence': draftEntries.fold<double>(0, (sum, e) => sum + e.effectiveConfidence) / draftEntries.length,
        'completion_rate': _getDraftCompletionRate(draftEntries),
        'phase_distribution': _getPhaseDistribution(draftEntries),
        'keyword_density': _getKeywordDensity(draftEntries),
      };
    }

    // Chat entry insights
    if (chatEntries.isNotEmpty) {
      insights['chats'] = {
        'count': chatEntries.length,
        'avg_confidence': chatEntries.fold<double>(0, (sum, e) => sum + e.effectiveConfidence) / chatEntries.length,
        'conversation_quality': _getConversationQuality(chatEntries),
        'phase_distribution': _getPhaseDistribution(chatEntries),
        'keyword_density': _getKeywordDensity(chatEntries),
      };
    }

    return insights;
  }

  /// Get phase distribution for entries
  static Map<String, int> _getPhaseDistribution(List<ReflectiveEntryData> entries) {
    final distribution = <String, int>{};
    for (final entry in entries) {
      distribution[entry.phase] = (distribution[entry.phase] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get keyword density for entries
  static double _getKeywordDensity(List<ReflectiveEntryData> entries) {
    if (entries.isEmpty) return 0.0;
    
    final totalKeywords = entries.fold<int>(0, (sum, e) => sum + e.keywords.length);
    final totalWords = entries.fold<int>(0, (sum, e) => 
      sum + (e.metadata['word_count'] as int? ?? 0)
    );
    
    return totalWords > 0 ? totalKeywords / totalWords : 0.0;
  }

  /// Get draft completion rate
  static double _getDraftCompletionRate(List<ReflectiveEntryData> draftEntries) {
    if (draftEntries.isEmpty) return 0.0;
    
    final completedDrafts = draftEntries.where((e) => 
      (e.metadata['word_count'] as int? ?? 0) > 50
    ).length;
    
    return completedDrafts / draftEntries.length;
  }

  /// Get conversation quality score
  static double _getConversationQuality(List<ReflectiveEntryData> chatEntries) {
    if (chatEntries.isEmpty) return 0.0;
    
    final userEntries = chatEntries.where((e) => 
      e.metadata['role'] == 'MessageRole.user'
    ).length;
    
    final assistantEntries = chatEntries.where((e) => 
      e.metadata['role'] == 'MessageRole.assistant'
    ).length;
    
    // Quality based on balanced conversation
    final totalEntries = userEntries + assistantEntries;
    if (totalEntries == 0) return 0.0;
    
    final balance = 1.0 - (userEntries - assistantEntries).abs() / totalEntries;
    return balance;
  }

  /// Generate unified recommendations
  static List<String> _generateUnifiedRecommendations({
    required SentinelAnalysis sentinelAnalysis,
    required Map<String, dynamic> sourceInsights,
  }) {
    final recommendations = <String>[];

    // Add SENTINEL recommendations
    recommendations.addAll(sentinelAnalysis.recommendations);

    // Add source-specific recommendations
    if (sourceInsights.containsKey('drafts')) {
      final draftInsights = sourceInsights['drafts'] as Map<String, dynamic>;
      final completionRate = draftInsights['completion_rate'] as double;
      
      if (completionRate < 0.3) {
        recommendations.add('📝 Consider completing more draft entries to improve reflective analysis');
      }
    }

    if (sourceInsights.containsKey('chats')) {
      final chatInsights = sourceInsights['chats'] as Map<String, dynamic>;
      final conversationQuality = chatInsights['conversation_quality'] as double;
      
      if (conversationQuality < 0.5) {
        recommendations.add('💬 Chat conversations could benefit from more balanced interaction');
      }
    }

    // Add data quality recommendations
    final journalInsights = sourceInsights['journal'] as Map<String, dynamic>?;
    if (journalInsights != null) {
      final highConfidenceRatio = journalInsights['high_confidence_ratio'] as double;
      
      if (highConfidenceRatio < 0.7) {
        recommendations.add('📊 Consider adding more detailed journal entries for better analysis');
      }
    }

    return recommendations.toSet().toList(); // Remove duplicates
  }

  /// Create RIVET events from all sources
  static List<RivetEvent> createRivetEventsFromAllSources({
    required List<ReflectiveEntryData> journalEntries,
    required List<ReflectiveEntryData> draftEntries,
    required List<ReflectiveEntryData> chatEntries,
    required String currentPhase,
  }) {
    final events = <RivetEvent>[];

    // Create events from journal entries
    for (final entry in journalEntries) {
      final event = RivetEvent.fromJournalEntry(
        date: entry.timestamp,
        keywords: entry.keywords.toSet(),
        predPhase: entry.phase,
        refPhase: currentPhase,
      );
      events.add(event);
    }

    // Create events from draft entries
    for (final entry in draftEntries) {
      final event = RivetEvent.fromDraftEntry(
        date: entry.timestamp,
        keywords: entry.keywords.toSet(),
        predPhase: entry.phase,
        refPhase: currentPhase,
      );
      events.add(event);
    }

    // Create events from chat entries (user messages only)
    for (final entry in chatEntries) {
      if (entry.metadata['role'] == 'MessageRole.user') {
        final event = RivetEvent.fromLumaraChat(
          date: entry.timestamp,
          keywords: entry.keywords.toSet(),
          predPhase: entry.phase,
          refPhase: currentPhase,
        );
        events.add(event);
      }
    }

    return events;
  }
}

/// Result of unified analysis across all reflective sources
class UnifiedAnalysisResult {
  final SentinelAnalysis sentinelAnalysis;
  final Map<String, dynamic> sourceInsights;
  final List<String> recommendations;
  final int totalEntries;
  final int journalCount;
  final int draftCount;
  final int chatCount;

  const UnifiedAnalysisResult({
    required this.sentinelAnalysis,
    required this.sourceInsights,
    required this.recommendations,
    required this.totalEntries,
    required this.journalCount,
    required this.draftCount,
    required this.chatCount,
  });

  /// Get summary of analysis
  String get summary {
    final buffer = StringBuffer();
    
    buffer.writeln('Unified Reflective Analysis Summary');
    buffer.writeln('=====================================');
    buffer.writeln();
    
    buffer.writeln('Data Sources:');
    buffer.writeln('  • Journal Entries: $journalCount');
    buffer.writeln('  • Draft Entries: $draftCount');
    buffer.writeln('  • Chat Entries: $chatCount');
    buffer.writeln('  • Total Entries: $totalEntries');
    buffer.writeln();
    
    buffer.writeln('Risk Assessment:');
    buffer.writeln('  • Risk Level: ${sentinelAnalysis.riskLevel.name.toUpperCase()}');
    buffer.writeln('  • Risk Score: ${sentinelAnalysis.riskScore.toStringAsFixed(2)}');
    buffer.writeln();
    
    if (recommendations.isNotEmpty) {
      buffer.writeln('Recommendations:');
      for (final rec in recommendations) {
        buffer.writeln('  • $rec');
      }
    }
    
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'sentinel_analysis': sentinelAnalysis.toJson(),
      'source_insights': sourceInsights,
      'recommendations': recommendations,
      'total_entries': totalEntries,
      'journal_count': journalCount,
      'draft_count': draftCount,
      'chat_count': chatCount,
    };
  }
}

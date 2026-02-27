import 'package:my_app/arc/chat/chat/chat_repo.dart';
import '../../insights/models/insight_card.dart';
import '../../insights/insight_service.dart';
import 'chat_metrics_service.dart';

/// Enhanced insight service that combines journal and chat insights
class EnhancedInsightService extends InsightService {
  final ChatMetricsService _chatMetricsService;
  final ChatRepo _chatRepo;

  EnhancedInsightService({
    required super.journalRepository,
    required ChatRepo chatRepo,
    super.rivetProvider,
    required super.userId,
  }) : _chatRepo = chatRepo,
       _chatMetricsService = ChatMetricsService(chatRepo: chatRepo);

  /// Generate combined insights from journals and chat sessions
  @override
  Future<List<InsightCard>> generateInsights({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      print('DEBUG: EnhancedInsightService.generateInsights called for period $periodStart to $periodEnd');

      // Generate journal-based insights (from parent)
      final journalInsights = await super.generateInsights(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      print('DEBUG: Generated ${journalInsights.length} journal insights');

      // Generate chat-based insights
      final chatInsights = await _chatMetricsService.generateChatInsights(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      print('DEBUG: Generated ${chatInsights.length} chat insights');

      // Combine and prioritize insights
      final combinedInsights = _combineAndPrioritizeInsights(
        journalInsights,
        chatInsights,
        periodStart,
        periodEnd,
      );

      print('DEBUG: Final combined insights: ${combinedInsights.length}');
      return combinedInsights;
    } catch (e) {
      print('ERROR: Failed to generate enhanced insights: $e');
      // Fallback to journal-only insights
      return await super.generateInsights(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    }
  }

  /// Get comprehensive metrics including both journal and chat data
  Future<EnhancedMetrics> getEnhancedMetrics({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // Get chat metrics
    final chatMetrics = await _chatMetricsService.getChatMetrics(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    // Get journal entry count for the period
    final allEntries = journalRepository.getAllJournalEntriesSync();
    final journalCount = allEntries.where((entry) {
      return entry.createdAt.isAfter(periodStart) &&
             entry.createdAt.isBefore(periodEnd);
    }).length;

    return EnhancedMetrics(
      periodStart: periodStart,
      periodEnd: periodEnd,
      journalEntries: journalCount,
      chatMetrics: chatMetrics,
      combinedActivityScore: _calculateCombinedActivityScore(journalCount, chatMetrics),
    );
  }

  /// Create MIRA-compatible insight records
  Future<List<Map<String, dynamic>>> generateMiraInsightNodes({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final insights = await generateInsights(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    return insights.map((insight) => _insightToMiraNode(insight)).toList();
  }

  /// Combine and prioritize insights from different sources
  List<InsightCard> _combineAndPrioritizeInsights(
    List<InsightCard> journalInsights,
    List<InsightCard> chatInsights,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final combined = <InsightCard>[];

    // Add all journal insights (higher priority for core functionality)
    combined.addAll(journalInsights);

    // Add chat insights, avoiding duplicates
    for (final chatInsight in chatInsights) {
      if (!_isDuplicateTheme(chatInsight, combined)) {
        combined.add(chatInsight);
      }
    }

    // Sort by creation date (most recent first)
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Limit to reasonable number to avoid overwhelming UI
    return combined.take(8).toList();
  }

  /// Check if a chat insight duplicates an existing theme
  bool _isDuplicateTheme(InsightCard chatInsight, List<InsightCard> existing) {
    return existing.any((existing) {
      return existing.badges.any((badge) => chatInsight.badges.contains(badge)) ||
             existing.title.toLowerCase().contains(chatInsight.title.toLowerCase());
    });
  }

  /// Calculate combined activity score
  double _calculateCombinedActivityScore(int journalCount, ChatMetrics chatMetrics) {
    // Weight: 60% journal activity, 40% chat activity
    final journalScore = (journalCount / 10.0).clamp(0.0, 1.0); // Normalize to 10 entries = max
    final chatScore = chatMetrics.engagementScore.clamp(0.0, 1.0);

    return (journalScore * 0.6) + (chatScore * 0.4);
  }

  /// Convert InsightCard to MIRA node format
  Map<String, dynamic> _insightToMiraNode(InsightCard insight) {
    return {
      'id': 'insight:${insight.id}',
      'type': 'insight',
      'timestamp': insight.createdAt.toUtc().toIso8601String(),
      'schema_version': 'node.v1',
      'content_summary': insight.title,
      'data': {
        'title': insight.title,
        'body': insight.body,
        'badges': insight.badges,
        'rule_id': insight.ruleId,
        'period_start': insight.periodStart.toIso8601String(),
        'period_end': insight.periodEnd.toIso8601String(),
        'sources': insight.sources,
        'deeplink': insight.deeplink,
      },
    };
  }
}

/// Enhanced metrics combining journal and chat data
class EnhancedMetrics {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int journalEntries;
  final ChatMetrics chatMetrics;
  final double combinedActivityScore;

  const EnhancedMetrics({
    required this.periodStart,
    required this.periodEnd,
    required this.journalEntries,
    required this.chatMetrics,
    required this.combinedActivityScore,
  });

  Map<String, dynamic> toJson() => {
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'journalEntries': journalEntries,
    'chatMetrics': chatMetrics.toJson(),
    'combinedActivityScore': combinedActivityScore,
  };

  /// Generate summary for display
  String getSummary() {
    final journalText = journalEntries == 1 ? '1 journal entry' : '$journalEntries journal entries';
    final chatText = chatMetrics.sessionCount == 1 ? '1 chat session' : '${chatMetrics.sessionCount} chat sessions';
    final activityLevel = combinedActivityScore > 0.7 ? 'High' :
                         combinedActivityScore > 0.4 ? 'Moderate' : 'Light';

    return '$journalText, $chatText. Activity level: $activityLevel';
  }
}
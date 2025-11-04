import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import '../../insights/models/insight_card.dart';
import '../core/schema.dart';
import '../ingest/chat_ingest.dart';
import '../graph/chat_graph_builder.dart';

/// Service for generating chat-based insights and metrics
class ChatMetricsService {
  final ChatRepo _chatRepo;

  ChatMetricsService({required ChatRepo chatRepo}) : _chatRepo = chatRepo;

  /// Generate insight cards based on chat activity
  Future<List<InsightCard>> generateChatInsights({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final sessions = await _getChatSessionsInPeriod(periodStart, periodEnd);
    final insights = <InsightCard>[];

    // Generate different types of chat insights
    insights.addAll(await _generateActivityInsights(sessions, periodStart, periodEnd));
    insights.addAll(await _generateTopicInsights(sessions, periodStart, periodEnd));
    insights.addAll(await _generateEngagementInsights(sessions, periodStart, periodEnd));

    return insights;
  }

  /// Get chat metrics for MIRA analysis
  Future<ChatMetrics> getChatMetrics({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final sessions = await _getChatSessionsInPeriod(periodStart, periodEnd);
    final allMessages = <ChatMessage>[];

    for (final session in sessions) {
      final messages = await _chatRepo.getMessages(session.id, lazy: false);
      allMessages.addAll(messages);
    }

    return ChatMetrics(
      periodStart: periodStart,
      periodEnd: periodEnd,
      sessionCount: sessions.length,
      messageCount: allMessages.length,
      averageMessagesPerSession: sessions.isEmpty ? 0.0 : allMessages.length / sessions.length,
      topTags: _extractTopTags(sessions),
      activityPatterns: _analyzeActivityPatterns(sessions, allMessages),
      engagementScore: _calculateEngagementScore(sessions, allMessages),
    );
  }

  /// Create MIRA graph fragment from chat metrics
  Future<GraphFragment> createMetricsGraphFragment({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final sessions = await _getChatSessionsInPeriod(periodStart, periodEnd);
    final messagesBySession = <String, List<ChatMessage>>{};

    for (final session in sessions) {
      final messages = await _chatRepo.getMessages(session.id, lazy: false);
      messagesBySession[session.id] = messages;
    }

    return ChatGraphBuilder.fromSessions(sessions, messagesBySession);
  }

  /// Get chat sessions within a specific period
  Future<List<ChatSession>> _getChatSessionsInPeriod(
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final allSessions = await _chatRepo.listAll(includeArchived: true);
    return allSessions.where((session) {
      return session.createdAt.isAfter(periodStart) &&
             session.createdAt.isBefore(periodEnd);
    }).toList();
  }

  /// Generate activity-based insights
  Future<List<InsightCard>> _generateActivityInsights(
    List<ChatSession> sessions,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    if (sessions.isEmpty) return [];

    final insights = <InsightCard>[];

    // Chat frequency insight
    if (sessions.length >= 5) {
      insights.add(InsightCard(
        id: 'chat_activity_${periodStart.millisecondsSinceEpoch}',
        title: 'Active Chat Period',
        body: 'You had ${sessions.length} chat sessions this period, showing consistent engagement with AI assistance.',
        badges: const ['activity', 'engagement'],
        periodStart: periodStart,
        periodEnd: periodEnd,
        sources: {
          'chat_sessions': sessions.map((s) => s.id).toList(),
          'session_count': sessions.length,
        },
        ruleId: 'chat_activity_high',
        createdAt: DateTime.now(),
      ));
    }

    return insights;
  }

  /// Generate topic-based insights
  Future<List<InsightCard>> _generateTopicInsights(
    List<ChatSession> sessions,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    if (sessions.isEmpty) return [];

    final insights = <InsightCard>[];
    final topTags = _extractTopTags(sessions);

    if (topTags.isNotEmpty) {
      final topTag = topTags.entries.first;
      insights.add(InsightCard(
        id: 'chat_topics_${periodStart.millisecondsSinceEpoch}',
        title: 'Key Discussion Theme',
        body: 'Your most discussed topic was "${topTag.key}" appearing in ${topTag.value} conversations.',
        badges: const ['topics', 'themes'],
        periodStart: periodStart,
        periodEnd: periodEnd,
        sources: {
          'top_tag': topTag.key,
          'tag_frequency': topTag.value,
          'all_tags': topTags,
        },
        ruleId: 'chat_topic_focus',
        createdAt: DateTime.now(),
      ));
    }

    return insights;
  }

  /// Generate engagement-based insights
  Future<List<InsightCard>> _generateEngagementInsights(
    List<ChatSession> sessions,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    if (sessions.isEmpty) return [];

    final insights = <InsightCard>[];
    final avgMessages = sessions.map((s) => s.messageCount).reduce((a, b) => a + b) / sessions.length;

    if (avgMessages >= 10) {
      insights.add(InsightCard(
        id: 'chat_engagement_${periodStart.millisecondsSinceEpoch}',
        title: 'Deep Conversations',
        body: 'Your conversations averaged ${avgMessages.toStringAsFixed(1)} messages, indicating thoughtful exchanges.',
        badges: const ['engagement', 'depth'],
        periodStart: periodStart,
        periodEnd: periodEnd,
        sources: {
          'average_messages': avgMessages,
          'session_count': sessions.length,
        },
        ruleId: 'chat_engagement_high',
        createdAt: DateTime.now(),
      ));
    }

    return insights;
  }

  /// Extract top tags from sessions
  Map<String, int> _extractTopTags(List<ChatSession> sessions) {
    final tagCounts = <String, int>{};
    for (final session in sessions) {
      for (final tag in session.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final sortedEntries = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries.take(5));
  }

  /// Analyze activity patterns
  Map<String, dynamic> _analyzeActivityPatterns(
    List<ChatSession> sessions,
    List<ChatMessage> messages,
  ) {
    final hourCounts = <int, int>{};
    final dayCounts = <String, int>{};

    for (final session in sessions) {
      final hour = session.createdAt.hour;
      final day = _getDayOfWeek(session.createdAt.weekday);

      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    return {
      'peak_hours': hourCounts.entries
          .where((e) => e.value > 0)
          .map((e) => {'hour': e.key, 'count': e.value})
          .toList(),
      'peak_days': dayCounts.entries
          .map((e) => {'day': e.key, 'count': e.value})
          .toList(),
    };
  }

  /// Calculate engagement score
  double _calculateEngagementScore(
    List<ChatSession> sessions,
    List<ChatMessage> messages,
  ) {
    if (sessions.isEmpty) return 0.0;

    final avgMessagesPerSession = messages.length / sessions.length;
    final pinnedRatio = sessions.where((s) => s.isPinned).length / sessions.length;

    // Simple scoring: message depth (40%) + pinned ratio (60%)
    return (avgMessagesPerSession / 20 * 0.4) + (pinnedRatio * 0.6);
  }

  String _getDayOfWeek(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

/// Chat metrics data class
class ChatMetrics {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int sessionCount;
  final int messageCount;
  final double averageMessagesPerSession;
  final Map<String, int> topTags;
  final Map<String, dynamic> activityPatterns;
  final double engagementScore;

  const ChatMetrics({
    required this.periodStart,
    required this.periodEnd,
    required this.sessionCount,
    required this.messageCount,
    required this.averageMessagesPerSession,
    required this.topTags,
    required this.activityPatterns,
    required this.engagementScore,
  });

  Map<String, dynamic> toJson() => {
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'sessionCount': sessionCount,
    'messageCount': messageCount,
    'averageMessagesPerSession': averageMessagesPerSession,
    'topTags': topTags,
    'activityPatterns': activityPatterns,
    'engagementScore': engagementScore,
  };
}
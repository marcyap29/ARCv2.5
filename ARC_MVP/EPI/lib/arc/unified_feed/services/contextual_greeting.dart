/// Contextual Greeting Service
///
/// Generates time-aware, context-sensitive greetings for the unified feed.
/// Takes into account:
/// - Time of day
/// - Day of week
/// - Recent activity patterns
/// - Current phase (if available)
/// - Last conversation recency

import 'package:flutter/foundation.dart';

/// Generates contextual greetings for the unified feed header.
class ContextualGreetingService {
  /// Generate a greeting based on current context.
  ///
  /// [lastEntryAt] - When the user last created/updated an entry
  /// [entryCount] - Total number of entries
  /// [currentPhase] - The user's current ATLAS phase label
  /// [userName] - Optional user name for personalization
  String generateGreeting({
    DateTime? lastEntryAt,
    int entryCount = 0,
    String? currentPhase,
    String? userName,
  }) {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;

    // Time-based base greeting
    final timeGreeting = _getTimeGreeting(hour);

    // Activity context
    final activityContext = _getActivityContext(
      lastEntryAt: lastEntryAt,
      entryCount: entryCount,
      now: now,
    );

    // Phase-aware context
    final phaseContext = _getPhaseContext(currentPhase);

    // Day-of-week context
    final dayContext = _getDayContext(dayOfWeek, hour);

    // Combine into a greeting
    if (userName != null && userName.isNotEmpty) {
      return '$timeGreeting, $userName. $activityContext';
    }

    // Choose a contextual greeting variant
    if (phaseContext != null && activityContext.isNotEmpty) {
      return '$timeGreeting. $activityContext';
    }

    if (dayContext != null) {
      return '$timeGreeting. $dayContext';
    }

    return '$timeGreeting. $activityContext';
  }

  /// Generate a sub-greeting (smaller text below the main greeting).
  String generateSubGreeting({
    DateTime? lastEntryAt,
    int activeConversationCount = 0,
    int todayEntryCount = 0,
  }) {
    if (activeConversationCount > 0) {
      return 'You have an active conversation';
    }

    if (todayEntryCount > 0) {
      final plural = todayEntryCount == 1 ? 'entry' : 'entries';
      return '$todayEntryCount $plural today';
    }

    if (lastEntryAt != null) {
      final diff = DateTime.now().difference(lastEntryAt);
      if (diff.inDays == 0) return 'Welcome back';
      if (diff.inDays == 1) return 'Last entry was yesterday';
      if (diff.inDays < 7) return 'Last entry ${diff.inDays} days ago';
      return 'It\'s been a while';
    }

    return 'Start a conversation or write an entry';
  }

  String _getTimeGreeting(int hour) {
    if (hour < 5) return 'Late night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good evening';
  }

  String _getActivityContext({
    DateTime? lastEntryAt,
    required int entryCount,
    required DateTime now,
  }) {
    if (entryCount == 0) {
      return 'Ready when you are';
    }

    if (lastEntryAt == null) {
      return 'What\'s on your mind?';
    }

    final diff = now.difference(lastEntryAt);

    if (diff.inMinutes < 30) {
      return 'Picking up where we left off';
    }
    if (diff.inHours < 2) {
      return 'Welcome back';
    }
    if (diff.inHours < 12) {
      return 'What\'s on your mind?';
    }
    if (diff.inDays == 0) {
      return 'How has your day been?';
    }
    if (diff.inDays == 1) {
      return 'How are you today?';
    }
    if (diff.inDays < 7) {
      return 'Good to see you';
    }
    return 'Welcome back';
  }

  String? _getPhaseContext(String? phase) {
    if (phase == null) return null;
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 'Exploring new territory';
      case 'expansion':
        return 'Growing and expanding';
      case 'transition':
        return 'Navigating change';
      case 'consolidation':
        return 'Building on foundations';
      case 'recovery':
        return 'Finding your way back';
      case 'breakthrough':
        return 'Breaking through';
      default:
        return null;
    }
  }

  String? _getDayContext(int dayOfWeek, int hour) {
    // Weekend morning
    if ((dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) &&
        hour >= 7 &&
        hour < 12) {
      return 'Enjoy your weekend';
    }
    // Friday evening
    if (dayOfWeek == DateTime.friday && hour >= 17) {
      return 'Happy Friday';
    }
    // Monday morning
    if (dayOfWeek == DateTime.monday && hour >= 6 && hour < 12) {
      return 'Fresh start to the week';
    }
    return null;
  }
}

/// Feed Helpers
///
/// Utility functions for the unified feed system.
/// Includes date formatting, content truncation, type detection,
/// and other shared helpers.

import 'package:flutter/material.dart';
import 'package:my_app/core/constants/phase_colors.dart';
import 'package:my_app/arc/unified_feed/models/entry_state.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Utility class for feed-related helpers.
class FeedHelpers {
  FeedHelpers._(); // Prevent instantiation

  /// Get the icon for a feed entry type.
  static IconData getEntryTypeIcon(FeedEntryType type) {
    switch (type) {
      case FeedEntryType.activeConversation:
        return Icons.chat_bubble;
      case FeedEntryType.savedConversation:
        return Icons.chat_bubble_outline;
      case FeedEntryType.voiceMemo:
        return Icons.mic;
      case FeedEntryType.reflection:
        return Icons.edit_note;
      case FeedEntryType.lumaraInitiative:
        return Icons.auto_awesome;
    }
  }

  /// Get the color accent for a feed entry type.
  static Color getEntryTypeColor(FeedEntryType type) {
    switch (type) {
      case FeedEntryType.activeConversation:
        return const Color(0xFF4F46E5); // Primary indigo
      case FeedEntryType.savedConversation:
        return const Color(0xFF7C3AED); // Purple
      case FeedEntryType.voiceMemo:
        return const Color(0xFF059669); // Emerald
      case FeedEntryType.reflection:
        return const Color(0xFF2563EB); // Blue
      case FeedEntryType.lumaraInitiative:
        return const Color(0xFF9B59B6); // Purple/violet
    }
  }

  /// Phase hashtags added by phase analysis (#discovery, #consolidation, etc.).
  /// Strip these from content when displaying so the phase shows only in the card/header, not in the body.
  static const List<String> _phaseHashtags = [
    '#discovery', '#expansion', '#transition',
    '#consolidation', '#recovery', '#breakthrough',
  ];

  /// Returns content with phase hashtags removed (for display only).
  /// Preserves newlines so paragraph structure is maintained.
  static String contentWithoutPhaseHashtags(String? content) {
    if (content == null || content.isEmpty) return '';
    String out = content;
    for (final tag in _phaseHashtags) {
      final regex = RegExp(RegExp.escape(tag), caseSensitive: false);
      out = out.replaceAll(regex, '').trim();
    }
    // Collapse runs of spaces/tabs on the same line, but preserve newlines
    return out.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim();
  }

  /// Pattern: ## Summary\n\n...\n\n---\n\n<body>
  static final _summaryPattern = RegExp(r'^## Summary\s*\n\n(.+?)\n\n---\n\n', dotAll: true);

  static String? extractSummary(String? content) {
    if (content == null || content.isEmpty) return null;
    final m = _summaryPattern.firstMatch(content);
    return m?.group(1)?.trim();
  }

  static String bodyWithoutSummary(String? content) {
    if (content == null || content.isEmpty) return '';
    final m = _summaryPattern.firstMatch(content);
    if (m == null) return content.trim();
    return content.substring(m.end).trim();
  }

  /// Format the entry creation date for display on the card (e.g. "Mar 15, 2025" or "Today, 2:30 PM").
  static String formatEntryCreationDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = monthNames[date.month - 1];
    if (date.year == now.year) return '$month ${date.day}, $timeStr';
    return '$month ${date.day}, ${date.year}';
  }

  /// Format a date for display in the feed.
  static String formatFeedDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    // Check if it's today
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Check if it's yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    // Within this week
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }

    // Older
    return '${date.month}/${date.day}';
  }

  /// Format a duration for display (for voice memos).
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Truncate text to a maximum length with ellipsis.
  static String truncate(String text, {int maxLength = 150}) {
    if (text.length <= maxLength) return text;
    // Find a natural break point
    final breakIdx = text.lastIndexOf(' ', maxLength - 3);
    if (breakIdx > maxLength ~/ 2) {
      return '${text.substring(0, breakIdx)}...';
    }
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Group feed entries by date for section headers.
  /// Uses [timestamp] field from the new FeedEntry model.
  static Map<String, List<FeedEntry>> groupByDate(List<FeedEntry> entries) {
    final grouped = <String, List<FeedEntry>>{};
    final now = DateTime.now();

    for (final entry in entries) {
      final key = _dateGroupKey(entry.timestamp, now);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(entry);
    }

    return grouped;
  }

  /// Get the date group key for section headers.
  static String _dateGroupKey(DateTime date, DateTime now) {
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    final diff = now.difference(date);
    if (diff.inDays < 7) return 'This Week';
    if (diff.inDays < 30) return 'This Month';
    if (diff.inDays < 365) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return months[date.month - 1];
    }

    return '${date.year}';
  }

  /// Build a date divider widget for the feed.
  static Widget buildDateDivider(String label, {int entryCount = 0}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF2D3748).withOpacity(0.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFFA0AEC0).withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (entryCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($entryCount)',
                    style: TextStyle(
                      color: const Color(0xFFA0AEC0).withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF2D3748).withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Detect if content appears to be a conversation vs. a written entry.
  static bool looksLikeConversation(String content) {
    // Heuristic: conversations tend to be shorter, question-oriented
    if (content.contains('?') && content.length < 500) return true;
    // Multiple short paragraphs
    final paragraphs = content.split('\n\n');
    if (paragraphs.length >= 3 &&
        paragraphs.every((p) => p.length < 200)) {
      return true;
    }
    return false;
  }

  /// Calculate reading time estimate for content.
  static String readingTimeEstimate(String content) {
    final wordCount = content.split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 200).ceil(); // ~200 WPM reading speed
    if (minutes <= 1) return '< 1 min read';
    return '$minutes min read';
  }

  /// Build a FeedEntry from a JournalEntry (e.g. for opening related entries in preview).
  static FeedEntry journalEntryToFeedEntry(JournalEntry entry) {
    final bool isConversation = entry.lumaraBlocks.isNotEmpty;
    final bool isVoiceMemo =
        entry.audioUri != null && entry.audioUri!.isNotEmpty;

    FeedEntryType type;
    if (isVoiceMemo) {
      type = FeedEntryType.voiceMemo;
    } else if (isConversation) {
      type = FeedEntryType.savedConversation;
    } else {
      type = FeedEntryType.reflection;
    }

    final phase = entry.computedPhase;
    final phaseColor = phase != null && phase.isNotEmpty ? PhaseColors.getPhaseColor(phase) : null;

    final themes = <String>[];
    if (entry.metadata != null && entry.metadata!['themes'] != null) {
      final rawThemes = entry.metadata!['themes'];
      if (rawThemes is List) {
        themes.addAll(rawThemes.cast<String>());
      }
    }

    String title = entry.title;
    if (title.isEmpty) {
      final content = entry.content.trim();
      if (content.isEmpty) {
        title = 'Untitled Entry';
      } else {
        final firstLine = content.split('\n').first.trim();
        title = firstLine.length <= 50 ? firstLine : '${firstLine.substring(0, 47)}...';
      }
    }

    return FeedEntry(
      id: 'journal_${entry.id}',
      type: type,
      timestamp: entry.createdAt,
      state: EntryState.saved,
      title: title,
      content: entry.content,
      themes: themes,
      exchangeCount: isConversation ? entry.lumaraBlocks.length : null,
      phase: phase,
      phaseColor: phaseColor,
      mood: entry.emotion ?? entry.mood,
      isPinned: false,
      hasLumaraReflections: entry.lumaraBlocks.isNotEmpty,
      hasMedia: entry.media.isNotEmpty,
      mediaCount: entry.media.length,
      mediaItems: entry.media,
      tags: entry.tags,
      journalEntryId: entry.id,
      audioPath: isVoiceMemo ? entry.audioUri : null,
      metadata: entry.metadata ?? {},
    );
  }
}

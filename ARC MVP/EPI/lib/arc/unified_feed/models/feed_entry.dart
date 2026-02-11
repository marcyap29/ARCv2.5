/// Unified Feed Entry model
///
/// Represents a single item in the unified LUMARA feed.
/// Can represent: active conversations, saved conversations,
/// voice memos, written journal entries, or LUMARA-initiated prompts.

import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'entry_state.dart';

/// The type of feed entry
enum FeedEntryType {
  /// Active conversation with LUMARA (not yet saved as journal)
  activeConversation,

  /// Saved conversation that was auto-saved or manually saved as a journal entry
  savedConversation,

  /// Voice memo (quick voice capture)
  voiceMemo,

  /// Reflection / thoughtful text capture
  reflection,

  /// LUMARA-initiated observation, prompt, or check-in
  lumaraInitiative,
}

/// A single message within a conversation-type feed entry.
class FeedMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const FeedMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// Unified feed entry that wraps all entry types into a single model.
///
/// This is a view-layer model that aggregates data from multiple sources
/// (JournalRepository, ChatRepo, VoiceNoteRepository) into a consistent
/// shape for display in the unified feed.
class FeedEntry {
  /// Unique identifier (maps to source ID: journal entry ID, chat session ID, etc.)
  final String id;

  /// The type of this feed entry
  final FeedEntryType type;

  /// Primary timestamp (creation or last activity)
  final DateTime timestamp;

  /// Current lifecycle state
  final EntryState state;

  /// Display title (auto-generated or user-provided)
  final String? title;

  /// Content preview or body (type-dependent)
  final dynamic content;

  /// Theme tags extracted by LUMARA analysis (shown on expanded view)
  final List<String> themes;

  /// Number of user-assistant exchanges (for conversation types)
  final int? exchangeCount;

  /// Duration of voice memo or conversation
  final Duration? duration;

  // --- Phase information (from ATLAS) ---

  /// Phase label (e.g., "Expansion", "Transition")
  final String? phase;

  /// Phase accent color for card border
  final Color? phaseColor;

  // --- Conversation data ---

  /// Messages in this conversation (for active/saved conversations)
  final List<FeedMessage>? messages;

  /// Whether this is an active (ongoing) conversation
  final bool isActive;

  // --- Voice memo data ---

  /// Path to audio file
  final String? audioPath;

  /// Path to transcript file
  final String? transcriptPath;

  // --- Source IDs for linking back to original repositories ---

  /// Source chat session ID (for conversation types)
  final String? chatSessionId;

  /// Source journal entry ID (for saved entries)
  final String? journalEntryId;

  /// Source voice note ID (for voice memos)
  final String? voiceNoteId;

  // --- Display metadata ---

  /// Mood/emotion label if available
  final String? mood;

  /// Whether this entry is pinned/favorited
  final bool isPinned;

  /// Whether this entry has LUMARA reflections attached
  final bool hasLumaraReflections;

  /// Whether this entry has media attachments
  final bool hasMedia;

  /// Number of media attachments
  final int mediaCount;

  /// Media items (photos, videos, files) for display
  final List<MediaItem> mediaItems;

  /// Tags from the original entry
  final List<String> tags;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  FeedEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.state,
    this.title,
    this.content,
    this.themes = const [],
    this.exchangeCount,
    this.duration,
    this.phase,
    this.phaseColor,
    this.messages,
    this.isActive = false,
    this.audioPath,
    this.transcriptPath,
    this.chatSessionId,
    this.journalEntryId,
    this.voiceNoteId,
    this.mood,
    this.isPinned = false,
    this.hasLumaraReflections = false,
    this.hasMedia = false,
    this.mediaCount = 0,
    this.mediaItems = const [],
    this.tags = const [],
    this.metadata = const {},
  });

  /// Human-readable age string (e.g., "2h ago", "Yesterday", "3 days ago")
  String get ageLabel {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  /// Short type label for display
  String get typeLabel {
    switch (type) {
      case FeedEntryType.activeConversation:
        return 'Active';
      case FeedEntryType.savedConversation:
        return 'Conversation';
      case FeedEntryType.voiceMemo:
        return 'Voice';
      case FeedEntryType.reflection:
        return 'Reflection';
      case FeedEntryType.lumaraInitiative:
        return 'LUMARA';
    }
  }

  /// Pattern to strip "## Summary\n\n...\n\n---\n\n" prefix from content for preview display.
  static final _summaryPrefix = RegExp(r'^## Summary\s*\n\n.+?\n\n---\n\n', dotAll: true);

  /// Preview text (body without summary header, first 200 chars)
  String get preview {
    if (content is String && (content as String).isNotEmpty) {
      // Strip the "## Summary...---" block so preview shows the actual body text
      String text = (content as String).replaceFirst(_summaryPrefix, '').trim();
      if (text.isEmpty) text = content as String; // fallback if regex removes everything
      return text.length > 200 ? '${text.substring(0, 197)}...' : text;
    }
    if (messages != null && messages!.isNotEmpty) {
      final first = messages!.first.content;
      return first.length > 200 ? '${first.substring(0, 197)}...' : first;
    }
    return '';
  }

  FeedEntry copyWith({
    String? id,
    FeedEntryType? type,
    DateTime? timestamp,
    EntryState? state,
    String? title,
    dynamic content,
    List<String>? themes,
    int? exchangeCount,
    Duration? duration,
    String? phase,
    Color? phaseColor,
    List<FeedMessage>? messages,
    bool? isActive,
    String? audioPath,
    String? transcriptPath,
    String? chatSessionId,
    String? journalEntryId,
    String? voiceNoteId,
    String? mood,
    bool? isPinned,
    bool? hasLumaraReflections,
    bool? hasMedia,
    int? mediaCount,
    List<MediaItem>? mediaItems,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return FeedEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      state: state ?? this.state,
      title: title ?? this.title,
      content: content ?? this.content,
      themes: themes ?? this.themes,
      exchangeCount: exchangeCount ?? this.exchangeCount,
      duration: duration ?? this.duration,
      phase: phase ?? this.phase,
      phaseColor: phaseColor ?? this.phaseColor,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      voiceNoteId: voiceNoteId ?? this.voiceNoteId,
      mood: mood ?? this.mood,
      isPinned: isPinned ?? this.isPinned,
      hasLumaraReflections: hasLumaraReflections ?? this.hasLumaraReflections,
      hasMedia: hasMedia ?? this.hasMedia,
      mediaCount: mediaCount ?? this.mediaCount,
      mediaItems: mediaItems ?? this.mediaItems,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }
}

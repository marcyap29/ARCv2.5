/// Unified Feed Entry model
///
/// Represents a single item in the unified LUMARA feed.
/// Can represent: active conversations, saved conversations,
/// voice memos, or written journal entries.

import 'package:equatable/equatable.dart';
import 'entry_state.dart';

/// The type of feed entry
enum FeedEntryType {
  /// Active conversation with LUMARA (not yet saved as journal)
  activeConversation,

  /// Saved conversation that was auto-saved or manually saved as a journal entry
  savedConversation,

  /// Voice memo (quick voice capture)
  voiceMemo,

  /// Written journal entry (text-based)
  writtenEntry,
}

/// Unified feed entry that wraps all entry types into a single model.
///
/// This is a view-layer model that aggregates data from multiple sources
/// (JournalRepository, ChatRepo, VoiceNoteRepository) into a consistent
/// shape for display in the unified feed.
class FeedEntry extends Equatable {
  /// Unique identifier (maps to source ID: journal entry ID, chat session ID, etc.)
  final String id;

  /// The type of this feed entry
  final FeedEntryType type;

  /// Display title (auto-generated or user-provided)
  final String title;

  /// Preview text shown in the feed card
  final String preview;

  /// When this entry was created
  final DateTime createdAt;

  /// When this entry was last updated
  final DateTime updatedAt;

  /// Current state of this entry (draft, saving, saved, error)
  final EntryState state;

  /// Number of messages in conversation (for conversation types)
  final int messageCount;

  /// Duration of voice memo in seconds (for voice memo type)
  final Duration? audioDuration;

  /// Tags associated with this entry
  final List<String> tags;

  /// Mood/emotion label if available
  final String? mood;

  /// Phase label at time of entry (e.g., 'discovery', 'expansion')
  final String? phase;

  /// Whether this entry is pinned/favorited
  final bool isPinned;

  /// Whether this entry has LUMARA reflections attached
  final bool hasLumaraReflections;

  /// Whether this entry has media attachments
  final bool hasMedia;

  /// Number of media attachments
  final int mediaCount;

  /// Source chat session ID (for conversation types, links back to ChatRepo)
  final String? chatSessionId;

  /// Source journal entry ID (for saved entries, links to JournalRepository)
  final String? journalEntryId;

  /// Source voice note ID (for voice memos)
  final String? voiceNoteId;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const FeedEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.preview,
    required this.createdAt,
    required this.updatedAt,
    this.state = const EntryState.saved(),
    this.messageCount = 0,
    this.audioDuration,
    this.tags = const [],
    this.mood,
    this.phase,
    this.isPinned = false,
    this.hasLumaraReflections = false,
    this.hasMedia = false,
    this.mediaCount = 0,
    this.chatSessionId,
    this.journalEntryId,
    this.voiceNoteId,
    this.metadata,
  });

  /// Whether this entry represents an ongoing (unsaved) conversation
  bool get isActive => type == FeedEntryType.activeConversation;

  /// Whether this entry has been persisted to journal storage
  bool get isSaved =>
      type == FeedEntryType.savedConversation ||
      type == FeedEntryType.writtenEntry ||
      type == FeedEntryType.voiceMemo;

  /// Human-readable age string (e.g., "2h ago", "Yesterday", "3 days ago")
  String get ageLabel {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
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
      case FeedEntryType.writtenEntry:
        return 'Entry';
    }
  }

  FeedEntry copyWith({
    String? id,
    FeedEntryType? type,
    String? title,
    String? preview,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntryState? state,
    int? messageCount,
    Duration? audioDuration,
    List<String>? tags,
    String? mood,
    String? phase,
    bool? isPinned,
    bool? hasLumaraReflections,
    bool? hasMedia,
    int? mediaCount,
    String? chatSessionId,
    String? journalEntryId,
    String? voiceNoteId,
    Map<String, dynamic>? metadata,
  }) {
    return FeedEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      state: state ?? this.state,
      messageCount: messageCount ?? this.messageCount,
      audioDuration: audioDuration ?? this.audioDuration,
      tags: tags ?? this.tags,
      mood: mood ?? this.mood,
      phase: phase ?? this.phase,
      isPinned: isPinned ?? this.isPinned,
      hasLumaraReflections: hasLumaraReflections ?? this.hasLumaraReflections,
      hasMedia: hasMedia ?? this.hasMedia,
      mediaCount: mediaCount ?? this.mediaCount,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      voiceNoteId: voiceNoteId ?? this.voiceNoteId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        preview,
        createdAt,
        updatedAt,
        state,
        messageCount,
        audioDuration,
        tags,
        mood,
        phase,
        isPinned,
        hasLumaraReflections,
        hasMedia,
        mediaCount,
        chatSessionId,
        journalEntryId,
        voiceNoteId,
      ];
}

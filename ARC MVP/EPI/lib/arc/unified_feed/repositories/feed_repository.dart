/// Feed Repository
///
/// Aggregates data from JournalRepository, ChatRepo, and VoiceNoteRepository
/// into a unified stream of FeedEntry items for the unified feed screen.
///
/// This is a read-through layer - it does NOT own persistence. All writes
/// go through the original repositories; this just provides a unified view.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/models/entry_state.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Aggregates multiple data sources into a unified feed.
class FeedRepository {
  final JournalRepository _journalRepo;
  final ChatRepoImpl _chatRepo;

  /// Controller that broadcasts feed updates.
  final _feedController = StreamController<List<FeedEntry>>.broadcast();

  /// Cached feed entries for fast access.
  List<FeedEntry> _cachedEntries = [];

  /// Active conversation entry (the one currently in progress).
  FeedEntry? _activeConversation;

  /// Whether the repository has been initialized.
  bool _initialized = false;

  FeedRepository({
    required JournalRepository journalRepo,
    required ChatRepoImpl chatRepo,
  })  : _journalRepo = journalRepo,
        _chatRepo = chatRepo;

  /// Stream of feed entries, sorted by updatedAt descending (newest first).
  Stream<List<FeedEntry>> get feedStream => _feedController.stream;

  /// Current cached entries.
  List<FeedEntry> get entries => List.unmodifiable(_cachedEntries);

  /// The active (in-progress) conversation, if any.
  FeedEntry? get activeConversation => _activeConversation;

  /// Initialize the repository and load initial data.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _chatRepo.initialize();
      await _journalRepo.ensureBoxOpen();
      await refresh();
      _initialized = true;
    } catch (e) {
      debugPrint('FeedRepository: Error initializing: $e');
      rethrow;
    }
  }

  /// Refresh the feed by re-querying all data sources.
  Future<void> refresh() async {
    try {
      final entries = <FeedEntry>[];

      // 1. Load journal entries → written entries + saved conversations
      final journalEntries = await _journalRepo.getAllJournalEntries();
      for (final entry in journalEntries) {
        entries.add(_journalEntryToFeedEntry(entry));
      }

      // 2. Load chat sessions → saved conversations (that may not be in journal yet)
      final chatSessions = await _chatRepo.listAll(includeArchived: false);
      for (final session in chatSessions) {
        // Only add if not already represented by a journal entry
        final alreadyInFeed = entries.any(
          (e) => e.chatSessionId == session.id,
        );
        if (!alreadyInFeed) {
          final messages = await _chatRepo.getMessages(session.id);
          entries.add(_chatSessionToFeedEntry(session, messages));
        }
      }

      // 3. Include active conversation if present
      if (_activeConversation != null) {
        // Remove stale version if present
        entries.removeWhere((e) => e.id == _activeConversation!.id);
        entries.insert(0, _activeConversation!);
      }

      // Sort by updatedAt descending
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _cachedEntries = entries;
      _feedController.add(_cachedEntries);
    } catch (e) {
      debugPrint('FeedRepository: Error refreshing feed: $e');
    }
  }

  /// Set or update the active conversation entry.
  void setActiveConversation(FeedEntry entry) {
    _activeConversation = entry.copyWith(
      type: FeedEntryType.activeConversation,
      state: const EntryState.draft(),
    );
    // Re-sort with active conversation at top
    _cachedEntries.removeWhere((e) => e.id == entry.id);
    _cachedEntries.insert(0, _activeConversation!);
    _feedController.add(_cachedEntries);
  }

  /// Clear the active conversation (e.g., after saving).
  void clearActiveConversation() {
    if (_activeConversation != null) {
      _cachedEntries.removeWhere((e) => e.id == _activeConversation!.id);
      _activeConversation = null;
      _feedController.add(_cachedEntries);
    }
  }

  /// Convert a journal entry to a feed entry.
  FeedEntry _journalEntryToFeedEntry(JournalEntry entry) {
    // Determine type: if entry has LUMARA blocks, it's a saved conversation
    final bool isConversation = entry.lumaraBlocks.isNotEmpty;
    final bool isVoiceMemo =
        entry.audioUri != null && entry.audioUri!.isNotEmpty;

    FeedEntryType type;
    if (isVoiceMemo) {
      type = FeedEntryType.voiceMemo;
    } else if (isConversation) {
      type = FeedEntryType.savedConversation;
    } else {
      type = FeedEntryType.writtenEntry;
    }

    // Generate preview text
    String preview = entry.content;
    if (preview.length > 200) {
      preview = '${preview.substring(0, 197)}...';
    }

    return FeedEntry(
      id: 'journal_${entry.id}',
      type: type,
      title: entry.title.isNotEmpty ? entry.title : _generateTitle(entry),
      preview: preview,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      state: const EntryState.saved(),
      tags: entry.tags,
      mood: entry.emotion ?? entry.mood,
      phase: entry.autoPhase ?? entry.phase,
      isPinned: false,
      hasLumaraReflections: entry.lumaraBlocks.isNotEmpty,
      hasMedia: entry.media.isNotEmpty,
      mediaCount: entry.media.length,
      journalEntryId: entry.id,
      metadata: entry.metadata,
    );
  }

  /// Convert a chat session to a feed entry.
  FeedEntry _chatSessionToFeedEntry(
    ChatSession session,
    List<ChatMessage> messages,
  ) {
    // Get preview from last message
    String preview = '';
    if (messages.isNotEmpty) {
      final lastUserMsg = messages.lastWhere(
        (m) => m.role == 'user',
        orElse: () => messages.last,
      );
      preview = lastUserMsg.textContent;
      if (preview.length > 200) {
        preview = '${preview.substring(0, 197)}...';
      }
    }

    return FeedEntry(
      id: 'chat_${session.id}',
      type: FeedEntryType.savedConversation,
      title: session.subject,
      preview: preview,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      state: const EntryState.saved(),
      messageCount: messages.length,
      tags: session.tags,
      isPinned: session.isPinned,
      chatSessionId: session.id,
      metadata: session.metadata,
    );
  }

  /// Generate a title from journal entry content.
  String _generateTitle(JournalEntry entry) {
    final content = entry.content.trim();
    if (content.isEmpty) return 'Untitled Entry';

    // Take first line or first 50 chars
    final firstLine = content.split('\n').first.trim();
    if (firstLine.length <= 50) return firstLine;
    return '${firstLine.substring(0, 47)}...';
  }

  /// Get entries filtered by type.
  List<FeedEntry> getEntriesByType(FeedEntryType type) {
    return _cachedEntries.where((e) => e.type == type).toList();
  }

  /// Get entries filtered by date range.
  List<FeedEntry> getEntriesByDateRange(DateTime start, DateTime end) {
    return _cachedEntries.where((e) {
      return e.createdAt.isAfter(start) && e.createdAt.isBefore(end);
    }).toList();
  }

  /// Search entries by text.
  List<FeedEntry> search(String query) {
    if (query.isEmpty) return _cachedEntries;
    final q = query.toLowerCase();
    return _cachedEntries.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.preview.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Dispose resources.
  void dispose() {
    _feedController.close();
  }
}

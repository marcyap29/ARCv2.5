/// Feed Repository
///
/// Aggregates data from JournalRepository, ChatRepo, and VoiceNoteRepository
/// into a unified stream of FeedEntry items for the unified feed screen.
///
/// Supports pagination (before/after), type filtering, and active conversation
/// detection. This is a read-through layer - all writes go through the
/// original repositories; this provides a unified view.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/models/entry_state.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/core/constants/phase_colors.dart';

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

  /// Stream of feed entries, sorted by timestamp descending (newest first).
  Stream<List<FeedEntry>> get feedStream => _feedController.stream;

  /// Current cached entries.
  List<FeedEntry> get entries => List.unmodifiable(_cachedEntries);

  /// The active (in-progress) conversation, if any.
  FeedEntry? get activeConversation => _activeConversation;

  /// Initialize the repository and load initial data.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize journal repo first (primary data source)
      await _journalRepo.ensureBoxOpen();
      debugPrint('FeedRepository: Journal repo initialized');
    } catch (e) {
      debugPrint('FeedRepository: Error initializing journal repo: $e');
    }

    try {
      // Initialize chat repo (secondary, may fail if adapters not ready)
      await _chatRepo.initialize();
      debugPrint('FeedRepository: Chat repo initialized');
    } catch (e) {
      debugPrint('FeedRepository: Error initializing chat repo (non-fatal): $e');
    }

    try {
      await refresh();
      _initialized = true;
      debugPrint('FeedRepository: Initialized with ${_cachedEntries.length} entries');
    } catch (e) {
      debugPrint('FeedRepository: Error during initial refresh: $e');
      _initialized = true; // Mark as initialized even on error to avoid loops
      _feedController.add([]); // Emit empty list so UI can render
    }
  }

  /// Get unified feed entries with pagination and type filtering.
  ///
  /// [before] - Only return entries before this timestamp.
  /// [after] - Only return entries after this timestamp.
  /// [limit] - Maximum number of entries to return.
  /// [types] - Only return entries of these types.
  Future<List<FeedEntry>> getFeed({
    DateTime? before,
    DateTime? after,
    int limit = 20,
    List<FeedEntryType>? types,
  }) async {
    var results = List<FeedEntry>.from(_cachedEntries);

    // Apply date filters
    if (before != null) {
      results = results.where((e) => e.timestamp.isBefore(before)).toList();
    }
    if (after != null) {
      results = results.where((e) => e.timestamp.isAfter(after)).toList();
    }

    // Apply type filter
    if (types != null && types.isNotEmpty) {
      results = results.where((e) => types.contains(e.type)).toList();
    }

    // Sort newest first and limit
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results.take(limit).toList();
  }

  /// Get active conversation if one exists (last message < 20 min ago).
  Future<FeedEntry?> getActiveConversation() async {
    if (_activeConversation == null) return null;

    final diff = DateTime.now().difference(_activeConversation!.timestamp);
    if (diff.inMinutes < 20) {
      return _activeConversation;
    }

    // Stale - no longer active
    return null;
  }

  /// Refresh the feed by re-querying all data sources.
  Future<void> refresh() async {
    try {
      final entries = <FeedEntry>[];

      // 1. Load journal entries → written entries + saved conversations
      try {
        final journalEntries = await _journalRepo.getAllJournalEntries();
        debugPrint('FeedRepository: Loaded ${journalEntries.length} journal entries');
        for (final entry in journalEntries) {
          entries.add(_journalEntryToFeedEntry(entry));
        }
      } catch (e) {
        debugPrint('FeedRepository: Error loading journal entries: $e');
      }

      // 2. Load chat sessions → saved conversations (not already in journal)
      try {
        final chatSessions = await _chatRepo.listAll(includeArchived: false);
        debugPrint('FeedRepository: Loaded ${chatSessions.length} chat sessions');
        for (final session in chatSessions) {
          final alreadyInFeed = entries.any((e) => e.chatSessionId == session.id);
          if (!alreadyInFeed) {
            final messages = await _chatRepo.getMessages(session.id);
            entries.add(_chatSessionToFeedEntry(session, messages));
          }
        }
      } catch (e) {
        debugPrint('FeedRepository: Error loading chat sessions: $e');
      }

      // 3. Include active conversation if present
      if (_activeConversation != null) {
        entries.removeWhere((e) => e.id == _activeConversation!.id);
        entries.insert(0, _activeConversation!);
      }

      // Sort by timestamp descending
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
      state: EntryState.active,
      isActive: true,
    );
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

    // Extract phase and phase color (manual user override takes priority over auto/detected)
    final phase = entry.computedPhase;
    final phaseColor = phase != null && phase.isNotEmpty ? PhaseColors.getPhaseColor(phase) : null;

    // Extract themes from metadata if available
    final themes = <String>[];
    if (entry.metadata != null && entry.metadata!['themes'] != null) {
      final rawThemes = entry.metadata!['themes'];
      if (rawThemes is List) {
        themes.addAll(rawThemes.cast<String>());
      }
    }

    // Generate preview
    String preview = entry.content;
    if (preview.length > 200) {
      preview = '${preview.substring(0, 197)}...';
    }

    return FeedEntry(
      id: 'journal_${entry.id}',
      type: type,
      timestamp: entry.createdAt,
      state: EntryState.saved,
      title: entry.title.isNotEmpty ? entry.title : _generateTitle(entry),
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

  /// Convert a chat session to a feed entry.
  FeedEntry _chatSessionToFeedEntry(
    ChatSession session,
    List<ChatMessage> messages,
  ) {
    String preview = '';
    final feedMessages = <FeedMessage>[];

    for (final msg in messages) {
      feedMessages.add(FeedMessage(
        id: msg.id,
        role: msg.role,
        content: msg.textContent,
        timestamp: msg.createdAt,
      ));
    }

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

    // Count exchanges (user messages only)
    final exchangeCount = messages.where((m) => m.role == 'user').length;

    return FeedEntry(
      id: 'chat_${session.id}',
      type: FeedEntryType.savedConversation,
      timestamp: session.updatedAt,
      state: EntryState.saved,
      title: session.subject,
      content: preview,
      exchangeCount: exchangeCount,
      messages: feedMessages,
      isPinned: session.isPinned,
      tags: session.tags,
      chatSessionId: session.id,
      metadata: session.metadata ?? {},
    );
  }

  /// Generate a title from journal entry content.
  String _generateTitle(JournalEntry entry) {
    final content = entry.content.trim();
    if (content.isEmpty) return 'Untitled Entry';

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
      return e.timestamp.isAfter(start) && e.timestamp.isBefore(end);
    }).toList();
  }

  /// Search entries by text.
  List<FeedEntry> search(String query) {
    if (query.isEmpty) return _cachedEntries;
    final q = query.toLowerCase();
    return _cachedEntries.where((e) {
      return (e.title?.toLowerCase().contains(q) ?? false) ||
          e.preview.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q)) ||
          e.themes.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Dispose resources.
  void dispose() {
    _feedController.close();
  }
}

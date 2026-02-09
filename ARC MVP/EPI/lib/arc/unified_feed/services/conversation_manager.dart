/// Conversation Manager
///
/// Manages the lifecycle of active conversations in the unified feed.
/// Handles:
/// - Auto-save timer logic (save after inactivity threshold)
/// - Conversation analysis via LLM for title/summary generation
/// - Transition from active conversation → saved journal entry
/// - Message tracking and state management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/models/entry_state.dart';
import 'package:my_app/arc/unified_feed/repositories/feed_repository.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Configuration for auto-save behavior.
class AutoSaveConfig {
  /// How long to wait after the last message before auto-saving.
  final Duration inactivityThreshold;

  /// Minimum number of user messages before auto-save is eligible.
  final int minMessagesForSave;

  /// Whether auto-save is enabled.
  final bool enabled;

  const AutoSaveConfig({
    this.inactivityThreshold = const Duration(minutes: 5),
    this.minMessagesForSave = 2,
    this.enabled = true,
  });
}

/// Manages active conversation lifecycle and auto-save logic.
class ConversationManager {
  final FeedRepository _feedRepo;
  final JournalRepository _journalRepo;
  final AutoSaveConfig config;

  /// Timer for auto-save inactivity detection.
  Timer? _inactivityTimer;

  /// The current active conversation's messages (user + assistant).
  final List<_ConversationMessage> _messages = [];

  /// The current active conversation's feed entry ID.
  String? _activeConversationId;

  /// Stream controller for conversation state changes.
  final _stateController = StreamController<ConversationState>.broadcast();

  ConversationManager({
    required FeedRepository feedRepo,
    required JournalRepository journalRepo,
    this.config = const AutoSaveConfig(),
  })  : _feedRepo = feedRepo,
        _journalRepo = journalRepo;

  /// Stream of conversation state changes.
  Stream<ConversationState> get stateStream => _stateController.stream;

  /// Whether there is an active conversation.
  bool get hasActiveConversation => _activeConversationId != null;

  /// Number of messages in the current conversation.
  int get messageCount => _messages.length;

  /// Start a new conversation.
  String startConversation() {
    // If there's an existing conversation, save it first
    if (hasActiveConversation) {
      saveConversation();
    }

    final id = _uuid.v4();
    _activeConversationId = id;
    _messages.clear();

    final entry = FeedEntry(
      id: 'active_$id',
      type: FeedEntryType.activeConversation,
      title: 'New Conversation',
      preview: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      state: const EntryState.draft(),
    );

    _feedRepo.setActiveConversation(entry);
    _stateController.add(ConversationState.active(id: id));

    return id;
  }

  /// Record a user message in the active conversation.
  void addUserMessage(String text) {
    if (!hasActiveConversation) {
      startConversation();
    }

    _messages.add(_ConversationMessage(
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    ));

    _updateActiveEntry();
    _resetInactivityTimer();
  }

  /// Record an assistant response in the active conversation.
  void addAssistantMessage(String text) {
    if (!hasActiveConversation) return;

    _messages.add(_ConversationMessage(
      role: 'assistant',
      text: text,
      timestamp: DateTime.now(),
    ));

    _updateActiveEntry();
    _resetInactivityTimer();
  }

  /// Update the active conversation's feed entry with latest state.
  void _updateActiveEntry() {
    if (_activeConversationId == null) return;

    final userMessages = _messages.where((m) => m.role == 'user').toList();
    final title = userMessages.isNotEmpty
        ? _generateConversationTitle(userMessages.first.text)
        : 'New Conversation';

    final preview = _messages.isNotEmpty ? _messages.last.text : '';
    final truncatedPreview =
        preview.length > 200 ? '${preview.substring(0, 197)}...' : preview;

    final entry = FeedEntry(
      id: 'active_$_activeConversationId',
      type: FeedEntryType.activeConversation,
      title: title,
      preview: truncatedPreview,
      createdAt: _messages.first.timestamp,
      updatedAt: _messages.last.timestamp,
      state: const EntryState.draft(),
      messageCount: _messages.length,
    );

    _feedRepo.setActiveConversation(entry);
  }

  /// Reset the inactivity timer (called after each message).
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!config.enabled) return;

    _inactivityTimer = Timer(config.inactivityThreshold, () {
      if (_messages.where((m) => m.role == 'user').length >=
          config.minMessagesForSave) {
        debugPrint(
            'ConversationManager: Inactivity threshold reached, auto-saving');
        saveConversation();
      }
    });
  }

  /// Save the current active conversation as a journal entry.
  Future<String?> saveConversation({String? customTitle}) async {
    if (!hasActiveConversation || _messages.isEmpty) return null;

    final conversationId = _activeConversationId!;
    _stateController.add(ConversationState.saving(id: conversationId));

    try {
      // Build journal entry from conversation
      final userMessages = _messages.where((m) => m.role == 'user').toList();
      final assistantMessages =
          _messages.where((m) => m.role == 'assistant').toList();

      // Compose content: user messages as the entry body
      final contentBuffer = StringBuffer();
      for (final msg in userMessages) {
        contentBuffer.writeln(msg.text);
        contentBuffer.writeln();
      }

      // Build LUMARA inline blocks from assistant messages
      final lumaraBlocks = assistantMessages.map((msg) {
        return InlineBlock(
          type: 'inline_reflection',
          intent: 'perspective',
          content: msg.text,
          timestamp: msg.timestamp.millisecondsSinceEpoch,
        );
      }).toList();

      final title = customTitle ??
          (userMessages.isNotEmpty
              ? _generateConversationTitle(userMessages.first.text)
              : 'Conversation');

      final now = DateTime.now();
      final entryId = _uuid.v4();
      final entry = JournalEntry(
        id: entryId,
        title: title,
        content: contentBuffer.toString().trim(),
        createdAt: _messages.first.timestamp,
        updatedAt: now,
        tags: const [],
        mood: '',
        media: const [],
        keywords: const [],
        lumaraBlocks: lumaraBlocks,
        isEdited: false,
        isPhaseLocked: false,
        metadata: {
          'source': 'unified_feed',
          'conversation_id': conversationId,
          'message_count': _messages.length,
        },
      );

      await _journalRepo.createJournalEntry(entry);

      // Clear the active conversation
      _activeConversationId = null;
      _messages.clear();
      _inactivityTimer?.cancel();
      _feedRepo.clearActiveConversation();

      // Refresh feed to show the new saved entry
      await _feedRepo.refresh();

      _stateController.add(ConversationState.saved(
        id: conversationId,
        journalEntryId: entryId,
      ));

      debugPrint(
          'ConversationManager: Saved conversation $conversationId as journal entry $entryId');
      return entryId;
    } catch (e) {
      debugPrint('ConversationManager: Error saving conversation: $e');
      _stateController.add(ConversationState.error(
        id: conversationId,
        message: e.toString(),
      ));
      return null;
    }
  }

  /// Generate a title from the first user message.
  String _generateConversationTitle(String firstMessage) {
    final clean = firstMessage.trim();
    if (clean.isEmpty) return 'New Conversation';
    if (clean.length <= 50) return clean;
    // Find a natural break point
    final breakIdx = clean.lastIndexOf(' ', 47);
    if (breakIdx > 20) return '${clean.substring(0, breakIdx)}...';
    return '${clean.substring(0, 47)}...';
  }

  /// Discard the current conversation without saving.
  void discardConversation() {
    if (!hasActiveConversation) return;

    final id = _activeConversationId!;
    _activeConversationId = null;
    _messages.clear();
    _inactivityTimer?.cancel();
    _feedRepo.clearActiveConversation();

    _stateController.add(ConversationState.discarded(id: id));
  }

  /// Dispose resources.
  void dispose() {
    _inactivityTimer?.cancel();
    _stateController.close();
  }
}

/// Internal message representation for conversation tracking.
class _ConversationMessage {
  final String role;
  final String text;
  final DateTime timestamp;

  const _ConversationMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });
}

/// State of a conversation lifecycle.
class ConversationState {
  final String id;
  final ConversationPhase phase;
  final String? journalEntryId;
  final String? errorMessage;

  const ConversationState({
    required this.id,
    required this.phase,
    this.journalEntryId,
    this.errorMessage,
  });

  factory ConversationState.active({required String id}) =>
      ConversationState(id: id, phase: ConversationPhase.active);

  factory ConversationState.saving({required String id}) =>
      ConversationState(id: id, phase: ConversationPhase.saving);

  factory ConversationState.saved({
    required String id,
    required String journalEntryId,
  }) =>
      ConversationState(
        id: id,
        phase: ConversationPhase.saved,
        journalEntryId: journalEntryId,
      );

  factory ConversationState.error({
    required String id,
    required String message,
  }) =>
      ConversationState(
        id: id,
        phase: ConversationPhase.error,
        errorMessage: message,
      );

  factory ConversationState.discarded({required String id}) =>
      ConversationState(id: id, phase: ConversationPhase.discarded);
}

enum ConversationPhase { active, saving, saved, error, discarded }

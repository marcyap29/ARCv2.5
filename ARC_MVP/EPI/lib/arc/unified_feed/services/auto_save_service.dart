/// Auto-Save Service
///
/// Manages automatic saving of conversations and draft entries.
/// Works with ConversationManager to persist conversations after
/// periods of inactivity, app backgrounding, or explicit save triggers.
///
/// This service is intentionally thin - the heavy lifting is in
/// ConversationManager. This service handles the app lifecycle hooks
/// and provides a clean API for the UI layer.
library;

import 'dart:async';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter/foundation.dart';
import 'package:my_app/arc/unified_feed/services/conversation_manager.dart';

/// Handles app lifecycle-aware auto-saving of conversations.
class AutoSaveService {
  final ConversationManager _conversationManager;

  /// Whether auto-save is currently paused (e.g., user is actively typing).
  bool _paused = false;

  /// Subscription to conversation state changes.
  StreamSubscription<ConversationState>? _stateSubscription;

  /// Callback for notifying the UI about save events.
  void Function(AutoSaveEvent)? onAutoSaveEvent;

  AutoSaveService({
    required ConversationManager conversationManager,
  }) : _conversationManager = conversationManager;

  /// Initialize the auto-save service.
  void initialize() {
    _stateSubscription =
        _conversationManager.stateStream.listen(_handleStateChange);
    debugPrint('AutoSaveService: Initialized');
  }

  /// Handle app lifecycle state changes.
  ///
  /// Call this from the widget's didChangeAppLifecycleState.
  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App going to background - save if there's an active conversation
        _saveOnBackground();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground - resume auto-save
        _paused = false;
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App being destroyed - emergency save
        _saveOnBackground();
        break;
    }
  }

  /// Pause auto-save (e.g., while user is actively typing).
  void pause() {
    _paused = true;
  }

  /// Resume auto-save.
  void resume() {
    _paused = false;
  }

  /// Force an immediate save of the active conversation.
  Future<String?> forceSave({String? customTitle}) async {
    if (!_conversationManager.hasActiveConversation) return null;
    return await _conversationManager.saveConversation(
      customTitle: customTitle,
    );
  }

  /// Save when app goes to background.
  void _saveOnBackground() {
    if (!_conversationManager.hasActiveConversation) return;
    if (_conversationManager.messageCount < 2) return; // Don't save tiny conversations

    debugPrint('AutoSaveService: App backgrounding, saving conversation');
    _conversationManager.saveConversation();

    onAutoSaveEvent?.call(AutoSaveEvent(
      type: AutoSaveEventType.backgroundSave,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle conversation state changes.
  void _handleStateChange(ConversationState state) {
    switch (state.phase) {
      case ConversationPhase.saved:
        onAutoSaveEvent?.call(AutoSaveEvent(
          type: AutoSaveEventType.saved,
          timestamp: DateTime.now(),
          journalEntryId: state.journalEntryId,
        ));
        break;
      case ConversationPhase.error:
        onAutoSaveEvent?.call(AutoSaveEvent(
          type: AutoSaveEventType.error,
          timestamp: DateTime.now(),
          errorMessage: state.errorMessage,
        ));
        break;
      default:
        break;
    }
  }

  /// Dispose resources.
  void dispose() {
    _stateSubscription?.cancel();
  }
}

/// Events emitted by the auto-save service.
class AutoSaveEvent {
  final AutoSaveEventType type;
  final DateTime timestamp;
  final String? journalEntryId;
  final String? errorMessage;

  const AutoSaveEvent({
    required this.type,
    required this.timestamp,
    this.journalEntryId,
    this.errorMessage,
  });
}

enum AutoSaveEventType {
  backgroundSave,
  inactivitySave,
  saved,
  error,
}

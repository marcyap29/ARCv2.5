/// Chat Store for Voice Chat
/// 
/// Saves voice chat sessions to chat history.
/// IMPORTANT: This saves ONLY to chat, NOT to journal.
/// 
/// Uses LumaraAssistantCubit for chat persistence.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import 'voice_journal_state.dart';

/// Voice chat session record
class VoiceChatRecord {
  final String sessionId;
  final DateTime timestamp;
  final List<VoiceChatTurn> turns;
  final VoiceLatencyMetrics? metrics;

  const VoiceChatRecord({
    required this.sessionId,
    required this.timestamp,
    required this.turns,
    this.metrics,
  });

  int get turnCount => turns.length;
}

/// Single turn in a voice chat conversation
class VoiceChatTurn {
  /// Scrubbed user text (safe for storage)
  final String scrubbedUserText;
  
  /// Display user text (with PII for local display)
  final String displayUserText;
  
  /// LUMARA response
  final String lumaraResponse;
  
  /// Timestamp
  final DateTime timestamp;

  const VoiceChatTurn({
    required this.scrubbedUserText,
    required this.displayUserText,
    required this.lumaraResponse,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'user': scrubbedUserText,
    'assistant': lumaraResponse,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Chat Store - saves voice chat to chat history
/// 
/// This store:
/// - Uses LumaraAssistantCubit for persistence
/// - NEVER saves to journal
/// - Maintains chat session continuity
class VoiceChatStore {
  final LumaraAssistantCubit? _chatCubit;
  final Uuid _uuid = const Uuid();
  
  String? _currentSessionId;

  VoiceChatStore({LumaraAssistantCubit? chatCubit})
      : _chatCubit = chatCubit;

  String get currentSessionId => _currentSessionId ?? '';

  /// Start a new chat session
  String startSession() {
    _currentSessionId = _uuid.v4();
    debugPrint('VoiceChatStore: Started session $_currentSessionId');
    return _currentSessionId!;
  }

  /// Save a single turn to chat history
  Future<void> saveTurn(VoiceChatTurn turn) async {
    if (_chatCubit == null) {
      debugPrint('VoiceChatStore: No chat cubit, skipping save');
      return;
    }

    try {
      // Send the user message through the cubit
      // This will trigger the chat persistence mechanism
      await _chatCubit!.sendMessage(turn.scrubbedUserText);
      
      debugPrint('VoiceChatStore: Saved turn to chat history');
    } catch (e) {
      debugPrint('VoiceChatStore: Error saving turn: $e');
    }
  }

  /// Save entire session
  Future<void> saveSession(VoiceChatRecord record) async {
    debugPrint('VoiceChatStore: Session ${record.sessionId} complete');
    debugPrint('  Turns: ${record.turnCount}');
    
    // Chat history is saved incrementally via saveTurn
    // This method is for any final cleanup or analytics
    
    _currentSessionId = null;
  }

  /// End session without saving
  void endSession() {
    _currentSessionId = null;
    debugPrint('VoiceChatStore: Session ended');
  }

  /// Get chat history (if cubit available)
  List<Map<String, String>> getChatHistory() {
    if (_chatCubit == null) return [];
    
    final state = _chatCubit!.state;
    if (state is LumaraAssistantLoaded) {
      return state.messages.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();
    }
    
    return [];
  }
}


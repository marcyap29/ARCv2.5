import 'chat_models.dart';
import 'chat_export_models.dart';

/// Enhanced repository interface for chat session persistence
abstract class EnhancedChatRepo {
  // Basic ChatRepo methods
  /// Create a new chat session
  Future<String> createSession({
    required String subject,
    List<String>? tags,
  });

  /// Add a message to an existing session
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  });

  /// List active (non-archived) sessions
  Future<List<ChatSession>> listActive({String? query});

  /// List archived sessions
  Future<List<ChatSession>> listArchived({String? query});

  /// List all sessions
  Future<List<ChatSession>> listAll({bool includeArchived = true});

  /// Get messages for a session (lazy load for archived sessions)
  Future<List<ChatMessage>> getMessages(String sessionId, {bool lazy = true});

  /// Get a single session by ID
  Future<ChatSession?> getSession(String sessionId);

  /// Rename a session
  Future<void> renameSession(String sessionId, String subject);

  /// Update session metadata
  Future<void> updateSessionMetadata(String sessionId, Map<String, dynamic> metadata);

  /// Update the phase classification for a chat session
  Future<void> updateSessionPhase(String sessionId, {
    required String autoPhase,
    required double autoPhaseConfidence,
  });

  /// Pin or unpin a session
  Future<void> pinSession(String sessionId, bool pin);

  /// Archive or restore a session
  Future<void> archiveSession(String sessionId, bool archive);

  /// Delete a session and all its messages
  Future<void> deleteSession(String sessionId);

  /// Delete a single message by ID
  Future<void> deleteMessage(String messageId);

  /// Add tags to a session
  Future<void> addTags(String sessionId, List<String> tags);

  /// Remove tags from a session
  Future<void> removeTags(String sessionId, List<String> tags);

  /// Prune sessions by policy (auto-archive old sessions)
  Future<void> pruneByPolicy({
    Duration maxAge = const Duration(days: 30),
  });

  /// Get session count statistics
  Future<Map<String, int>> getStats();

  /// Initialize repository (setup boxes/tables)
  Future<void> initialize();

  /// Delete multiple sessions and all their messages
  Future<void> deleteSessions(List<String> sessionIds);

  /// Close repository connections
  Future<void> close();

  // Export/Import
  /// Export all chat data
  Future<ChatExportData> exportAllData();

  /// Import chat data
  Future<void> importData(ChatExportData data, {bool merge = false});

  /// Export specific sessions
  Future<ChatExportData> exportSessions(List<String> sessionIds);

  // Search and Filter
  /// Search sessions
  Future<List<ChatSession>> searchSessions(String query);

  /// Get recent sessions across categories
  Future<List<ChatSession>> getRecentSessions({int limit = 10});

  /// Get pinned sessions
  Future<List<ChatSession>> getPinnedSessions();
}

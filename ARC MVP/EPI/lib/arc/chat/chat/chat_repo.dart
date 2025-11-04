import 'chat_models.dart';

/// Repository interface for chat session persistence
abstract class ChatRepo {
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

  /// Pin or unpin a session
  Future<void> pinSession(String sessionId, bool pin);

  /// Archive or restore a session
  Future<void> archiveSession(String sessionId, bool archive);

  /// Delete a session and all its messages
  Future<void> deleteSession(String sessionId);

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
}
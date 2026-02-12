import 'chat_models.dart';
import 'chat_category_models.dart';

/// Enhanced repository interface for chat session persistence with category support
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
  // Category Management
  /// Create a new chat category
  Future<String> createCategory({
    required String name,
    String? description,
    required String color,
    required String icon,
    int sortOrder = 0,
  });

  /// Get all categories
  Future<List<ChatCategory>> getCategories();

  /// Get a category by ID
  Future<ChatCategory?> getCategory(String categoryId);

  /// Update a category
  Future<void> updateCategory(String categoryId, {
    String? name,
    String? description,
    String? color,
    String? icon,
    int? sortOrder,
  });

  /// Delete a category (moves sessions to General category)
  Future<void> deleteCategory(String categoryId);

  /// Reorder categories
  Future<void> reorderCategories(List<String> categoryIds);

  // Session-Category Management
  /// Assign a session to a category
  Future<void> assignSessionToCategory(String sessionId, String categoryId);

  /// Remove a session from a category (moves to General)
  Future<void> removeSessionFromCategory(String sessionId);

  /// Get sessions in a specific category
  Future<List<ChatSession>> getSessionsInCategory(String categoryId, {String? query});

  /// Get category for a session
  Future<ChatCategory?> getSessionCategory(String sessionId);

  /// Move session between categories
  Future<void> moveSessionToCategory(String sessionId, String categoryId);

  // Export/Import
  /// Export all chat data
  Future<ChatExportData> exportAllData();

  /// Import chat data
  Future<void> importData(ChatExportData data, {bool merge = false});

  /// Export specific sessions
  Future<ChatExportData> exportSessions(List<String> sessionIds);

  /// Export sessions by category
  Future<ChatExportData> exportCategory(String categoryId);

  // Enhanced Statistics
  /// Get category statistics
  Future<Map<String, int>> getCategoryStats();

  /// Get session count by category
  Future<Map<String, int>> getSessionCountByCategory();

  // Search and Filter
  /// Search sessions across all categories
  Future<List<ChatSession>> searchSessions(String query, {String? categoryId});

  /// Get recent sessions across categories
  Future<List<ChatSession>> getRecentSessions({int limit = 10});

  /// Get pinned sessions across categories
  Future<List<ChatSession>> getPinnedSessions();
}

import 'package:hive/hive.dart';
import 'chat_models.dart';
import 'chat_repo.dart';
import 'chat_archive_policy.dart';

/// Hive implementation of ChatRepo
class ChatRepoImpl implements ChatRepo {
  static const String _sessionsBoxName = 'chat_sessions';
  static const String _messagesBoxName = 'chat_messages';

  Box<ChatSession>? _sessionsBox;
  Box<ChatMessage>? _messagesBox;

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ChatSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ChatMessageAdapter());
      }

      // Open boxes
      _sessionsBox = await Hive.openBox<ChatSession>(_sessionsBoxName);
      _messagesBox = await Hive.openBox<ChatMessage>(_messagesBoxName);

      _isInitialized = true;
      print('ChatRepoImpl: Initialized with ${_sessionsBox!.length} sessions');
    } catch (e) {
      print('ChatRepoImpl: Failed to initialize: $e');
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ChatRepo not initialized. Call initialize() first.');
    }
  }

  @override
  Future<String> createSession({
    required String subject,
    List<String>? tags,
  }) async {
    _ensureInitialized();

    final session = ChatSession.create(
      subject: subject,
      tags: tags ?? [],
    );

    await _sessionsBox!.put(session.id, session);
    print('ChatRepo: Created session ${session.id} - "$subject"');

    return session.id;
  }

  @override
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    _ensureInitialized();

    // Validate role
    if (!ChatMessage.isValidRole(role)) {
      throw ArgumentError('Invalid message role: $role');
    }

    // Get session to verify it exists
    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    // Create and store message
    final message = ChatMessage.create(
      sessionId: sessionId,
      role: role,
      content: content,
    );

    await _messagesBox!.put(message.id, message);

    // Update session timestamp and message count
    final updatedSession = session.copyWith(
      updatedAt: DateTime.now(),
      messageCount: session.messageCount + 1,
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: Added $role message to session $sessionId');
  }

  @override
  Future<List<ChatSession>> listActive({String? query}) async {
    _ensureInitialized();

    final sessions = _sessionsBox!.values
        .where((session) => !session.isArchived)
        .toList();

    if (query != null && query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      sessions.retainWhere((session) =>
          session.subject.toLowerCase().contains(lowercaseQuery) ||
          session.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery)));
    }

    // Sort by updatedAt descending
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return sessions;
  }

  @override
  Future<List<ChatSession>> listArchived({String? query}) async {
    _ensureInitialized();

    final sessions = _sessionsBox!.values
        .where((session) => session.isArchived)
        .toList();

    if (query != null && query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      sessions.retainWhere((session) =>
          session.subject.toLowerCase().contains(lowercaseQuery) ||
          session.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery)));
    }

    // Sort by archivedAt descending (most recently archived first)
    sessions.sort((a, b) {
      final aTime = a.archivedAt ?? a.updatedAt;
      final bTime = b.archivedAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    return sessions;
  }

  @override
  Future<List<ChatSession>> listAll({bool includeArchived = true}) async {
    _ensureInitialized();

    final sessions = _sessionsBox!.values.toList();

    if (!includeArchived) {
      sessions.retainWhere((session) => !session.isArchived);
    }

    // Sort by updatedAt descending
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return sessions;
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId, {bool lazy = true}) async {
    _ensureInitialized();

    // For lazy loading (list views), we might want to limit the number of messages
    // For now, we'll load all messages but this could be optimized
    final messages = _messagesBox!.values
        .where((message) => message.sessionId == sessionId)
        .toList();

    // Sort by createdAt ascending (chronological order)
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  @override
  Future<ChatSession?> getSession(String sessionId) async {
    _ensureInitialized();
    return _sessionsBox!.get(sessionId);
  }

  @override
  Future<void> renameSession(String sessionId, String subject) async {
    _ensureInitialized();

    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(
      subject: subject,
      updatedAt: DateTime.now(),
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: Renamed session $sessionId to "$subject"');
  }

  @override
  Future<void> pinSession(String sessionId, bool pin) async {
    _ensureInitialized();

    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(
      isPinned: pin,
      updatedAt: DateTime.now(),
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: ${pin ? 'Pinned' : 'Unpinned'} session $sessionId');
  }

  @override
  Future<void> archiveSession(String sessionId, bool archive) async {
    _ensureInitialized();

    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(
      isArchived: archive,
      archivedAt: archive ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: ${archive ? 'Archived' : 'Restored'} session $sessionId');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _ensureInitialized();

    // Delete all messages for this session
    final messageKeys = _messagesBox!.keys.where((key) {
      final message = _messagesBox!.get(key);
      return message?.sessionId == sessionId;
    }).toList();

    for (final key in messageKeys) {
      await _messagesBox!.delete(key);
    }

    // Delete the session
    await _sessionsBox!.delete(sessionId);
    print('ChatRepo: Deleted session $sessionId and ${messageKeys.length} messages');
  }

  @override
  Future<void> addTags(String sessionId, List<String> tags) async {
    _ensureInitialized();

    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final currentTags = Set<String>.from(session.tags);
    currentTags.addAll(tags);

    final updatedSession = session.copyWith(
      tags: currentTags.toList(),
      updatedAt: DateTime.now(),
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: Added tags $tags to session $sessionId');
  }

  @override
  Future<void> removeTags(String sessionId, List<String> tags) async {
    _ensureInitialized();

    final session = await getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final currentTags = Set<String>.from(session.tags);
    currentTags.removeAll(tags);

    final updatedSession = session.copyWith(
      tags: currentTags.toList(),
      updatedAt: DateTime.now(),
    );

    await _sessionsBox!.put(sessionId, updatedSession);
    print('ChatRepo: Removed tags $tags from session $sessionId');
  }

  @override
  Future<void> pruneByPolicy({Duration maxAge = const Duration(days: 30)}) async {
    _ensureInitialized();

    final cutoff = DateTime.now().subtract(maxAge);
    int archivedCount = 0;

    final sessionsToProcess = _sessionsBox!.values
        .where((session) => ChatArchivePolicy.shouldArchive(
              session.updatedAt,
              session.isPinned,
              session.isArchived,
            ))
        .take(ChatArchivePolicy.kMaxSessionsPerPrunerRun)
        .toList();

    for (final session in sessionsToProcess) {
      final updatedSession = session.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
      );

      await _sessionsBox!.put(session.id, updatedSession);
      archivedCount++;
    }

    if (archivedCount > 0) {
      print('ChatRepo: Auto-archived $archivedCount sessions older than ${maxAge.inDays} days');
    }
  }

  @override
  Future<Map<String, int>> getStats() async {
    _ensureInitialized();

    final sessions = _sessionsBox!.values.toList();
    final messages = _messagesBox!.values.toList();

    final activeCount = sessions.where((s) => !s.isArchived).length;
    final archivedCount = sessions.where((s) => s.isArchived).length;
    final pinnedCount = sessions.where((s) => s.isPinned).length;

    return {
      'total_sessions': sessions.length,
      'active_sessions': activeCount,
      'archived_sessions': archivedCount,
      'pinned_sessions': pinnedCount,
      'total_messages': messages.length,
    };
  }

  @override
  Future<void> close() async {
    if (_sessionsBox?.isOpen == true) {
      await _sessionsBox!.close();
    }
    if (_messagesBox?.isOpen == true) {
      await _messagesBox!.close();
    }
    _isInitialized = false;
  }
}
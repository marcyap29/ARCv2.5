import 'chat_models.dart';
import 'chat_export_models.dart';
import 'enhanced_chat_repo.dart';
import 'chat_repo_impl.dart';

/// Enhanced implementation of chat repository
class EnhancedChatRepoImpl implements EnhancedChatRepo {
  final ChatRepoImpl _baseRepo;

  EnhancedChatRepoImpl(this._baseRepo);

  @override
  Future<void> initialize() async {
    await _baseRepo.initialize();
  }

  @override
  Future<void> close() async {
    await _baseRepo.close();
  }

  // Delegate basic methods to base repo
  @override
  Future<String> createSession({required String subject, List<String>? tags}) =>
      _baseRepo.createSession(subject: subject, tags: tags);

  @override
  Future<void> addMessage({required String sessionId, required String role, required String content}) =>
      _baseRepo.addMessage(sessionId: sessionId, role: role, content: content);

  @override
  Future<List<ChatSession>> listActive({String? query}) =>
      _baseRepo.listActive(query: query);

  @override
  Future<List<ChatSession>> listArchived({String? query}) =>
      _baseRepo.listArchived(query: query);

  @override
  Future<List<ChatSession>> listAll({bool includeArchived = true}) =>
      _baseRepo.listAll(includeArchived: includeArchived);

  @override
  Future<List<ChatMessage>> getMessages(String sessionId, {bool lazy = true}) =>
      _baseRepo.getMessages(sessionId, lazy: lazy);

  @override
  Future<ChatSession?> getSession(String sessionId) =>
      _baseRepo.getSession(sessionId);

  @override
  Future<void> renameSession(String sessionId, String subject) =>
      _baseRepo.renameSession(sessionId, subject);

  @override
  Future<void> updateSessionMetadata(String sessionId, Map<String, dynamic> metadata) =>
      _baseRepo.updateSessionMetadata(sessionId, metadata);

  @override
  Future<void> updateSessionPhase(String sessionId, {
    required String autoPhase,
    required double autoPhaseConfidence,
  }) =>
      _baseRepo.updateSessionPhase(sessionId, autoPhase: autoPhase, autoPhaseConfidence: autoPhaseConfidence);

  @override
  Future<void> pinSession(String sessionId, bool pin) =>
      _baseRepo.pinSession(sessionId, pin);

  @override
  Future<void> archiveSession(String sessionId, bool archive) =>
      _baseRepo.archiveSession(sessionId, archive);

  @override
  Future<void> deleteSession(String sessionId) =>
      _baseRepo.deleteSession(sessionId);

  @override
  Future<void> deleteMessage(String messageId) =>
      _baseRepo.deleteMessage(messageId);

  @override
  Future<void> addTags(String sessionId, List<String> tags) =>
      _baseRepo.addTags(sessionId, tags);

  @override
  Future<void> removeTags(String sessionId, List<String> tags) =>
      _baseRepo.removeTags(sessionId, tags);

  @override
  Future<void> pruneByPolicy({Duration maxAge = const Duration(days: 30)}) =>
      _baseRepo.pruneByPolicy(maxAge: maxAge);

  @override
  Future<Map<String, int>> getStats() =>
      _baseRepo.getStats();

  @override
  Future<void> deleteSessions(List<String> sessionIds) =>
      _baseRepo.deleteSessions(sessionIds);

  // Export/Import
  @override
  Future<ChatExportData> exportAllData() async {
    final sessions = await listAll();
    final messages = <ChatMessage>[];

    for (final session in sessions) {
      final sessionMessages = await getMessages(session.id, lazy: false);
      messages.addAll(sessionMessages);
    }

    return ChatExportData.create(
      sessions: sessions,
      messages: messages,
    );
  }

  @override
  Future<void> importData(ChatExportData data, {bool merge = false}) async {
    print('📱 Chat Import: Importing ${data.sessions.length} sessions, ${data.messages.length} messages');

    final sessionIdMap = <String, String>{};

    for (final session in data.sessions) {
      try {
        final newSessionId = await _baseRepo.createSession(
          subject: session.subject,
          tags: session.tags,
        );
        sessionIdMap[session.id] = newSessionId;

        if (session.metadata != null && session.metadata!.isNotEmpty) {
          Map<String, dynamic> updatedMetadata = Map<String, dynamic>.from(session.metadata!);
          if (updatedMetadata.containsKey('forkedFrom')) {
            final originalForkedFrom = updatedMetadata['forkedFrom'] as String?;
            if (originalForkedFrom != null) {
              final newForkedFromId = sessionIdMap[originalForkedFrom];
              if (newForkedFromId != null) {
                updatedMetadata['forkedFrom'] = newForkedFromId;
              } else {
                updatedMetadata['forkedFromOriginal'] = originalForkedFrom;
                updatedMetadata['forkedFrom'] = null;
              }
            }
          }
          await _baseRepo.updateSessionMetadata(newSessionId, updatedMetadata);
        }

        if (session.isPinned) await _baseRepo.pinSession(newSessionId, true);
        if (session.isArchived) await _baseRepo.archiveSession(newSessionId, true);

        print('✅ Chat Import: Imported session "${session.subject}" (${session.id} -> $newSessionId)');
      } catch (e) {
        print('❌ Chat Import: Failed to import session "${session.subject}": $e');
      }
    }

    final messagesBySession = <String, List<ChatMessage>>{};
    for (final message in data.messages) {
      messagesBySession.putIfAbsent(message.sessionId, () => []).add(message);
    }

    for (final entry in messagesBySession.entries) {
      final originalSessionId = entry.key;
      final newSessionId = sessionIdMap[originalSessionId];

      if (newSessionId == null) {
        print('⚠️ Chat Import: No mapped session ID for $originalSessionId, skipping ${entry.value.length} messages');
        continue;
      }

      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final message in entry.value) {
        try {
          await _baseRepo.addMessage(
            sessionId: newSessionId,
            role: message.role,
            content: message.textContent,
          );
        } catch (e) {
          print('❌ Chat Import: Failed to import message to session $newSessionId: $e');
        }
      }

      print('✅ Chat Import: Imported ${entry.value.length} messages to session $newSessionId');
    }

    print('✅ Chat Import: Import complete - ${sessionIdMap.length} sessions, ${data.messages.length} messages');
  }

  @override
  Future<ChatExportData> exportSessions(List<String> sessionIds) async {
    final sessions = <ChatSession>[];
    final messages = <ChatMessage>[];

    for (final sessionId in sessionIds) {
      final session = await getSession(sessionId);
      if (session != null) {
        sessions.add(session);
        final sessionMessages = await getMessages(sessionId, lazy: false);
        messages.addAll(sessionMessages);
      }
    }

    return ChatExportData.create(
      sessions: sessions,
      messages: messages,
    );
  }

  @override
  Future<List<ChatSession>> searchSessions(String query) async {
    return listActive(query: query);
  }

  @override
  Future<List<ChatSession>> getRecentSessions({int limit = 10}) async {
    final sessions = await listActive();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions.take(limit).toList();
  }

  @override
  Future<List<ChatSession>> getPinnedSessions() async {
    final sessions = await listActive();
    return sessions.where((s) => s.isPinned).toList();
  }
}

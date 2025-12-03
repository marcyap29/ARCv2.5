import 'package:hive/hive.dart';
import 'chat_models.dart';
import 'chat_category_models.dart';
import 'enhanced_chat_repo.dart';
import 'chat_repo_impl.dart';

/// Enhanced implementation of chat repository with category support
class EnhancedChatRepoImpl implements EnhancedChatRepo {
  final ChatRepoImpl _baseRepo;
  late Box<ChatCategory> _categoryBox;
  late Box<ChatSessionCategory> _sessionCategoryBox;

  EnhancedChatRepoImpl(this._baseRepo);

  @override
  Future<void> initialize() async {
    await _baseRepo.initialize();
    
    // Initialize category boxes
    _categoryBox = await Hive.openBox<ChatCategory>('chat_categories');
    _sessionCategoryBox = await Hive.openBox<ChatSessionCategory>('chat_session_categories');
    
    // Create default categories if they don't exist
    if (_categoryBox.isEmpty) {
      final defaultCategories = ChatCategory.createDefaultCategories();
      for (final category in defaultCategories) {
        await _categoryBox.put(category.id, category);
      }
    }
  }

  @override
  Future<void> close() async {
    await _baseRepo.close();
    await _categoryBox.close();
    await _sessionCategoryBox.close();
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

  // Category Management
  @override
  Future<String> createCategory({
    required String name,
    String? description,
    required String color,
    required String icon,
    int sortOrder = 0,
  }) async {
    final category = ChatCategory.create(
      name: name,
      description: description,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
    );
    await _categoryBox.put(category.id, category);
    return category.id;
  }

  @override
  Future<List<ChatCategory>> getCategories() async {
    return _categoryBox.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<ChatCategory?> getCategory(String categoryId) async {
    return _categoryBox.get(categoryId);
  }

  @override
  Future<void> updateCategory(String categoryId, {
    String? name,
    String? description,
    String? color,
    String? icon,
    int? sortOrder,
  }) async {
    final category = await getCategory(categoryId);
    if (category != null) {
      final updatedCategory = category.copyWith(
        name: name,
        description: description,
        color: color,
        icon: icon,
        sortOrder: sortOrder,
        updatedAt: DateTime.now(),
      );
      await _categoryBox.put(categoryId, updatedCategory);
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    // Move all sessions in this category to General category
    final generalCategoryId = 'cat:general';
    final sessionCategories = _sessionCategoryBox.values
        .where((sc) => sc.categoryId == categoryId)
        .toList();
    
    for (final sessionCategory in sessionCategories) {
      await _sessionCategoryBox.put(
        sessionCategory.sessionId,
        ChatSessionCategory(
          sessionId: sessionCategory.sessionId,
          categoryId: generalCategoryId,
          assignedAt: DateTime.now(),
        ),
      );
    }
    
    await _categoryBox.delete(categoryId);
  }

  @override
  Future<void> reorderCategories(List<String> categoryIds) async {
    for (int i = 0; i < categoryIds.length; i++) {
      final category = await getCategory(categoryIds[i]);
      if (category != null) {
        await updateCategory(categoryIds[i], sortOrder: i);
      }
    }
  }

  // Session-Category Management
  @override
  Future<void> assignSessionToCategory(String sessionId, String categoryId) async {
    final sessionCategory = ChatSessionCategory(
      sessionId: sessionId,
      categoryId: categoryId,
      assignedAt: DateTime.now(),
    );
    await _sessionCategoryBox.put(sessionId, sessionCategory);
    
    // Update category session count
    final category = await getCategory(categoryId);
    if (category != null) {
      // Note: sessionCount is calculated dynamically, not stored
      // This is handled by the getSessionsInCategory method
    }
  }

  @override
  Future<void> removeSessionFromCategory(String sessionId) async {
    await _sessionCategoryBox.delete(sessionId);
  }

  @override
  Future<List<ChatSession>> getSessionsInCategory(String categoryId, {String? query}) async {
    final sessionCategories = _sessionCategoryBox.values
        .where((sc) => sc.categoryId == categoryId)
        .toList();
    
    final sessionIds = sessionCategories.map((sc) => sc.sessionId).toList();
    final allSessions = await listActive(query: query);
    
    return allSessions.where((session) => sessionIds.contains(session.id)).toList();
  }

  @override
  Future<ChatCategory?> getSessionCategory(String sessionId) async {
    final sessionCategory = _sessionCategoryBox.get(sessionId);
    if (sessionCategory != null) {
      return await getCategory(sessionCategory.categoryId);
    }
    return null;
  }

  @override
  Future<void> moveSessionToCategory(String sessionId, String categoryId) async {
    await assignSessionToCategory(sessionId, categoryId);
  }

  // Export/Import
  @override
  Future<ChatExportData> exportAllData() async {
    final sessions = await listAll();
    final messages = <ChatMessage>[];
    final categories = await getCategories();
    final sessionCategories = _sessionCategoryBox.values.toList();
    
    // Get all messages for all sessions
    for (final session in sessions) {
      final sessionMessages = await getMessages(session.id, lazy: false);
      messages.addAll(sessionMessages);
    }
    
    return ChatExportData.create(
      sessions: sessions,
      messages: messages,
      categories: categories,
      sessionCategories: sessionCategories,
    );
  }

  @override
  Future<void> importData(ChatExportData data, {bool merge = false}) async {
    if (!merge) {
      // Clear existing data
      await _categoryBox.clear();
      await _sessionCategoryBox.clear();
    }
    
    // Import categories
    for (final category in data.categories) {
      await _categoryBox.put(category.id, category);
    }
    
    // Import session categories
    for (final sessionCategory in data.sessionCategories) {
      await _sessionCategoryBox.put(sessionCategory.sessionId, sessionCategory);
    }
    
    // Import sessions and messages
    print('📱 Chat Import: Importing ${data.sessions.length} sessions, ${data.messages.length} messages');
    
    // Map to track original session IDs to new session IDs
    final sessionIdMap = <String, String>{};
    
    // First, import all sessions
    for (final session in data.sessions) {
      try {
        // Create new session with same subject and tags
        final newSessionId = await _baseRepo.createSession(
          subject: session.subject,
          tags: session.tags,
        );
        
        // Map original ID to new ID
        sessionIdMap[session.id] = newSessionId;
        
        // Update fork metadata to point to new session IDs if forked
        if (session.metadata != null && session.metadata!.isNotEmpty) {
          Map<String, dynamic> updatedMetadata = Map<String, dynamic>.from(session.metadata!);
          if (updatedMetadata.containsKey('forkedFrom')) {
            final originalForkedFrom = updatedMetadata['forkedFrom'] as String?;
            if (originalForkedFrom != null) {
              // Map original forkedFrom ID to new session ID if it exists
              final newForkedFromId = sessionIdMap[originalForkedFrom];
              if (newForkedFromId != null) {
                updatedMetadata['forkedFrom'] = newForkedFromId;
              } else {
                // Keep original but mark as unresolved
                updatedMetadata['forkedFromOriginal'] = originalForkedFrom;
                updatedMetadata['forkedFrom'] = null;
              }
            }
          }
          // Preserve all metadata (including fork relationships)
          await _baseRepo.updateSessionMetadata(newSessionId, updatedMetadata);
        }
        
        // Set additional properties if needed
        if (session.isPinned) {
          await _baseRepo.pinSession(newSessionId, true);
        }
        if (session.isArchived) {
          await _baseRepo.archiveSession(newSessionId, true);
        }
        
        print('✅ Chat Import: Imported session "${session.subject}" (${session.id} -> $newSessionId)');
      } catch (e) {
        print('❌ Chat Import: Failed to import session "${session.subject}": $e');
      }
    }
    
    // Then, import all messages (grouped by session)
    final messagesBySession = <String, List<ChatMessage>>{};
    for (final message in data.messages) {
      if (!messagesBySession.containsKey(message.sessionId)) {
        messagesBySession[message.sessionId] = [];
      }
      messagesBySession[message.sessionId]!.add(message);
    }
    
    // Import messages for each session in order
    for (final entry in messagesBySession.entries) {
      final originalSessionId = entry.key;
      final newSessionId = sessionIdMap[originalSessionId];
      
      if (newSessionId == null) {
        print('⚠️ Chat Import: No mapped session ID for $originalSessionId, skipping ${entry.value.length} messages');
        continue;
      }
      
      // Sort messages by creation time to maintain order
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Import messages in order
      for (final message in entry.value) {
        try {
          await _baseRepo.addMessage(
            sessionId: newSessionId,
            role: message.role,
            content: message.content,
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
    final sessionCategories = <ChatSessionCategory>[];
    
    for (final sessionId in sessionIds) {
      final session = await getSession(sessionId);
      if (session != null) {
        sessions.add(session);
        final sessionMessages = await getMessages(sessionId, lazy: false);
        messages.addAll(sessionMessages);
        
        final sessionCategory = _sessionCategoryBox.get(sessionId);
        if (sessionCategory != null) {
          sessionCategories.add(sessionCategory);
        }
      }
    }
    
    final categories = await getCategories();
    
    return ChatExportData.create(
      sessions: sessions,
      messages: messages,
      categories: categories,
      sessionCategories: sessionCategories,
    );
  }

  @override
  Future<ChatExportData> exportCategory(String categoryId) async {
    final sessions = await getSessionsInCategory(categoryId);
    final sessionIds = sessions.map((s) => s.id).toList();
    return exportSessions(sessionIds);
  }

  // Enhanced Statistics
  @override
  Future<Map<String, int>> getCategoryStats() async {
    final categories = await getCategories();
    final stats = <String, int>{};
    
    for (final category in categories) {
      final sessionCount = _sessionCategoryBox.values
          .where((sc) => sc.categoryId == category.id)
          .length;
      stats[category.name] = sessionCount;
    }
    
    return stats;
  }

  @override
  Future<Map<String, int>> getSessionCountByCategory() async {
    return getCategoryStats();
  }

  // Search and Filter
  @override
  Future<List<ChatSession>> searchSessions(String query, {String? categoryId}) async {
    List<ChatSession> sessions;
    
    if (categoryId != null) {
      sessions = await getSessionsInCategory(categoryId, query: query);
    } else {
      sessions = await listActive(query: query);
    }
    
    return sessions;
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

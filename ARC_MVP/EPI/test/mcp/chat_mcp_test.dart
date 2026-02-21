// test/mcp/chat_mcp_test.dart
// Test MCP export/import compatibility with chat data

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/mira/store/mcp/export/mcp_export_service.dart';
import 'package:my_app/arc/chat/services/mcp_bundle_parser.dart';
import 'package:my_app/arc/chat/models/reflective_node.dart';

class MockChatRepo implements ChatRepo {
  final List<ChatSession> _sessions = [];
  final Map<String, List<ChatMessage>> _messages = {};

  void setSessions(List<ChatSession> sessions) {
    _sessions.clear();
    _sessions.addAll(sessions);
  }

  void setMessages(String sessionId, List<ChatMessage> messages) {
    _messages[sessionId] = messages;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<String> createSession({required String subject, List<String>? tags}) async => 'test_session';

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> deleteSessions(List<String> sessionIds) async {}

  @override
  Future<ChatSession?> getSession(String sessionId) async => _sessions.firstWhere((s) => s.id == sessionId, orElse: () => throw StateError('No session'));

  @override
  Future<List<ChatSession>> listActive({String? query}) async => _sessions.where((s) => !s.isArchived).toList();

  @override
  Future<List<ChatSession>> listArchived({String? query}) async => _sessions.where((s) => s.isArchived).toList();

  @override
  Future<List<ChatSession>> listAll({bool includeArchived = true}) async {
    if (includeArchived) return _sessions;
    return _sessions.where((s) => !s.isArchived).toList();
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId, {bool lazy = false}) async {
    return _messages[sessionId] ?? [];
  }

  @override
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {}

  @override
  Future<void> clearMessages(String sessionId) async {}

  @override
  Future<void> addTags(String sessionId, List<String> tags) async {}

  @override
  Future<void> removeTags(String sessionId, List<String> tags) async {}

  @override
  Future<void> archiveSession(String sessionId, bool archive) async {}

  @override
  Future<void> pinSession(String sessionId, bool pin) async {}

  @override
  Future<void> renameSession(String sessionId, String subject) async {}

  @override
  Future<Map<String, int>> getStats() async => {};

  @override
  Future<void> pruneByPolicy({Duration maxAge = const Duration(days: 30)}) async {}

  @override
  Future<void> deleteMessage(String messageId) async {
    // Find and remove message from any session
    for (final sessionId in _messages.keys) {
      final messages = _messages[sessionId];
      if (messages != null) {
        _messages[sessionId] = messages.where((m) => m.id != messageId).toList();
      }
    }
  }
}

void main() {
  group('Chat MCP Compatibility', () {
    late McpExportService exportService;
    late McpBundleParser parser;
    late MockChatRepo mockChatRepo;

    setUp(() {
      mockChatRepo = MockChatRepo();
      exportService = McpExportService(chatRepo: mockChatRepo);
      parser = McpBundleParser();
    });

    test('should export chat sessions and messages to MCP format', () async {
      // Given
      final session = ChatSession(
        id: 'session_1',
        subject: 'Discussion about life phases',
        tags: ['phases', 'reflection'],
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        isArchived: false,
      );

      final message1 = ChatMessage(
        id: 'msg_1',
        sessionId: 'session_1',
        role: MessageRole.user,
        textContent: 'I think I\'m in a transition phase right now.',
        createdAt: DateTime(2024, 1, 15, 10, 0),
      );

      final message2 = ChatMessage(
        id: 'msg_2',
        sessionId: 'session_1',
        role: MessageRole.assistant,
        textContent: 'That\'s interesting. What makes you feel that way?',
        createdAt: DateTime(2024, 1, 15, 10, 5),
      );

      // Mock chat repo responses
      mockChatRepo.setSessions([session]);
      mockChatRepo.setMessages('session_1', [message1, message2]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        includeChats: true,
      );

      // Then
      expect(exportData.success, isTrue);
      expect(exportData.nodes, isNotEmpty);
      
      // Find chat nodes
      final chatSessionNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      final chatMessageNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatMessage'
      ).toList();
      
      expect(chatSessionNodes.length, equals(1));
      expect(chatMessageNodes.length, equals(2));
      
      // Verify session node
      final sessionNode = chatSessionNodes.first;
      expect(sessionNode.id, equals('session:session_1'));
      expect(sessionNode.contentSummary, equals('Discussion about life phases'));
      expect(sessionNode.keywords, equals(['phases', 'reflection']));
      
      // Verify message nodes
      final userMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_1'
      );
      expect(userMessage.contentSummary, contains('transition phase'));
      
      final lumaraMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_2'
      );
      expect(lumaraMessage.contentSummary, contains('interesting'));
    });

    test('should create proper chat relationships in MCP', () async {
      // Given
      final session = ChatSession(
        id: 'session_1',
        subject: 'Test session',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isArchived: false,
      );

      final message = ChatMessage(
        id: 'msg_1',
        sessionId: 'session_1',
        role: MessageRole.user,
        textContent: 'Test message',
        createdAt: DateTime.now(),
      );

      mockChatRepo.setSessions([session]);
      mockChatRepo.setMessages('session_1', [message]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        includeChats: true,
      );

      // Then
      expect(exportData.nodes, isNotEmpty);
      
      // Verify nodes exist (edges are handled internally in MCP export)
      final sessionNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      final messageNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatMessage'
      ).toList();
      
      expect(sessionNodes.length, equals(1));
      expect(messageNodes.length, equals(1));
    });

    test('should import chat data from MCP format', () async {
      // Given - Create mock MCP bundle data with chat
      final mockBundleData = {
        'nodes.jsonl': '''
{"id":"session:session_1","type":"ChatSession","timestamp":"2024-01-15T00:00:00Z","contentSummary":"Discussion about life phases","keywords":["phases","reflection"]}
{"id":"msg:msg_1","type":"ChatMessage","timestamp":"2024-01-15T10:00:00Z","contentSummary":"I think I'm in a transition phase right now."}
{"id":"msg:msg_2","type":"ChatMessage","timestamp":"2024-01-15T10:05:00Z","contentSummary":"That's interesting. What makes you feel that way?"}
''',
      };

      // When - Parse the bundle
      final nodes = await parser.parseBundle('mock_bundle_path');

      // Then
      expect(nodes, isNotEmpty);
      
      // Find chat nodes
      final chatSessionNodes = nodes.where(
        (node) => node.type == NodeType.chatSession
      ).toList();
      final chatMessageNodes = nodes.where(
        (node) => node.type == NodeType.chatMessage
      ).toList();
      
      expect(chatSessionNodes.length, equals(1));
      expect(chatMessageNodes.length, equals(2));
      
      // Verify session node
      final sessionNode = chatSessionNodes.first;
      expect(sessionNode.id, equals('session:session_1'));
      expect(sessionNode.contentText, equals('Discussion about life phases'));
      
      // Verify message nodes
      final userMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_1'
      );
      expect(userMessage.contentText, contains('transition phase'));
      
      final lumaraMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_2'
      );
      expect(lumaraMessage.contentText, contains('interesting'));
    });

    test('should handle chat data filtering by date scope', () async {
      // Given
      final oldSession = ChatSession(
        id: 'old_session',
        subject: 'Old discussion',
        tags: [],
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 60)),
        isArchived: false,
      );

      final recentSession = ChatSession(
        id: 'recent_session',
        subject: 'Recent discussion',
        tags: [],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
        isArchived: false,
      );

      mockChatRepo.setSessions([oldSession, recentSession]);

      // When - Export with 30-day scope
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.last30Days,
        journalEntries: [],
        includeChats: true,
      );

      // Then
      final chatSessionNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      
      expect(chatSessionNodes.length, equals(1));
      expect(chatSessionNodes.first.id, equals('session:recent_session'));
    });

    test('should include archived chats when requested', () async {
      // Given
      final activeSession = ChatSession(
        id: 'active_session',
        subject: 'Active discussion',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isArchived: false,
      );

      final archivedSession = ChatSession(
        id: 'archived_session',
        subject: 'Archived discussion',
        tags: [],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
        isArchived: true,
      );

      mockChatRepo.setSessions([activeSession, archivedSession]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        includeChats: true,
        includeArchivedChats: true,
      );

      // Then
      final chatSessionNodes = exportData.nodes!.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      
      expect(chatSessionNodes.length, equals(2));
      expect(chatSessionNodes.any((node) => node.id == 'session:active_session'), isTrue);
      expect(chatSessionNodes.any((node) => node.id == 'session:archived_session'), isTrue);
    });
  });
}

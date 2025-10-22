// test/mcp/chat_mcp_test.dart
// Test MCP export/import compatibility with chat data

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/mcp/export/mcp_export_service.dart';
import 'package:my_app/lumara/services/mcp_bundle_parser.dart';
import 'package:my_app/lumara/models/reflective_node.dart';

class MockChatRepo extends Mock implements ChatRepo {}

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
        content: 'I think I\'m in a transition phase right now.',
        createdAt: DateTime(2024, 1, 15, 10, 0),
        isFromUser: true,
      );

      final message2 = ChatMessage(
        id: 'msg_2',
        sessionId: 'session_1',
        content: 'That\'s interesting. What makes you feel that way?',
        createdAt: DateTime(2024, 1, 15, 10, 5),
        isFromUser: false,
      );

      // Mock chat repo responses
      when(mockChatRepo.listAll(includeArchived: false))
          .thenAnswer((_) async => [session]);
      when(mockChatRepo.getMessages('session_1', lazy: false))
          .thenAnswer((_) async => [message1, message2]);

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
      final chatSessionNodes = exportData.nodes.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      final chatMessageNodes = exportData.nodes.where(
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
        content: 'Test message',
        createdAt: DateTime.now(),
        isFromUser: true,
      );

      when(mockChatRepo.listAll(includeArchived: false))
          .thenAnswer((_) async => [session]);
      when(mockChatRepo.getMessages('session_1', lazy: false))
          .thenAnswer((_) async => [message]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        includeChats: true,
      );

      // Then
      expect(exportData.edges, isNotEmpty);
      
      // Find contains edges
      final containsEdges = exportData.edges.where(
        (edge) => edge.relationship == 'contains'
      ).toList();
      
      expect(containsEdges.length, equals(1));
      
      final containsEdge = containsEdges.first;
      expect(containsEdge.sourceId, equals('session:session_1'));
      expect(containsEdge.targetId, equals('msg:msg_1'));
      expect(containsEdge.metadata?['relationship_type'], equals('contains'));
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
      expect(sessionNode.content, equals('Discussion about life phases'));
      expect(sessionNode.metadata?['subject'], equals('Discussion about life phases'));
      expect(sessionNode.metadata?['tags'], equals(['phases', 'reflection']));
      
      // Verify message nodes
      final userMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_1'
      );
      expect(userMessage.content, contains('transition phase'));
      expect(userMessage.metadata?['content'], contains('transition phase'));
      
      final lumaraMessage = chatMessageNodes.firstWhere(
        (node) => node.id == 'msg:msg_2'
      );
      expect(lumaraMessage.content, contains('interesting'));
      expect(lumaraMessage.metadata?['content'], contains('interesting'));
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

      when(mockChatRepo.listAll(includeArchived: false))
          .thenAnswer((_) async => [oldSession, recentSession]);
      when(mockChatRepo.getMessages(any, lazy: false))
          .thenAnswer((_) async => []);

      // When - Export with 30-day scope
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.last30Days,
        journalEntries: [],
        includeChats: true,
      );

      // Then
      final chatSessionNodes = exportData.nodes.where(
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

      when(mockChatRepo.listAll(includeArchived: true))
          .thenAnswer((_) async => [activeSession, archivedSession]);
      when(mockChatRepo.getMessages(any, lazy: false))
          .thenAnswer((_) async => []);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        includeChats: true,
        includeArchivedChats: true,
      );

      // Then
      final chatSessionNodes = exportData.nodes.where(
        (node) => node.type == 'ChatSession'
      ).toList();
      
      expect(chatSessionNodes.length, equals(2));
      expect(chatSessionNodes.any((node) => node.id == 'session:active_session'), isTrue);
      expect(chatSessionNodes.any((node) => node.id == 'session:archived_session'), isTrue);
    });
  });
}

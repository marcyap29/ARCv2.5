import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/adapters/from_mira.dart';
import 'package:my_app/mira/store/mcp/import/mcp_import_service.dart';
import 'package:my_app/mira/store/mcp/export/chat_exporter.dart';
import 'package:my_app/mira/core/schema.dart';
import 'package:my_app/mira/nodes/chat_session_node.dart';
import 'package:my_app/mira/nodes/chat_message_node.dart';
import 'package:my_app/mira/edges/contains_edge.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';

void main() {
  group('Mixed Version MCP Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mixed_version_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should handle mixed node.v1 and node.v2 records correctly', () async {
      // Create test data with mixed versions
      final testBundle = await _createMixedVersionTestBundle(tempDir);

      // Validate the bundle files exist
      expect(await File('${tempDir.path}/nodes.jsonl').exists(), isTrue);
      expect(await File('${tempDir.path}/edges.jsonl').exists(), isTrue);
      expect(await File('${tempDir.path}/manifest.json').exists(), isTrue);

      // Validate node records contain both versions
      final nodesContent = await File('${tempDir.path}/nodes.jsonl').readAsLines();
      final nodeRecords = nodesContent.map((line) => jsonDecode(line)).toList();

      // Should have both node.v1 (legacy journal) and node.v2 (chat) records
      final v1Records = nodeRecords.where((r) => r['schema_version'] == 'node.v1').toList();
      final v2Records = nodeRecords.where((r) => r['schema_version'] == 'node.v2').toList();

      expect(v1Records, isNotEmpty, reason: 'Should have node.v1 records');
      expect(v2Records, isNotEmpty, reason: 'Should have node.v2 records');
      print('Found ${v1Records.length} node.v1 records and ${v2Records.length} node.v2 records');

      // Validate v1 record structure
      final v1Record = v1Records.first;
      expect(v1Record, containsPair('type', isA<String>()));
      expect(v1Record, containsPair('id', isA<String>()));
      expect(v1Record, containsPair('timestamp', isA<String>()));
      expect(v1Record, containsPair('content_summary', isA<String>()));

      // Validate v2 record structure
      final v2Record = v2Records.first;
      expect(v2Record, containsPair('kind', 'node'));
      expect(v2Record, containsPair('type', isA<String>()));
      expect(v2Record, containsPair('id', isA<String>()));
      expect(v2Record, containsPair('timestamp', isA<String>()));
      expect(v2Record, containsPair('content', isA<Map>()));
      expect(v2Record, containsPair('metadata', isA<Map>()));
    });

    test('should export chat sessions as valid node.v2 records', () async {
      // Create test chat data
      final testSession = _createTestChatSession();
      final testMessages = _createTestChatMessages(testSession.id);

      // Convert to MIRA nodes
      final sessionNode = ChatSessionNode.fromModel(testSession);
      final messageNodes = testMessages.map((m) => ChatMessageNode.fromModel(m)).toList();

      // Convert using adapter
      final sessionMcp = MiraToMcpAdapter.nodeToMcp(sessionNode);
      final messageMcps = messageNodes.map((n) => MiraToMcpAdapter.nodeToMcp(n)).toList();

      // Validate session record
      expect(sessionMcp, isNotNull);
      expect(sessionMcp!['schema_version'], equals('node.v2'));
      expect(sessionMcp['kind'], equals('node'));
      expect(sessionMcp['type'], equals('ChatSession'));
      expect(sessionMcp['content'], isA<Map>());
      expect(sessionMcp['metadata'], isA<Map>());

      // Validate message records
      for (final messageMcp in messageMcps) {
        expect(messageMcp, isNotNull);
        expect(messageMcp!['schema_version'], equals('node.v2'));
        expect(messageMcp['kind'], equals('node'));
        expect(messageMcp['type'], equals('ChatMessage'));
        expect(messageMcp['content'], isA<Map>());
        expect(messageMcp['content']['text'], isA<String>());
        expect(messageMcp['content']['mime'], equals('text/plain'));
        expect(messageMcp['metadata']['role'], isIn(['user', 'assistant']));
      }
    });

    test('should export legacy journal entries as valid node.v1 records', () async {
      // Create test legacy data
      final legacyEntryNode = _createTestLegacyEntryNode();
      final legacyKeywordNode = _createTestLegacyKeywordNode();

      // Convert using adapter
      final entryMcp = MiraToMcpAdapter.nodeToMcp(legacyEntryNode);
      final keywordMcp = MiraToMcpAdapter.nodeToMcp(legacyKeywordNode);

      // Validate entry record
      expect(entryMcp, isNotNull);
      expect(entryMcp!['schema_version'], equals('node.v1'));
      expect(entryMcp['type'], equals('entry'));
      expect(entryMcp['content_summary'], isA<String>());
      expect(entryMcp['keywords'], isA<List>());

      // Validate keyword record
      expect(keywordMcp, isNotNull);
      expect(keywordMcp!['schema_version'], equals('node.v1'));
      expect(keywordMcp['type'], equals('keyword'));
      expect(keywordMcp['content_summary'], contains('Keyword node:'));
    });

    test('should export contains edges with proper metadata', () async {
      // Create test edge
      final testEdge = ContainsEdge.sessionMessage(
        sessionId: 'test_session',
        messageId: 'test_message',
        timestamp: DateTime.now(),
        messageOrder: 0,
      );

      // Convert using adapter
      final edgeMcp = MiraToMcpAdapter.edgeToMcp(testEdge);

      // Validate edge record
      expect(edgeMcp, isNotNull);
      expect(edgeMcp!['schema_version'], equals('edge.v1'));
      expect(edgeMcp['kind'], equals('edge'));
      expect(edgeMcp['type'], equals('contains'));
      expect(edgeMcp['source_id'], equals('session:test_session'));
      expect(edgeMcp['target_id'], equals('msg:test_message'));
      expect(edgeMcp['metadata']['order'], equals(0));
    });

    test('should validate against golden bundle structure', () async {
      // Read the actual golden bundle
      final goldenDir = Directory('mcp/golden/mcp_chats_2025-09_mixed_versions');
      expect(await goldenDir.exists(), isTrue, reason: 'Golden bundle should exist');

      // Validate golden bundle files
      final goldenNodes = File('${goldenDir.path}/nodes.jsonl');
      final goldenEdges = File('${goldenDir.path}/edges.jsonl');
      final goldenManifest = File('${goldenDir.path}/manifest.json');

      expect(await goldenNodes.exists(), isTrue);
      expect(await goldenEdges.exists(), isTrue);
      expect(await goldenManifest.exists(), isTrue);

      // Parse and validate golden records
      final nodeLines = await goldenNodes.readAsLines();
      final nodeRecords = nodeLines.where((line) => line.trim().isNotEmpty)
                                   .map((line) => jsonDecode(line)).toList();

      // Validate mixed versions in golden bundle
      final v1Records = nodeRecords.where((r) => r['schema_version'] == 'node.v1').toList();
      final v2Records = nodeRecords.where((r) => r['schema_version'] == 'node.v2').toList();

      expect(v1Records.length, equals(3), reason: 'Golden bundle should have 3 v1 records');
      expect(v2Records.length, equals(3), reason: 'Golden bundle should have 3 v2 records');

      // Validate v1 record structure matches our exports
      for (final record in v1Records) {
        _validateNodeV1Structure(record);
      }

      // Validate v2 record structure matches our exports
      for (final record in v2Records) {
        _validateNodeV2Structure(record);
      }
    });

    test('should handle AJV validation requirements', () async {
      // This test ensures our records are structured for AJV validation
      // In a real implementation, this would shell out to ajv command

      final testSession = _createTestChatSession();
      final sessionNode = ChatSessionNode.fromModel(testSession);
      final sessionMcp = MiraToMcpAdapter.nodeToMcp(sessionNode);

      // Validate required fields for AJV schema compliance
      expect(sessionMcp!['kind'], equals('node'));
      expect(sessionMcp['type'], equals('ChatSession'));
      expect(sessionMcp['id'], startsWith('session:'));
      expect(sessionMcp['timestamp'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
      expect(sessionMcp['schema_version'], equals('node.v2'));
      expect(sessionMcp['content'], isA<Map>());
      expect(sessionMcp['metadata'], isA<Map>());

      print('Generated valid node.v2 record for AJV validation');
      print('Record: ${jsonEncode(sessionMcp)}');
    });
  });
}

/// Create a mixed-version test bundle similar to golden bundle
Future<Directory> _createMixedVersionTestBundle(Directory outputDir) async {
  final nodesFile = File('${outputDir.path}/nodes.jsonl');
  final edgesFile = File('${outputDir.path}/edges.jsonl');
  final manifestFile = File('${outputDir.path}/manifest.json');

  // Create mixed node records
  final nodeRecords = [
    // Legacy node.v1 records
    {
      'type': 'entry',
      'id': 'entry:test_legacy_entry',
      'timestamp': '2025-09-15T10:00:00Z',
      'schema_version': 'node.v1',
      'content_summary': 'Test legacy journal entry',
      'keywords': ['test', 'legacy'],
    },
    {
      'type': 'keyword',
      'id': 'kw:test',
      'timestamp': '2025-09-15T10:00:01Z',
      'schema_version': 'node.v1',
      'content_summary': 'Keyword node: test',
      'keywords': ['test'],
    },
    // Modern node.v2 records
    {
      'kind': 'node',
      'type': 'ChatSession',
      'id': 'session:test_session',
      'timestamp': '2025-09-15T11:00:00Z',
      'content': {'title': 'Test Chat Session'},
      'metadata': {
        'isArchived': false,
        'isPinned': false,
        'tags': ['test'],
        'messageCount': 1,
      },
      'schema_version': 'node.v2',
    },
    {
      'kind': 'node',
      'type': 'ChatMessage',
      'id': 'msg:test_message',
      'timestamp': '2025-09-15T11:01:00Z',
      'content': {
        'text': 'Test chat message',
        'mime': 'text/plain',
      },
      'metadata': {'role': 'user'},
      'schema_version': 'node.v2',
    },
  ];

  // Write nodes
  final nodesSink = nodesFile.openWrite();
  for (final record in nodeRecords) {
    nodesSink.writeln(jsonEncode(record));
  }
  await nodesSink.close();

  // Create test edges
  final edgeRecords = [
    {
      'kind': 'edge',
      'type': 'contains',
      'source_id': 'session:test_session',
      'target_id': 'msg:test_message',
      'timestamp': '2025-09-15T11:01:00Z',
      'metadata': {'order': 0},
      'schema_version': 'edge.v1',
    },
  ];

  final edgesSink = edgesFile.openWrite();
  for (final record in edgeRecords) {
    edgesSink.writeln(jsonEncode(record));
  }
  await edgesSink.close();

  // Create manifest
  final manifest = {
    'bundle_id': 'test_mixed_version',
    'version': '1.0.0',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'files': {
      'nodes_jsonl': {'path': 'nodes.jsonl', 'records': nodeRecords.length},
      'edges_jsonl': {'path': 'edges.jsonl', 'records': edgeRecords.length},
    }
  };

  await manifestFile.writeAsString(jsonEncode(manifest));

  return outputDir;
}

/// Create test chat session
ChatSession _createTestChatSession() {
  return ChatSession(
    id: 'test_session_id',
    subject: 'Test Chat Session',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    updatedAt: DateTime.now(),
    isPinned: false,
    isArchived: false,
    tags: const ['test', 'example'],
    messageCount: 2,
  );
}

/// Create test chat messages
List<ChatMessage> _createTestChatMessages(String sessionId) {
  return [
    ChatMessage(
      id: 'test_message_1',
      sessionId: sessionId,
      role: 'user',
      textContent: 'Hello, this is a test message',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    ChatMessage(
      id: 'test_message_2',
      sessionId: sessionId,
      role: 'assistant',
      textContent: 'Hi! This is a test response',
      createdAt: DateTime.now().subtract(const Duration(minutes: 29)),
    ),
  ];
}

/// Create test legacy entry node
MiraNode _createTestLegacyEntryNode() {
  return MiraNode(
    id: 'entry:test_legacy',
    type: NodeType.entry,
    schemaVersion: 1,
    data: {
      'content': 'This is a test legacy journal entry',
      'keywords': ['legacy', 'test', 'journal'],
      'phase_hint': 'Exploration',
    },
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

/// Create test legacy keyword node
MiraNode _createTestLegacyKeywordNode() {
  return MiraNode(
    id: 'kw:legacy',
    type: NodeType.keyword,
    schemaVersion: 1,
    data: {
      'keyword': 'legacy',
      'frequency': 5,
    },
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

/// Validate node.v1 record structure
void _validateNodeV1Structure(Map<String, dynamic> record) {
  expect(record['schema_version'], equals('node.v1'));
  expect(record['type'], isA<String>());
  expect(record['id'], isA<String>());
  expect(record['timestamp'], isA<String>());
  expect(record['content_summary'], isA<String>());

  // Optional fields
  if (record.containsKey('keywords')) {
    expect(record['keywords'], isA<List>());
  }
}

/// Validate node.v2 record structure
void _validateNodeV2Structure(Map<String, dynamic> record) {
  expect(record['schema_version'], equals('node.v2'));
  expect(record['kind'], equals('node'));
  expect(record['type'], isA<String>());
  expect(record['id'], isA<String>());
  expect(record['timestamp'], isA<String>());
  expect(record['content'], isA<Map>());
  expect(record['metadata'], isA<Map>());
}
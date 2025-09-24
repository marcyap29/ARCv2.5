import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/lumara/chat/chat_repo_impl.dart';
import 'package:my_app/mcp/export/mcp_export_service.dart';
import 'package:my_app/mcp/import/mcp_import_service.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/models/journal_entry_model.dart';

void main() {
  group('MCP Integration Tests', () {
    late ChatRepoImpl chatRepo;
    late MiraService miraService;
    late Directory tempDir;

    setUp(() async {
      // Initialize Hive with in-memory storage for testing
      Hive.init('test_hive');

      // Register adapters
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ChatSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ChatMessageAdapter());
      }

      chatRepo = ChatRepoImpl();
      await chatRepo.initialize();

      miraService = MiraService.instance;
      await miraService.initialize(chatRepo: chatRepo);

      // Create temp directory for exports
      tempDir = await Directory.systemTemp.createTemp('mcp_integration_test');
    });

    tearDown(() async {
      await chatRepo.close();
      await miraService.close();
      await Hive.deleteFromDisk();

      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('End-to-End Export/Import', () {
      test('should export and import chat data successfully', () async {
        // Step 1: Create test chat data
        print('📝 Creating test chat data...');

        final sessionId1 = await chatRepo.createSession(
          subject: 'Test Chat Session 1',
          tags: ['test', 'integration'],
        );

        final sessionId2 = await chatRepo.createSession(
          subject: 'Test Chat Session 2',
          tags: ['test', 'demo'],
        );

        // Add messages to sessions
        await chatRepo.addMessage(
          sessionId: sessionId1,
          role: MessageRole.user,
          content: 'Hello LUMARA, this is a test message for integration testing.',
        );

        await chatRepo.addMessage(
          sessionId: sessionId1,
          role: MessageRole.assistant,
          content: 'Hello! I understand this is an integration test. How can I help you test the system?',
        );

        await chatRepo.addMessage(
          sessionId: sessionId2,
          role: MessageRole.user,
          content: 'Testing the export functionality.',
        );

        // Archive one session for testing
        await chatRepo.archiveSession(sessionId2, true);

        // Step 2: Export data
        print('📤 Exporting data to MCP format...');

        final exportDir = Directory('${tempDir.path}/export');
        final exportResult = await miraService.exportToMcpEnhanced(
          outputDir: exportDir,
          journalEntries: [], // No journal entries for this test
          includeChats: true,
          includeArchivedChats: true,
          notes: 'Integration test export with chat data',
        );

        expect(exportResult.success, true, reason: 'Export should succeed');
        expect(exportResult.manifestFile, isNotNull);
        expect(exportResult.ndjsonFiles, isNotNull);

        // Verify export files exist
        expect(await File('${exportDir.path}/manifest.json').exists(), true);
        expect(await File('${exportDir.path}/nodes.jsonl').exists(), true);
        expect(await File('${exportDir.path}/edges.jsonl').exists(), true);
        expect(await File('${exportDir.path}/pointers.jsonl').exists(), true);

        // Step 3: Verify export content
        print('🔍 Verifying export content...');

        // Read and verify nodes
        final nodesContent = await File('${exportDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');

        var chatSessionNodes = 0;
        var chatMessageNodes = 0;

        for (final line in nodeLines) {
          final node = jsonDecode(line);
          if (node['type'] == 'ChatSession') {
            chatSessionNodes++;
            expect(node['schema_version'], anyOf('node.v1', 'node.v2'));
            expect(node['content'], isNotNull);
          } else if (node['type'] == 'ChatMessage') {
            chatMessageNodes++;
            expect(node['schema_version'], anyOf('node.v1', 'node.v2'));
            expect(node['content'], isNotNull);
          }
        }

        expect(chatSessionNodes, 2, reason: 'Should export 2 chat sessions');
        expect(chatMessageNodes, 3, reason: 'Should export 3 chat messages');

        // Read and verify edges
        final edgesContent = await File('${exportDir.path}/edges.jsonl').readAsString();
        if (edgesContent.trim().isNotEmpty) {
          final edgeLines = edgesContent.trim().split('\n');
          var containsEdges = 0;

          for (final line in edgeLines) {
            final edge = jsonDecode(line);
            if (edge['relation'] == 'contains') {
              containsEdges++;
              expect(edge['source'], startsWith('session:'));
              expect(edge['target'], startsWith('msg:'));
            }
          }

          expect(containsEdges, 3, reason: 'Should have 3 contains edges');
        }

        // Step 4: Clear original data
        print('🗑️ Clearing original data...');

        await chatRepo.deleteSession(sessionId1);
        await chatRepo.deleteSession(sessionId2);

        final statsAfterClear = await chatRepo.getStats();
        expect(statsAfterClear['total_sessions'], 0);
        expect(statsAfterClear['total_messages'], 0);

        // Step 5: Import data back
        print('📥 Importing data back from MCP...');

        final importResult = await miraService.importFromMcpEnhanced(
          bundleDir: exportDir,
          options: const McpImportOptions(
            dryRun: false,
            verifyCas: false,
            strictMode: false,
            rebuildIndexes: true,
          ),
        );

        expect(importResult.success, true, reason: 'Import should succeed: ${importResult.message}');
        expect(importResult.counts['chat_sessions'], 2, reason: 'Should import 2 sessions');
        expect(importResult.counts['chat_messages'], 3, reason: 'Should import 3 messages');

        // Step 6: Verify imported data
        print('✅ Verifying imported data...');

        final finalStats = await chatRepo.getStats();
        expect(finalStats['total_sessions'], 2);
        expect(finalStats['total_messages'], 3);

        // Verify sessions can be retrieved
        final importedSessions = await chatRepo.listAll(includeArchived: true);
        expect(importedSessions.length, 2);

        // Check session content
        var foundTestSession1 = false;
        var foundTestSession2 = false;

        for (final session in importedSessions) {
          if (session.subject == 'Test Chat Session 1') {
            foundTestSession1 = true;
            expect(session.tags, containsAll(['test', 'integration']));

            final messages = await chatRepo.getMessages(session.id);
            expect(messages.length, 2);
            expect(messages[0].content, contains('Hello LUMARA'));
            expect(messages[1].content, contains('integration test'));
          } else if (session.subject == 'Test Chat Session 2') {
            foundTestSession2 = true;
            expect(session.tags, containsAll(['test', 'demo']));
            expect(session.isArchived, true, reason: 'Session should remain archived after import');

            final messages = await chatRepo.getMessages(session.id);
            expect(messages.length, 1);
            expect(messages[0].content, contains('export functionality'));
          }
        }

        expect(foundTestSession1, true, reason: 'Should find Test Chat Session 1');
        expect(foundTestSession2, true, reason: 'Should find Test Chat Session 2');

        print('🎉 End-to-end test completed successfully!');
      });

      test('should handle export with mixed content types', () async {
        // Create chat data
        final sessionId = await chatRepo.createSession(subject: 'Mixed Content Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'This message contains an email: test@example.com and phone: 555-1234',
        );

        // Create mock journal entries
        final journalEntries = [
          JournalEntry(
            id: 'journal_1',
            title: 'Testing Conversation',
            content: 'Today I had a great conversation with LUMARA about testing.',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: ['journal', 'testing'],
            mood: 'Excited',
            metadata: {'phase': 'Discovery'},
          ),
        ];

        final exportDir = Directory('${tempDir.path}/mixed_export');
        final exportResult = await miraService.exportToMcpEnhanced(
          outputDir: exportDir,
          journalEntries: journalEntries,
          includeChats: true,
          notes: 'Mixed content export test',
        );

        expect(exportResult.success, true);

        // Verify mixed content in nodes
        final nodesContent = await File('${exportDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');

        var journalNodes = 0;
        var chatNodes = 0;

        for (final line in nodeLines) {
          final node = jsonDecode(line);
          if (node['type'] == 'journal_entry') {
            journalNodes++;
          } else if (['ChatSession', 'ChatMessage'].contains(node['type'])) {
            chatNodes++;
          }
        }

        expect(journalNodes, greaterThan(0), reason: 'Should have journal entries');
        expect(chatNodes, greaterThan(0), reason: 'Should have chat data');

        print('✅ Mixed content export test passed!');
      });

      test('should handle import errors gracefully', () async {
        // Create invalid MCP bundle
        final invalidDir = Directory('${tempDir.path}/invalid_bundle');
        await invalidDir.create();

        // Create malformed manifest
        final manifestFile = File('${invalidDir.path}/manifest.json');
        await manifestFile.writeAsString('{"invalid": "json"}');

        // Create empty nodes file
        final nodesFile = File('${invalidDir.path}/nodes.jsonl');
        await nodesFile.writeAsString('');

        final importResult = await miraService.importFromMcpEnhanced(
          bundleDir: invalidDir,
          options: const McpImportOptions(
            dryRun: false,
            strictMode: false,
            maxErrors: 10,
          ),
        );

        expect(importResult.success, false);
        expect(importResult.errors, isNotEmpty);

        print('✅ Error handling test passed!');
      });

      test('should validate schema compliance', () async {
        // Create test data
        final sessionId = await chatRepo.createSession(subject: 'Schema Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Testing schema compliance',
        );

        final exportDir = Directory('${tempDir.path}/schema_test');
        await miraService.exportToMcpEnhanced(
          outputDir: exportDir,
          journalEntries: [],
          includeChats: true,
        );

        // Validate all exported nodes comply with schemas
        final nodesContent = await File('${exportDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');

        for (final line in nodeLines) {
          final nodeData = jsonDecode(line);

          // Basic schema validation
          expect(nodeData['kind'], isNull); // Nodes don't have 'kind' field in v2
          expect(nodeData['id'], isNotNull);
          expect(nodeData['type'], isNotNull);
          expect(nodeData['timestamp'], isNotNull);
          expect(nodeData['schema_version'], anyOf('node.v1', 'node.v2'));

          // Chat-specific validation
          if (['ChatSession', 'ChatMessage'].contains(nodeData['type'])) {
            expect(nodeData['content'], isNotNull);

            if (nodeData['type'] == 'ChatSession') {
              expect(nodeData['content']['title'], isNotNull);
            } else if (nodeData['type'] == 'ChatMessage') {
              expect(nodeData['content']['text'], isNotNull);
            }
          }
        }

        // Validate edges
        final edgesContent = await File('${exportDir.path}/edges.jsonl').readAsString();
        if (edgesContent.trim().isNotEmpty) {
          final edgeLines = edgesContent.trim().split('\n');

          for (final line in edgeLines) {
            final edgeData = jsonDecode(line);

            expect(edgeData['kind'], 'edge');
            expect(edgeData['source'], isNotNull);
            expect(edgeData['target'], isNotNull);
            expect(edgeData['relation'], isNotNull);
            expect(edgeData['timestamp'], isNotNull);
            expect(edgeData['schema_version'], 'edge.v1');
          }
        }

        print('✅ Schema validation test passed!');
      });
    });

    group('Performance and Scale', () {
      test('should handle large chat datasets efficiently', () async {
        print('📈 Testing performance with large dataset...');

        // Create multiple sessions with many messages
        final sessionIds = <String>[];

        for (int i = 0; i < 10; i++) {
          final sessionId = await chatRepo.createSession(
            subject: 'Performance Test Session $i',
            tags: ['performance', 'test', 'session$i'],
          );
          sessionIds.add(sessionId);

          // Add multiple messages per session
          for (int j = 0; j < 20; j++) {
            await chatRepo.addMessage(
              sessionId: sessionId,
              role: j % 2 == 0 ? MessageRole.user : MessageRole.assistant,
              content: 'Message $j in session $i - testing performance with longer content that simulates real conversation data.',
            );
          }
        }

        // Export with timing
        final stopwatch = Stopwatch()..start();
        final exportDir = Directory('${tempDir.path}/performance_export');

        final exportResult = await miraService.exportToMcpEnhanced(
          outputDir: exportDir,
          journalEntries: [],
          includeChats: true,
        );

        stopwatch.stop();

        expect(exportResult.success, true);
        expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // Should complete within 30 seconds

        // Verify export count
        final stats = await chatRepo.getStats();
        expect(stats['total_sessions'], 10);
        expect(stats['total_messages'], 200);

        print('✅ Performance test completed in ${stopwatch.elapsedMilliseconds}ms');
      });
    });
  });
}

/// Mock journal entry for testing
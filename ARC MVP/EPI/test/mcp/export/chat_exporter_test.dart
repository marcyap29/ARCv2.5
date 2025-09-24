import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// import 'package:hive_test/hive_test.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/lumara/chat/chat_repo_impl.dart';
import 'package:my_app/lumara/chat/privacy_redactor.dart';
import 'package:my_app/lumara/chat/provenance_tracker.dart';
import 'package:my_app/mcp/export/chat_exporter.dart';

void main() {
  group('ChatMcpExporter Tests', () {
    late ChatRepoImpl chatRepo;
    late ChatMcpExporter exporter;
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

      // Create test exporter with default settings
      exporter = ChatMcpExporter(chatRepo);

      // Create temp directory for exports
      tempDir = await Directory.systemTemp.createTemp('chat_export_test');
    });

    tearDown(() async {
      await chatRepo.close();
      await Hive.deleteFromDisk();

      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Basic Export Functionality', () {
      test('should export empty database', () async {
        final outputDir = Directory('${tempDir.path}/empty_export');

        await exporter.exportChatsToMcp(outputDir: outputDir);

        // Verify files exist
        expect(await File('${outputDir.path}/nodes.jsonl').exists(), true);
        expect(await File('${outputDir.path}/edges.jsonl').exists(), true);
        expect(await File('${outputDir.path}/pointers.jsonl').exists(), true);
        expect(await File('${outputDir.path}/manifest.json').exists(), true);

        // Verify manifest content
        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        expect(manifest['files']['nodes_jsonl']['records'], 0);
        expect(manifest['files']['edges_jsonl']['records'], 0);
        expect(manifest['files']['pointers_jsonl']['records'], 0);
      });

      test('should export single session with messages', () async {
        // Create test session with messages
        final sessionId = await chatRepo.createSession(subject: 'Test Export Session');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Hello LUMARA',
        );
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.assistant,
          content: 'Hello! How can I help you today?',
        );

        final outputDir = Directory('${tempDir.path}/single_session_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        // Verify node count (1 session + 2 messages = 3 nodes)
        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        expect(manifest['files']['nodes_jsonl']['records'], 3);
        expect(manifest['files']['edges_jsonl']['records'], 2); // 2 contains edges
        expect(manifest['files']['pointers_jsonl']['records'], 1); // 1 session pointer

        // Verify node structure
        final nodesContent = await File('${outputDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');
        expect(nodeLines.length, 3);

        // Parse first node (should be session)
        final sessionNode = jsonDecode(nodeLines[0]);
        expect(sessionNode['kind'], 'node');
        expect(sessionNode['type'], 'ChatSession');
        expect(sessionNode['id'], 'session:$sessionId');
        expect(sessionNode['content']['title'], 'Test Export Session');
        expect(sessionNode['schema_version'], 'node.v2');
      });

      test('should export with date filtering', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));

        // Create sessions with different dates
        await chatRepo.createSession(subject: 'Old Session');
        await chatRepo.createSession(subject: 'New Session');

        final outputDir = Directory('${tempDir.path}/date_filtered_export');
        await exporter.exportChatsToMcp(
          outputDir: outputDir,
          since: yesterday,
          until: tomorrow,
        );

        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        // Should export both sessions (created today)
        expect(manifest['files']['nodes_jsonl']['records'], 2);
        expect(manifest['files']['pointers_jsonl']['records'], 2);
      });

      test('should exclude archived sessions when includeArchived is false', () async {
        // Create sessions
        final activeId = await chatRepo.createSession(subject: 'Active Session');
        final archivedId = await chatRepo.createSession(subject: 'Archived Session');

        // Archive one session
        await chatRepo.archiveSession(archivedId, true);

        final outputDir = Directory('${tempDir.path}/active_only_export');
        await exporter.exportChatsToMcp(
          outputDir: outputDir,
          includeArchived: false,
        );

        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        // Should only export active session
        expect(manifest['files']['nodes_jsonl']['records'], 1);
        expect(manifest['files']['pointers_jsonl']['records'], 1);

        // Verify it's the active session
        final nodesContent = await File('${outputDir.path}/nodes.jsonl').readAsString();
        final sessionNode = jsonDecode(nodesContent.trim());
        expect(sessionNode['id'], 'session:$activeId');
      });
    });

    group('Privacy Redaction', () {
      test('should redact PII when privacy is enabled', () async {
        final privacyRedactor = const ChatPrivacyRedactor(
          enabled: true,
          maskPii: true,
        );
        final privacyExporter = ChatMcpExporter(
          chatRepo,
          privacyRedactor: privacyRedactor,
        );

        // Create session with PII content
        final sessionId = await chatRepo.createSession(subject: 'Privacy Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'My email is john.doe@example.com and my phone is 555-123-4567',
        );

        final outputDir = Directory('${tempDir.path}/privacy_export');
        await privacyExporter.exportChatsToMcp(outputDir: outputDir);

        // Verify redaction in nodes
        final nodesContent = await File('${outputDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');

        // Find message node (should be second line)
        final messageNode = jsonDecode(nodeLines[1]);
        expect(messageNode['type'], 'ChatMessage');
        expect(messageNode['content']['text'], contains('[REDACTED-'));
        expect(messageNode['metadata']['privacy']['contains_pii'], true);
        expect(messageNode['metadata']['privacy']['detected_patterns'], 2);
      });

      test('should preserve original hash when enabled', () async {
        final privacyRedactor = const ChatPrivacyRedactor(
          enabled: true,
          preserveHashes: true,
        );
        final privacyExporter = ChatMcpExporter(
          chatRepo,
          privacyRedactor: privacyRedactor,
        );

        final sessionId = await chatRepo.createSession(subject: 'Hash Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Regular message without PII',
        );

        final outputDir = Directory('${tempDir.path}/hash_export');
        await privacyExporter.exportChatsToMcp(outputDir: outputDir);

        final nodesContent = await File('${outputDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');
        final messageNode = jsonDecode(nodeLines[1]);

        // Should have original hash even for non-PII content
        expect(messageNode['metadata']['privacy'], isNotNull);
        expect(messageNode['metadata']['privacy']['original_hash'], isNotNull);
      });
    });

    group('Provenance Tracking', () {
      test('should include provenance metadata in manifest', () async {
        final outputDir = Directory('${tempDir.path}/provenance_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        expect(manifest['provenance'], isNotNull);
        expect(manifest['provenance']['source'], 'LUMARA');
        expect(manifest['provenance']['timestamp'], isNotNull);
        expect(manifest['provenance']['export_context'], isNotNull);
        expect(manifest['provenance']['export_context']['feature'], 'chat_memory');
        expect(manifest['provenance']['export_context']['format'], 'mcp_v1');
      });

      test('should clear provenance cache', () async {
        // Get initial provenance
        final tracker = ChatProvenanceTracker.instance;
        final provenance1 = await tracker.getProvenanceMetadata();

        // Clear cache and get again
        tracker.clearCache();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should have different timestamps
        expect(provenance1['timestamp'], isNot(equals(provenance2['timestamp'])));
      });
    });

    group('Schema Validation', () {
      test('should generate valid node.v2 format', () async {
        final sessionId = await chatRepo.createSession(subject: 'Schema Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Test message',
        );

        final outputDir = Directory('${tempDir.path}/schema_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        final nodesContent = await File('${outputDir.path}/nodes.jsonl').readAsString();
        final nodeLines = nodesContent.trim().split('\n');

        for (final line in nodeLines) {
          final node = jsonDecode(line);

          // Verify required node.v2 fields
          expect(node['kind'], 'node');
          expect(node['id'], isNotNull);
          expect(node['timestamp'], isNotNull);
          expect(node['content'], isNotNull);
          expect(node['schema_version'], 'node.v2');

          // Verify type-specific fields
          if (node['type'] == 'ChatSession') {
            expect(node['content']['title'], isNotNull);
            expect(node['metadata']['messageCount'], isA<int>());
          } else if (node['type'] == 'ChatMessage') {
            expect(node['content']['mime'], 'text/plain');
            expect(node['content']['text'], isNotNull);
            expect(node['metadata']['role'], isNotNull);
          }
        }
      });

      test('should generate valid edge.v1 format', () async {
        final sessionId = await chatRepo.createSession(subject: 'Edge Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Test message',
        );

        final outputDir = Directory('${tempDir.path}/edge_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        final edgesContent = await File('${outputDir.path}/edges.jsonl').readAsString();
        final edgeLines = edgesContent.trim().split('\n');

        for (final line in edgeLines) {
          final edge = jsonDecode(line);

          // Verify required edge.v1 fields
          expect(edge['kind'], 'edge');
          expect(edge['source'], startsWith('session:'));
          expect(edge['target'], startsWith('msg:'));
          expect(edge['relation'], 'contains');
          expect(edge['timestamp'], isNotNull);
          expect(edge['schema_version'], 'edge.v1');
          expect(edge['metadata']['order'], isA<int>());
        }
      });

      test('should generate valid manifest with checksums', () async {
        await chatRepo.createSession(subject: 'Checksum Test');

        final outputDir = Directory('${tempDir.path}/checksum_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        // Verify manifest structure
        expect(manifest['bundle_id'], isNotNull);
        expect(manifest['version'], '1.0.0');
        expect(manifest['schema_version'], '1.0.0');
        expect(manifest['created_at'], isNotNull);
        expect(manifest['files'], isNotNull);

        // Verify file checksums
        for (final fileInfo in manifest['files'].values) {
          expect(fileInfo['path'], isNotNull);
          expect(fileInfo['records'], isA<int>());
          expect(fileInfo['checksum'], startsWith('sha256:'));
        }

        // Verify schema references
        expect(manifest['schemas']['node_v2'], 'schemas/node.v2.json');
        expect(manifest['schemas']['edge_v1'], 'schemas/edge.v1.json');
      });
    });

    group('Export Configuration', () {
      test('should use full archive config', () async {
        final config = ChatExportConfig.fullArchive(notes: 'Test export');

        expect(config.mode, ChatExportMode.fullArchive);
        expect(config.includeArchived, true);
        expect(config.profile, 'full_chat_archive');
        expect(config.notes, 'Test export');
      });

      test('should use active only config', () async {
        final config = ChatExportConfig.activeOnly(notes: 'Active only');

        expect(config.mode, ChatExportMode.activeOnly);
        expect(config.includeArchived, false);
        expect(config.profile, 'active_chat_archive');
        expect(config.notes, 'Active only');
      });

      test('should use date bounded config', () async {
        final since = DateTime.now().subtract(const Duration(days: 7));
        final until = DateTime.now();

        final config = ChatExportConfig.dateBounded(
          since: since,
          until: until,
          notes: 'Weekly export',
        );

        expect(config.mode, ChatExportMode.dateBounded);
        expect(config.since, since);
        expect(config.until, until);
        expect(config.profile, 'date_bounded_chat_archive');
        expect(config.notes, 'Weekly export');
      });
    });

    group('Error Handling', () {
      test('should handle export to non-existent directory', () async {
        final outputDir = Directory('${tempDir.path}/non_existent/deep/path');

        // Should create directory and export successfully
        await exporter.exportChatsToMcp(outputDir: outputDir);

        expect(await outputDir.exists(), true);
        expect(await File('${outputDir.path}/manifest.json').exists(), true);
      });

      test('should handle large exports gracefully', () async {
        // Create multiple sessions with many messages
        for (int i = 0; i < 10; i++) {
          final sessionId = await chatRepo.createSession(subject: 'Session $i');
          for (int j = 0; j < 20; j++) {
            await chatRepo.addMessage(
              sessionId: sessionId,
              role: j % 2 == 0 ? MessageRole.user : MessageRole.assistant,
              content: 'Message $j in session $i',
            );
          }
        }

        final outputDir = Directory('${tempDir.path}/large_export');
        await exporter.exportChatsToMcp(outputDir: outputDir);

        final manifestContent = await File('${outputDir.path}/manifest.json').readAsString();
        final manifest = jsonDecode(manifestContent);

        // Should export all data
        expect(manifest['files']['nodes_jsonl']['records'], 210); // 10 sessions + 200 messages
        expect(manifest['files']['edges_jsonl']['records'], 200); // 200 contains edges
        expect(manifest['files']['pointers_jsonl']['records'], 10); // 10 session pointers
      });
    });
  });
}
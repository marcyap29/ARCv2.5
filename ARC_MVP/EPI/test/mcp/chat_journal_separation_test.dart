import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/export/mcp_export_service.dart';
import 'package:my_app/mira/store/mcp/import/mcp_import_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';
import 'package:my_app/mira/store/mcp/utils/chat_journal_detector.dart';

void main() {
  group('MCP Chat/Journal Separation', () {
    test('should separate chat messages from journal entries during export', () async {
      // Create test journal entries including chat messages
      final testEntries = [
        JournalEntry(
          id: '1',
          title: 'Real Journal Entry',
          content: 'I had a great day today. Went for a walk and felt refreshed.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: const [],
          mood: 'happy',
          phase: 'Discovery',
          keywords: const ['walk', 'refreshed'],
          media: const [],
          metadata: const {'source': 'ARC'},
        ),
        JournalEntry(
          id: '2',
          title: 'LUMARA Chat',
          content: 'Hello! I\'m LUMARA, your personal assistant. What would you like to know?',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: const [],
          mood: 'neutral',
          phase: 'Discovery',
          keywords: const [],
          media: const [],
          metadata: const {'source': 'LUMARA_Assistant'},
        ),
        JournalEntry(
          id: '3',
          title: 'User Chat Input',
          content: 'Tell me about my patterns',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: const [],
          mood: 'neutral',
          phase: 'Discovery',
          keywords: const [],
          media: const [],
          metadata: const {'source': 'LUMARA_Chat'},
        ),
      ];

      // Create export service
      final exportService = McpExportService();
      
      // Test the separation logic using ChatJournalDetector utility
      final (chatMessages, journalEntries) = ChatJournalDetector.separateJournalEntries(testEntries);
      
      // Verify separation
      expect(journalEntries.length, 1);
      expect(chatMessages.length, 2);
      
      expect(journalEntries.first.id, '1');
      expect(chatMessages.map((e) => e.id).toList(), ['2', '3']);
    });

    test('should detect chat messages in MCP nodes during import', () async {
      // Create test MCP nodes
      final chatNode = McpNode(
        id: 'chat-1',
        type: 'journal_entry',
        contentSummary: 'Hello! I\'m LUMARA, your personal assistant.',
        metadata: {
          'source': 'LUMARA_Assistant',
          'entry_type': 'user_input',
        },
        timestamp: DateTime.now().toUtc(),
        schemaVersion: '1.0.0',
        provenance: const McpProvenance(source: 'test', device: 'test'),
      );

      final journalNode = McpNode(
        id: 'journal-1',
        type: 'journal_entry',
        contentSummary: 'I had a great day today. Went for a walk.',
        metadata: {
          'source': 'ARC',
          'entry_type': 'journal_entry',
        },
        timestamp: DateTime.now().toUtc(),
        schemaVersion: '1.0.0',
        provenance: const McpProvenance(source: 'test', device: 'test'),
      );

      // Create import service
      final importService = McpImportService();
      
      // Test detection using ChatJournalDetector utility
      expect(ChatJournalDetector.isChatMessageNode(chatNode), true);
      expect(ChatJournalDetector.isChatMessageNode(journalNode), false);
    });
  });
}

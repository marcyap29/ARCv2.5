import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/utils/chat_journal_detector.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';
import 'package:my_app/models/journal_entry_model.dart';

void main() {
  group('ChatJournalDetector', () {
    group('isChatMessageNode', () {
      test('should detect LUMARA assistant messages by content', () {
        final node = McpNode(
          id: 'test-1',
          type: 'journal_entry',
          contentSummary: 'Hello! I\'m LUMARA, your personal assistant. What would you like to know?',
          metadata: {'source': 'ARC'},
          timestamp: DateTime.now().toUtc(),
          schemaVersion: '1.0.0',
          provenance: McpProvenance(source: 'test'),
        );

        expect(ChatJournalDetector.isChatMessageNode(node), true);
      });

      test('should detect chat messages by metadata source', () {
        final node = McpNode(
          id: 'test-2',
          type: 'journal_entry',
          contentSummary: 'Tell me about my patterns',
          metadata: {'source': 'LUMARA_Chat'},
          timestamp: DateTime.now().toUtc(),
          schemaVersion: '1.0.0',
          provenance: McpProvenance(source: 'test'),
        );

        expect(ChatJournalDetector.isChatMessageNode(node), true);
      });

      test('should detect short user inputs as chat', () {
        final node = McpNode(
          id: 'test-3',
          type: 'journal_entry',
          contentSummary: 'What should I do?',
          metadata: {
            'entry_type': 'user_input',
            'source': 'ARC',
          },
          timestamp: DateTime.now().toUtc(),
          schemaVersion: '1.0.0',
          provenance: McpProvenance(source: 'test'),
        );

        expect(ChatJournalDetector.isChatMessageNode(node), true);
      });

      test('should not detect journal entries as chat', () {
        final node = McpNode(
          id: 'test-4',
          type: 'journal_entry',
          contentSummary: 'I had a great day today. Went for a walk and felt refreshed. The weather was beautiful and I enjoyed the fresh air.',
          metadata: {'source': 'ARC'},
          timestamp: DateTime.now().toUtc(),
          schemaVersion: '1.0.0',
          provenance: McpProvenance(source: 'test'),
        );

        expect(ChatJournalDetector.isChatMessageNode(node), false);
      });
    });

    group('isChatMessageEntry', () {
      test('should detect LUMARA assistant messages', () {
        final entry = JournalEntry(
          id: 'test-1',
          title: 'LUMARA Response',
          content: 'I\'m here to help you with your questions. How can I assist you today?',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          mood: 'neutral',
          phase: 'Discovery',
          keywords: [],
          media: [],
          metadata: {'source': 'ARC'},
        );

        expect(ChatJournalDetector.isChatMessageEntry(entry), true);
      });

      test('should detect chat messages by metadata', () {
        final entry = JournalEntry(
          id: 'test-2',
          title: 'User Question',
          content: 'Can you help me understand this?',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          mood: 'neutral',
          phase: 'Discovery',
          keywords: [],
          media: [],
          metadata: {'source': 'LUMARA_Assistant'},
        );

        expect(ChatJournalDetector.isChatMessageEntry(entry), true);
      });

      test('should not detect journal entries as chat', () {
        final entry = JournalEntry(
          id: 'test-3',
          title: 'Daily Reflection',
          content: 'Today was a productive day. I completed several important tasks and felt accomplished.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          mood: 'happy',
          phase: 'Discovery',
          keywords: ['productive', 'accomplished'],
          media: [],
          metadata: {'source': 'ARC'},
        );

        expect(ChatJournalDetector.isChatMessageEntry(entry), false);
      });
    });

    group('separateJournalEntries', () {
      test('should separate mixed entries correctly', () {
        final entries = <JournalEntry>[
          JournalEntry(
            id: 'journal-1',
            title: 'Real Journal Entry',
            content: 'I had a great day today.',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: [],
            mood: 'happy',
            phase: 'Discovery',
            keywords: [],
            media: [],
            metadata: {'source': 'ARC'},
          ),
          JournalEntry(
            id: 'chat-1',
            title: 'LUMARA Chat',
            content: 'Hello! I\'m LUMARA, your personal assistant.',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: [],
            mood: 'neutral',
            phase: 'Discovery',
            keywords: [],
            media: [],
            metadata: {'source': 'LUMARA_Assistant'},
          ),
          JournalEntry(
            id: 'chat-2',
            title: 'User Question',
            content: 'Tell me about my patterns',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: [],
            mood: 'neutral',
            phase: 'Discovery',
            keywords: [],
            media: [],
            metadata: {'source': 'LUMARA_Chat'},
          ),
        ];

        final (chatMessages, journalEntries) = ChatJournalDetector.separateJournalEntries(entries);

        expect(chatMessages.length, 2);
        expect(journalEntries.length, 1);
        expect(chatMessages.map((e) => e.id).toList(), ['chat-1', 'chat-2']);
        expect(journalEntries.map((e) => e.id).toList(), ['journal-1']);
      });
    });

    group('separateMcpNodes', () {
      test('should separate MCP nodes correctly', () {
        final nodes = <McpNode>[
          McpNode(
            id: 'journal-1',
            type: 'journal_entry',
            contentSummary: 'I had a great day today.',
            metadata: {'source': 'ARC'},
            timestamp: DateTime.now().toUtc(),
            schemaVersion: '1.0.0',
            provenance: McpProvenance(source: 'test'),
          ),
          McpNode(
            id: 'chat-1',
            type: 'journal_entry',
            contentSummary: 'Hello! I\'m LUMARA, your personal assistant.',
            metadata: {'source': 'LUMARA_Assistant'},
            timestamp: DateTime.now().toUtc(),
            schemaVersion: '1.0.0',
            provenance: McpProvenance(source: 'test'),
          ),
          McpNode(
            id: 'other-1',
            type: 'other_type',
            contentSummary: 'Some other content',
            metadata: {},
            timestamp: DateTime.now().toUtc(),
            schemaVersion: '1.0.0',
            provenance: McpProvenance(source: 'test'),
          ),
        ];

        final (chatNodes, journalNodes) = ChatJournalDetector.separateMcpNodes(nodes);

        expect(chatNodes.length, 1);
        expect(journalNodes.length, 2);
        expect(chatNodes.map((n) => n.id).toList(), ['chat-1']);
        expect(journalNodes.map((n) => n.id).toList(), ['journal-1', 'other-1']);
      });
    });
  });
}

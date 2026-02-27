import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/raw_entry_schema.dart';

void main() {
  group('Layer0Repository', () {
    late Layer0Repository repository;
    const testUserId = 'test_user_123';

    setUpAll(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
    });

    setUp(() async {
      repository = Layer0Repository();
      // Note: In real tests, you'd want to use a test database
      // For now, we'll test the structure
    });

    tearDown(() async {
      // Cleanup
      await repository.close();
    });

    test('repository can be instantiated', () {
      expect(repository, isNotNull);
    });

    test('can create raw entry schema', () {
      final schema = RawEntrySchema(
        entryId: 'test_entry_1',
        timestamp: DateTime.now(),
        content: 'Test journal entry content',
        metadata: const RawEntryMetadata(
          wordCount: 5,
          voiceTranscribed: false,
          mediaAttachments: [],
        ),
        analysis: const RawEntryAnalysis(
          extractedThemes: ['test_theme'],
          keywords: ['test', 'entry'],
        ),
      );

      expect(schema.entryId, 'test_entry_1');
      expect(schema.content, 'Test journal entry content');
      expect(schema.analysis.extractedThemes, contains('test_theme'));
    });

    test('raw entry schema can be serialized to JSON', () {
      final schema = RawEntrySchema(
        entryId: 'test_entry_1',
        timestamp: DateTime(2025, 1, 15, 10, 30),
        content: 'Test content',
        metadata: const RawEntryMetadata(wordCount: 2),
        analysis: const RawEntryAnalysis(
          extractedThemes: ['theme1'],
          keywords: ['keyword1'],
        ),
      );

      final json = schema.toJson();
      
      expect(json['entry_id'], 'test_entry_1');
      expect(json['content'], 'Test content');
      expect(json['metadata']['word_count'], 2);
      expect(json['analysis']['extracted_themes'], ['theme1']);
    });

    test('raw entry schema can be deserialized from JSON', () {
      final json = {
        'entry_id': 'test_entry_1',
        'timestamp': '2025-01-15T10:30:00.000Z',
        'content': 'Test content',
        'metadata': {
          'word_count': 2,
          'voice_transcribed': false,
          'media_attachments': [],
        },
        'analysis': {
          'extracted_themes': ['theme1'],
          'keywords': ['keyword1'],
        },
      };

      final schema = RawEntrySchema.fromJson(json);
      
      expect(schema.entryId, 'test_entry_1');
      expect(schema.content, 'Test content');
      expect(schema.metadata.wordCount, 2);
      expect(schema.analysis.extractedThemes, contains('theme1'));
    });
  });
}

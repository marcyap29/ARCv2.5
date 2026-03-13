// Phase 5a: Path tags and content tags from sample data.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';

void main() {
  group('pathTags', () {
    test('scanner scans -> [scanner, scans]', () {
      expect(pathTags('scanner', 'scans'), ['scanner', 'scans']);
    });
    test('scanner always -> [scanner, scans]', () {
      expect(pathTags('scanner', 'inferences'), ['scanner', 'scans']);
      expect(pathTags('scanner', 'scans'), ['scanner', 'scans']);
    });
    test('research research -> [research]', () {
      expect(pathTags('research', 'research'), ['research']);
    });
    test('writer linkedin -> [writer, linkedin]', () {
      expect(pathTags('writer', 'linkedin'), ['writer', 'linkedin']);
    });
  });

  group('contentTagsFromBrief', () {
    test('extracts up to 3 keywords from title', () {
      final brief = ContentBrief(
        title: 'Machine Learning in Healthcare',
        summary: '',
        createdAt: DateTime.now(),
        query: 'ml health',
      );
      final tags = contentTagsFromBrief(brief);
      expect(tags.length, lessThanOrEqualTo(3));
      expect(tags.any((t) => t.contains('machine') || t.contains('learning')), true);
    });
  });

  group('normaliseUserTag', () {
    test('lowercase and spaces to hyphens', () {
      expect(normaliseUserTag('Machine Learning'), 'machine-learning');
    });
    test('max 30 chars', () {
      expect(normaliseUserTag('a' * 40).length, 30);
    });
  });
}

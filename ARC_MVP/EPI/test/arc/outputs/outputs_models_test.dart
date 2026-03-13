// Phase 5a: OutputItem serialisation to/from Firestore map.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';

void main() {
  group('OutputItem', () {
    test('toFirestore and fromFirestore round-trip', () {
      final item = OutputItem(
        id: 'test-id',
        agentKey: 'scanner',
        folderKey: 'inferences',
        title: 'Test title',
        createdAt: DateTime.utc(2025, 3, 10, 12, 0),
        contentJson: '{"key":"value"}',
        autoTags: ['scanner', 'inferences', 'invoice'],
        userTags: ['my-tag'],
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      final data = item.toFirestore();
      final restored = OutputItem.fromFirestore(item.id, data);
      expect(restored.id, item.id);
      expect(restored.agentKey, item.agentKey);
      expect(restored.folderKey, item.folderKey);
      expect(restored.title, item.title);
      expect(restored.autoTags, item.autoTags);
      expect(restored.userTags, item.userTags);
      expect(restored.contentJson, item.contentJson);
      expect(restored.thumbnailUrl, item.thumbnailUrl);
    });

    test('fromFirestore handles string createdAt', () {
      final data = {
        'agentKey': 'research',
        'folderKey': 'research',
        'title': 'Brief',
        'createdAt': '2025-03-10T12:00:00.000Z',
        'contentJson': null,
        'autoTags': ['research'],
        'userTags': [],
        'thumbnailUrl': null,
      };
      final item = OutputItem.fromFirestore('id1', data);
      expect(item.createdAt.year, 2025);
      expect(item.createdAt.month, 3);
    });
  });

  group('kOutputFolders', () {
    test('contains all required folder keys', () {
      final keys = kOutputFolders.map((f) => f.fullKey).toSet();
      expect(keys, contains('forms/completed_forms'));
      expect(keys, contains('research/research'));
      expect(keys, contains('scanner/scans'));
      expect(keys, contains('writer/articles'));
      expect(keys, contains('writer/linkedin'));
    });
  });
}

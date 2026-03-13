// Phase 5a: OutputsRepository — save/retrieve. Run with Firestore emulator or mock.
// Without emulator this test is skipped.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';

void main() {
  group('OutputsRepository', () {
    test('OutputItem toFirestore has required keys', () {
      final item = OutputItem(
        id: '',
        agentKey: 'scanner',
        folderKey: 'scans',
        title: 'Scan',
        createdAt: DateTime.now(),
        autoTags: ['scanner', 'scans'],
        userTags: [],
      );
      final data = item.toFirestore();
      expect(data.containsKey('agentKey'), true);
      expect(data.containsKey('folderKey'), true);
      expect(data.containsKey('title'), true);
      expect(data.containsKey('createdAt'), true);
      expect(data.containsKey('autoTags'), true);
      expect(data.containsKey('userTags'), true);
    });
  });
}

// lib/arc/outputs/outputs_chronicle_service.dart
//
// Phase 5a: Fire-and-forget CHRONICLE write-back when an output is saved or tagged.

import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/raw_entry_schema.dart';
import 'package:my_app/services/firebase_auth_service.dart';

class OutputsChronicleService {
  OutputsChronicleService._();
  static final OutputsChronicleService instance = OutputsChronicleService._();

  /// Call after saving an output (create or update). Fire-and-forget; never blocks UI.
  void onOutputSaved({
    required String type,
    required OutputItem item,
  }) {
    assert(type == 'output_created' || type == 'output_tagged');
    _writeToChronicle(type: type, item: item);
  }

  Future<void> _writeToChronicle({
    required String type,
    required OutputItem item,
  }) async {
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) return;

      final allTags = [...item.autoTags, ...item.userTags];
      final content = '${item.title}\n${allTags.join(' ')}'.trim();
      final schema = RawEntrySchema(
        entryId: 'output_${item.id}_${item.createdAt.millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        content: content,
        metadata: const RawEntryMetadata(
          wordCount: 0,
          voiceTranscribed: false,
          mediaAttachments: [],
        ),
        analysis: RawEntryAnalysis(
          entryType: type,
          keywords: allTags,
          outputData: {
            'sourceId': item.id,
            'agentKey': item.agentKey,
            'folderKey': item.folderKey,
            'title': item.title,
            'allTags': allTags,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );
      final entry = ChronicleRawEntry.fromSchema(schema, userId);
      await Layer0Repository().saveEntry(entry);
    } catch (e) {
      // Log but do not surface to user (per spec)
      assert(() {
        print('OutputsChronicleService: write failed $e');
        return true;
      }());
    }
  }
}

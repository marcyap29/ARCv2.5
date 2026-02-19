// test/chronicle/dual/sacred_separation_test.dart
//
// Tests that approved insights live only in LUMARA CHRONICLE (promoted);
// User's CHRONICLE is SACRED. ChronicleQueryAdapter reads entries from user's CHRONICLE Layer0 and annotations from LUMARA CHRONICLE.

import 'dart:io';

import 'package:my_app/chronicle/dual/models/chronicle_models.dart';
import 'package:my_app/chronicle/dual/services/chronicle_query_adapter.dart';
import 'package:my_app/chronicle/dual/repositories/lumara_chronicle_repository.dart';
import 'package:my_app/chronicle/dual/storage/chronicle_storage.dart';
import 'package:my_app/chronicle/dual/services/promotion_service.dart';
import 'package:my_app/chronicle/dual/intelligence/interrupt/clarification_processor.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ChronicleStorage storage;
  late LumaraChronicleRepository lumaraRepo;
  late ChronicleQueryAdapter chronicleAdapter;
  const userId = 'test_user_sacred';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chronicle_dual_test');
    storage = ChronicleStorage(testBaseDirectory: tempDir);
    lumaraRepo = LumaraChronicleRepository(storage);
    chronicleAdapter = ChronicleQueryAdapter(
      lumaraRepo: lumaraRepo,
      loadEntriesOverride: (_) async => [], // No CHRONICLE Layer0 in test
    );
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Sacred Separation', () {
    test('gap-fill events recorded in LUMARA CHRONICLE only', () async {
      final processor = ClarificationProcessor(
        lumaraChronicleRepo: lumaraRepo,
        promotionService: PromotionService(
          lumaraChronicleRepo: lumaraRepo,
        ),
      );

      final gap = Gap(
        id: 'gap1',
        type: GapType.causal_gap,
        severity: GapSeverity.medium,
        description: 'Why',
        topic: 'work',
        requiredFor: 'query',
        fillStrategy: GapFillStrategy.clarify,
        priority: 5,
        identifiedAt: DateTime.now(),
        status: 'open',
      );
      await lumaraRepo.addGap(userId, gap);

      await processor.processClarification(
        userId,
        'Why am I stressed?',
        'Can you say more?',
        'Work feels meaningless',
        gap.id,
      );

      final userEntries = await chronicleAdapter.loadEntries(userId);
      final userAnnotations = await chronicleAdapter.loadAnnotations(userId);
      final lumaraEvents = await lumaraRepo.loadGapFillEvents(userId);

      expect(userEntries.length, 0);
      expect(userAnnotations.length, 0);
      expect(lumaraEvents.length, 1);
    });

    test('promotion marks event as promoted in LUMARA CHRONICLE only', () async {
      final promotionService = PromotionService(
        lumaraChronicleRepo: lumaraRepo,
      );

      final gap = Gap(
        id: 'gap_promote',
        type: GapType.causal_gap,
        severity: GapSeverity.high,
        description: 'Why',
        topic: 'work',
        requiredFor: 'query',
        fillStrategy: GapFillStrategy.clarify,
        priority: 7,
        identifiedAt: DateTime.now(),
        status: 'open',
      );
      await lumaraRepo.addGap(userId, gap);

      final event = GapFillEvent(
        id: 'gf_promote',
        type: GapFillEventType.clarification,
        trigger: GapFillEventTrigger(originalQuery: 'q', identifiedGap: gap),
        process: GapFillEventProcess(userResponse: 'Work is meaningless'),
        extractedSignal: BiographicalSignal(
          concepts: ['work', 'meaning'],
          causalChain: CausalChainSignal(
            trigger: 'work',
            response: 'feels meaningless',
          ),
        ),
        updates: GapFillEventUpdates(gapsFilled: [gap.id]),
        recordedAt: DateTime.now(),
        promotableToAnnotation: true,
      );
      await lumaraRepo.addGapFillEvent(userId, event);

      expect((await chronicleAdapter.loadAnnotations(userId)).length, 0);

      await promotionService.approvePromotion(userId, event.id);

      final annotations = await chronicleAdapter.loadAnnotations(userId);
      expect(annotations.length, 1);
      expect(annotations.first.provenance.userApproved, true);
      expect(annotations.first.provenance.gapFillEventId, event.id);
    });

    test('dismissing promotion leaves approved list unchanged', () async {
      final promotionService = PromotionService(
        lumaraChronicleRepo: lumaraRepo,
      );

      final gap = Gap(
        id: 'gap_dismiss',
        type: GapType.causal_gap,
        severity: GapSeverity.medium,
        description: 'Why',
        topic: 'work',
        requiredFor: 'query',
        fillStrategy: GapFillStrategy.clarify,
        priority: 5,
        identifiedAt: DateTime.now(),
        status: 'open',
      );
      final event = GapFillEvent(
        id: 'gf_dismiss',
        type: GapFillEventType.clarification,
        trigger: GapFillEventTrigger(originalQuery: 'q', identifiedGap: gap),
        process: GapFillEventProcess(userResponse: 'Okay'),
        extractedSignal: BiographicalSignal(concepts: ['work']),
        updates: GapFillEventUpdates(gapsFilled: [gap.id]),
        recordedAt: DateTime.now(),
        promotableToAnnotation: true,
      );
      await lumaraRepo.addGapFillEvent(userId, event);

      await promotionService.dismissPromotion(userId, event.id);

      final annotations = await chronicleAdapter.loadAnnotations(userId);
      expect(annotations.length, 0);

      final events = await lumaraRepo.loadGapFillEvents(userId);
      expect(events.length, 1);
    });

    test('approved insight remains in LUMARA CHRONICLE after promotion', () async {
      final promotionService = PromotionService(
        lumaraChronicleRepo: lumaraRepo,
      );

      final gap = Gap(
        id: 'gap_keep',
        type: GapType.causal_gap,
        severity: GapSeverity.medium,
        description: 'Why',
        topic: 'work',
        requiredFor: 'query',
        fillStrategy: GapFillStrategy.clarify,
        priority: 5,
        identifiedAt: DateTime.now(),
        status: 'open',
      );
      final event = GapFillEvent(
        id: 'gf_keep',
        type: GapFillEventType.clarification,
        trigger: GapFillEventTrigger(originalQuery: 'q', identifiedGap: gap),
        process: GapFillEventProcess(userResponse: 'Stress'),
        extractedSignal: BiographicalSignal(
          concepts: ['stress'],
          causalChain: CausalChainSignal(trigger: 'work', response: 'stress'),
        ),
        updates: GapFillEventUpdates(gapsFilled: [gap.id]),
        recordedAt: DateTime.now(),
        promotableToAnnotation: true,
      );
      await lumaraRepo.addGapFillEvent(userId, event);
      final annotation = await promotionService.approvePromotion(userId, event.id);

      expect((await chronicleAdapter.loadAnnotations(userId)).length, 1);

      final kept = await lumaraRepo.getGapFillEvent(userId, event.id);
      expect(kept, isNotNull);
      expect(kept!.promotedToAnnotation, isNotNull);
      expect(kept.promotedToAnnotation!.annotationId, annotation.id);
    });
  });
}

// test/chronicle/dual/sacred_separation_test.dart
//
// CRITICAL: Tests that the User's Chronicle is never written to by the system
// without explicit user approval.

import 'dart:io';

import 'package:my_app/chronicle/dual/models/chronicle_models.dart';
import 'package:my_app/chronicle/dual/repositories/user_chronicle_repository.dart';
import 'package:my_app/chronicle/dual/repositories/lumara_chronicle_repository.dart';
import 'package:my_app/chronicle/dual/storage/chronicle_storage.dart';
import 'package:my_app/chronicle/dual/services/promotion_service.dart';
import 'package:my_app/chronicle/dual/intelligence/interrupt/clarification_processor.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ChronicleStorage storage;
  late UserChronicleRepository userRepo;
  late LumaraChronicleRepository lumaraRepo;
  const userId = 'test_user_sacred';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chronicle_dual_test');
    storage = ChronicleStorage(testBaseDirectory: tempDir);
    userRepo = UserChronicleRepository(storage);
    lumaraRepo = LumaraChronicleRepository(storage);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Sacred Separation', () {
    test('system cannot write non-user-authored entries to user chronicle', () async {
      final entry = UserEntry(
        id: 'e1',
        timestamp: DateTime.now(),
        type: UserEntryType.reflect,
        content: 'test',
        modality: UserEntryModality.reflect,
        authoredBy: 'system',
      );

      expect(
        () => userRepo.addEntry(userId, entry),
        throwsA(isA<SacredChronicleViolation>()),
      );
    });

    test('annotations require explicit user approval', () async {
      final annotation = UserAnnotation(
        id: 'a1',
        timestamp: DateTime.now(),
        content: 'test insight',
        source: AnnotationSource.lumara_gap_fill,
        provenance: UserAnnotationProvenance(
          gapFillEventId: 'gf1',
          userApproved: false,
          approvedAt: DateTime.now(),
        ),
        editable: true,
      );

      expect(
        () => userRepo.addAnnotation(userId, annotation),
        throwsA(isA<SacredChronicleViolation>()),
      );
    });

    test('user-authored entry is accepted', () async {
      final entry = UserEntry(
        id: 'e_user',
        timestamp: DateTime.now(),
        type: UserEntryType.reflect,
        content: 'I reflected on this',
        modality: UserEntryModality.reflect,
        authoredBy: 'user',
      );

      await userRepo.addEntry(userId, entry);
      final layer0 = await userRepo.queryLayer0(userId, '');
      expect(layer0.entries.length, 1);
      expect(layer0.entries.first.authoredBy, 'user');
    });

    test('user-approved annotation is accepted', () async {
      final annotation = UserAnnotation(
        id: 'a_approved',
        timestamp: DateTime.now(),
        content: 'Approved insight',
        source: AnnotationSource.lumara_gap_fill,
        provenance: UserAnnotationProvenance(
          gapFillEventId: 'gf1',
          userApproved: true,
          approvedAt: DateTime.now(),
        ),
        editable: true,
      );

      await userRepo.addAnnotation(userId, annotation);
      final layer0 = await userRepo.queryLayer0(userId, '');
      expect(layer0.annotations.length, 1);
      expect(layer0.annotations.first.provenance.userApproved, true);
    });

    test('gap-fill events recorded in LUMARA chronicle only', () async {
      final processor = ClarificationProcessor(
        userChronicleRepo: userRepo,
        lumaraChronicleRepo: lumaraRepo,
        promotionService: PromotionService(
          userChronicleRepo: userRepo,
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

      final userEntries = await userRepo.loadEntries(userId);
      final userAnnotations = await userRepo.loadAnnotations(userId);
      final lumaraEvents = await lumaraRepo.loadGapFillEvents(userId);

      expect(userEntries.length, 0);
      expect(userAnnotations.length, 0);
      expect(lumaraEvents.length, 1);
    });

    test('promotion creates annotation only on approval', () async {
      final promotionService = PromotionService(
        userChronicleRepo: userRepo,
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

      expect((await userRepo.loadAnnotations(userId)).length, 0);

      await promotionService.approvePromotion(userId, event.id);

      final annotations = await userRepo.loadAnnotations(userId);
      expect(annotations.length, 1);
      expect(annotations.first.provenance.userApproved, true);
      expect(annotations.first.provenance.gapFillEventId, event.id);
    });

    test('dismissing promotion leaves timeline unchanged', () async {
      final promotionService = PromotionService(
        userChronicleRepo: userRepo,
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

      final annotations = await userRepo.loadAnnotations(userId);
      expect(annotations.length, 0);

      final events = await lumaraRepo.loadGapFillEvents(userId);
      expect(events.length, 1);
    });

    test('user can delete annotation without affecting LUMARA chronicle', () async {
      final promotionService = PromotionService(
        userChronicleRepo: userRepo,
        lumaraChronicleRepo: lumaraRepo,
      );

      final gap = Gap(
        id: 'gap_del',
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
        id: 'gf_del',
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

      await userRepo.deleteAnnotation(userId, annotation.id);

      expect((await userRepo.loadAnnotations(userId)).length, 0);

      final kept = await lumaraRepo.getGapFillEvent(userId, event.id);
      expect(kept, isNotNull);
      expect(kept!.promotedToAnnotation, isNotNull);
    });
  });
}

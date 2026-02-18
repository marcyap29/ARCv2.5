// lib/chronicle/dual/intelligence/interrupt/clarification_processor.dart
//
// Processes user responses to clarifying questions.
// Records learning in LUMARA Chronicle only; offers promotion to User Chronicle.

import '../../models/chronicle_models.dart';
import '../../repositories/user_chronicle_repository.dart';
import '../../repositories/lumara_chronicle_repository.dart';
import '../../services/promotion_service.dart';

class ClarificationProcessingResult {
  final GapFillEvent gapFillEvent;
  final List<CausalChain> newInferences;
  final bool offeredForPromotion;

  const ClarificationProcessingResult({
    required this.gapFillEvent,
    required this.newInferences,
    required this.offeredForPromotion,
  });
}

/// Processes clarifications; writes only to LUMARA Chronicle.
class ClarificationProcessor {
  ClarificationProcessor({
    UserChronicleRepository? userChronicleRepo,
    LumaraChronicleRepository? lumaraChronicleRepo,
    PromotionService? promotionService,
  })  : _userRepo = userChronicleRepo ?? UserChronicleRepository(),
        _lumaraRepo = lumaraChronicleRepo ?? LumaraChronicleRepository(),
        _promotionService = promotionService ?? PromotionService();

  final UserChronicleRepository _userRepo;
  final LumaraChronicleRepository _lumaraRepo;
  final PromotionService _promotionService;

  Future<ClarificationProcessingResult> processClarification(
    String userId,
    String originalQuery,
    String clarifyingQuestion,
    String userResponse,
    String gapId,
  ) async {
    final gap = await _lumaraRepo.getGap(userId, gapId);
    if (gap == null) throw Exception('Gap not found: $gapId');

    final signal = _extractSignal(userResponse, gapId);
    final now = DateTime.now();
    final eventId = 'gf_${gapId}_${now.millisecondsSinceEpoch}';

    final gapFillEvent = GapFillEvent(
      id: eventId,
      type: GapFillEventType.clarification,
      trigger: GapFillEventTrigger(originalQuery: originalQuery, identifiedGap: gap),
      process: GapFillEventProcess(
        clarifyingQuestion: clarifyingQuestion,
        userResponse: userResponse,
      ),
      extractedSignal: signal,
      updates: GapFillEventUpdates(gapsFilled: [gapId]),
      recordedAt: now,
      promotableToAnnotation: _evaluatePromotability(signal),
    );

    await _lumaraRepo.addGapFillEvent(userId, gapFillEvent);

    final newInferences = await _createInferences(userId, signal, gapFillEvent);
    for (final inf in newInferences) {
      await _lumaraRepo.addCausalChain(userId, inf);
    }

    await _lumaraRepo.updateGap(userId, gapId, gap.copyWith(status: 'filled'));

    if (gapFillEvent.promotableToAnnotation) {
      await _promotionService.offerPromotion(userId, gapFillEvent);
    }

    return ClarificationProcessingResult(
      gapFillEvent: gapFillEvent,
      newInferences: newInferences,
      offeredForPromotion: gapFillEvent.promotableToAnnotation,
    );
  }

  BiographicalSignal _extractSignal(String response, String gapId) {
    final concepts = response
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet()
        .toList();
    return BiographicalSignal(concepts: concepts);
  }

  bool _evaluatePromotability(BiographicalSignal signal) {
    if (signal.causalChain != null) return true;
    if (signal.relationship != null) return true;
    if (signal.value != null && signal.value!.importance == 'core') return true;
    return false;
  }

  Future<List<CausalChain>> _createInferences(
    String userId,
    BiographicalSignal signal,
    GapFillEvent event,
  ) async {
    final list = <CausalChain>[];
    if (signal.causalChain != null) {
      final c = signal.causalChain!;
      final id = 'cc_${event.id}_${list.length}';
      list.add(CausalChain(
        id: id,
        trigger: c.trigger,
        response: c.response,
        resolution: c.resolution,
        confidence: 0.8,
        evidence: [],
        frequency: 'observed_once',
        lastObserved: event.recordedAt,
        provenance: Provenance(
          sourceEntries: [],
          generatedAt: event.recordedAt,
          lastUpdated: event.recordedAt,
          algorithm: 'clarification',
        ),
      ));
    }
    return list;
  }
}

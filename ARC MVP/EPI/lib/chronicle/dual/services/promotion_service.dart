// lib/chronicle/dual/services/promotion_service.dart
//
// Manages user-controlled promotion of gap-fill events. On approve, only
// LUMARA CHRONICLE is updated (promotedToAnnotation); approved insights
// are read from LUMARA CHRONICLE by ChronicleQueryAdapter. User's CHRONICLE is never written to.

import '../models/chronicle_models.dart';
import '../repositories/lumara_chronicle_repository.dart';

class PromotionOffer {
  final String id;
  final String gapFillEventId;
  final String suggestedContent;
  final DateTime offeredAt;
  final String status; // 'pending' | 'approved' | 'dismissed'

  const PromotionOffer({
    required this.id,
    required this.gapFillEventId,
    required this.suggestedContent,
    required this.offeredAt,
    this.status = 'pending',
  });
}

/// Callback when a promotion is offered (UI shows "Add to Timeline" / "Dismiss").
typedef OnPromotionOffered = void Function(String userId, PromotionOffer offer);

/// In-memory pending offers; can be replaced with NotificationService/persistence.
class PromotionOfferStore {
  final Map<String, List<PromotionOffer>> _byUser = {};

  void add(String userId, PromotionOffer offer) {
    _byUser.putIfAbsent(userId, () => []).add(offer);
  }

  List<PromotionOffer> getPending(String userId) {
    return (_byUser[userId] ?? [])
        .where((o) => o.status == 'pending')
        .toList();
  }

  void clear(String userId, String gapFillEventId) {
    final list = _byUser[userId];
    if (list == null) return;
    list.removeWhere((o) => o.gapFillEventId == gapFillEventId);
  }
}

class PromotionService {
  PromotionService({
    LumaraChronicleRepository? lumaraChronicleRepo,
    PromotionOfferStore? offerStore,
  })  : _lumaraRepo = lumaraChronicleRepo ?? LumaraChronicleRepository(),
        _offerStore = offerStore ?? PromotionOfferStore();

  final LumaraChronicleRepository _lumaraRepo;
  final PromotionOfferStore _offerStore;

  /// Called when a promotable event is created; creates offer and notifies (e.g. UI).
  OnPromotionOffered? onPromotionOffered;

  /// Offer promotion to user. Does not write to any chronicle.
  Future<void> offerPromotion(String userId, GapFillEvent gapFillEvent) async {
    final suggestedContent = _generateAnnotationContent(gapFillEvent);
    final offer = PromotionOffer(
      id: 'offer_${gapFillEvent.id}_${DateTime.now().millisecondsSinceEpoch}',
      gapFillEventId: gapFillEvent.id,
      suggestedContent: suggestedContent,
      offeredAt: DateTime.now(),
    );
    _offerStore.add(userId, offer);
    onPromotionOffered?.call(userId, offer);
    print('[Promotion] Offered to user: "$suggestedContent"');
    print('[Promotion] Waiting for user decision (approve or dismiss)');
  }

  /// User approves: mark event as promoted in LUMARA CHRONICLE only. Approved
  /// insights appear via ChronicleQueryAdapter.loadAnnotations().
  Future<UserAnnotation> approvePromotion(String userId, String gapFillEventId) async {
    final event = await _lumaraRepo.getGapFillEvent(userId, gapFillEventId);
    if (event == null) throw Exception('Gap-fill event not found: $gapFillEventId');
    if (!event.promotableToAnnotation) {
      throw Exception('This event is not promotable');
    }

    final now = DateTime.now();
    final annotationId = 'ann_${event.id}_${now.millisecondsSinceEpoch}';
    final content = _generateAnnotationContent(event);
    final annotation = UserAnnotation(
      id: annotationId,
      timestamp: now,
      content: content,
      source: AnnotationSource.lumara_gap_fill,
      provenance: UserAnnotationProvenance(
        gapFillEventId: event.id,
        userApproved: true,
        approvedAt: now,
      ),
      editable: true,
    );

    final updated = event.copyWith(
      promotedToAnnotation: PromotedToAnnotation(
        annotationId: annotationId,
        promotedAt: now,
      ),
    );
    await _lumaraRepo.updateGapFillEvent(userId, gapFillEventId, updated);

    _offerStore.clear(userId, gapFillEventId);
    print('[Promotion] Marked as promoted in LUMARA CHRONICLE: ${event.id}');
    return annotation;
  }

  /// User dismisses: timeline unchanged, learning retained in LUMARA CHRONICLE.
  Future<void> dismissPromotion(String userId, String gapFillEventId) async {
    _offerStore.clear(userId, gapFillEventId);
    print('[Promotion] User dismissed promotion: $gapFillEventId');
    print('[Promotion] Timeline unchanged. Learning retained in LUMARA CHRONICLE.');
  }

  List<PromotionOffer> getPendingOffers(String userId) {
    return _offerStore.getPending(userId);
  }

  String _generateAnnotationContent(GapFillEvent event) {
    final s = event.extractedSignal;
    if (s.causalChain != null) {
      return 'Clarified: ${s.causalChain!.trigger} leads to ${s.causalChain!.response}';
    }
    if (s.relationship != null) {
      return 'Learned: ${s.relationship!.entity} provides ${s.relationship!.role}';
    }
    if (s.value != null) {
      return 'Identified value: ${s.value!.value} (${s.value!.importance})';
    }
    if (s.concepts.isNotEmpty) {
      return 'Learned about: ${s.concepts.join(', ')}';
    }
    return event.process.userResponse ?? 'New insight learned';
  }
}

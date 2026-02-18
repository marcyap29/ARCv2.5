// lib/chronicle/dual/services/dual_chronicle_services.dart
//
// Shared instances for dual chronicle so UI and agentic loop use the same
// PromotionService (pending offers visible in settings).

import '../intelligence/agentic_loop_orchestrator.dart';
import '../intelligence/interrupt/clarification_processor.dart';
import '../intelligence/interrupt/interrupt_decision_engine.dart';
import '../intelligence/gap/gap_analyzer.dart';
import '../intelligence/gap/gap_classifier.dart';
import '../repositories/user_chronicle_repository.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../storage/chronicle_storage.dart';
import 'promotion_service.dart';

/// Shared dual chronicle services. Use these so the Chronicle settings UI
/// and the agentic loop share the same promotion offers and repositories.
abstract final class DualChronicleServices {
  static ChronicleStorage? _storage;
  static UserChronicleRepository? _userRepo;
  static LumaraChronicleRepository? _lumaraRepo;
  static PromotionOfferStore? _offerStore;
  static PromotionService? _promotionService;
  static ClarificationProcessor? _clarificationProcessor;
  static AgenticLoopOrchestrator? _orchestrator;

  static ChronicleStorage get storage => _storage ??= ChronicleStorage();
  static UserChronicleRepository get userChronicle => _userRepo ??= UserChronicleRepository(storage);
  static LumaraChronicleRepository get lumaraChronicle => _lumaraRepo ??= LumaraChronicleRepository(storage);
  static PromotionOfferStore get promotionOfferStore => _offerStore ??= PromotionOfferStore();
  static PromotionService get promotionService =>
      _promotionService ??= PromotionService(
        userChronicleRepo: userChronicle,
        lumaraChronicleRepo: lumaraChronicle,
        offerStore: promotionOfferStore,
      );

  static ClarificationProcessor get clarificationProcessor =>
      _clarificationProcessor ??= ClarificationProcessor(
        userChronicleRepo: userChronicle,
        lumaraChronicleRepo: lumaraChronicle,
        promotionService: promotionService,
      );

  static AgenticLoopOrchestrator get agenticLoopOrchestrator =>
      _orchestrator ??= AgenticLoopOrchestrator(
        userRepo: userChronicle,
        lumaraRepo: lumaraChronicle,
        gapAnalyzer: GapAnalyzer(),
        gapClassifier: GapClassifier(),
        interruptEngine: InterruptDecisionEngine(),
        clarificationProcessor: clarificationProcessor,
      );
}

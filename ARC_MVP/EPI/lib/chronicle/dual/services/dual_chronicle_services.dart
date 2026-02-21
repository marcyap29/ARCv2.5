// lib/chronicle/dual/services/dual_chronicle_services.dart
//
// Shared instances for dual chronicle so UI and agentic loop use the same
// PromotionService (pending offers visible in settings).
// CHRONICLE (layers 0-3) is the user's chronicle; Layer0 + promoted annotations
// are provided via ChronicleQueryAdapter. User's CHRONICLE is SACRED; LUMARA CHRONICLE is the single sandbox.

import '../intelligence/agentic_loop_orchestrator.dart';
import '../intelligence/interrupt/clarification_processor.dart';
import '../intelligence/interrupt/interrupt_decision_engine.dart';
import '../intelligence/gap/gap_analyzer.dart';
import '../intelligence/gap/gap_classifier.dart';
import '../models/intelligence_summary_models.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../repositories/intelligence_summary_repository.dart';
import '../storage/chronicle_storage.dart';
import 'chronicle_query_adapter.dart';
import 'intelligence_summary_schedule_preferences.dart';
import 'lumara_comments_loader.dart';
import 'promotion_service.dart';
import 'intelligence_summary_generator.dart';

/// Shared dual chronicle services. Use these so the Chronicle settings UI
/// and the agentic loop share the same promotion offers and repositories.
abstract final class DualChronicleServices {
  static ChronicleStorage? _storage;
  static ChronicleQueryAdapter? _chronicleAdapter;
  static LumaraChronicleRepository? _lumaraRepo;
  static IntelligenceSummaryRepository? _summaryRepo;
  static IntelligenceSummaryGenerator? _summaryGenerator;
  static PromotionOfferStore? _offerStore;
  static PromotionService? _promotionService;
  static ClarificationProcessor? _clarificationProcessor;
  static AgenticLoopOrchestrator? _orchestrator;
  static LumaraCommentsLoader? _lumaraCommentsLoader;

  static ChronicleStorage get storage => _storage ??= ChronicleStorage();
  /// CHRONICLE-backed adapter: entries from Layer 0, annotations from LUMARA promoted.
  static ChronicleQueryAdapter get chronicleQueryAdapter =>
      _chronicleAdapter ??= ChronicleQueryAdapter(lumaraRepo: lumaraChronicle);
  static LumaraChronicleRepository get lumaraChronicle => _lumaraRepo ??= LumaraChronicleRepository(storage);
  static IntelligenceSummaryRepository get intelligenceSummaryRepo =>
      _summaryRepo ??= IntelligenceSummaryRepository(storage);
  static PromotionOfferStore get promotionOfferStore => _offerStore ??= PromotionOfferStore();
  static PromotionService get promotionService =>
      _promotionService ??= PromotionService(
        lumaraChronicleRepo: lumaraChronicle,
        offerStore: promotionOfferStore,
      );

  static ClarificationProcessor get clarificationProcessor =>
      _clarificationProcessor ??= ClarificationProcessor(
        lumaraChronicleRepo: lumaraChronicle,
        promotionService: promotionService,
      );

  static AgenticLoopOrchestrator get agenticLoopOrchestrator =>
      _orchestrator ??= AgenticLoopOrchestrator(
        chronicleAdapter: chronicleQueryAdapter,
        lumaraRepo: lumaraChronicle,
        gapAnalyzer: GapAnalyzer(),
        gapClassifier: GapClassifier(),
        interruptEngine: InterruptDecisionEngine(),
        clarificationProcessor: clarificationProcessor,
        intelligenceSummaryRepo: intelligenceSummaryRepo,
        lumaraCommentsLoader: _lumaraCommentsLoader,
      );

  /// Optional: set to enable LUMARA prior-comments context (from reflections + chats) in the agentic loop.
  static set lumaraCommentsLoader(LumaraCommentsLoader? loader) {
    _lumaraCommentsLoader = loader;
    _orchestrator = null; // Force re-creation so new loader is used
  }

  /// Intelligence Summary (Layer 3) generator. Uses Groq via LumaraAPIConfig (same as LUMARA chat/reflection).
  static IntelligenceSummaryGenerator get intelligenceSummaryGenerator =>
      _summaryGenerator ??= IntelligenceSummaryGenerator(
        chronicleAdapter: chronicleQueryAdapter,
        lumaraRepo: lumaraChronicle,
        summaryRepo: intelligenceSummaryRepo,
      );

  /// Generate Intelligence Summary, update schedule last-generated time, run gap analysis
  /// on the new summary so LUMARA continuously updates, then clear stale flag.
  /// Use this for manual "Regenerate" and for scheduled refresh. Only the user sees the summary.
  static Future<IntelligenceSummary> generateIntelligenceSummaryWithGapAnalysis(
    String userId,
  ) async {
    final generator = intelligenceSummaryGenerator;
    final summary = await generator.generateSummary(userId);
    await IntelligenceSummarySchedulePreferences.setLastGeneratedAt(
      summary.generatedAt,
    );
    try {
      await agenticLoopOrchestrator.execute(
        userId,
        summary.content,
        const AgenticContext(modality: AgenticModality.reflect),
      );
      await intelligenceSummaryRepo.clearStale(userId);
    } catch (e) {
      print('[DualChronicle] Gap analysis after summary generation failed (non-fatal): $e');
      await intelligenceSummaryRepo.clearStale(userId);
    }
    return summary;
  }
}

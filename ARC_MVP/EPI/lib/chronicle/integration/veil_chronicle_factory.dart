import '../../echo/rhythms/veil_aurora_scheduler.dart';
import '../../echo/rhythms/veil_chronicle_scheduler.dart';
import '../core/chronicle_repos.dart';
import '../synthesis/synthesis_engine.dart';
import '../storage/chronicle_index_storage.dart';
import '../embeddings/create_embedding_service.dart';
import '../index/chronicle_index_builder.dart';
import '../scheduling/synthesis_scheduler.dart';
import 'chronicle_narrative_integration.dart';

/// Factory for creating unified VEIL-CHRONICLE scheduler.
///
/// Initializes synthesis engine, optional cross-temporal pattern index,
/// and narrative integration. Pattern index runs on-device embeddings
/// (Universal Sentence Encoder); if TFLite is unavailable, index update
/// is skipped non-fatally.
class VeilChronicleFactory {
  /// Create unified VEIL-CHRONICLE scheduler.
  static Future<VeilChronicleScheduler?> create({
    required String userId,
    required SynthesisTier tier,
  }) async {
    try {
      final (layer0Repo, aggregationRepo, changelogRepo) = await ChronicleRepos.initializedRepos;

      final synthesisEngine = SynthesisEngine(
        layer0Repo: layer0Repo,
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );

      ChronicleIndexBuilder? indexBuilder;
      try {
        final embedder = await createEmbeddingService();
        await embedder.initialize();
        final storage = ChronicleIndexStorage();
        indexBuilder = ChronicleIndexBuilder(
          embedder: embedder,
          storage: storage,
        );
      } catch (e) {
        print('⚠️ VeilChronicleFactory: Chronicle pattern index disabled: $e');
      }

      final narrativeIntegration = ChronicleNarrativeIntegration(
        synthesisEngine: synthesisEngine,
        changelogRepo: changelogRepo,
        chronicleIndexBuilder: indexBuilder,
      );

      final maintenanceScheduler = VeilAuroraScheduler();

      return VeilChronicleScheduler(
        maintenanceScheduler: maintenanceScheduler,
        narrativeIntegration: narrativeIntegration,
      );
    } catch (e) {
      print('❌ VeilChronicleFactory: Failed to create scheduler: $e');
      return null;
    }
  }
  
  /// Initialize and start unified scheduler
  /// 
  /// Convenience method that creates and starts the scheduler in one call.
  static Future<VeilChronicleScheduler?> createAndStart({
    required String userId,
    required SynthesisTier tier,
  }) async {
    final scheduler = await create(userId: userId, tier: tier);
    if (scheduler != null) {
      await scheduler.start(userId: userId, tier: tier);
    }
    return scheduler;
  }
}

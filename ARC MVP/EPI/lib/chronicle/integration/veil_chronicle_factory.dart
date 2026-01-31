import '../../echo/rhythms/veil_aurora_scheduler.dart';
import '../../echo/rhythms/veil_chronicle_scheduler.dart';
import '../synthesis/synthesis_engine.dart';
import '../storage/changelog_repository.dart';
import '../storage/aggregation_repository.dart';
import '../storage/layer0_repository.dart';
import '../scheduling/synthesis_scheduler.dart';
import 'chronicle_narrative_integration.dart';

/// Factory for creating unified VEIL-CHRONICLE scheduler
/// 
/// Simplifies initialization of the unified architecture.
class VeilChronicleFactory {
  /// Create unified VEIL-CHRONICLE scheduler
  /// 
  /// Initializes all required components and returns a configured scheduler.
  static Future<VeilChronicleScheduler?> create({
    required String userId,
    required SynthesisTier tier,
  }) async {
    try {
      // Initialize CHRONICLE components
      final layer0Repo = Layer0Repository();
      await layer0Repo.initialize();
      
      final aggregationRepo = AggregationRepository();
      final changelogRepo = ChangelogRepository();
      
      final synthesisEngine = SynthesisEngine(
        layer0Repo: layer0Repo,
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );
      
      // Create narrative integration (VEIL-framed synthesis)
      final narrativeIntegration = ChronicleNarrativeIntegration(
        synthesisEngine: synthesisEngine,
        changelogRepo: changelogRepo,
      );
      
      // Create maintenance scheduler (existing VEIL tasks)
      final maintenanceScheduler = VeilAuroraScheduler();
      
      // Create unified scheduler
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

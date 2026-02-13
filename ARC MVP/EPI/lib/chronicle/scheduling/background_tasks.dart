import 'dart:async';
import 'synthesis_scheduler.dart';
import '../core/chronicle_repos.dart';
import '../synthesis/synthesis_engine.dart';

/// Background Task Manager for CHRONICLE
/// 
/// @Deprecated Use VeilChronicleScheduler instead. 
/// CHRONICLE synthesis is now integrated into the VEIL nightly cycle.
/// This class is kept for backward compatibility during migration.
@Deprecated('Use VeilChronicleScheduler instead. CHRONICLE is now integrated into VEIL cycle.')
/// Background Task Manager for CHRONICLE
/// 
/// Manages synthesis scheduling and execution in the background.
/// Integrates with app lifecycle to run synthesis when appropriate.
class ChronicleBackgroundTasks {
  final SynthesisScheduler _scheduler;
  Timer? _synthesisTimer;
  bool _isRunning = false;

  ChronicleBackgroundTasks({
    required SynthesisScheduler scheduler,
  }) : _scheduler = scheduler;

  /// Start background synthesis tasks
  /// 
  /// [checkInterval] - How often to check for pending synthesis (default: 1 hour)
  void start({Duration checkInterval = const Duration(hours: 1)}) {
    if (_isRunning) {
      print('⚠️ ChronicleBackgroundTasks: Already running');
      return;
    }

    _isRunning = true;
    print('🔄 ChronicleBackgroundTasks: Starting background synthesis (check interval: ${checkInterval.inMinutes} minutes)');

    // Run immediately on start
    _checkAndSynthesize();

    // Schedule periodic checks
    _synthesisTimer = Timer.periodic(checkInterval, (_) {
      _checkAndSynthesize();
    });
  }

  /// Stop background synthesis tasks
  void stop() {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _synthesisTimer?.cancel();
    _synthesisTimer = null;
    print('⏹️ ChronicleBackgroundTasks: Stopped background synthesis');
  }

  /// Check and synthesize pending aggregations
  Future<void> _checkAndSynthesize() async {
    try {
      final synthesized = await _scheduler.checkAndSynthesize();
      if (synthesized.isNotEmpty) {
        print('✅ ChronicleBackgroundTasks: Synthesized ${synthesized.length} aggregation(s): ${synthesized.join(", ")}');
      } else {
        print('ℹ️ ChronicleBackgroundTasks: No pending synthesis');
      }
    } catch (e) {
      print('❌ ChronicleBackgroundTasks: Error during synthesis: $e');
    }
  }

  /// Manually trigger synthesis check
  Future<List<String>> triggerSynthesis() async {
    return await _scheduler.checkAndSynthesize();
  }

  /// Get next scheduled synthesis time
  DateTime? getNextSynthesisTime() {
    return _scheduler.getNextSynthesisTime();
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Factory for creating ChronicleBackgroundTasks
class ChronicleBackgroundTasksFactory {
  /// Create background tasks for a user
  static Future<ChronicleBackgroundTasks?> create({
    required String userId,
    required SynthesisTier tier,
  }) async {
    try {
      final (layer0Repo, aggregationRepo, changelogRepo) = await ChronicleRepos.initializedRepos;

      // Create synthesis engine (it will create synthesizers internally)
      final synthesisEngine = SynthesisEngine(
        layer0Repo: layer0Repo,
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );

      // Get cadence for tier
      final cadence = SynthesisCadence.forTier(tier);

      // Create scheduler
      final scheduler = SynthesisScheduler(
        synthesisEngine: synthesisEngine,
        changelogRepo: changelogRepo,
        aggregationRepo: aggregationRepo,
        layer0Repo: layer0Repo,
        cadence: cadence,
        userId: userId,
      );

      // Create background tasks
      return ChronicleBackgroundTasks(scheduler: scheduler);
    } catch (e) {
      print('❌ ChronicleBackgroundTasksFactory: Failed to create background tasks: $e');
      return null;
    }
  }
}

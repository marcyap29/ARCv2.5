import 'dart:async';
import 'dart:developer' as developer;
import 'veil_aurora_scheduler.dart';
import '../../chronicle/integration/chronicle_narrative_integration.dart';
import '../../chronicle/integration/veil_stage_models.dart';
import '../../chronicle/scheduling/synthesis_scheduler.dart';

/// Unified VEIL-CHRONICLE nightly scheduler.
/// 
/// Performs two categories of work:
/// 1. System Maintenance (archives, cache, PRISM, RIVET)
/// 2. Narrative Integration (CHRONICLE synthesis as VEIL cycle)
class VeilChronicleScheduler {
  final ChronicleNarrativeIntegration _narrativeIntegration;
  Timer? _nightlyTimer;
  bool _isRunning = false;
  
  VeilChronicleScheduler({
    required VeilAuroraScheduler maintenanceScheduler, // Kept for API compatibility
    required ChronicleNarrativeIntegration narrativeIntegration,
  })  : _narrativeIntegration = narrativeIntegration;
  
  /// Start unified nightly cycle
  /// 
  /// Schedules both maintenance and narrative integration to run at midnight.
  Future<void> start({
    required String userId,
    required SynthesisTier tier,
  }) async {
    if (_isRunning) {
      developer.log('VEIL: Already running');
      return;
    }
    
    _isRunning = true;
    
    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);
    
    developer.log('VEIL: Starting unified scheduler, first run at ${nextMidnight.toIso8601String()}');
    
    // Schedule periodic runs (every 24 hours)
    _nightlyTimer = Timer.periodic(Duration(hours: 24), (_) {
      _runNightlyCycle(userId: userId, tier: tier);
    });
    
    // Run first cycle after calculated delay
    Timer(timeUntilMidnight, () {
      _runNightlyCycle(userId: userId, tier: tier);
    });
  }
  
  /// Stop the scheduler
  void stop() {
    _nightlyTimer?.cancel();
    _nightlyTimer = null;
    _isRunning = false;
    developer.log('VEIL: Stopped unified scheduler');
  }
  
  /// Run complete nightly VEIL cycle
  Future<VeilNightlyReport> runNightlyCycle({
    required String userId,
    required SynthesisTier tier,
  }) async {
    final startTime = DateTime.now();
    final report = VeilNightlyReport(userId: userId, startTime: startTime);
    
    try {
      // Part 1: System Maintenance (existing VEIL tasks)
      developer.log('VEIL: Starting system maintenance...');
      await VeilAuroraScheduler.forceRun();
      report.maintenanceCompleted = true;
      report.maintenanceDetails = {'status': 'completed'};
      
      // Part 2: Narrative Integration (CHRONICLE as VEIL cycle)
      developer.log('VEIL: Starting narrative integration cycle...');
      final narrativeResult = await _narrativeIntegration.runVeilCycle(
        userId: userId,
        tier: tier,
      );
      report.narrativeIntegrationCompleted = true;
      report.veilStagesExecuted = narrativeResult.stagesExecuted;
      report.synthesisDetails = narrativeResult.details;
      
      report.success = true;
      report.endTime = DateTime.now();
      
      developer.log('VEIL: Nightly cycle completed - ${report.getSummary()}');
      return report;
    } catch (e, stack) {
      developer.log('VEIL: Nightly cycle failed: $e', error: e, stackTrace: stack);
      report.success = false;
      report.error = e.toString();
      report.stackTrace = stack.toString();
      report.endTime = DateTime.now();
      
      return report;
    }
  }
  
  /// Internal method to run cycle (called by timer)
  Future<void> _runNightlyCycle({
    required String userId,
    required SynthesisTier tier,
  }) async {
    await runNightlyCycle(userId: userId, tier: tier);
  }
  
  /// Get next scheduled VEIL cycle time
  DateTime getNextCycleTime() {
    // Default: Midnight local time
    final now = DateTime.now();
    var nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0);
    
    // If already past midnight today, use tomorrow
    if (now.isAfter(nextMidnight)) {
      nextMidnight = nextMidnight.add(Duration(days: 1));
    }
    
    return nextMidnight;
  }
  
  /// Get scheduler status
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'nextCycle': getNextCycleTime().toIso8601String(),
      'maintenanceStatus': VeilAuroraScheduler.getStatus(),
    };
  }
}

/// Report from a complete VEIL nightly cycle
class VeilNightlyReport {
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;
  
  // Maintenance
  bool maintenanceCompleted = false;
  Map<String, dynamic>? maintenanceDetails;
  
  // Narrative Integration
  bool narrativeIntegrationCompleted = false;
  List<VeilStage> veilStagesExecuted = [];
  Map<String, dynamic>? synthesisDetails;
  
  // Errors
  String? error;
  String? stackTrace;
  
  VeilNightlyReport({
    required this.userId,
    required this.startTime,
  });
  
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
  
  String getSummary() {
    if (!success) {
      return 'VEIL cycle failed: $error';
    }
    
    final parts = <String>[];
    
    if (maintenanceCompleted) {
      parts.add('Maintenance complete');
    }
    
    if (narrativeIntegrationCompleted && veilStagesExecuted.isNotEmpty) {
      final stageNames = veilStagesExecuted.map((s) => s.displayName).join(', ');
      parts.add('VEIL stages: $stageNames');
    }
    
    return parts.join(' | ');
  }
  
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'success': success,
      'maintenanceCompleted': maintenanceCompleted,
      'narrativeIntegrationCompleted': narrativeIntegrationCompleted,
      'veilStagesExecuted': veilStagesExecuted.map((s) => s.name).toList(),
      'durationSeconds': duration.inSeconds,
      'error': error,
    };
  }
}

import '../synthesis/synthesis_engine.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_layer.dart';
import '../models/chronicle_aggregation.dart';
import '../integration/chronicle_narrative_integration.dart';
import '../integration/veil_stage_models.dart';
import '../scheduling/synthesis_scheduler.dart';

/// Manual CHRONICLE synthesis service
/// 
/// Provides manual triggers for CHRONICLE synthesis operations,
/// allowing users to synthesize specific periods or all pending periods.
class ChronicleManualService {
  final SynthesisEngine _synthesisEngine;
  final ChangelogRepository _changelogRepo;
  final ChronicleNarrativeIntegration? _narrativeIntegration;

  ChronicleManualService({
    required SynthesisEngine synthesisEngine,
    required ChangelogRepository changelogRepo,
    ChronicleNarrativeIntegration? narrativeIntegration,
  })  : _synthesisEngine = synthesisEngine,
        _changelogRepo = changelogRepo,
        _narrativeIntegration = narrativeIntegration;

  /// Synthesize the current month
  Future<ChronicleAggregation?> synthesizeCurrentMonth({
    required String userId,
  }) async {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    print('📝 ChronicleManualService: Synthesizing current month: $period');
    
    try {
      final aggregation = await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: period,
      );
      
      if (aggregation != null) {
        await _changelogRepo.log(
          userId: userId,
          layer: ChronicleLayer.monthly,
          action: 'manual_synthesis',
          metadata: {
            'period': period,
            'trigger': 'user_manual',
          },
        );
      }
      
      return aggregation;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to synthesize current month: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: ChronicleLayer.monthly,
        error: e.toString(),
        metadata: {'period': period, 'trigger': 'user_manual'},
      );
      rethrow;
    }
  }

  /// Synthesize a specific month
  Future<ChronicleAggregation?> synthesizeMonth({
    required String userId,
    required String period, // Format: "YYYY-MM"
  }) async {
    print('📝 ChronicleManualService: Synthesizing month: $period');
    
    try {
      final aggregation = await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: period,
      );
      
      if (aggregation != null) {
        await _changelogRepo.log(
          userId: userId,
          layer: ChronicleLayer.monthly,
          action: 'manual_synthesis',
          metadata: {
            'period': period,
            'trigger': 'user_manual',
          },
        );
      }
      
      return aggregation;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to synthesize month $period: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: ChronicleLayer.monthly,
        error: e.toString(),
        metadata: {'period': period, 'trigger': 'user_manual'},
      );
      rethrow;
    }
  }

  /// Synthesize the current year
  Future<ChronicleAggregation?> synthesizeCurrentYear({
    required String userId,
  }) async {
    final now = DateTime.now();
    final period = now.year.toString();
    
    print('📝 ChronicleManualService: Synthesizing current year: $period');
    
    try {
      final aggregation = await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
        period: period,
      );
      
      if (aggregation != null) {
        await _changelogRepo.log(
          userId: userId,
          layer: ChronicleLayer.yearly,
          action: 'manual_synthesis',
          metadata: {
            'period': period,
            'trigger': 'user_manual',
          },
        );
      }
      
      return aggregation;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to synthesize current year: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: ChronicleLayer.yearly,
        error: e.toString(),
        metadata: {'period': period, 'trigger': 'user_manual'},
      );
      rethrow;
    }
  }

  /// Synthesize a specific year
  Future<ChronicleAggregation?> synthesizeYear({
    required String userId,
    required String period, // Format: "YYYY"
  }) async {
    print('📝 ChronicleManualService: Synthesizing year: $period');
    
    try {
      final aggregation = await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
        period: period,
      );
      
      if (aggregation != null) {
        await _changelogRepo.log(
          userId: userId,
          layer: ChronicleLayer.yearly,
          action: 'manual_synthesis',
          metadata: {
            'period': period,
            'trigger': 'user_manual',
          },
        );
      }
      
      return aggregation;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to synthesize year $period: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: ChronicleLayer.yearly,
        error: e.toString(),
        metadata: {'period': period, 'trigger': 'user_manual'},
      );
      rethrow;
    }
  }

  /// Synthesize all pending periods
  /// 
  /// Synthesizes all months/years that have entries but no aggregations yet.
  /// Uses a simple heuristic: checks last 3 months, last 2 years, and available multi-year periods.
  Future<Map<String, int>> synthesizeAllPending({
    required String userId,
    required SynthesisTier tier,
  }) async {
    print('📝 ChronicleManualService: Synthesizing all pending periods...');
    
    final results = <String, int>{
      'monthly': 0,
      'yearly': 0,
      'multiyear': 0,
      'errors': 0,
    };
    
    try {
      final now = DateTime.now();
      final cadence = SynthesisCadence.forTier(tier);
      
      // Get pending monthly periods (last 3 months)
      final pendingMonthly = <String>[];
      for (int i = 0; i < 3; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        final period = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        pendingMonthly.add(period);
      }
      
      for (final period in pendingMonthly) {
        try {
          final aggregation = await _synthesisEngine.synthesizeLayer(
            userId: userId,
            layer: ChronicleLayer.monthly,
            period: period,
          );
          if (aggregation != null) {
            results['monthly'] = (results['monthly'] ?? 0) + 1;
          }
        } catch (e) {
          results['errors'] = (results['errors'] ?? 0) + 1;
          print('⚠️ ChronicleManualService: Failed to synthesize month $period: $e');
        }
      }
      
      // Get pending yearly periods (only if tier supports it)
      if (cadence.enableYearly) {
        final pendingYearly = <String>[];
        for (int i = 0; i < 2; i++) {
          final year = now.year - i;
          pendingYearly.add(year.toString());
        }
        
        for (final period in pendingYearly) {
          try {
            final aggregation = await _synthesisEngine.synthesizeLayer(
              userId: userId,
              layer: ChronicleLayer.yearly,
              period: period,
            );
            if (aggregation != null) {
              results['yearly'] = (results['yearly'] ?? 0) + 1;
            }
          } catch (e) {
            results['errors'] = (results['errors'] ?? 0) + 1;
            print('⚠️ ChronicleManualService: Failed to synthesize year $period: $e');
          }
        }
      }
      
      // Get pending multi-year periods (only if tier supports it)
      if (cadence.enableMultiYear) {
        final pendingMultiYear = <String>[];
        final currentYear = now.year;
        // Generate 5-year periods (e.g., 2020-2024, 2015-2019)
        for (int startYear = currentYear - 4; startYear >= 2000; startYear -= 5) {
          final endYear = startYear + 4;
          pendingMultiYear.add('$startYear-$endYear');
        }
        
        for (final period in pendingMultiYear) {
          try {
            final aggregation = await _synthesisEngine.synthesizeLayer(
              userId: userId,
              layer: ChronicleLayer.multiyear,
              period: period,
            );
            if (aggregation != null) {
              results['multiyear'] = (results['multiyear'] ?? 0) + 1;
            }
          } catch (e) {
            results['errors'] = (results['errors'] ?? 0) + 1;
            print('⚠️ ChronicleManualService: Failed to synthesize multi-year $period: $e');
          }
        }
      }
      
      await _changelogRepo.log(
        userId: userId,
        layer: ChronicleLayer.monthly, // Use monthly as default for batch operations
        action: 'manual_batch_synthesis',
        metadata: {
          'results': results,
          'trigger': 'user_manual',
        },
      );
      
      print('✅ ChronicleManualService: Synthesized ${results['monthly']} monthly, ${results['yearly']} yearly, ${results['multiyear']} multi-year aggregations');
      
      return results;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to synthesize all pending: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: ChronicleLayer.monthly,
        error: e.toString(),
        metadata: {'trigger': 'user_manual_batch'},
      );
      rethrow;
    }
  }

  /// Re-synthesize a specific period (force re-synthesis)
  Future<ChronicleAggregation?> resynthesizePeriod({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    print('📝 ChronicleManualService: Re-synthesizing ${layer.displayName} - $period');
    
    try {
      final aggregation = await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: layer,
        period: period,
      );
      
      if (aggregation != null) {
        await _changelogRepo.log(
          userId: userId,
          layer: layer,
          action: 'manual_resynthesis',
          metadata: {
            'period': period,
            'trigger': 'user_manual',
            'force': true,
          },
        );
      }
      
      return aggregation;
    } catch (e) {
      print('❌ ChronicleManualService: Failed to re-synthesize ${layer.displayName} - $period: $e');
      await _changelogRepo.logError(
        userId: userId,
        layer: layer,
        error: e.toString(),
        metadata: {'period': period, 'trigger': 'user_manual_resynthesis'},
      );
      rethrow;
    }
  }

  /// Run full VEIL cycle manually
  Future<VeilCycleResult> runVeilCycleManually({
    required String userId,
    required SynthesisTier tier,
  }) async {
    if (_narrativeIntegration == null) {
      throw StateError('ChronicleNarrativeIntegration not available');
    }
    
    print('📝 ChronicleManualService: Running manual VEIL cycle...');
    
    final result = await _narrativeIntegration!.runVeilCycle(
      userId: userId,
      tier: tier,
    );
    
    await _changelogRepo.log(
      userId: userId,
      layer: ChronicleLayer.monthly, // Use monthly as default for cycle operations
      action: 'manual_veil_cycle',
      metadata: {
        'stages_executed': result.stagesExecuted.map((s) => s.name).toList(),
        'success': result.success,
        'trigger': 'user_manual',
      },
      error: result.error,
    );
    
    return result;
  }
}

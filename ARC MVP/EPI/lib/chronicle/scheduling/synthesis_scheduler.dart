import '../synthesis/synthesis_engine.dart';
import '../storage/changelog_repository.dart';
import '../storage/aggregation_repository.dart';
import '../storage/layer0_repository.dart';
import '../models/chronicle_layer.dart';
import '../index/chronicle_index_builder.dart';
import '../index/monthly_aggregation_adapter.dart';

/// Synthesis Tier Configuration
/// 
/// Defines synthesis cadence based on user tier.
enum SynthesisTier {
  free,      // No CHRONICLE access
  basic,      // Monthly only, 30-day retention
  premium,    // Monthly + Yearly, 90-day retention
  enterprise, // All layers, unlimited retention
}

/// Synthesis Cadence Configuration
class SynthesisCadence {
  final Duration monthlyInterval;
  final Duration yearlyInterval;
  final Duration multiYearInterval;
  final int layer0RetentionDays;
  final bool enableMonthly;
  final bool enableYearly;
  final bool enableMultiYear;

  const SynthesisCadence({
    required this.monthlyInterval,
    required this.yearlyInterval,
    required this.multiYearInterval,
    required this.layer0RetentionDays,
    this.enableMonthly = true,
    this.enableYearly = false,
    this.enableMultiYear = false,
  });

  /// Get cadence for a specific tier
  static SynthesisCadence forTier(SynthesisTier tier) {
    switch (tier) {
      case SynthesisTier.free:
        return const SynthesisCadence(
          monthlyInterval: Duration(days: 999999), // Never
          yearlyInterval: Duration(days: 999999),
          multiYearInterval: Duration(days: 999999),
          layer0RetentionDays: 0,
          enableMonthly: false,
          enableYearly: false,
          enableMultiYear: false,
        );
      
      case SynthesisTier.basic:
        return const SynthesisCadence(
          monthlyInterval: Duration(days: 1), // Daily check, synthesize monthly
          yearlyInterval: Duration(days: 999999),
          multiYearInterval: Duration(days: 999999),
          layer0RetentionDays: 30,
          enableMonthly: true,
          enableYearly: false,
          enableMultiYear: false,
        );
      
      case SynthesisTier.premium:
        return const SynthesisCadence(
          monthlyInterval: Duration(days: 1), // Daily check
          yearlyInterval: Duration(days: 7), // Weekly check, synthesize yearly
          multiYearInterval: Duration(days: 999999),
          layer0RetentionDays: 90,
          enableMonthly: true,
          enableYearly: true,
          enableMultiYear: false,
        );
      
      case SynthesisTier.enterprise:
        return const SynthesisCadence(
          monthlyInterval: Duration(days: 1), // Daily check
          yearlyInterval: Duration(days: 7), // Weekly check
          multiYearInterval: Duration(days: 30), // Monthly check, synthesize multi-year
          layer0RetentionDays: 365, // 1 year retention
          enableMonthly: true,
          enableYearly: true,
          enableMultiYear: true,
        );
    }
  }
}

/// Synthesis Scheduler
/// 
/// Manages tier-based cadence for aggregation synthesis.
/// Handles scheduling and execution of synthesis operations.
class SynthesisScheduler {
  final SynthesisEngine _synthesisEngine;
  final ChangelogRepository _changelogRepo;
  final AggregationRepository _aggregationRepo;
  final Layer0Repository _layer0Repo;
  final SynthesisCadence _cadence;
  final String _userId;
  final ChronicleIndexBuilder? _chronicleIndexBuilder;

  SynthesisScheduler({
    required SynthesisEngine synthesisEngine,
    required ChangelogRepository changelogRepo,
    required AggregationRepository aggregationRepo,
    required Layer0Repository layer0Repo,
    required SynthesisCadence cadence,
    required String userId,
    ChronicleIndexBuilder? chronicleIndexBuilder,
  })  : _synthesisEngine = synthesisEngine,
        _changelogRepo = changelogRepo,
        _aggregationRepo = aggregationRepo,
        _layer0Repo = layer0Repo,
        _cadence = cadence,
        _userId = userId,
        _chronicleIndexBuilder = chronicleIndexBuilder;

  /// Check and synthesize pending aggregations
  /// 
  /// Returns list of synthesized aggregation periods.
  Future<List<String>> checkAndSynthesize() async {
    final synthesized = <String>[];

    try {
      // 1. Check monthly synthesis
      if (_cadence.enableMonthly) {
        final monthlyPeriods = await _getPendingMonthlyPeriods();
        for (final period in monthlyPeriods) {
          try {
            final aggregation = await _synthesisEngine.synthesizeLayer(
              userId: _userId,
              layer: ChronicleLayer.monthly,
              period: period,
            );
            if (aggregation != null) {
              synthesized.add('monthly:$period');
              print('✅ SynthesisScheduler: Synthesized monthly $period');
              if (_chronicleIndexBuilder != null) {
                try {
                  final synthesis = MonthlyAggregation.fromChronicleAggregation(aggregation);
                  await _chronicleIndexBuilder!.updateIndexAfterSynthesis(
                    userId: _userId,
                    synthesis: synthesis,
                  );
                  print('✅ SynthesisScheduler: Updated Chronicle pattern index for $period');
                } catch (e) {
                  print('⚠️ SynthesisScheduler: Chronicle index update failed: $e');
                }
              }
            }
          } catch (e) {
            print('⚠️ SynthesisScheduler: Failed to synthesize monthly $period: $e');
            await _changelogRepo.logError(
              userId: _userId,
              layer: ChronicleLayer.monthly,
              error: e.toString(),
              metadata: {'period': period},
            );
          }
        }
      }

      // 2. Check yearly synthesis
      if (_cadence.enableYearly) {
        final yearlyPeriods = await _getPendingYearlyPeriods();
        for (final period in yearlyPeriods) {
          try {
            await _synthesisEngine.synthesizeLayer(
              userId: _userId,
              layer: ChronicleLayer.yearly,
              period: period,
            );
            synthesized.add('yearly:$period');
            print('✅ SynthesisScheduler: Synthesized yearly $period');
          } catch (e) {
            print('⚠️ SynthesisScheduler: Failed to synthesize yearly $period: $e');
            await _changelogRepo.logError(
              userId: _userId,
              layer: ChronicleLayer.yearly,
              error: e.toString(),
              metadata: {'period': period},
            );
          }
        }
      }

      // 3. Check multi-year synthesis
      if (_cadence.enableMultiYear) {
        final multiYearPeriods = await _getPendingMultiYearPeriods();
        for (final period in multiYearPeriods) {
          try {
            await _synthesisEngine.synthesizeLayer(
              userId: _userId,
              layer: ChronicleLayer.multiyear,
              period: period,
            );
            synthesized.add('multiyear:$period');
            print('✅ SynthesisScheduler: Synthesized multi-year $period');
          } catch (e) {
            print('⚠️ SynthesisScheduler: Failed to synthesize multi-year $period: $e');
            await _changelogRepo.logError(
              userId: _userId,
              layer: ChronicleLayer.multiyear,
              error: e.toString(),
              metadata: {'period': period},
            );
          }
        }
      }

      // 4. Cleanup old Layer 0 entries
      if (_cadence.layer0RetentionDays > 0) {
        await _layer0Repo.cleanupOldEntries(_userId, _cadence.layer0RetentionDays);
      }

      return synthesized;
    } catch (e) {
      print('❌ SynthesisScheduler: Error during synthesis check: $e');
      return synthesized;
    }
  }

  /// Get pending monthly periods that need synthesis
  Future<List<String>> _getPendingMonthlyPeriods() async {
    final now = DateTime.now();
    final pending = <String>[];

    // Check last 3 months (in case we missed some)
    for (int i = 0; i < 3; i++) {
      final checkDate = DateTime(now.year, now.month - i, 1);
      final period = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}';

      // Check if already synthesized
      final lastSynthesis = await _changelogRepo.getLastSynthesis(
        _userId,
        ChronicleLayer.monthly,
      );

      // If never synthesized, or last synthesis was before this month
      if (lastSynthesis == null || 
          lastSynthesis.isBefore(checkDate) ||
          (lastSynthesis.year == checkDate.year && lastSynthesis.month < checkDate.month)) {
        // Check if aggregation exists
        final existing = await _aggregationRepo.loadLayer(
          userId: _userId,
          layer: ChronicleLayer.monthly,
          period: period,
        );
        
        if (existing == null) {
          // Check if we have entries for this month
          final entries = await _layer0Repo.getEntriesForMonth(_userId, period);
          if (entries.isNotEmpty) {
            pending.add(period);
          }
        }
      }
    }

    return pending;
  }

  /// Get pending yearly periods that need synthesis
  Future<List<String>> _getPendingYearlyPeriods() async {
    final now = DateTime.now();
    final pending = <String>[];

    // Check last 2 years
    for (int i = 0; i < 2; i++) {
      final year = (now.year - i).toString();

      // Check if already synthesized
      final lastSynthesis = await _changelogRepo.getLastSynthesis(
        _userId,
        ChronicleLayer.yearly,
      );

      // If never synthesized, or last synthesis was before this year
      if (lastSynthesis == null || lastSynthesis.year < int.parse(year)) {
        // Check if aggregation exists
        final existing = await _aggregationRepo.loadLayer(
          userId: _userId,
          layer: ChronicleLayer.yearly,
          period: year,
        );
        
        if (existing == null) {
          // Check if we have monthly aggregations for this year
          final monthlyAggs = await _aggregationRepo.getAllForLayer(
            userId: _userId,
            layer: ChronicleLayer.monthly,
          );
          final yearMonthlyAggs = monthlyAggs.where((agg) => agg.period.startsWith(year)).toList();
          if (yearMonthlyAggs.length >= 3) {
            pending.add(year);
          }
        }
      }
    }

    return pending;
  }

  /// Get pending multi-year periods that need synthesis
  Future<List<String>> _getPendingMultiYearPeriods() async {
    final now = DateTime.now();
    final pending = <String>[];

    // Check for 5-year periods (e.g., 2020-2024, 2015-2019)
    final currentYear = now.year;
    final startYear = currentYear - (currentYear % 5); // Round down to nearest 5
    final endYear = startYear + 4;

    // Check if already synthesized
    final lastSynthesis = await _changelogRepo.getLastSynthesis(
      _userId,
      ChronicleLayer.multiyear,
    );

    final period = '$startYear-$endYear';

    // If never synthesized, or last synthesis was before this period
    if (lastSynthesis == null || lastSynthesis.year < endYear) {
      // Check if aggregation exists
      final existing = await _aggregationRepo.loadLayer(
        userId: _userId,
        layer: ChronicleLayer.multiyear,
        period: period,
      );
      
      if (existing == null) {
        // Check if we have yearly aggregations for this period
        final yearlyAggs = await _aggregationRepo.getAllForLayer(
          userId: _userId,
          layer: ChronicleLayer.yearly,
        );
        bool hasYearlyAggs = true;
        for (int y = startYear; y <= endYear; y++) {
          final yearlyAgg = yearlyAggs.firstWhere(
            (agg) => agg.period == y.toString(),
            orElse: () => throw StateError('Missing year $y'),
          );
          if (yearlyAgg.period != y.toString()) {
            hasYearlyAggs = false;
            break;
          }
        }
        
        if (hasYearlyAggs) {
          pending.add(period);
        }
      }
    }

    return pending;
  }

  /// Get next scheduled synthesis time
  DateTime? getNextSynthesisTime() {
    final now = DateTime.now();
    DateTime? nextTime;

    if (_cadence.enableMonthly) {
      nextTime = now.add(_cadence.monthlyInterval);
    }

    if (_cadence.enableYearly) {
      final yearlyNext = now.add(_cadence.yearlyInterval);
      if (nextTime == null || yearlyNext.isBefore(nextTime)) {
        nextTime = yearlyNext;
      }
    }

    if (_cadence.enableMultiYear) {
      final multiYearNext = now.add(_cadence.multiYearInterval);
      if (nextTime == null || multiYearNext.isBefore(nextTime)) {
        nextTime = multiYearNext;
      }
    }

    return nextTime;
  }
}

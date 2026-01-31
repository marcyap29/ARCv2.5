import '../storage/layer0_repository.dart';
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_layer.dart';
import '../models/chronicle_aggregation.dart';
import 'monthly_synthesizer.dart';
import 'yearly_synthesizer.dart';
import 'multiyear_synthesizer.dart';

/// Synthesis Engine Orchestrator
/// 
/// Coordinates LLM calls, manages synthesis workflow,
/// handles errors, and logs to changelog.

class SynthesisEngine {
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository _changelogRepo;
  final MonthlySynthesizer _monthlySynthesizer;
  final YearlySynthesizer _yearlySynthesizer;
  final MultiYearSynthesizer _multiYearSynthesizer;

  SynthesisEngine({
    required Layer0Repository layer0Repo,
    required AggregationRepository aggregationRepo,
    required ChangelogRepository changelogRepo,
    MonthlySynthesizer? monthlySynthesizer,
    YearlySynthesizer? yearlySynthesizer,
    MultiYearSynthesizer? multiYearSynthesizer,
  })  : _layer0Repo = layer0Repo,
        _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo,
        _monthlySynthesizer = monthlySynthesizer ??
            MonthlySynthesizer(
              layer0Repo: layer0Repo,
              aggregationRepo: aggregationRepo,
              changelogRepo: changelogRepo,
            ),
        _yearlySynthesizer = yearlySynthesizer ??
            YearlySynthesizer(
              aggregationRepo: aggregationRepo,
              changelogRepo: changelogRepo,
            ),
        _multiYearSynthesizer = multiYearSynthesizer ??
            MultiYearSynthesizer(
              aggregationRepo: aggregationRepo,
              changelogRepo: changelogRepo,
            );

  /// Synthesize a specific layer for a given period
  Future<ChronicleAggregation?> synthesizeLayer({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    try {
      print('🔧 SynthesisEngine: Starting synthesis for ${layer.displayName} - $period');

      switch (layer) {
        case ChronicleLayer.monthly:
          return await _monthlySynthesizer.synthesize(
            userId: userId,
            month: period,
          );

        case ChronicleLayer.yearly:
          return await _yearlySynthesizer.synthesize(
            userId: userId,
            year: period,
          );

        case ChronicleLayer.multiyear:
          // Parse period (format: "2020-2024")
          final parts = period.split('-');
          if (parts.length != 2) {
            throw ArgumentError('Multi-year period must be in format "startYear-endYear"');
          }
          return await _multiYearSynthesizer.synthesize(
            userId: userId,
            startYear: parts[0],
            endYear: parts[1],
          );

        case ChronicleLayer.layer0:
          throw ArgumentError('Layer 0 is raw entries, not synthesized');
      }
    } catch (e, stackTrace) {
      print('❌ SynthesisEngine: Synthesis failed for ${layer.displayName} - $period: $e');
      print('Stack trace: $stackTrace');

      // Log error to changelog
      await _changelogRepo.logError(
        userId: userId,
        layer: layer,
        error: e.toString(),
        metadata: {
          'period': period,
          'stack_trace': stackTrace.toString(),
        },
      );

      // Don't rethrow - allow graceful degradation
      return null;
    }
  }

  /// Check if synthesis is needed for a layer/period
  Future<bool> needsSynthesis({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    if (layer == ChronicleLayer.layer0) {
      return false; // Layer 0 is always populated, not synthesized
    }

    // Check if aggregation already exists
    final existing = await _aggregationRepo.loadLayer(
      userId: userId,
      layer: layer,
      period: period,
    );

    if (existing != null) {
      // Check if re-synthesis is needed (e.g., user edited, new entries added)
      // For now, if it exists, we don't need to re-synthesize
      return false;
    }

    return true;
  }

  /// Get synthesis status for a layer/period
  Future<SynthesisStatus> getSynthesisStatus({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    final exists = await _aggregationRepo.loadLayer(
      userId: userId,
      layer: layer,
      period: period,
    );

    if (exists == null) {
      return SynthesisStatus.notSynthesized;
    }

    final lastSynthesis = await _changelogRepo.getLastSynthesis(userId, layer);
    if (lastSynthesis == null) {
      return SynthesisStatus.synthesized; // Exists but no changelog entry
    }

    return SynthesisStatus.synthesized;
  }
}

/// Synthesis status
enum SynthesisStatus {
  notSynthesized,
  synthesized,
  error,
}

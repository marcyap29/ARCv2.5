import 'dart:developer' as developer;
import '../synthesis/synthesis_engine.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_layer.dart';
import '../scheduling/synthesis_scheduler.dart';
import '../index/chronicle_index_builder.dart';
import '../index/monthly_aggregation_adapter.dart';
import 'veil_stage_models.dart';

/// CHRONICLE synthesis framed as VEIL narrative integration.
/// 
/// This class wraps the existing SynthesisEngine but frames it
/// explicitly as implementing the VEIL cycle stages.
/// When [chronicleIndexBuilder] is set, EXAMINE (monthly synthesis) also updates
/// the cross-temporal pattern index.
class ChronicleNarrativeIntegration {
  final SynthesisEngine _synthesisEngine;
  final ChangelogRepository _changelogRepo;
  final ChronicleIndexBuilder? _chronicleIndexBuilder;

  ChronicleNarrativeIntegration({
    required SynthesisEngine synthesisEngine,
    required ChangelogRepository changelogRepo,
    ChronicleIndexBuilder? chronicleIndexBuilder,
  })  : _synthesisEngine = synthesisEngine,
        _changelogRepo = changelogRepo,
        _chronicleIndexBuilder = chronicleIndexBuilder;
  
  /// Run VEIL narrative integration cycle
  /// 
  /// Executes VEIL stages (Examine → Integrate → Link) based on
  /// tier configuration and synthesis needs.
  Future<VeilCycleResult> runVeilCycle({
    required String userId,
    required SynthesisTier tier,
  }) async {
    final result = VeilCycleResult(userId: userId, tier: tier.name);
    final cadence = SynthesisCadence.forTier(tier);
    
    // Free tier: No narrative integration
    if (tier == SynthesisTier.free) {
      developer.log('VEIL: Free tier - skipping narrative integration');
      return result;
    }
    
    try {
      // Stage 1: EXAMINE (Monthly synthesis)
      if (cadence.enableMonthly && await _shouldExamine(userId, cadence)) {
        developer.log('VEIL: Executing EXAMINE stage (monthly synthesis)...');
        
        final monthlyResult = await _examineRecentPatterns(userId);
        result.stagesExecuted.add(VeilStage.examine);
        result.details['examine'] = {
          'period': monthlyResult.period,
          'summary': monthlyResult.summary,
          'themes': monthlyResult.themes,
        };
        
        await _logVeilStage(
          userId: userId,
          stage: VeilStage.examine,
          summary: monthlyResult.summary,
        );
      }
      
      // Stage 2: INTEGRATE (Yearly synthesis)
      if (cadence.enableYearly && await _shouldIntegrate(userId, cadence)) {
        developer.log('VEIL: Executing INTEGRATE stage (yearly synthesis)...');
        
        final yearlyResult = await _integrateIntoNarrative(userId);
        result.stagesExecuted.add(VeilStage.integrate);
        result.details['integrate'] = {
          'period': yearlyResult.period,
          'summary': yearlyResult.summary,
          'chapters': yearlyResult.chapters,
        };
        
        await _logVeilStage(
          userId: userId,
          stage: VeilStage.integrate,
          summary: yearlyResult.summary,
        );
      }
      
      // Stage 3: LINK (Multi-year synthesis)
      if (cadence.enableMultiYear && await _shouldLink(userId, cadence)) {
        developer.log('VEIL: Executing LINK stage (multi-year synthesis)...');
        
        final multiYearResult = await _linkAcrossYears(userId);
        result.stagesExecuted.add(VeilStage.link);
        result.details['link'] = {
          'period': multiYearResult.period,
          'summary': multiYearResult.summary,
          'metaPatterns': multiYearResult.metaPatterns,
        };
        
        await _logVeilStage(
          userId: userId,
          stage: VeilStage.link,
          summary: multiYearResult.summary,
        );
      }
      
      result.success = true;
      return result;
    } catch (e, stack) {
      developer.log('VEIL: Narrative integration failed: $e', error: e, stackTrace: stack);
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }
  
  // VEIL Stage 1: EXAMINE (Pattern Recognition)
  Future<StageResult> _examineRecentPatterns(String userId) async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    final aggregation = await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.monthly,
      period: currentMonth,
    );
    
    if (aggregation == null) {
      return StageResult(
        stage: VeilStage.examine,
        period: currentMonth,
        summary: 'No entries found for $currentMonth',
      );
    }

    // Update cross-temporal pattern index when available
    if (_chronicleIndexBuilder != null) {
      try {
        final synthesis = MonthlyAggregation.fromChronicleAggregation(aggregation);
        await _chronicleIndexBuilder!.updateIndexAfterSynthesis(
          userId: userId,
          synthesis: synthesis,
        );
      } catch (e) {
        developer.log('VEIL: Chronicle index update failed (non-fatal): $e');
      }
    }

    // Extract key themes for summary
    final themes = _extractThemes(aggregation.content);

    return StageResult(
      stage: VeilStage.examine,
      period: currentMonth,
      summary: 'Found ${themes.length} dominant themes in $currentMonth',
      themes: themes,
      aggregation: aggregation,
    );
  }
  
  // VEIL Stage 2: INTEGRATE (Narrative Synthesis)
  Future<StageResult> _integrateIntoNarrative(String userId) async {
    final now = DateTime.now();
    final currentYear = now.year.toString();
    
    final aggregation = await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
      period: currentYear,
    );
    
    if (aggregation == null) {
      return StageResult(
        stage: VeilStage.integrate,
        period: currentYear,
        summary: 'Insufficient monthly data for $currentYear',
      );
    }
    
    final chapters = _extractChapters(aggregation.content);
    
    return StageResult(
      stage: VeilStage.integrate,
      period: currentYear,
      summary: 'Updated yearly narrative with ${chapters.length} chapters',
      chapters: chapters,
      aggregation: aggregation,
    );
  }
  
  // VEIL Stage 3: LINK (Biographical Connection)
  Future<StageResult> _linkAcrossYears(String userId) async {
    final now = DateTime.now();
    final endYear = now.year;
    final startYear = endYear - 4;
    final period = '$startYear-$endYear';
    
    final aggregation = await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.multiyear,
      period: period,
    );
    
    if (aggregation == null) {
      return StageResult(
        stage: VeilStage.link,
        period: period,
        summary: 'Insufficient yearly data for $period',
      );
    }
    
    final metaPatterns = _extractMetaPatterns(aggregation.content);
    
    return StageResult(
      stage: VeilStage.link,
      period: period,
      summary: 'Connected ${endYear - startYear + 1} years, found ${metaPatterns.length} meta-patterns',
      metaPatterns: metaPatterns,
      aggregation: aggregation,
    );
  }
  
  // Check if EXAMINE stage should run
  Future<bool> _shouldExamine(String userId, SynthesisCadence cadence) async {
    final lastSynthesis = await _changelogRepo.getLastSynthesis(
      userId,
      ChronicleLayer.monthly,
    );
    
    if (lastSynthesis == null) return true;
    
    final timeSince = DateTime.now().difference(lastSynthesis);
    return timeSince >= cadence.monthlyInterval;
  }
  
  // Check if INTEGRATE stage should run
  Future<bool> _shouldIntegrate(String userId, SynthesisCadence cadence) async {
    final lastSynthesis = await _changelogRepo.getLastSynthesis(
      userId,
      ChronicleLayer.yearly,
    );
    
    if (lastSynthesis == null) return true;
    
    final timeSince = DateTime.now().difference(lastSynthesis);
    return timeSince >= cadence.yearlyInterval;
  }
  
  // Check if LINK stage should run
  Future<bool> _shouldLink(String userId, SynthesisCadence cadence) async {
    final lastSynthesis = await _changelogRepo.getLastSynthesis(
      userId,
      ChronicleLayer.multiyear,
    );
    
    if (lastSynthesis == null) return true;
    
    final timeSince = DateTime.now().difference(lastSynthesis);
    return timeSince >= cadence.multiYearInterval;
  }
  
  // Log VEIL stage completion
  Future<void> _logVeilStage({
    required String userId,
    required VeilStage stage,
    required String summary,
  }) async {
    await _changelogRepo.log(
      userId: userId,
      layer: _stageToLayer(stage),
      action: 'veil_${stage.name}',
      metadata: {
        'veil_stage': stage.name,
        'summary': summary,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  ChronicleLayer _stageToLayer(VeilStage stage) {
    switch (stage) {
      case VeilStage.examine:
        return ChronicleLayer.monthly;
      case VeilStage.integrate:
        return ChronicleLayer.yearly;
      case VeilStage.link:
        return ChronicleLayer.multiyear;
      default:
        return ChronicleLayer.monthly;
    }
  }
  
  // Helper: Extract themes from monthly aggregation
  List<String> _extractThemes(String content) {
    final themePattern = RegExp(r'\*\*(.+?)\*\* \(confidence: (\w+)\)');
    final matches = themePattern.allMatches(content);
    return matches.map((m) => m.group(1) ?? '').where((t) => t.isNotEmpty).toList();
  }
  
  // Helper: Extract chapters from yearly aggregation
  List<String> _extractChapters(String content) {
    final chapterPattern = RegExp(r'### (.+?)(?:\n|$)');
    final matches = chapterPattern.allMatches(content);
    return matches.map((m) => m.group(1) ?? '').where((t) => t.isNotEmpty).toList();
  }
  
  // Helper: Extract meta-patterns from multi-year aggregation
  List<String> _extractMetaPatterns(String content) {
    final patternSection = RegExp(
      r'## Meta-Patterns(.*?)(?:##|$)',
      dotAll: true,
    ).firstMatch(content)?.group(1);
    
    if (patternSection == null) return [];
    
    final patterns = RegExp(r'- (.+?)(?:\n|$)')
        .allMatches(patternSection)
        .map((m) => m.group(1) ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
    
    return patterns;
  }
}

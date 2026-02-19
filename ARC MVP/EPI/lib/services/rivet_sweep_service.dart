// lib/services/rivet_sweep_service.dart
// RIVET Sweep: Segmented Phase Backfill Pipeline
//
// Phase determination is done by:
// - RIVET: structures the sweep (segmentation, change points, hysteresis, min dwell) and gates
//   real-time phase changes via RivetProvider.
// - ATLAS: used for phase inference per segment via AtlasPhaseDecisionService (scoring and
//   decidePhaseForEntry) in _inferPhaseFromContent and in trend analysis fallbacks.
// - Sentinel: applied when applying proposals (see phase_sentinel_integration); safety override
//   can set segment phase to Recovery when crisis/cluster alert is detected.

import 'dart:math';
import '../models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'phase_index.dart';
// import 'semantic_similarity_service.dart'; // TODO: Implement or use existing
import 'analytics_service.dart';
import 'phase_regime_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
import 'atlas_phase_decision_service.dart';
import 'phase_sentinel_integration.dart';
import 'chronicle_phase_signal_service.dart';
import 'firebase_auth_service.dart';

class RivetSweepService {
  // final SemanticSimilarityService _similarityService; // TODO: Implement
  // final AnalyticsService _analytics; // TODO: Use analytics
  
  // Configuration - Minimum regime durations ensure meaningful life periods
  static const Duration _minRegimeDuration = Duration(days: 10); // Minimum 10 days per regime
  static const Duration _preferredMinDuration = Duration(days: 14); // Preferred 2 weeks minimum
  static const Duration _shortTermThreshold = Duration(days: 5); // Flag regimes shorter than 5 days
  static const double _minConfidence = 0.70;
  static const double _reviewConfidence = 0.50;
  static const double _hysteresisThreshold = 0.15;
  static const int _maxRegimesPerYear = 12; // Maximum 12 regimes per year (monthly average)
  static const int _minRegimesPerYear = 4; // Minimum 4 regimes per year (seasonal)
  /// Weight for Chronicle phase scores when fusing with ATLAS (0 = ATLAS only, 1 = Chronicle only).
  static const double _chronicleFusionWeight = 0.35;

  RivetSweepService(AnalyticsService analytics);

  /// Detect if RIVET Sweep is needed
  bool needsRivetSweep(List<JournalEntry> entries, PhaseIndex phaseIndex) {
    // Check for unphased entries
    final unphasedCount = entries.where((entry) {
      final regime = phaseIndex.regimeFor(entry.createdAt);
      return regime == null;
    }).length;

    // Check for regimes needing attention
    final regimesNeedingAttention = phaseIndex.findRegimesNeedingAttention();

    return unphasedCount >= 20 || regimesNeedingAttention.isNotEmpty;
  }

  /// Run RIVET Sweep analysis.
  /// If [userId] is provided, Chronicle (LUMARA) phase scores are fused with ATLAS for proposals.
  Future<RivetSweepResult> analyzeEntries(
    List<JournalEntry> entries, {
    String? userId,
  }) async {
        AnalyticsService.trackEvent('rivet_sweep.analysis_started', properties: {
      'entry_count': entries.length,
    });

    try {
      // Validate input
      if (entries.isEmpty) {
        throw ArgumentError('Cannot analyze empty entry list. Add journal entries first.');
      }

      // 1. Aggregate daily signals
      final dailySignals = await _aggregateDailySignals(entries);
      
      // 2. Detect change points
      final changePoints = _detectChangePoints(dailySignals);
      
      // 3. Create segments from change points
      final segments = _createSegments(entries, changePoints);
      
      // 4. Infer phases for each segment (ATLAS + optional Chronicle fusion)
      final proposals = await _inferSegmentPhases(segments, userId);
      
      // 5. Apply hysteresis and minimum dwell
      final finalProposals = _applyHysteresisAndMinDwell(proposals);
      
      // 6. Categorize by confidence
      final autoAssign = finalProposals.where((p) => p.confidence >= _minConfidence).toList();
      final review = finalProposals.where((p) => 
        p.confidence >= _reviewConfidence && p.confidence < _minConfidence).toList();
      final lowConfidence = finalProposals.where((p) => p.confidence < _reviewConfidence).toList();

          AnalyticsService.trackEvent('rivet_sweep.analysis_completed', properties: {
        'total_segments': finalProposals.length,
        'auto_assign': autoAssign.length,
        'review_needed': review.length,
        'low_confidence': lowConfidence.length,
      });

      return RivetSweepResult(
        autoAssign: autoAssign,
        review: review,
        lowConfidence: lowConfidence,
        changePoints: changePoints,
        dailySignals: dailySignals,
      );
    } catch (e) {
          AnalyticsService.trackEvent('rivet_sweep.analysis_failed', properties: {
        'error': e.toString(),
      });
      rethrow;
    }
  }

  /// Apply RIVET Sweep proposals to create phase regimes
  Future<List<PhaseRegime>> applyProposals(
    List<PhaseSegmentProposal> proposals,
    PhaseIndex phaseIndex,
  ) async {
    final regimes = <PhaseRegime>[];
    final journalRepo = JournalRepository();
    
    for (final proposal in proposals) {
      final regime = PhaseRegime(
        id: 'rivet_${DateTime.now().millisecondsSinceEpoch}_${regimes.length}',
        label: proposal.proposedLabel,
        start: proposal.start,
        end: proposal.end,
        source: PhaseSource.rivet,
        confidence: proposal.confidence,
        inferredAt: DateTime.now(),
        anchors: proposal.entryIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      regimes.add(regime);
      phaseIndex.addRegime(regime);
      
      // Add phase hashtags to entries in this regime
      await _addPhaseHashtagsToEntries(proposal.entryIds, proposal.proposedLabel, journalRepo);
    }

        AnalyticsService.trackEvent('rivet_sweep.proposals_applied', properties: {
      'regime_count': regimes.length,
    });

    return regimes;
  }

  /// Add phase hashtags to entries retroactively when phases are detected
  Future<void> _addPhaseHashtagsToEntries(
    List<String> entryIds,
    PhaseLabel phaseLabel,
    JournalRepository journalRepo,
  ) async {
    try {
      final phaseName = _getPhaseLabelName(phaseLabel).toLowerCase();
      final hashtag = '#$phaseName';
      
      print('DEBUG: RIVET Sweep - Adding phase hashtag $hashtag to ${entryIds.length} entries');
      
      int updatedCount = 0;
      for (final entryId in entryIds) {
        try {
          final entry = await journalRepo.getJournalEntryById(entryId);
          if (entry == null) {
            print('DEBUG: RIVET Sweep - Entry $entryId not found, skipping');
            continue;
          }
          
          // Check if hashtag already exists (case-insensitive)
          final contentLower = entry.content.toLowerCase();
          if (contentLower.contains(hashtag)) {
            print('DEBUG: RIVET Sweep - Entry $entryId already has hashtag $hashtag, skipping');
            continue;
          }
          
          // Remove any existing phase hashtags first
          final allPhaseHashtags = PhaseLabel.values.map((label) => 
            '#${_getPhaseLabelName(label).toLowerCase()}'
          ).toList();
          
          String cleanedContent = entry.content;
          for (final existingHashtag in allPhaseHashtags) {
            if (existingHashtag == hashtag) continue; // Don't remove the one we're adding
            final regex = RegExp(RegExp.escape(existingHashtag), caseSensitive: false);
            cleanedContent = cleanedContent.replaceAll(regex, '').trim();
          }
          
          // Add new hashtag to content
          final updatedContent = '$cleanedContent $hashtag'.trim();
          final updatedEntry = entry.copyWith(
            content: updatedContent,
            updatedAt: DateTime.now(),
          );
          
          await journalRepo.updateJournalEntry(updatedEntry);
          updatedCount++;
          print('DEBUG: RIVET Sweep - Added hashtag $hashtag to entry $entryId');
        } catch (e) {
          print('DEBUG: RIVET Sweep - Error updating entry $entryId: $e');
        }
      }
      
      print('DEBUG: RIVET Sweep - Successfully added phase hashtags to $updatedCount/${entryIds.length} entries');
    } catch (e) {
      print('DEBUG: RIVET Sweep - Error adding phase hashtags to entries: $e');
    }
  }

  /// Get phase label name as string
  String _getPhaseLabelName(PhaseLabel label) {
    return label.toString().split('.').last;
  }

  /// Aggregate daily signals from entries
  Future<List<DailySignal>> _aggregateDailySignals(List<JournalEntry> entries) async {
    final dailyMap = <String, List<JournalEntry>>{};
    
    // Group entries by date
    for (final entry in entries) {
      final dateKey = '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap.putIfAbsent(dateKey, () => <JournalEntry>[]).add(entry);
    }

    final signals = <DailySignal>[];
    
    for (final entry in dailyMap.entries) {
      final date = DateTime.parse(entry.key);
      final dayEntries = entry.value;
      
      // Calculate topic shift (cosine distance from 14-day trailing mean)
      final topicShift = await _calculateTopicShift(dayEntries, dailyMap, date);
      
      // Calculate emotion delta
      final emotionDelta = _calculateEmotionDelta(dayEntries);
      
      // Calculate tempo (FFT energy ratio)
      final tempo = _calculateTempo(dayEntries);
      
      // Composite score
      final composite = 0.4 * topicShift + 0.4 * emotionDelta + 0.2 * tempo;
      
      signals.add(DailySignal(
        date: date,
        topicShift: topicShift,
        emotionDelta: emotionDelta,
        tempo: tempo,
        composite: composite,
        entryCount: dayEntries.length,
      ));
    }
    
    signals.sort((a, b) => a.date.compareTo(b.date));
    return signals;
  }

  /// Calculate topic shift using cosine similarity
  Future<double> _calculateTopicShift(
    List<JournalEntry> dayEntries,
    Map<String, List<JournalEntry>> dailyMap,
    DateTime date,
  ) async {
    if (dayEntries.isEmpty) return 0.0;
    
    // Get current day's mean embedding
    final currentEmbeddings = <List<double>>[];
    for (final _ in dayEntries) {
      // This would use your existing embedding service
      // For now, return a placeholder
      currentEmbeddings.add(List.filled(384, 0.5)); // Placeholder embedding
    }
    final currentMean = _meanEmbedding(currentEmbeddings);
    
    // Get 14-day trailing mean
    final trailingEntries = <JournalEntry>[];
    for (int i = 1; i <= 14; i++) {
      final pastDate = date.subtract(Duration(days: i));
      final pastKey = '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}';
      trailingEntries.addAll(dailyMap[pastKey] ?? <JournalEntry>[]);
    }
    
    if (trailingEntries.isEmpty) return 0.0;
    
    final trailingEmbeddings = <List<double>>[];
    for (final _ in trailingEntries) {
      trailingEmbeddings.add(List.filled(384, 0.5)); // Placeholder
    }
    final trailingMean = _meanEmbedding(trailingEmbeddings);
    
    // Calculate cosine distance
    return _cosineDistance(currentMean, trailingMean);
  }

  /// Calculate emotion delta
  double _calculateEmotionDelta(List<JournalEntry> dayEntries) {
    if (dayEntries.isEmpty) return 0.0;
    
    // This would use your existing emotion analysis
    // For now, return a placeholder based on mood diversity
    final moods = dayEntries.map((e) => e.mood).toSet();
    return moods.length / 10.0; // Normalize to 0-1
  }

  /// Calculate tempo (FFT energy ratio)
  double _calculateTempo(List<JournalEntry> dayEntries) {
    if (dayEntries.isEmpty) return 0.0;
    
    // This would use FFT on entry density and intensity
    // For now, return a placeholder based on entry count and time spread
    final times = dayEntries.map((e) => e.createdAt.hour + e.createdAt.minute / 60.0).toList();
    times.sort();
    
    if (times.length < 2) return 0.0;
    
    final spread = times.last - times.first;
    return min(spread / 24.0, 1.0); // Normalize to 0-1
  }

  /// Detect change points using binary segmentation
  List<PhaseChangePoint> _detectChangePoints(List<DailySignal> signals) {
    if (signals.length < _minRegimeDuration.inDays * 2) return [];

    final changePoints = <PhaseChangePoint>[];
    final compositeScores = signals.map((s) => s.composite).toList();

    // Simple change point detection - find significant drops in composite score
    for (int i = _minRegimeDuration.inDays; i < compositeScores.length - _minRegimeDuration.inDays; i++) {
      final before = compositeScores.sublist(i - _minRegimeDuration.inDays, i);
      final after = compositeScores.sublist(i, i + _minRegimeDuration.inDays);
      
      final beforeMean = before.reduce((a, b) => a + b) / before.length;
      final afterMean = after.reduce((a, b) => a + b) / after.length;
      
      final change = (beforeMean - afterMean).abs();
      
      if (change > 0.3) { // Threshold for significant change
        changePoints.add(PhaseChangePoint(
          timestamp: signals[i].date,
          score: change,
          signals: {
            'topic_shift': signals[i].topicShift,
            'emotion_delta': signals[i].emotionDelta,
            'tempo': signals[i].tempo,
          },
        ));
      }
    }
    
    return changePoints;
  }

  /// Create segments from change points
  List<EntrySegment> _createSegments(List<JournalEntry> entries, List<PhaseChangePoint> changePoints) {
    final segments = <EntrySegment>[];
    final sortedEntries = List.from(entries)..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (sortedEntries.isEmpty) {
      return segments;
    }

    DateTime segmentStart = sortedEntries.first.createdAt;
    
    for (final changePoint in changePoints) {
      final segmentEntries = sortedEntries.where((entry) =>
        entry.createdAt.isAfter(segmentStart) && 
        entry.createdAt.isBefore(changePoint.timestamp)
      ).toList();
      
      if (segmentEntries.isNotEmpty) {
        segments.add(EntrySegment(
          start: segmentStart,
          end: changePoint.timestamp,
              entries: segmentEntries.cast<JournalEntry>(),
        ));
      }
      
      segmentStart = changePoint.timestamp;
    }
    
    // Add final segment
    final finalSegmentEntries = sortedEntries.where((entry) =>
      entry.createdAt.isAfter(segmentStart)
    ).toList();
    
    if (finalSegmentEntries.isNotEmpty) {
      segments.add(EntrySegment(
        start: segmentStart,
        end: DateTime.now(),
            entries: finalSegmentEntries.cast<JournalEntry>(),
      ));
    }
    
    return segments;
  }

  /// Infer phases for segments using RIVET classifier.
  /// When [userId] is non-null, Chronicle phase scores are fused with ATLAS for the proposal.
  Future<List<PhaseSegmentProposal>> _inferSegmentPhases(
    List<EntrySegment> segments, [
    String? userId,
  ]) async {
    final proposals = <PhaseSegmentProposal>[];
    PhaseLabel? prevProposedPhase;

    for (final segment in segments) {
      if (segment.entries.isEmpty) continue;

      // Sort entries chronologically to analyze trends
      final sortedEntries = List<JournalEntry>.from(segment.entries)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Analyze phase trends across consecutive entries in this segment
      final phaseTrends = _analyzePhaseTrends(sortedEntries);

      // Determine the dominant phase for this segment based on trends (used when no Chronicle fusion)
      final dominantPhase = _determineDominantPhase(phaseTrends, sortedEntries);
      final confidence = _calculateTrendConfidence(phaseTrends, sortedEntries);

      // Aggregate content and keywords from all entries in segment
      final content = sortedEntries.map((e) => e.content).join(' ');
      final keywords = sortedEntries.expand((e) => e.keywords).toList();

      // ATLAS scores for this segment (used for fusion or as fallback)
      final atlasScores = AtlasPhaseDecisionService.generatePhaseScores(
        content: content,
        keywords: keywords,
      );

      PhaseLabel proposedLabel = dominantPhase;
      if (userId != null) {
        final chronicleScores = await ChroniclePhaseSignalService.getPhaseScores(
          userId,
          segmentStart: segment.start,
          segmentEnd: segment.end,
        );
        if (chronicleScores != null) {
          final fusedScores = _fusePhaseScores(atlasScores, chronicleScores);
          final decided = AtlasPhaseDecisionService.decidePhaseForEntry(
            scores: fusedScores,
            prevPhase: prevProposedPhase,
          );
          if (decided != null) proposedLabel = decided;
        }
      }
      prevProposedPhase = proposedLabel;

      proposals.add(PhaseSegmentProposal(
        start: segment.start,
        end: segment.end,
        proposedLabel: proposedLabel,
        confidence: confidence,
        signals: {
          'entry_count': sortedEntries.length.toDouble(),
          'trend_strength': phaseTrends['trend_strength'] ?? 0.0,
          'phase_consistency': phaseTrends['consistency'] ?? 0.0,
        },
        entryIds: sortedEntries.map((e) => e.id).toList(),
        summary: _generateSummary(content),
        topKeywords: _extractTopKeywords(keywords),
      ));
    }

    return proposals;
  }

  /// Fuse ATLAS and Chronicle phase score maps with fixed weight.
  Map<PhaseLabel, double> _fusePhaseScores(
    Map<PhaseLabel, double> atlasScores,
    Map<PhaseLabel, double> chronicleScores,
  ) {
    const w = _chronicleFusionWeight;
    final fused = <PhaseLabel, double>{};
    for (final phase in PhaseLabel.values) {
      final a = atlasScores[phase] ?? 0.1;
      final c = chronicleScores[phase] ?? 0.1;
      fused[phase] = (1 - w) * a + w * c;
    }
    return fused;
  }

  /// Analyze phase trends across consecutive entries to detect patterns
  /// Returns a map with phase distribution and trend strength
  Map<String, dynamic> _analyzePhaseTrends(List<JournalEntry> entries) {
    if (entries.isEmpty) {
      return {'trend_strength': 0.0, 'consistency': 0.0};
    }

    // Get phase recommendations for each entry using PhaseRecommender
    final phaseCounts = <PhaseLabel, int>{};
    final consecutivePatterns = <PhaseLabel, int>{}; // Track consecutive same-phase entries
    
    PhaseLabel? lastPhase;
    int consecutiveCount = 0;
    int totalConsecutive = 0;

    for (final entry in entries) {
      // Use existing phase data with proper priority hierarchy:
      // 1. userPhaseOverride (manual user choice or imported phase) - especially if isPhaseLocked
      // 2. autoPhase (model-detected phase)
      // 3. Infer from content using PhaseRecommender
      String? recommendedPhaseStr;
      
      // Use computedPhase which respects the proper hierarchy (userPhaseOverride > autoPhase > legacy)
      final existingPhase = entry.computedPhase;
      
      if (existingPhase != null && existingPhase.trim().isNotEmpty) {
        // Entry already has a phase (manual, imported, or previously detected)
        // Respect it, especially if isPhaseLocked
        recommendedPhaseStr = existingPhase;
        if (entry.isPhaseLocked) {
          print('DEBUG: RIVET Sweep - Entry ${entry.id} has LOCKED phase: $recommendedPhaseStr (will not override)');
        } else if (entry.userPhaseOverride != null) {
          print('DEBUG: RIVET Sweep - Entry ${entry.id} has userPhaseOverride: $recommendedPhaseStr (respecting user choice)');
        } else {
          print('DEBUG: RIVET Sweep - Entry ${entry.id} has existing phase: $recommendedPhaseStr');
        }
      } else {
        // No existing phase data - infer from content using PhaseRecommender
        recommendedPhaseStr = PhaseRecommender.recommend(
          emotion: entry.emotion ?? '',
          reason: entry.emotionReason ?? '',
          text: entry.content,
          selectedKeywords: entry.keywords,
        );
        print('DEBUG: RIVET Sweep - Entry ${entry.id} inferring phase from content: $recommendedPhaseStr');
      }
      
      // Convert string to PhaseLabel enum
      final recommendedPhase = _stringToPhaseLabel(recommendedPhaseStr ?? 'Discovery');
      
      // Count phase occurrences
      phaseCounts[recommendedPhase] = (phaseCounts[recommendedPhase] ?? 0) + 1;
      
      // Track consecutive patterns
      if (lastPhase == recommendedPhase) {
        consecutiveCount++;
      } else {
        if (consecutiveCount > 1 && lastPhase != null) {
          consecutivePatterns[lastPhase] = 
              (consecutivePatterns[lastPhase] ?? 0) + consecutiveCount;
          totalConsecutive += consecutiveCount;
        }
        consecutiveCount = 1;
        lastPhase = recommendedPhase;
      }
    }
    
    // Handle final consecutive pattern
    if (consecutiveCount > 1 && lastPhase != null) {
      consecutivePatterns[lastPhase] = 
          (consecutivePatterns[lastPhase] ?? 0) + consecutiveCount;
      totalConsecutive += consecutiveCount;
    }

    // Calculate consistency (how many entries show the same phase)
    final maxCount = phaseCounts.values.isNotEmpty 
        ? phaseCounts.values.reduce((a, b) => a > b ? a : b) 
        : 0;
    final consistency = entries.isEmpty ? 0.0 : (maxCount / entries.length);
    
    // Calculate trend strength (based on consecutive patterns)
    final trendStrength = entries.isEmpty 
        ? 0.0 
        : (totalConsecutive / entries.length).clamp(0.0, 1.0);

    return {
      'phase_counts': phaseCounts,
      'consecutive_patterns': consecutivePatterns,
      'trend_strength': trendStrength,
      'consistency': consistency,
      'total_entries': entries.length,
    };
  }

  /// Extract phase hashtag from text (e.g., #discovery, #transition)
  String? _extractPhaseHashtag(String text) {
    // Match hashtags followed by phase names (case-insensitive)
    final hashtagPattern = RegExp(r'#(discovery|expansion|transition|consolidation|recovery|breakthrough)', caseSensitive: false);
    final match = hashtagPattern.firstMatch(text);
    
    if (match != null) {
      final phaseName = match.group(1)?.toLowerCase();
      if (phaseName != null) {
        // Capitalize first letter to match expected format
        return phaseName[0].toUpperCase() + phaseName.substring(1);
      }
    }
    
    return null;
  }

  /// Convert string phase name to PhaseLabel enum
  PhaseLabel _stringToPhaseLabel(String phaseStr) {
    final normalized = phaseStr.toLowerCase().trim();
    switch (normalized) {
      case 'discovery':
        return PhaseLabel.discovery;
      case 'expansion':
        return PhaseLabel.expansion;
      case 'transition':
        return PhaseLabel.transition;
      case 'consolidation':
        return PhaseLabel.consolidation;
      case 'recovery':
        return PhaseLabel.recovery;
      case 'breakthrough':
        return PhaseLabel.breakthrough;
      default:
        // More balanced fallback - rotate through phases instead of always Discovery
        final phases = [PhaseLabel.expansion, PhaseLabel.transition, PhaseLabel.consolidation, PhaseLabel.discovery];
        return phases[phaseStr.hashCode % phases.length];
    }
  }

  /// Determine the dominant phase for a segment based on trends
  PhaseLabel _determineDominantPhase(
    Map<String, dynamic> trends,
    List<JournalEntry> entries,
  ) {
    final phaseCounts = trends['phase_counts'] as Map<PhaseLabel, int>?;
    
    if (phaseCounts == null || phaseCounts.isEmpty) {
      // Fallback to content-based inference using ATLAS scoring
      final content = entries.map((e) => e.content).join(' ');
      final keywords = entries.expand((e) => e.keywords).toList();
      final inferredPhase = _inferPhaseFromContent(content, keywords);

      // If ATLAS scoring returns null (weak signal), use a balanced fallback
      if (inferredPhase == null) {
        // Rotate through phases based on content characteristics to avoid bias
        final contentLength = content.length;
        if (contentLength < 200) {
          return PhaseLabel.discovery; // Short content suggests exploration
        } else if (contentLength > 800) {
          return PhaseLabel.consolidation; // Long content suggests integration
        } else {
          // Medium content - rotate through transition/expansion
          final phases = [PhaseLabel.transition, PhaseLabel.expansion];
          return phases[content.hashCode % phases.length];
        }
      }

      return inferredPhase;
    }

    // Find phase with highest count
    PhaseLabel? dominantPhase;
    int maxCount = 0;
    
    for (final entry in phaseCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominantPhase = entry.key;
      }
    }

    // Also consider consecutive patterns - if a phase appears in long streaks, boost it
    final consecutivePatterns = trends['consecutive_patterns'] as Map<PhaseLabel, int>?;
    if (consecutivePatterns != null && consecutivePatterns.isNotEmpty) {
      int maxConsecutive = 0;
      PhaseLabel? consecutivePhase;
      
      for (final entry in consecutivePatterns.entries) {
        if (entry.value > maxConsecutive) {
          maxConsecutive = entry.value;
          consecutivePhase = entry.key;
        }
      }
      
      // If consecutive pattern is strong (3+ entries in a row), prefer it
      if (maxConsecutive >= 3 && consecutivePhase != null) {
        // Boost confidence for phases with strong consecutive patterns
        final consecutiveRatio = maxConsecutive / entries.length;
        if (consecutiveRatio > 0.3) { // 30% or more entries in consecutive pattern
          dominantPhase = consecutivePhase;
        }
      }
    }

    return dominantPhase ?? PhaseLabel.discovery;
  }

  /// Calculate confidence based on trend analysis
  double _calculateTrendConfidence(
    Map<String, dynamic> trends,
    List<JournalEntry> entries,
  ) {
    if (entries.isEmpty) return 0.0;

    final consistency = trends['consistency'] as double? ?? 0.0;
    final trendStrength = trends['trend_strength'] as double? ?? 0.0;
    
    // Confidence increases with:
    // 1. High consistency (most entries show same phase)
    // 2. Strong trend strength (consecutive patterns)
    // 3. More entries in segment (more data = higher confidence)
    
    final entryCountScore = min(entries.length / 10.0, 1.0); // More entries = better
    final consistencyScore = consistency;
    final trendScore = trendStrength;
    
    // Weighted combination
    final confidence = (consistencyScore * 0.5 + 
                        trendScore * 0.3 + 
                        entryCountScore * 0.2).clamp(0.0, 1.0);
    
    return confidence;
  }

  /// Apply hysteresis and minimum dwell constraints with enhanced duration validation
  List<PhaseSegmentProposal> _applyHysteresisAndMinDwell(List<PhaseSegmentProposal> proposals) {
    if (proposals.isEmpty) return [];

    final result = <PhaseSegmentProposal>[];
    PhaseLabel? lastLabel;
    double lastConfidence = 0.0;

    for (int i = 0; i < proposals.length; i++) {
      final proposal = proposals[i];
      final duration = proposal.end.difference(proposal.start);

      // Enhanced minimum duration validation
      if (duration.inDays < _minRegimeDuration.inDays) {
        print('DEBUG: Rejecting regime shorter than minimum duration: ${duration.inDays} days (${proposal.proposedLabel})');

        // Try to merge with adjacent regimes of same phase
        if (lastLabel == proposal.proposedLabel && result.isNotEmpty) {
          final lastProposal = result.last;
          final mergedDuration = proposal.end.difference(lastProposal.start);

          if (mergedDuration.inDays >= _minRegimeDuration.inDays) {
            print('DEBUG: Merging short regime with previous: ${mergedDuration.inDays} days');
            result[result.length - 1] = PhaseSegmentProposal(
              start: lastProposal.start,
              end: proposal.end,
              proposedLabel: proposal.proposedLabel,
              confidence: (lastProposal.confidence + proposal.confidence) / 2,
              signals: {...lastProposal.signals, ...proposal.signals},
              entryIds: [...lastProposal.entryIds, ...proposal.entryIds],
              summary: lastProposal.summary,
              topKeywords: [...lastProposal.topKeywords, ...proposal.topKeywords].take(5).toList(),
            );
          }
        }
        // Try to merge with next regime if same phase
        else if (i + 1 < proposals.length && proposals[i + 1].proposedLabel == proposal.proposedLabel) {
          final nextProposal = proposals[i + 1];
          final mergedDuration = nextProposal.end.difference(proposal.start);

          if (mergedDuration.inDays >= _minRegimeDuration.inDays) {
            print('DEBUG: Merging short regime with next: ${mergedDuration.inDays} days');
            // Skip current proposal, next iteration will handle the merged regime
            proposals[i + 1] = PhaseSegmentProposal(
              start: proposal.start,
              end: nextProposal.end,
              proposedLabel: proposal.proposedLabel,
              confidence: (proposal.confidence + nextProposal.confidence) / 2,
              signals: {...proposal.signals, ...nextProposal.signals},
              entryIds: [...proposal.entryIds, ...nextProposal.entryIds],
              summary: proposal.summary,
              topKeywords: [...proposal.topKeywords, ...nextProposal.topKeywords].take(5).toList(),
            );
          }
        }
        continue;
      }

      // Flag short-term regimes for review
      PhaseSegmentProposal finalProposal = proposal;
      if (duration.inDays < _preferredMinDuration.inDays) {
        print('DEBUG: Short regime flagged for review: ${duration.inDays} days (${proposal.proposedLabel})');
        // Reduce confidence for short regimes to encourage manual review
        finalProposal = PhaseSegmentProposal(
          start: proposal.start,
          end: proposal.end,
          proposedLabel: proposal.proposedLabel,
          confidence: proposal.confidence * 0.8, // Reduce confidence by 20%
          signals: proposal.signals,
          entryIds: proposal.entryIds,
          summary: '${proposal.summary ?? ''} [Short regime - review recommended]',
          topKeywords: proposal.topKeywords,
        );
      }

      // Apply hysteresis
      if (lastLabel != null && lastLabel == finalProposal.proposedLabel) {
        // Same label as previous - check if confidence improved enough
        if (finalProposal.confidence - lastConfidence < _hysteresisThreshold) {
          // Not enough improvement, keep previous label
          continue;
        }
      }

      result.add(finalProposal);
      lastLabel = finalProposal.proposedLabel;
      lastConfidence = finalProposal.confidence;
    }

    // Final validation: ensure we don't have too many regimes per year
    return _validateRegimeFrequency(result);
  }

  /// Validate that we don't have too many regimes per year (prevents micro-regimes)
  List<PhaseSegmentProposal> _validateRegimeFrequency(List<PhaseSegmentProposal> proposals) {
    if (proposals.isEmpty) return proposals;

    final sortedProposals = List<PhaseSegmentProposal>.from(proposals)
      ..sort((a, b) => a.start.compareTo(b.start));

    final totalDuration = sortedProposals.last.end.difference(sortedProposals.first.start);
    final yearsSpanned = totalDuration.inDays / 365.0;
    final regimesPerYear = proposals.length / yearsSpanned;

    print('DEBUG: Regime frequency validation: ${proposals.length} regimes over ${yearsSpanned.toStringAsFixed(1)} years = ${regimesPerYear.toStringAsFixed(1)} regimes/year');

    if (regimesPerYear > _maxRegimesPerYear) {
      print('WARNING: Too many regimes detected (${regimesPerYear.toStringAsFixed(1)}/year > $_maxRegimesPerYear/year limit)');
      print('Consider increasing minimum duration or reducing detection sensitivity.');
    }

    return proposals;
  }

  // Helper methods
  List<double> _meanEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return List.filled(384, 0.0);
    
    final mean = List.filled(embeddings.first.length, 0.0);
    for (final embedding in embeddings) {
      for (int i = 0; i < embedding.length; i++) {
        mean[i] += embedding[i];
      }
    }
    
    for (int i = 0; i < mean.length; i++) {
      mean[i] /= embeddings.length;
    }
    
    return mean;
  }

  double _cosineDistance(List<double> a, List<double> b) {
    if (a.length != b.length) return 1.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 1.0;
    
    return 1.0 - (dotProduct / (sqrt(normA) * sqrt(normB)));
  }

  /// Infer phase from content using ATLAS phase decision scoring system.
  /// RIVET uses ATLAS here so phases are determined by ATLAS scoring + hysteresis.
  PhaseLabel? _inferPhaseFromContent(String content, List<String> keywords, {PhaseLabel? prevPhase}) {
    // Generate phase scores using ATLAS decision system
    final scores = AtlasPhaseDecisionService.generatePhaseScores(
      content: content,
      keywords: keywords,
    );

    // Use ATLAS decision logic to determine phase with hysteresis
    final decidedPhase = AtlasPhaseDecisionService.decidePhaseForEntry(
      scores: scores,
      prevPhase: prevPhase,
    );

    print('DEBUG: RIVET Phase inference for content (${content.length} chars):');
    AtlasPhaseDecisionService.debugPrintScores(scores, 'segment');
    print('  Previous: ${AtlasPhaseDecisionService.phaseToString(prevPhase)}');
    print('  Decided: ${AtlasPhaseDecisionService.phaseToString(decidedPhase)}');

    return decidedPhase;
  }

  String _generateSummary(String content) {
    // Simple summary generation - take first sentence or first 100 chars
    final sentences = content.split('.');
    if (sentences.isNotEmpty && sentences.first.length > 10) {
      return sentences.first.trim();
    }
    return content.length > 100 ? '${content.substring(0, 100)}...' : content;
  }

  List<String> _extractTopKeywords(List<String> keywords) {
    // Count keyword frequency and return top 5
    final frequency = <String, int>{};
    for (final keyword in keywords) {
      frequency[keyword] = (frequency[keyword] ?? 0) + 1;
    }
    
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => e.key).toList();
  }
}

/// Runs RIVET Sweep then applies proposals. Phases are determined by RIVET + ATLAS;
/// Sentinel override (Recovery when alert) is applied in the UI/regime-creation layer.
// Supporting classes
class DailySignal {
  final DateTime date;
  final double topicShift;
  final double emotionDelta;
  final double tempo;
  final double composite;
  final int entryCount;

  const DailySignal({
    required this.date,
    required this.topicShift,
    required this.emotionDelta,
    required this.tempo,
    required this.composite,
    required this.entryCount,
  });
}

class EntrySegment {
  final DateTime start;
  final DateTime end;
  final List<JournalEntry> entries;

  const EntrySegment({
    required this.start,
    required this.end,
    required this.entries,
  });
}

class RivetSweepResult {
  final List<PhaseSegmentProposal> autoAssign;
  final List<PhaseSegmentProposal> review;
  final List<PhaseSegmentProposal> lowConfidence;
  final List<PhaseChangePoint> changePoints;
  final List<DailySignal> dailySignals;

  const RivetSweepResult({
    required this.autoAssign,
    required this.review,
    required this.lowConfidence,
    required this.changePoints,
    required this.dailySignals,
  });

  /// All proposals that should be auto-applied (auto + review, skipping low).
  List<PhaseSegmentProposal> get approvableProposals =>
      [...autoAssign, ...review]..sort((a, b) => a.start.compareTo(b.start));
}

/// Runs RIVET Sweep analysis on all entries and auto-creates phase regimes.
///
/// This is a headless convenience wrapper used after ARCX import to
/// automatically detect phases without requiring the user to navigate to
/// Settings > Phase Analysis.
///
/// Returns the number of regimes created, or -1 on error.
Future<int> runAutoPhaseAnalysis() async {
  try {
    final journalRepo = JournalRepository();
    final entries = journalRepo.getAllJournalEntriesSync();

    if (entries.length < 5) {
      print('AutoPhaseAnalysis: Not enough entries (${entries.length}) — need at least 5');
      return 0;
    }

    final analyticsService = AnalyticsService();
    final rivetSweepService = RivetSweepService(analyticsService);
    final userId = FirebaseAuthService.instance.currentUser?.uid;
    final result = await rivetSweepService.analyzeEntries(entries, userId: userId);

    final proposals = result.approvableProposals;
    if (proposals.isEmpty) {
      print('AutoPhaseAnalysis: No proposals to apply');
      return 0;
    }

    // Initialize phase regime service
    final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
    await phaseRegimeService.initialize();

    // Create regimes from proposals (RIVET + ATLAS phase; Sentinel can override to Recovery)
    int created = 0;
    for (int i = 0; i < proposals.length; i++) {
      final proposal = proposals[i];
      final isLast = i == proposals.length - 1;

      DateTime? regimeEnd = proposal.end;
      if (isLast) {
        final daysSinceEnd = DateTime.now().difference(proposal.end).inDays;
        if (daysSinceEnd <= 2) regimeEnd = null; // ongoing
      }

      final label = await resolvePhaseWithSentinel(proposal, entries);
      await phaseRegimeService.createRegime(
        label: label,
        start: proposal.start,
        end: regimeEnd,
        source: PhaseSource.rivet,
        confidence: proposal.confidence,
        anchors: proposal.entryIds,
      );
      created++;
    }

    await phaseRegimeService.setLastAnalysisDate(DateTime.now());
    print('AutoPhaseAnalysis: Created $created phase regimes from ${entries.length} entries');
    return created;
  } catch (e) {
    print('AutoPhaseAnalysis: Failed — $e');
    return -1;
  }
}

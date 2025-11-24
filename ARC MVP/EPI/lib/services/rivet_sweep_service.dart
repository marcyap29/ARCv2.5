// lib/services/rivet_sweep_service.dart
// RIVET Sweep: Segmented Phase Backfill Pipeline

import 'dart:math';
import '../models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'phase_index.dart';
// import 'semantic_similarity_service.dart'; // TODO: Implement or use existing
import 'analytics_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';

class RivetSweepService {
  // final SemanticSimilarityService _similarityService; // TODO: Implement
  // final AnalyticsService _analytics; // TODO: Use analytics
  
  // Configuration
  static const Duration _minWindowDays = Duration(days: 10);
  static const double _minConfidence = 0.70;
  static const double _reviewConfidence = 0.50;
  static const double _hysteresisThreshold = 0.15;
  // static const int _maxSegmentsPerYear = 15; // TODO: Use in future
  // static const int _minSegmentsPerYear = 6; // TODO: Use in future

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

  /// Run RIVET Sweep analysis
  Future<RivetSweepResult> analyzeEntries(List<JournalEntry> entries) async {
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
      
      // 4. Infer phases for each segment
      final proposals = await _inferSegmentPhases(segments);
      
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
          final entry = journalRepo.getJournalEntryById(entryId);
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
    if (signals.length < _minWindowDays.inDays * 2) return [];
    
    final changePoints = <PhaseChangePoint>[];
    final compositeScores = signals.map((s) => s.composite).toList();
    
    // Simple change point detection - find significant drops in composite score
    for (int i = _minWindowDays.inDays; i < compositeScores.length - _minWindowDays.inDays; i++) {
      final before = compositeScores.sublist(i - _minWindowDays.inDays, i);
      final after = compositeScores.sublist(i, i + _minWindowDays.inDays);
      
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

  /// Infer phases for segments using RIVET classifier
  /// Analyzes all entries in each segment and detects trends across consecutive entries
  Future<List<PhaseSegmentProposal>> _inferSegmentPhases(List<EntrySegment> segments) async {
    final proposals = <PhaseSegmentProposal>[];
    
    for (final segment in segments) {
      if (segment.entries.isEmpty) continue;
      
      // Sort entries chronologically to analyze trends
      final sortedEntries = List<JournalEntry>.from(segment.entries)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Analyze phase trends across consecutive entries in this segment
      final phaseTrends = _analyzePhaseTrends(sortedEntries);
      
      // Determine the dominant phase for this segment based on trends
      final dominantPhase = _determineDominantPhase(phaseTrends, sortedEntries);
      final confidence = _calculateTrendConfidence(phaseTrends, sortedEntries);
      
      // Aggregate content and keywords from all entries in segment
      final content = sortedEntries.map((e) => e.content).join(' ');
      final keywords = sortedEntries.expand((e) => e.keywords).toList();
      
      proposals.add(PhaseSegmentProposal(
        start: segment.start,
        end: segment.end,
        proposedLabel: dominantPhase,
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
      // Use PhaseRecommender for phase detection (hashtags are no longer used for inference)
      // If entry has autoPhase, use that; otherwise use PhaseRecommender
      String? recommendedPhaseStr;
      
      if (entry.autoPhase != null) {
        recommendedPhaseStr = entry.autoPhase;
        print('DEBUG: RIVET Sweep - Entry ${entry.id} has autoPhase: $recommendedPhaseStr');
      } else {
        // Use PhaseRecommender for phase detection
        recommendedPhaseStr = PhaseRecommender.recommend(
          emotion: entry.emotion ?? '',
          reason: entry.emotionReason ?? '',
          text: entry.content,
          selectedKeywords: entry.keywords,
        );
      }
      
      // Convert string to PhaseLabel enum
      final recommendedPhase = _stringToPhaseLabel(recommendedPhaseStr);
      
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
        return PhaseLabel.discovery; // Default fallback
    }
  }

  /// Determine the dominant phase for a segment based on trends
  PhaseLabel _determineDominantPhase(
    Map<String, dynamic> trends,
    List<JournalEntry> entries,
  ) {
    final phaseCounts = trends['phase_counts'] as Map<PhaseLabel, int>?;
    
    if (phaseCounts == null || phaseCounts.isEmpty) {
      // Fallback to content-based inference
      final content = entries.map((e) => e.content).join(' ');
      final keywords = entries.expand((e) => e.keywords).toList();
      return _inferPhaseFromContent(content, keywords);
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

  /// Apply hysteresis and minimum dwell constraints
  List<PhaseSegmentProposal> _applyHysteresisAndMinDwell(List<PhaseSegmentProposal> proposals) {
    if (proposals.isEmpty) return [];
    
    final result = <PhaseSegmentProposal>[];
    PhaseLabel? lastLabel;
    double lastConfidence = 0.0;
    
    for (int i = 0; i < proposals.length; i++) {
      final proposal = proposals[i];
      
      // Check minimum dwell
      final duration = proposal.end.difference(proposal.start);
      if (duration.inDays < _minWindowDays.inDays) {
        // Merge with previous if same label, otherwise skip
        if (lastLabel == proposal.proposedLabel && result.isNotEmpty) {
          final lastProposal = result.last;
          result[result.length - 1] = PhaseSegmentProposal(
            start: lastProposal.start,
            end: proposal.end,
            proposedLabel: proposal.proposedLabel,
            confidence: (lastProposal.confidence + proposal.confidence) / 2,
            signals: {...lastProposal.signals, ...proposal.signals},
            entryIds: [...lastProposal.entryIds, ...proposal.entryIds],
            summary: lastProposal.summary,
            topKeywords: lastProposal.topKeywords,
          );
        }
        continue;
      }
      
      // Apply hysteresis
      if (lastLabel != null && lastLabel == proposal.proposedLabel) {
        // Same label as previous - check if confidence improved enough
        if (proposal.confidence - lastConfidence < _hysteresisThreshold) {
          // Not enough improvement, keep previous label
          continue;
        }
      }
      
      result.add(proposal);
      lastLabel = proposal.proposedLabel;
      lastConfidence = proposal.confidence;
    }
    
    return result;
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

  PhaseLabel _inferPhaseFromContent(String content, List<String> keywords) {
    // Simple heuristic-based phase inference
    final lowerContent = content.toLowerCase();
    final lowerKeywords = keywords.map((k) => k.toLowerCase()).toList();
    
    // Discovery keywords
    if (lowerContent.contains('new') || lowerContent.contains('discover') || 
        lowerKeywords.any((k) => k.contains('learning') || k.contains('explore'))) {
      return PhaseLabel.discovery;
    }
    
    // Expansion keywords
    if (lowerContent.contains('grow') || lowerContent.contains('expand') ||
        lowerKeywords.any((k) => k.contains('growth') || k.contains('building'))) {
      return PhaseLabel.expansion;
    }
    
    // Transition keywords
    if (lowerContent.contains('change') || lowerContent.contains('transition') ||
        lowerKeywords.any((k) => k.contains('change') || k.contains('shift'))) {
      return PhaseLabel.transition;
    }
    
    // Consolidation keywords
    if (lowerContent.contains('consolidate') || lowerContent.contains('stable') ||
        lowerKeywords.any((k) => k.contains('stable') || k.contains('solid'))) {
      return PhaseLabel.consolidation;
    }
    
    // Recovery keywords
    if (lowerContent.contains('recover') || lowerContent.contains('heal') ||
        lowerKeywords.any((k) => k.contains('recovery') || k.contains('healing'))) {
      return PhaseLabel.recovery;
    }
    
    // Breakthrough keywords
    if (lowerContent.contains('breakthrough') || lowerContent.contains('break') ||
        lowerKeywords.any((k) => k.contains('breakthrough') || k.contains('insight'))) {
      return PhaseLabel.breakthrough;
    }
    
    return PhaseLabel.discovery; // Default
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
}

/// SENTINEL - Severity Evaluation and Negative Trend Identification for Emotional Longitudinal tracking
///
/// This module is the reverse of RIVET - instead of filtering keywords to add,
/// it monitors keyword patterns over time to detect escalating risk levels.
///
/// Key Features:
/// - Tracks keyword amplitude patterns over time
/// - Detects clustering of high-amplitude negative keywords
/// - Identifies concerning trends and deterioration patterns
/// - Provides risk level classifications and recommendations
library;

import 'dart:math';
import 'package:my_app/prism/extractors/enhanced_keyword_extractor.dart';
import '../../core/models/reflective_entry_data.dart';

/// Risk level classifications
enum RiskLevel {
  minimal,     // Normal, healthy emotional range
  low,         // Some distress but manageable
  moderate,    // Noticeable concern, should monitor
  elevated,    // Significant concern, consider intervention
  high,        // Serious concern, immediate attention needed
  severe,      // Critical concern, urgent professional help recommended
}

/// Time window for risk analysis
enum TimeWindow {
  day,         // Last 24 hours
  threeDay,    // Last 3 days
  week,        // Last 7 days
  twoWeek,     // Last 14 days
  month,       // Last 30 days
}

/// Configuration for SENTINEL risk detection
class SentinelConfig {
  // Amplitude thresholds
  final double highAmplitudeThreshold;
  final double criticalAmplitudeThreshold;

  // Frequency thresholds (number of entries)
  final int severeConcernFrequency;      // High-amplitude keywords in short period
  final int persistentDistressMinDays;   // Days of continuous negative keywords

  // Clustering detection
  final int clusterWindowHours;          // Time window for detecting clusters
  final int clusterMinSize;              // Minimum cluster size for concern

  // Trend detection
  final double deteriorationThreshold;   // Rate of amplitude increase
  final int trendAnalysisMinEntries;     // Minimum entries needed for trend

  // Phase-based adjustments
  final Map<String, double> phaseRiskMultipliers;

  const SentinelConfig({
    this.highAmplitudeThreshold = 0.75,
    this.criticalAmplitudeThreshold = 0.90,
    this.severeConcernFrequency = 3,
    this.persistentDistressMinDays = 5,
    this.clusterWindowHours = 48,
    this.clusterMinSize = 3,
    this.deteriorationThreshold = 0.15,
    this.trendAnalysisMinEntries = 7,
    this.phaseRiskMultipliers = const {
      'Discovery': 0.8,        // Lower multiplier - exploration is normal
      'Expansion': 0.9,        // Slightly lower - stress can be growth
      'Transition': 1.2,       // Higher multiplier - vulnerable period
      'Consolidation': 1.0,    // Baseline
      'Recovery': 1.3,         // Higher multiplier - fragile state
      'Breakthrough': 1.1,     // Slightly higher - intense period
    },
  });

  static const SentinelConfig defaultConfig = SentinelConfig();
}

/// Represents a journal entry for risk analysis
class JournalEntryData {
  final DateTime timestamp;
  final List<String> keywords;
  final String phase;
  final String? mood;

  const JournalEntryData({
    required this.timestamp,
    required this.keywords,
    required this.phase,
    this.mood,
  });
}

/// Risk pattern detected in the data
class RiskPattern {
  final String type;           // 'cluster', 'persistent', 'escalating', 'phase-mismatch'
  final String description;
  final double severity;       // 0.0 - 1.0
  final List<DateTime> affectedDates;
  final List<String> triggerKeywords;

  const RiskPattern({
    required this.type,
    required this.description,
    required this.severity,
    required this.affectedDates,
    required this.triggerKeywords,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'severity': severity,
    'affected_dates': affectedDates.map((d) => d.toIso8601String()).toList(),
    'trigger_keywords': triggerKeywords,
  };
}

/// Risk analysis result
class SentinelAnalysis {
  final RiskLevel riskLevel;
  final double riskScore;              // 0.0 - 1.0
  final List<RiskPattern> patterns;
  final Map<String, dynamic> metrics;
  final List<String> recommendations;
  final String summary;

  const SentinelAnalysis({
    required this.riskLevel,
    required this.riskScore,
    required this.patterns,
    required this.metrics,
    required this.recommendations,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
    'risk_level': riskLevel.name,
    'risk_score': riskScore,
    'patterns': patterns.map((p) => p.toJson()).toList(),
    'metrics': metrics,
    'recommendations': recommendations,
    'summary': summary,
  };
}

/// Main SENTINEL risk detector
class SentinelRiskDetector {
  static const SentinelConfig _defaultConfig = SentinelConfig.defaultConfig;

  /// Analyze reflective entries (journal, drafts, chats) for risk patterns
  static SentinelAnalysis analyzeRisk({
    required List<ReflectiveEntryData> entries,
    required TimeWindow timeWindow,
    SentinelConfig config = _defaultConfig,
  }) {
    if (entries.isEmpty) {
      return SentinelAnalysis(
        riskLevel: RiskLevel.minimal,
        riskScore: 0.0,
        patterns: [],
        metrics: {},
        recommendations: [],
        summary: 'No data available for analysis',
      );
    }

    // Filter entries by time window
    final now = DateTime.now();
    final cutoffDate = _getCutoffDate(now, timeWindow);
    final filteredEntries = entries
        .where((entry) => entry.timestamp.isAfter(cutoffDate))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (filteredEntries.isEmpty) {
      return SentinelAnalysis(
        riskLevel: RiskLevel.minimal,
        riskScore: 0.0,
        patterns: [],
        metrics: {},
        recommendations: [],
        summary: 'No entries in selected time window',
      );
    }

    // Calculate metrics with source weighting
    final metrics = _calculateMetricsWithWeighting(filteredEntries, config);

    // Detect patterns with source awareness
    final patterns = _detectPatternsWithWeighting(filteredEntries, config);

    // Calculate risk score with source weighting
    final riskScore = _calculateRiskScoreWithWeighting(metrics, patterns, config);

    // Determine risk level
    final riskLevel = _determineRiskLevel(riskScore);

    // Generate recommendations
    final recommendations = _generateRecommendations(riskLevel, patterns, metrics);

    // Generate summary with source breakdown
    final summary = _generateSummaryWithSources(riskLevel, patterns, metrics, filteredEntries);

    return SentinelAnalysis(
      riskLevel: riskLevel,
      riskScore: riskScore,
      patterns: patterns,
      metrics: metrics,
      recommendations: recommendations,
      summary: summary,
    );
  }

  /// Backward-compatible method for journal entries only
  static SentinelAnalysis analyzeJournalRisk({
    required List<JournalEntryData> entries,
    required TimeWindow timeWindow,
    SentinelConfig config = _defaultConfig,
  }) {
    // Convert JournalEntryData to ReflectiveEntryData
    final reflectiveEntries = entries.map((entry) => ReflectiveEntryData.fromJournalEntry(
      timestamp: entry.timestamp,
      keywords: entry.keywords,
      phase: entry.phase,
      mood: entry.mood,
    )).toList();

    return analyzeRisk(
      entries: reflectiveEntries,
      timeWindow: timeWindow,
      config: config,
    );
  }

  /// Calculate metrics with source weighting for ReflectiveEntryData
  static Map<String, dynamic> _calculateMetricsWithWeighting(
    List<ReflectiveEntryData> entries,
    SentinelConfig config,
  ) {
    final metrics = <String, dynamic>{};

    // Amplitude statistics with source weighting
    final amplitudes = <double>[];
    final highAmplitudeCount = <int>[0];
    final criticalAmplitudeCount = <int>[0];
    final sourceBreakdown = <String, int>{};

    for (final entry in entries) {
      double maxAmplitude = 0.0;
      final sourceWeight = entry.effectiveConfidence;
      
      // Track source breakdown
      sourceBreakdown[entry.source.toString()] = (sourceBreakdown[entry.source.toString()] ?? 0) + 1;
      
      for (final keyword in entry.keywords) {
        final baseAmplitude = EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ?? 0.0;
        final weightedAmplitude = baseAmplitude * sourceWeight;
        amplitudes.add(weightedAmplitude);
        
        if (weightedAmplitude >= config.highAmplitudeThreshold) {
          highAmplitudeCount[0]++;
        }
        if (weightedAmplitude >= config.criticalAmplitudeThreshold) {
          criticalAmplitudeCount[0]++;
        }
        if (weightedAmplitude > maxAmplitude) {
          maxAmplitude = weightedAmplitude;
        }
      }
    }

    // Calculate statistics
    final avgAmplitude = amplitudes.isEmpty ? 0.0 : amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final maxAmplitude = amplitudes.isEmpty ? 0.0 : amplitudes.reduce(max);

    metrics['total_entries'] = entries.length;
    metrics['avg_amplitude'] = avgAmplitude;
    metrics['max_amplitude'] = maxAmplitude;
    metrics['high_amplitude_count'] = highAmplitudeCount[0];
    metrics['critical_amplitude_count'] = criticalAmplitudeCount[0];
    metrics['high_amplitude_rate'] = entries.isEmpty ? 0.0 : highAmplitudeCount[0] / entries.length;
    metrics['source_breakdown'] = sourceBreakdown;

    // Temporal metrics
    final daySpan = entries.last.timestamp.difference(entries.first.timestamp).inDays;
    metrics['day_span'] = daySpan;
    metrics['entries_per_day'] = daySpan == 0 ? entries.length.toDouble() : entries.length / daySpan;

    // Negative keyword dominance with weighting
    final negativeKeywords = _countNegativeKeywordsWithWeighting(entries);
    final totalKeywords = entries.fold<double>(0, (sum, entry) => sum + (entry.keywords.length * entry.effectiveConfidence));
    metrics['negative_keyword_ratio'] = totalKeywords == 0 ? 0.0 : negativeKeywords / totalKeywords;

    // Phase distribution
    final phaseCounts = <String, int>{};
    for (final entry in entries) {
      phaseCounts[entry.phase] = (phaseCounts[entry.phase] ?? 0) + 1;
    }
    metrics['phase_distribution'] = phaseCounts;

    // Source confidence metrics
    final avgConfidence = entries.fold<double>(0, (sum, entry) => sum + entry.effectiveConfidence) / entries.length;
    final highConfidenceCount = entries.where((e) => e.isHighConfidence).length;
    metrics['avg_confidence'] = avgConfidence;
    metrics['high_confidence_ratio'] = entries.isEmpty ? 0.0 : highConfidenceCount / entries.length;

    return metrics;
  }

  /// Calculate various metrics from entries (legacy method)
  static Map<String, dynamic> _calculateMetrics(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    final metrics = <String, dynamic>{};

    // Amplitude statistics
    final amplitudes = <double>[];
    final highAmplitudeCount = <int>[0];
    final criticalAmplitudeCount = <int>[0];

    for (final entry in entries) {
      double maxAmplitude = 0.0;
      for (final keyword in entry.keywords) {
        final amplitude = EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ?? 0.0;
        amplitudes.add(amplitude);
        if (amplitude >= config.highAmplitudeThreshold) {
          highAmplitudeCount[0]++;
        }
        if (amplitude >= config.criticalAmplitudeThreshold) {
          criticalAmplitudeCount[0]++;
        }
        if (amplitude > maxAmplitude) {
          maxAmplitude = amplitude;
        }
      }
    }

    // Calculate statistics
    final avgAmplitude = amplitudes.isEmpty ? 0.0 : amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final maxAmplitude = amplitudes.isEmpty ? 0.0 : amplitudes.reduce(max);

    metrics['total_entries'] = entries.length;
    metrics['avg_amplitude'] = avgAmplitude;
    metrics['max_amplitude'] = maxAmplitude;
    metrics['high_amplitude_count'] = highAmplitudeCount[0];
    metrics['critical_amplitude_count'] = criticalAmplitudeCount[0];
    metrics['high_amplitude_rate'] = entries.isEmpty ? 0.0 : highAmplitudeCount[0] / entries.length;

    // Temporal metrics
    final daySpan = entries.last.timestamp.difference(entries.first.timestamp).inDays;
    metrics['day_span'] = daySpan;
    metrics['entries_per_day'] = daySpan == 0 ? entries.length.toDouble() : entries.length / daySpan;

    // Negative keyword dominance
    final negativeKeywords = _countNegativeKeywords(entries);
    final totalKeywords = entries.fold<int>(0, (sum, entry) => sum + entry.keywords.length);
    metrics['negative_keyword_ratio'] = totalKeywords == 0 ? 0.0 : negativeKeywords / totalKeywords;

    // Phase distribution
    final phaseDistribution = <String, int>{};
    for (final entry in entries) {
      phaseDistribution[entry.phase] = (phaseDistribution[entry.phase] ?? 0) + 1;
    }
    metrics['phase_distribution'] = phaseDistribution;

    return metrics;
  }

  /// Detect risk patterns in entries
  static List<RiskPattern> _detectPatterns(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    final patterns = <RiskPattern>[];

    // Pattern 1: Clustering of high-amplitude negative keywords
    final clusterPattern = _detectClustering(entries, config);
    if (clusterPattern != null) patterns.add(clusterPattern);

    // Pattern 2: Persistent distress over multiple days
    final persistentPattern = _detectPersistentDistress(entries, config);
    if (persistentPattern != null) patterns.add(persistentPattern);

    // Pattern 3: Escalating/deteriorating trend
    final escalatingPattern = _detectEscalation(entries, config);
    if (escalatingPattern != null) patterns.add(escalatingPattern);

    // Pattern 4: Phase-emotion mismatch (e.g., extreme distress in "Expansion")
    final mismatchPattern = _detectPhaseMismatch(entries, config);
    if (mismatchPattern != null) patterns.add(mismatchPattern);

    // Pattern 5: Isolation keywords
    final isolationPattern = _detectIsolationPattern(entries, config);
    if (isolationPattern != null) patterns.add(isolationPattern);

    // Pattern 6: Hopelessness indicators
    final hopelessnessPattern = _detectHopelessness(entries, config);
    if (hopelessnessPattern != null) patterns.add(hopelessnessPattern);

    return patterns;
  }

  /// Detect clustering of high-amplitude keywords in short time period
  static RiskPattern? _detectClustering(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    final clusterWindow = Duration(hours: config.clusterWindowHours);
    final clusters = <List<JournalEntryData>>[];

    for (int i = 0; i < entries.length; i++) {
      final cluster = <JournalEntryData>[entries[i]];
      final windowEnd = entries[i].timestamp.add(clusterWindow);

      for (int j = i + 1; j < entries.length; j++) {
        if (entries[j].timestamp.isBefore(windowEnd)) {
          final hasHighAmplitude = entries[j].keywords.any((kw) {
            final amp = EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0;
            return amp >= config.highAmplitudeThreshold;
          });
          if (hasHighAmplitude) {
            cluster.add(entries[j]);
          }
        } else {
          break;
        }
      }

      if (cluster.length >= config.clusterMinSize) {
        clusters.add(cluster);
      }
    }

    if (clusters.isEmpty) return null;

    // Find most severe cluster
    final worstCluster = clusters.reduce((a, b) {
      final aScore = _getClusterSeverity(a, config);
      final bScore = _getClusterSeverity(b, config);
      return aScore > bScore ? a : b;
    });

    final severity = _getClusterSeverity(worstCluster, config);
    final triggerKeywords = worstCluster
        .expand((e) => e.keywords)
        .where((kw) {
          final amp = EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0;
          return amp >= config.highAmplitudeThreshold;
        })
        .toSet()
        .toList();

    return RiskPattern(
      type: 'cluster',
      description: 'Detected ${worstCluster.length} high-intensity entries within ${config.clusterWindowHours} hours',
      severity: severity,
      affectedDates: worstCluster.map((e) => e.timestamp).toList(),
      triggerKeywords: triggerKeywords,
    );
  }

  /// Detect persistent distress over multiple consecutive days
  static RiskPattern? _detectPersistentDistress(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    if (entries.length < config.persistentDistressMinDays) return null;

    // Group entries by day
    final entriesByDay = <DateTime, List<JournalEntryData>>{};
    for (final entry in entries) {
      final dayKey = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      entriesByDay.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Find consecutive days with negative keywords
    final sortedDays = entriesByDay.keys.toList()..sort();
    int consecutiveDays = 0;
    int maxConsecutiveDays = 0;
    List<DateTime> longestStreak = [];
    List<DateTime> currentStreak = [];

    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final dayEntries = entriesByDay[day]!;

      final hasNegativeKeywords = dayEntries.any((entry) {
        return entry.keywords.any((kw) {
          final amp = EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0;
          return amp >= config.highAmplitudeThreshold * 0.8; // Slightly lower threshold
        });
      });

      if (hasNegativeKeywords) {
        consecutiveDays++;
        currentStreak.add(day);
        if (consecutiveDays > maxConsecutiveDays) {
          maxConsecutiveDays = consecutiveDays;
          longestStreak = List.from(currentStreak);
        }
      } else {
        consecutiveDays = 0;
        currentStreak = [];
      }
    }

    if (maxConsecutiveDays < config.persistentDistressMinDays) return null;

    final affectedEntries = entries.where((e) {
      final dayKey = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      return longestStreak.contains(dayKey);
    }).toList();

    final triggerKeywords = affectedEntries
        .expand((e) => e.keywords)
        .where((kw) {
          final amp = EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0;
          return amp >= config.highAmplitudeThreshold * 0.8;
        })
        .toSet()
        .toList();

    final severity = (maxConsecutiveDays / 10).clamp(0.5, 1.0); // Max out at 10 days

    return RiskPattern(
      type: 'persistent',
      description: 'Sustained distress detected over $maxConsecutiveDays consecutive days',
      severity: severity,
      affectedDates: longestStreak,
      triggerKeywords: triggerKeywords,
    );
  }

  /// Detect escalating/deteriorating trend
  static RiskPattern? _detectEscalation(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    if (entries.length < config.trendAnalysisMinEntries) return null;

    // Calculate average amplitude for each entry
    final amplitudeTimeSeries = entries.map((entry) {
      if (entry.keywords.isEmpty) return 0.0;
      final amps = entry.keywords.map((kw) =>
          EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0);
      return amps.reduce((a, b) => a + b) / amps.length;
    }).toList();

    // Simple linear trend detection
    final n = amplitudeTimeSeries.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += amplitudeTimeSeries[i];
      sumXY += i * amplitudeTimeSeries[i];
      sumX2 += i * i;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    // Positive slope means increasing amplitude (worsening)
    if (slope < config.deteriorationThreshold) return null;

    final recentEntries = entries.sublist((entries.length * 0.7).round());
    final triggerKeywords = recentEntries
        .expand((e) => e.keywords)
        .toSet()
        .toList();

    final severity = (slope * 2).clamp(0.3, 1.0);

    return RiskPattern(
      type: 'escalating',
      description: 'Emotional intensity shows concerning upward trend',
      severity: severity,
      affectedDates: recentEntries.map((e) => e.timestamp).toList(),
      triggerKeywords: triggerKeywords,
    );
  }

  /// Detect phase-emotion mismatches
  static RiskPattern? _detectPhaseMismatch(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    final mismatches = <JournalEntryData>[];

    for (final entry in entries) {
      // Check if in "positive" phase but experiencing high negative emotions
      final isPositivePhase = ['Expansion', 'Breakthrough', 'Discovery'].contains(entry.phase);

      if (isPositivePhase) {
        final hasHighNegativeAmplitude = entry.keywords.any((kw) {
          final amp = EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0;
          final isNegative = _isNegativeKeyword(kw);
          return amp >= config.highAmplitudeThreshold && isNegative;
        });

        if (hasHighNegativeAmplitude) {
          mismatches.add(entry);
        }
      }
    }

    if (mismatches.isEmpty) return null;

    final severity = (mismatches.length / entries.length).clamp(0.3, 0.9);
    final triggerKeywords = mismatches
        .expand((e) => e.keywords)
        .toSet()
        .toList();

    return RiskPattern(
      type: 'phase-mismatch',
      description: 'Significant negative emotions during expected positive phase',
      severity: severity,
      affectedDates: mismatches.map((e) => e.timestamp).toList(),
      triggerKeywords: triggerKeywords,
    );
  }

  /// Detect isolation and withdrawal patterns
  static RiskPattern? _detectIsolationPattern(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    const isolationKeywords = [
      'isolated', 'alone', 'lonely', 'abandoned', 'rejected', 'unwanted',
      'disconnected', 'withdrawal', 'hiding', 'avoiding', 'isolating'
    ];

    final isolationEntries = entries.where((entry) {
      return entry.keywords.any((kw) =>
          isolationKeywords.contains(kw.toLowerCase()));
    }).toList();

    if (isolationEntries.length < 2) return null;

    final isolationRate = isolationEntries.length / entries.length;
    if (isolationRate < 0.3) return null;

    final severity = isolationRate.clamp(0.4, 0.95);
    final triggerKeywords = isolationEntries
        .expand((e) => e.keywords)
        .where((kw) => isolationKeywords.contains(kw.toLowerCase()))
        .toSet()
        .toList();

    return RiskPattern(
      type: 'isolation',
      description: 'Pattern of isolation and social withdrawal detected',
      severity: severity,
      affectedDates: isolationEntries.map((e) => e.timestamp).toList(),
      triggerKeywords: triggerKeywords,
    );
  }

  /// Detect hopelessness and despair patterns
  static RiskPattern? _detectHopelessness(
    List<JournalEntryData> entries,
    SentinelConfig config,
  ) {
    const hopelessnessKeywords = [
      'hopeless', 'despair', 'despairing', 'give up', 'giving up', 'no point',
      'pointless', 'meaningless', 'worthless', 'cant go on', 'ending', 'end it'
    ];

    final hopelessnessEntries = entries.where((entry) {
      return entry.keywords.any((kw) =>
          hopelessnessKeywords.any((hk) => kw.toLowerCase().contains(hk)));
    }).toList();

    if (hopelessnessEntries.isEmpty) return null;

    // High severity even with one occurrence
    final severity = (0.85 + (hopelessnessEntries.length * 0.05)).clamp(0.85, 1.0);
    final triggerKeywords = hopelessnessEntries
        .expand((e) => e.keywords)
        .where((kw) => hopelessnessKeywords.any((hk) => kw.toLowerCase().contains(hk)))
        .toSet()
        .toList();

    return RiskPattern(
      type: 'hopelessness',
      description: 'Critical: Indicators of hopelessness or despair detected',
      severity: severity,
      affectedDates: hopelessnessEntries.map((e) => e.timestamp).toList(),
      triggerKeywords: triggerKeywords,
    );
  }

  /// Calculate overall risk score using REVERSE RIVET gating
  ///
  /// RIVET gates keywords IN (adds them to selection)
  /// SENTINEL gates risk levels UP (raises alarm levels)
  ///
  /// Reverse RIVET Gates:
  /// - Gate 1: If score > threshold_HIGH → ESCALATE risk level
  /// - Gate 2: If evidence_types (patterns) > threshold → ESCALATE risk level
  /// - Gate 3: If amplitude_trend_increasing > threshold → ESCALATE risk level
  /// - Gate 4: If negative_keyword_density > threshold → ESCALATE risk level
  static double _calculateRiskScore(
    Map<String, dynamic> metrics,
    List<RiskPattern> patterns,
    SentinelConfig config,
  ) {
    double baseScore = 0.0;

    // Base score from metrics (inverse of RIVET's keyword quality scoring)
    final avgAmplitude = metrics['avg_amplitude'] as double;
    final highAmplitudeRate = metrics['high_amplitude_rate'] as double;
    final negativeRatio = metrics['negative_keyword_ratio'] as double;

    baseScore += avgAmplitude * 0.3;
    baseScore += highAmplitudeRate * 0.3;
    baseScore += negativeRatio * 0.2;

    // Add pattern severity
    if (patterns.isNotEmpty) {
      final maxPatternSeverity = patterns.map((p) => p.severity).reduce(max);
      baseScore += maxPatternSeverity * 0.2;
    }

    // Apply REVERSE RIVET GATING - each gate can INCREASE the score
    double gatedScore = baseScore;
    final gatingReasons = <String>[];

    // REVERSE GATE 1: High base score automatically escalates
    if (baseScore > 0.60) {
      gatedScore += 0.10;
      gatingReasons.add('REVERSE_GATE_1_HIGH_BASE_SCORE');
    }

    // REVERSE GATE 2: Multiple concerning patterns escalate
    if (patterns.length >= 3) {
      gatedScore += 0.15;
      gatingReasons.add('REVERSE_GATE_2_MULTIPLE_PATTERNS');
    }

    // REVERSE GATE 3: Critical patterns (hopelessness, isolation) escalate significantly
    final hasCriticalPattern = patterns.any((p) =>
        p.type == 'hopelessness' || p.type == 'isolation');
    if (hasCriticalPattern) {
      gatedScore += 0.20;
      gatingReasons.add('REVERSE_GATE_3_CRITICAL_PATTERN');
    }

    // REVERSE GATE 4: High negative keyword density escalates
    if (negativeRatio > 0.70) {
      gatedScore += 0.10;
      gatingReasons.add('REVERSE_GATE_4_HIGH_NEGATIVE_DENSITY');
    }

    // REVERSE GATE 5: Escalating trend pattern gets additional weight
    final hasEscalation = patterns.any((p) => p.type == 'escalating');
    if (hasEscalation) {
      gatedScore += 0.12;
      gatingReasons.add('REVERSE_GATE_5_ESCALATING_TREND');
    }

    // REVERSE GATE 6: Persistent pattern (chronic distress) escalates
    final hasPersistent = patterns.any((p) => p.type == 'persistent');
    if (hasPersistent) {
      gatedScore += 0.08;
      gatingReasons.add('REVERSE_GATE_6_PERSISTENT_DISTRESS');
    }

    // Store gating trace for transparency
    metrics['reverse_rivet_gates'] = gatingReasons;
    metrics['base_score'] = baseScore;
    metrics['gated_score'] = gatedScore.clamp(0.0, 1.0);

    return gatedScore.clamp(0.0, 1.0);
  }

  /// Determine risk level from score
  static RiskLevel _determineRiskLevel(double score) {
    if (score >= 0.85) return RiskLevel.severe;
    if (score >= 0.70) return RiskLevel.high;
    if (score >= 0.55) return RiskLevel.elevated;
    if (score >= 0.40) return RiskLevel.moderate;
    if (score >= 0.25) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  /// Generate recommendations based on risk level
  static List<String> _generateRecommendations(
    RiskLevel riskLevel,
    List<RiskPattern> patterns,
    Map<String, dynamic> metrics,
  ) {
    final recommendations = <String>[];

    switch (riskLevel) {
      case RiskLevel.severe:
      case RiskLevel.high:
        recommendations.add('🚨 Immediate action recommended: Consider reaching out to a mental health professional');
        recommendations.add('Contact a crisis helpline if you\'re in immediate distress');
        recommendations.add('Inform a trusted friend or family member about how you\'re feeling');
        break;
      case RiskLevel.elevated:
        recommendations.add('⚠️ Significant concern: Schedule an appointment with a therapist or counselor');
        recommendations.add('Practice daily self-care routines and prioritize rest');
        recommendations.add('Reach out to supportive people in your life');
        break;
      case RiskLevel.moderate:
        recommendations.add('⚡ Monitor closely: Consider speaking with a mental health professional');
        recommendations.add('Engage in stress-reduction activities (meditation, exercise, creative outlets)');
        recommendations.add('Maintain social connections and avoid isolation');
        break;
      case RiskLevel.low:
        recommendations.add('✓ Continue self-care practices');
        recommendations.add('Stay connected with supportive relationships');
        recommendations.add('Monitor your emotional patterns');
        break;
      case RiskLevel.minimal:
        recommendations.add('✓ Emotional health appears stable');
        recommendations.add('Continue healthy habits and routines');
        break;
    }

    // Pattern-specific recommendations
    for (final pattern in patterns) {
      switch (pattern.type) {
        case 'isolation':
          recommendations.add('📞 Consider reaching out to at least one person today');
          break;
        case 'hopelessness':
          recommendations.add('🆘 CRITICAL: Please contact a crisis helpline or emergency services');
          break;
        case 'persistent':
          recommendations.add('📅 Persistent distress detected - professional support strongly recommended');
          break;
        case 'escalating':
          recommendations.add('📈 Emotional intensity is increasing - take preventive action now');
          break;
      }
    }

    return recommendations.toSet().toList(); // Remove duplicates
  }

  /// Generate summary text
  static String _generateSummary(
    RiskLevel riskLevel,
    List<RiskPattern> patterns,
    Map<String, dynamic> metrics,
    int entryCount,
  ) {
    final buffer = StringBuffer();

    buffer.write('Risk Level: ${riskLevel.name.toUpperCase()} - ');
    buffer.write('Analyzed $entryCount entries. ');

    if (patterns.isEmpty) {
      buffer.write('No concerning patterns detected.');
    } else {
      buffer.write('Detected ${patterns.length} risk pattern(s): ');
      buffer.write(patterns.map((p) => p.type).join(', '));
      buffer.write('.');
    }

    return buffer.toString();
  }

  // Helper methods

  static DateTime _getCutoffDate(DateTime now, TimeWindow window) {
    switch (window) {
      case TimeWindow.day:
        return now.subtract(const Duration(days: 1));
      case TimeWindow.threeDay:
        return now.subtract(const Duration(days: 3));
      case TimeWindow.week:
        return now.subtract(const Duration(days: 7));
      case TimeWindow.twoWeek:
        return now.subtract(const Duration(days: 14));
      case TimeWindow.month:
        return now.subtract(const Duration(days: 30));
    }
  }

  static double _getClusterSeverity(
    List<JournalEntryData> cluster,
    SentinelConfig config,
  ) {
    final amplitudes = cluster
        .expand((e) => e.keywords)
        .map((kw) => EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0)
        .where((amp) => amp >= config.highAmplitudeThreshold)
        .toList();

    if (amplitudes.isEmpty) return 0.0;

    final avgAmplitude = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final clusterSize = cluster.length / config.clusterMinSize;

    return (avgAmplitude * 0.7 + clusterSize * 0.3).clamp(0.0, 1.0);
  }

  static int _countNegativeKeywords(List<JournalEntryData> entries) {
    int count = 0;
    for (final entry in entries) {
      for (final keyword in entry.keywords) {
        if (_isNegativeKeyword(keyword)) {
          count++;
        }
      }
    }
    return count;
  }

  static bool _isNegativeKeyword(String keyword) {
    const negativeCategories = [
      // Anxiety & Fear
      'anxious', 'stressed', 'overwhelmed', 'worried', 'fearful', 'scared', 'terrified',
      'panicked', 'nervous', 'tense', 'uneasy', 'restless', 'threatened', 'insecure',
      'helpless', 'powerless', 'trapped', 'suffocated',
      // Sadness & Depression
      'sad', 'depressed', 'heartbroken', 'devastated', 'grief', 'grieving', 'mourning',
      'lonely', 'empty', 'hollow', 'numb', 'hopeless', 'despair', 'defeated',
      'broken', 'shattered', 'crushed', 'miserable', 'isolated', 'alone', 'abandoned',
      'rejected', 'unwanted', 'unloved',
      // Anger & Frustration
      'angry', 'frustrated', 'irritated', 'annoyed', 'furious', 'enraged', 'bitter',
      'resentful', 'hostile', 'aggressive', 'disgusted', 'outraged',
      // Shame & Guilt
      'ashamed', 'guilty', 'embarrassed', 'humiliated', 'mortified', 'inadequate',
      'unworthy', 'worthless', 'failure',
    ];

    return negativeCategories.contains(keyword.toLowerCase());
  }

  /// Count negative keywords with source weighting
  static double _countNegativeKeywordsWithWeighting(List<ReflectiveEntryData> entries) {
    double count = 0.0;
    for (final entry in entries) {
      for (final keyword in entry.keywords) {
        if (_isNegativeKeyword(keyword)) {
          count += entry.effectiveConfidence;
        }
      }
    }
    return count;
  }

  /// Detect patterns with source weighting
  static List<RiskPattern> _detectPatternsWithWeighting(
    List<ReflectiveEntryData> entries,
    SentinelConfig config,
  ) {
    final patterns = <RiskPattern>[];

    // High amplitude clustering with weighting
    final clusters = _detectClustersWithWeighting(entries, config);
    patterns.addAll(clusters);

    // Persistent distress with weighting
    final persistent = _detectPersistentDistressWithWeighting(entries, config);
    if (persistent != null) patterns.add(persistent);

    // Escalating patterns with weighting
    final escalating = _detectEscalatingPatternsWithWeighting(entries, config);
    if (escalating != null) patterns.add(escalating);

    return patterns;
  }

  /// Detect clusters with source weighting
  static List<RiskPattern> _detectClustersWithWeighting(
    List<ReflectiveEntryData> entries,
    SentinelConfig config,
  ) {
    final patterns = <RiskPattern>[];
    final windowHours = config.clusterWindowHours;
    final minSize = config.clusterMinSize;

    for (int i = 0; i < entries.length; i++) {
      final cluster = <ReflectiveEntryData>[];
      final startTime = entries[i].timestamp;

      // Find entries within the time window
      for (int j = i; j < entries.length; j++) {
        final timeDiff = entries[j].timestamp.difference(startTime).inHours;
        if (timeDiff <= windowHours) {
          cluster.add(entries[j]);
        } else {
          break;
        }
      }

      // Check if cluster meets criteria with weighting
      if (cluster.length >= minSize) {
        final weightedSeverity = _getClusterSeverityWithWeighting(cluster, config);
        if (weightedSeverity > 0.5) {
          patterns.add(RiskPattern(
            type: 'cluster',
            description: 'High-amplitude emotional keywords clustered over ${windowHours}h',
            severity: weightedSeverity,
            affectedDates: cluster.map((e) => e.timestamp).toList(),
            triggerKeywords: cluster
                .expand((e) => e.keywords)
                .where((kw) => EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0 >= config.highAmplitudeThreshold)
                .toSet()
                .toList(),
          ));
        }
      }
    }

    return patterns;
  }

  /// Detect persistent distress with weighting
  static RiskPattern? _detectPersistentDistressWithWeighting(
    List<ReflectiveEntryData> entries,
    SentinelConfig config,
  ) {
    final minDays = config.persistentDistressMinDays;
    final negativeEntries = <ReflectiveEntryData>[];

    for (final entry in entries) {
      final hasNegativeKeywords = entry.keywords.any((kw) => _isNegativeKeyword(kw));
      if (hasNegativeKeywords) {
        negativeEntries.add(entry);
      }
    }

    if (negativeEntries.isEmpty) return null;

    // Group by day and check for persistent patterns
    final dayGroups = <DateTime, List<ReflectiveEntryData>>{};
    for (final entry in negativeEntries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      dayGroups[day] = (dayGroups[day] ?? [])..add(entry);
    }

    final consecutiveDays = <DateTime>[];
    final sortedDays = dayGroups.keys.toList()..sort();

    for (int i = 0; i < sortedDays.length; i++) {
      if (i == 0 || sortedDays[i].difference(sortedDays[i - 1]).inDays == 1) {
        consecutiveDays.add(sortedDays[i]);
      } else {
        if (consecutiveDays.length >= minDays) break;
        consecutiveDays.clear();
        consecutiveDays.add(sortedDays[i]);
      }
    }

    if (consecutiveDays.length >= minDays) {
      final affectedEntries = consecutiveDays
          .expand((day) => dayGroups[day] ?? [])
          .toList();

      final weightedSeverity = _getClusterSeverityWithWeighting(affectedEntries, config);
      
      return RiskPattern(
        type: 'persistent',
        description: 'Persistent negative emotional patterns over ${consecutiveDays.length} days',
        severity: weightedSeverity,
        affectedDates: consecutiveDays,
        triggerKeywords: affectedEntries
            .expand((e) => e.keywords)
            .where((kw) => _isNegativeKeyword(kw))
            .toSet()
            .toList(),
      );
    }

    return null;
  }

  /// Detect escalating patterns with weighting
  static RiskPattern? _detectEscalatingPatternsWithWeighting(
    List<ReflectiveEntryData> entries,
    SentinelConfig config,
  ) {
    if (entries.length < config.trendAnalysisMinEntries) return null;

    // Calculate weighted amplitude trend
    final amplitudes = <double>[];
    for (final entry in entries) {
      double maxAmplitude = 0.0;
      for (final keyword in entry.keywords) {
        final baseAmplitude = EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ?? 0.0;
        final weightedAmplitude = baseAmplitude * entry.effectiveConfidence;
        if (weightedAmplitude > maxAmplitude) {
          maxAmplitude = weightedAmplitude;
        }
      }
      amplitudes.add(maxAmplitude);
    }

    // Simple linear trend analysis
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < amplitudes.length; i++) {
      sumX += i.toDouble();
      sumY += amplitudes[i];
      sumXY += i * amplitudes[i];
      sumXX += i * i;
    }

    final n = amplitudes.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);

    if (slope > config.deteriorationThreshold) {
      return RiskPattern(
        type: 'escalating',
        description: 'Emotional intensity is escalating over time',
        severity: slope.clamp(0.0, 1.0),
        affectedDates: entries.map((e) => e.timestamp).toList(),
        triggerKeywords: entries
            .expand((e) => e.keywords)
            .where((kw) => EnhancedKeywordExtractor.emotionAmplitudeMap[kw.toLowerCase()] ?? 0.0 >= config.highAmplitudeThreshold)
            .toSet()
            .toList(),
      );
    }

    return null;
  }

  /// Get cluster severity with weighting
  static double _getClusterSeverityWithWeighting(
    List<ReflectiveEntryData> cluster,
    SentinelConfig config,
  ) {
    final amplitudes = <double>[];
    for (final entry in cluster) {
      for (final keyword in entry.keywords) {
        final baseAmplitude = EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ?? 0.0;
        final weightedAmplitude = baseAmplitude * entry.effectiveConfidence;
        if (weightedAmplitude >= config.highAmplitudeThreshold) {
          amplitudes.add(weightedAmplitude);
        }
      }
    }

    if (amplitudes.isEmpty) return 0.0;

    final avgAmplitude = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final clusterSize = cluster.length / config.clusterMinSize;

    return (avgAmplitude * 0.7 + clusterSize * 0.3).clamp(0.0, 1.0);
  }

  /// Calculate risk score with weighting
  static double _calculateRiskScoreWithWeighting(
    Map<String, dynamic> metrics,
    List<RiskPattern> patterns,
    SentinelConfig config,
  ) {
    double score = 0.0;

    // Base amplitude score
    final avgAmplitude = metrics['avg_amplitude'] as double;
    final highAmplitudeRate = metrics['high_amplitude_rate'] as double;
    score += avgAmplitude * 0.3;
    score += highAmplitudeRate * 0.2;

    // Pattern severity
    if (patterns.isNotEmpty) {
      final avgPatternSeverity = patterns.map((p) => p.severity).reduce((a, b) => a + b) / patterns.length;
      score += avgPatternSeverity * 0.3;
    }

    // Source confidence adjustment
    final avgConfidence = metrics['avg_confidence'] as double;
    final highConfidenceRatio = metrics['high_confidence_ratio'] as double;
    score += (1.0 - avgConfidence) * 0.1; // Lower confidence = higher risk
    score += (1.0 - highConfidenceRatio) * 0.1; // Fewer high-confidence entries = higher risk

    return score.clamp(0.0, 1.0);
  }

  /// Generate summary with source breakdown
  static String _generateSummaryWithSources(
    RiskLevel riskLevel,
    List<RiskPattern> patterns,
    Map<String, dynamic> metrics,
    List<ReflectiveEntryData> entries,
  ) {
    final buffer = StringBuffer();
    
    // Risk level summary
    buffer.writeln('Risk Level: ${riskLevel.name.toUpperCase()}');
    buffer.writeln('Risk Score: ${(metrics['risk_score'] as double).toStringAsFixed(2)}');
    buffer.writeln();

    // Source breakdown
    final sourceBreakdown = metrics['source_breakdown'] as Map<String, int>;
    buffer.writeln('Data Sources:');
    sourceBreakdown.forEach((source, count) {
      final percentage = (count / entries.length * 100).toStringAsFixed(1);
      buffer.writeln('  • $source: $count entries ($percentage%)');
    });
    buffer.writeln();

    // Pattern summary
    if (patterns.isNotEmpty) {
      buffer.writeln('Detected Patterns:');
      for (final pattern in patterns) {
        buffer.writeln('  • ${pattern.type}: ${pattern.description}');
      }
      buffer.writeln();
    }

    // Confidence summary
    final avgConfidence = metrics['avg_confidence'] as double;
    final highConfidenceRatio = metrics['high_confidence_ratio'] as double;
    buffer.writeln('Data Quality:');
    buffer.writeln('  • Average Confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('  • High Confidence Entries: ${(highConfidenceRatio * 100).toStringAsFixed(1)}%');

    return buffer.toString();
  }
}

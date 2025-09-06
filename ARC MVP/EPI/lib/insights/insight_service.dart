import 'package:hive/hive.dart';
import '../repositories/journal_repository.dart';
import '../models/journal_entry_model.dart';
import '../core/rivet/rivet_provider.dart';
import '../core/rivet/rivet_models.dart';
import 'models/insight_card.dart';
import 'templates.dart';
import 'rules_loader.dart';
import '../data/hive/insight_snapshot.dart';

/// Service for generating deterministic insight cards
class InsightService {
  final JournalRepository _journalRepository;
  final RivetProvider? _rivetProvider;
  final String _userId;

  InsightService({
    required JournalRepository journalRepository,
    RivetProvider? rivetProvider,
    required String userId,
  }) : _journalRepository = journalRepository,
       _rivetProvider = rivetProvider,
       _userId = userId;

  /// Generate insight cards for a given period
  Future<List<InsightCard>> generateInsights({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      print('DEBUG: InsightService.generateInsights called for period $periodStart to $periodEnd');
      
      // Load rules
      final rulePack = await loadInsightRules();
      print('DEBUG: Loaded ${rulePack.rules.length} rules');
      
      // Get journal entries for the period
      final allEntries = _journalRepository.getAllJournalEntries();
      print('DEBUG: Found ${allEntries.length} total journal entries');
      
      final entries = allEntries
          .where((entry) => 
              entry.createdAt.isAfter(periodStart) && 
              entry.createdAt.isBefore(periodEnd))
          .toList();

      print('DEBUG: Found ${entries.length} entries in period');

      if (entries.isEmpty) {
        print('DEBUG: No entries in period, returning empty list');
        return [];
      }

      // Compute signals
      final signals = await _computeSignals(entries, periodStart, periodEnd);
      
      // Get RIVET status
      final rivetState = await _getRivetState();
      
      // Generate cards using rules
      final cards = <InsightCard>[];
      
      for (final rule in rulePack.rules.where((r) => r.enabled)) {
        if (await _evaluateRule(rule, signals, rivetState)) {
          final card = await _createCardFromRule(rule, signals, periodStart, periodEnd);
          if (card != null) {
            cards.add(card);
          }
        }
      }

      // Store snapshot for future reference
      await _storeSnapshot(signals, periodStart, periodEnd);

      print('DEBUG: Generated ${cards.length} insight cards');
      return cards;
    } catch (e) {
      print('ERROR: Failed to generate insights: $e');
      return [];
    }
  }

  /// Compute all signals needed for rule evaluation
  Future<InsightSignals> _computeSignals(
    List<JournalEntry> entries,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    // Extract keywords and compute frequencies
    final keywordFrequencies = <String, int>{};
    final keywordToEntries = <String, List<JournalEntry>>{};
    
    for (final entry in entries) {
      for (final keyword in entry.keywords) {
        if (keyword.isNotEmpty) {
          keywordFrequencies[keyword] = (keywordFrequencies[keyword] ?? 0) + 1;
          keywordToEntries.putIfAbsent(keyword, () => []).add(entry);
        }
      }
    }

    // Get top words
    final sortedKeywords = keywordFrequencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWords = sortedKeywords.take(5).map((e) => e.key).toList();

    // Compute emotion scores (simplified - using emotion strings)
    final emotionScores = <String, double>{};
    final emotionCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.emotion != null && entry.emotion!.isNotEmpty) {
        emotionCounts[entry.emotion!] = (emotionCounts[entry.emotion!] ?? 0) + 1;
      }
    }
    
    // Convert counts to percentages
    final totalEmotions = emotionCounts.values.fold(0, (a, b) => a + b);
    if (totalEmotions > 0) {
      emotionCounts.forEach((emotion, count) {
        emotionScores[emotion] = count / totalEmotions;
      });
    }

    // Compute phase counts (using mood as a proxy for now)
    final phaseCounts = <String, int>{};
    for (final entry in entries) {
      // For now, use mood as a simple phase indicator
      // In a real implementation, you'd have phase detection logic
      final mood = entry.mood.toLowerCase();
      if (mood.contains('discovery') || mood.contains('explore')) {
        phaseCounts['Discovery'] = (phaseCounts['Discovery'] ?? 0) + 1;
      } else if (mood.contains('growth') || mood.contains('expand')) {
        phaseCounts['Expansion'] = (phaseCounts['Expansion'] ?? 0) + 1;
      } else if (mood.contains('change') || mood.contains('transition')) {
        phaseCounts['Transition'] = (phaseCounts['Transition'] ?? 0) + 1;
      } else if (mood.contains('consolidate') || mood.contains('stable')) {
        phaseCounts['Consolidation'] = (phaseCounts['Consolidation'] ?? 0) + 1;
      } else if (mood.contains('recover') || mood.contains('rest')) {
        phaseCounts['Recovery'] = (phaseCounts['Recovery'] ?? 0) + 1;
      } else if (mood.contains('breakthrough') || mood.contains('break')) {
        phaseCounts['Breakthrough'] = (phaseCounts['Breakthrough'] ?? 0) + 1;
      }
    }

    // Compute SAGE coverage
    final sageCoverage = <String, double>{};
    int totalSageTokens = 0;
    for (final entry in entries) {
      if (entry.sageAnnotation != null) {
        final sage = entry.sageAnnotation!;
        if (sage.situation.isNotEmpty) {
          sageCoverage['situation'] = (sageCoverage['situation'] ?? 0.0) + 1.0;
          totalSageTokens++;
        }
        if (sage.action.isNotEmpty) {
          sageCoverage['action'] = (sageCoverage['action'] ?? 0.0) + 1.0;
          totalSageTokens++;
        }
        if (sage.growth.isNotEmpty) {
          sageCoverage['growth'] = (sageCoverage['growth'] ?? 0.0) + 1.0;
          totalSageTokens++;
        }
        if (sage.essence.isNotEmpty) {
          sageCoverage['essence'] = (sageCoverage['essence'] ?? 0.0) + 1.0;
          totalSageTokens++;
        }
      }
    }
    
    // Normalize SAGE coverage
    if (totalSageTokens > 0) {
      sageCoverage.forEach((key, value) {
        sageCoverage[key] = value / totalSageTokens;
      });
    }

    // Compute emotion variance
    final emotionVariance = _computeEmotionVariance(entries);

    return InsightSignals(
      topWords: topWords,
      keywordFrequencies: keywordFrequencies,
      emotionScores: emotionScores,
      phaseCounts: phaseCounts,
      sageCoverage: sageCoverage,
      emotionVariance: emotionVariance,
      journalIds: entries.map((e) => e.id).toList(),
      keywordToEntries: keywordToEntries,
    );
  }

  /// Compute emotion variance across entries
  double _computeEmotionVariance(List<JournalEntry> entries) {
    if (entries.length < 2) return 0.0;
    
    // Simple variance calculation based on emotion string diversity
    final emotions = entries
        .where((e) => e.emotion != null && e.emotion!.isNotEmpty)
        .map((e) => e.emotion!)
        .toList();
    
    if (emotions.length < 2) return 0.0;
    
    // Count unique emotions
    final uniqueEmotions = emotions.toSet().length;
    final totalEmotions = emotions.length;
    
    // Return diversity ratio (0.0 = all same, 1.0 = all different)
    return uniqueEmotions / totalEmotions;
  }

  /// Get current RIVET state
  Future<RivetState?> _getRivetState() async {
    try {
      if (_rivetProvider == null) {
        return null;
      }
      if (!_rivetProvider!.isAvailable) {
        await _rivetProvider!.initialize(_userId);
      }
      return await _rivetProvider!.safeGetState(_userId);
    } catch (e) {
      print('ERROR: Failed to get RIVET state: $e');
      return null;
    }
  }

  /// Evaluate if a rule should fire
  Future<bool> _evaluateRule(
    RuleSpec rule,
    InsightSignals signals,
    RivetState? rivetState,
  ) async {
    try {
      final when = rule.when;
      
      // Check RIVET gating
      if (rule.gate == 'rivet' && rivetState != null) {
        // For now, use simple thresholds - you can make this more sophisticated
        final alignThreshold = 0.6;
        final traceThreshold = 0.6;
        if (rivetState.align < alignThreshold || rivetState.trace < traceThreshold) {
          return false;
        }
      }

      // Evaluate rule conditions
      switch (rule.id) {
        case 'R1_TOP_THEMES':
          return signals.topWords.length >= (when['topWordsMin'] as int? ?? 2);
        
        case 'R2_PHASE_LEAN':
          final minPct = when['phaseLeanMinPct'] as double? ?? 0.35;
          final totalPhases = signals.phaseCounts.values.fold(0, (a, b) => a + b);
          if (totalPhases == 0) return false;
          final maxPhaseCount = signals.phaseCounts.values.fold(0, (a, b) => a > b ? a : b);
          return (maxPhaseCount / totalPhases) >= minPct;
        
        case 'R3_EMOTION_TILT':
          final minDelta = when['emotionDominantDeltaMin'] as double? ?? 0.12;
          // Check if any emotion dominates significantly
          if (signals.emotionScores.isEmpty) return false;
          final maxEmotionScore = signals.emotionScores.values.reduce((a, b) => a > b ? a : b);
          return maxEmotionScore >= minDelta;
        
        case 'R4_SAGE_NUDGE':
          final maxPct = when['sageMaxPct'] as double? ?? 0.35;
          final sageValues = signals.sageCoverage.values.toList();
          if (sageValues.isEmpty) return false;
          final minSage = sageValues.reduce((a, b) => a < b ? a : b);
          final maxSage = sageValues.reduce((a, b) => a > b ? a : b);
          return minSage < 0.15 && maxSage > maxPct;
        
        case 'R8_STUCK_NUDGE':
          final stuckKeywords = when['hasAnyKeyword'] as List<dynamic>? ?? [];
          return signals.topWords.any((word) => 
              stuckKeywords.any((stuck) => word.toLowerCase().contains(stuck.toString().toLowerCase())));
        
        case 'R11_THEME_STABILITY':
          // For now, return true if we have consistent keywords
          return signals.topWords.length >= 3;
        
        default:
          return false;
      }
    } catch (e) {
      print('ERROR: Failed to evaluate rule ${rule.id}: $e');
      return false;
    }
  }

  /// Create an insight card from a rule
  Future<InsightCard?> _createCardFromRule(
    RuleSpec rule,
    InsightSignals signals,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    try {
      final template = kInsightTemplates[rule.templateKey];
      if (template == null) return null;

      final rivetState = await _getRivetState();
      final rivetPass = rivetState != null && 
          rivetState.align >= 0.6 && rivetState.trace >= 0.6;

      Map<String, String?> params = {};
      String title = template.title;
      String body = template.body;

      switch (rule.id) {
        case 'R1_TOP_THEMES':
          params = buildTopThemesParams(signals.topWords.take(3).toList());
          break;
        
        case 'R2_PHASE_LEAN':
          final dominantPhase = signals.phaseCounts.entries
              .fold<MapEntry<String, int>>(
                MapEntry('', 0),
                (a, b) => a.value > b.value ? a : b)
              .key;
          params = buildPhaseLeanParams(dominantPhase, rivetPass: rivetPass);
          break;
        
        case 'R3_EMOTION_TILT':
          // Find the dominant emotion
          String dominantEmotion = 'neutral';
          if (signals.emotionScores.isNotEmpty) {
            final maxEntry = signals.emotionScores.entries.reduce((a, b) => a.value > b.value ? a : b);
            dominantEmotion = maxEntry.key;
          }
          params = buildEmotionTiltParams(dominantEmotion);
          break;
        
        case 'R4_SAGE_NUDGE':
          final sageEntries = signals.sageCoverage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          if (sageEntries.length >= 2) {
            params = {
              'maxTag': sageEntries.first.key,
              'minTag': sageEntries.last.key,
            };
          }
          break;
        
        case 'R8_STUCK_NUDGE':
          final stuckWord = signals.topWords.firstWhere(
            (word) => ['stuck', 'drift', 'fog'].any((stuck) => 
                word.toLowerCase().contains(stuck)),
            orElse: () => 'uncertain');
          params = {'stuckWord': stuckWord};
          break;
        
        case 'R11_THEME_STABILITY':
          // No parameters needed
          break;
        
        default:
          return null;
      }

      body = formatTemplate(body, params);

      // Create badges
      final badges = <String>[];
      if (rule.windowDays != null) {
        badges.add('${rule.windowDays}d');
      }
      if (rivetPass) {
        badges.add('Verified');
      }

      // Create sources map
      final sources = <String, dynamic>{
        'journalIds': signals.journalIds,
        'keywordScores': signals.keywordFrequencies,
        'emotionScores': signals.emotionScores,
        'phaseCounts': signals.phaseCounts,
        'sageCoverage': signals.sageCoverage,
        'rivet': rivetState?.toJson(),
      };

      return InsightCard(
        id: _generateStableId(rule.id, periodStart),
        title: title,
        body: body,
        badges: badges,
        periodStart: periodStart,
        periodEnd: periodEnd,
        sources: sources,
        deeplink: 'patterns://${template.anchor}',
        ruleId: rule.id,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('ERROR: Failed to create card for rule ${rule.id}: $e');
      return null;
    }
  }

  /// Generate a stable ID for the card
  String _generateStableId(String ruleId, DateTime periodStart) {
    final periodKey = '${periodStart.year}-${periodStart.month}-${periodStart.day}';
    return '${ruleId}_$periodKey';
  }

  /// Store insight snapshot for future reference
  Future<void> _storeSnapshot(
    InsightSignals signals,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    try {
      final box = await Hive.openBox<InsightSnapshot>('insight_snapshots');
      final snapshot = InsightSnapshot(
        id: '${periodStart.millisecondsSinceEpoch}_${periodEnd.millisecondsSinceEpoch}',
        periodStart: periodStart,
        periodEnd: periodEnd,
        topWords: signals.topWords,
        wordFrequencies: signals.keywordFrequencies,
        emotionScores: signals.emotionScores,
        phaseCounts: signals.phaseCounts,
        sageCoverage: signals.sageCoverage,
        emotionVariance: signals.emotionVariance,
        journalIds: signals.journalIds,
        createdAt: DateTime.now(),
      );
      await box.put(snapshot.id, snapshot);
    } catch (e) {
      print('ERROR: Failed to store insight snapshot: $e');
    }
  }
}

/// Signals computed from journal entries
class InsightSignals {
  final List<String> topWords;
  final Map<String, int> keywordFrequencies;
  final Map<String, double> emotionScores;
  final Map<String, int> phaseCounts;
  final Map<String, double> sageCoverage;
  final double emotionVariance;
  final List<String> journalIds;
  final Map<String, List<JournalEntry>> keywordToEntries;

  InsightSignals({
    required this.topWords,
    required this.keywordFrequencies,
    required this.emotionScores,
    required this.phaseCounts,
    required this.sageCoverage,
    required this.emotionVariance,
    required this.journalIds,
    required this.keywordToEntries,
  });
}

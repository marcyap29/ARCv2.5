import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import '../arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../rivet/validation/rivet_provider.dart';
import '../rivet/models/rivet_models.dart';
import 'models/insight_card.dart';
import 'templates.dart';
import 'rules_loader.dart';
import '../data/hive/insight_snapshot.dart';

/// Service for generating deterministic insight cards
class InsightService {
  final JournalRepository _journalRepository;
  final RivetProvider? _rivetProvider;
  final String _userId;

  @protected
  JournalRepository get journalRepository => _journalRepository;

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
      final allEntries = _journalRepository.getAllJournalEntriesSync();
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

      // Ensure a minimum number of cards (fallbacks with relaxed checks)
      await _ensureMinimumCards(
        cards: cards,
        signals: signals,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      // Store snapshot for future reference
      await _storeSnapshot(signals, periodStart, periodEnd);

      print('DEBUG: Generated ${cards.length} insight cards');
      return cards;
    } catch (e) {
      print('ERROR: Failed to generate insights: $e');
      return [];
    }
  }

  /// Guarantee at least 3 insight cards by adding sensible fallbacks
  Future<void> _ensureMinimumCards({
    required List<InsightCard> cards,
    required InsightSignals signals,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    const int minCards = 3;
    if (cards.length >= minCards) return;

    final existingRuleIds = cards.map((c) => c.ruleId).toSet();

    Future<void> addRuleIfMissing(RuleSpec spec) async {
      if (existingRuleIds.contains(spec.id)) return;
      final card = await _createCardFromRule(spec, signals, periodStart, periodEnd);
      if (card != null) {
        cards.add(card);
        existingRuleIds.add(spec.id);
      }
    }

    // Prioritized fallbacks
    // 1) Top themes (usually available)
    await addRuleIfMissing(RuleSpec(
      id: 'R1_TOP_THEMES',
      enabled: true,
      priority: 10,
      windowDays: 7,
      when: const {},
      templateKey: 'TOP_THEMES',
      gate: 'none',
      deeplinkAnchor: 'top_words',
    ));

    if (cards.length >= minCards) return;

    // 2) Emotion tilt (usually available)
    await addRuleIfMissing(RuleSpec(
      id: 'R3_EMOTION_TILT',
      enabled: true,
      priority: 30,
      windowDays: 7,
      when: const {},
      templateKey: 'EMOTION_TILT',
      gate: 'none',
      deeplinkAnchor: 'emotions_sparkline',
    ));

    if (cards.length >= minCards) return;

    // 2) Phase lean
    await addRuleIfMissing(RuleSpec(
      id: 'R2_PHASE_LEAN',
      enabled: true,
      priority: 20,
      windowDays: 14,
      when: const {},
      templateKey: 'PHASE_LEAN',
      gate: 'none',
      deeplinkAnchor: 'phase_counts',
    ));

    if (cards.length >= minCards) return;

    // 3) SAGE nudge if any SAGE coverage exists
    await addRuleIfMissing(RuleSpec(
      id: 'R4_SAGE_NUDGE',
      enabled: true,
      priority: 40,
      windowDays: 7,
      when: const {},
      templateKey: 'SAGE_NUDGE',
      gate: 'none',
      deeplinkAnchor: 'sage_coverage',
    ));

    if (cards.length >= minCards) return;

    // 4) Stuck nudge
    await addRuleIfMissing(RuleSpec(
      id: 'R8_STUCK_NUDGE',
      enabled: true,
      priority: 80,
      windowDays: 7,
      when: const {},
      templateKey: 'STUCK_NUDGE',
      gate: 'none',
      deeplinkAnchor: 'stuck_keywords',
    ));

    if (cards.length >= minCards) return;

    // 5) Theme stability or new theme
    await addRuleIfMissing(RuleSpec(
      id: 'R11_THEME_STABILITY',
      enabled: true,
      priority: 110,
      windowDays: 7,
      when: const {},
      templateKey: 'THEME_STABILITY',
      gate: 'none',
      deeplinkAnchor: 'top_words',
    ));
  }

  /// Compute all signals needed for rule evaluation
  Future<InsightSignals> _computeSignals(
    List<JournalEntry> entries,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    print('DEBUG: _computeSignals processing ${entries.length} entries');

    // Extract keywords and compute frequencies
    final keywordFrequencies = <String, int>{};
    final keywordToEntries = <String, List<JournalEntry>>{};

    for (final entry in entries) {
      print('DEBUG: Entry ${entry.id} has ${entry.keywords.length} keywords: ${entry.keywords}');
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

    print('DEBUG: Top words: $topWords');
    print('DEBUG: Keyword frequencies: $keywordFrequencies');

    // Compute emotion scores (use mood as fallback if emotion is missing)
    final emotionScores = <String, double>{};
    final emotionCounts = <String, int>{};

    for (final entry in entries) {
      String? emotionValue = entry.emotion;

      // If no explicit emotion, derive from mood
      if (emotionValue == null || emotionValue.isEmpty) {
        final mood = entry.mood.toLowerCase();
        if (mood.contains('happy') || mood.contains('joy') || mood.contains('content')) {
          emotionValue = 'positive';
        } else if (mood.contains('sad') || mood.contains('down') || mood.contains('difficult')) {
          emotionValue = 'negative';
        } else if (mood.contains('calm') || mood.contains('peaceful') || mood.contains('steady')) {
          emotionValue = 'neutral';
        } else {
          emotionValue = 'mixed'; // Default for any mood
        }
      }

      emotionCounts[emotionValue] = (emotionCounts[emotionValue] ?? 0) + 1;
    }

    // Convert counts to percentages
    final totalEmotions = emotionCounts.values.fold(0, (a, b) => a + b);
    if (totalEmotions > 0) {
      emotionCounts.forEach((emotion, count) {
        emotionScores[emotion] = count / totalEmotions;
      });
    }

    print('DEBUG: Emotion counts: $emotionCounts');
    print('DEBUG: Emotion scores: $emotionScores');

    // Compute phase counts (improved logic using mood, keywords, and content analysis)
    final phaseCounts = <String, int>{};
    for (final entry in entries) {
      final mood = entry.mood.toLowerCase();
      final keywords = entry.keywords.map((k) => k.toLowerCase()).join(' ');
      final content = entry.content.toLowerCase();
      final allText = '$mood $keywords $content';

      // Use a scoring system for better phase detection
      final phaseScores = <String, int>{
        'Discovery': 0,
        'Expansion': 0,
        'Transition': 0,
        'Consolidation': 0,
        'Recovery': 0,
        'Breakthrough': 0,
      };

      // Discovery indicators
      if (allText.contains(RegExp(r'\b(discover|explore|learn|new|question|wonder|curious|unknown)\b'))) {
        phaseScores['Discovery'] = phaseScores['Discovery']! + 2;
      }

      // Expansion indicators
      if (allText.contains(RegExp(r'\b(grow|expand|build|create|progress|develop|move|forward)\b'))) {
        phaseScores['Expansion'] = phaseScores['Expansion']! + 2;
      }

      // Transition indicators
      if (allText.contains(RegExp(r'\b(change|shift|transition|between|different|transform|evolve)\b'))) {
        phaseScores['Transition'] = phaseScores['Transition']! + 2;
      }

      // Consolidation indicators
      if (allText.contains(RegExp(r'\b(stable|consolidate|organize|focus|refine|settle|established)\b'))) {
        phaseScores['Consolidation'] = phaseScores['Consolidation']! + 2;
      }

      // Recovery indicators
      if (allText.contains(RegExp(r'\b(recover|rest|heal|pause|tired|overwhelm|reset|gentle)\b'))) {
        phaseScores['Recovery'] = phaseScores['Recovery']! + 2;
      }

      // Breakthrough indicators
      if (allText.contains(RegExp(r'\b(breakthrough|break|clarity|suddenly|realize|understand|insight)\b'))) {
        phaseScores['Breakthrough'] = phaseScores['Breakthrough']! + 2;
      }

      // Find the highest scoring phase, default to Expansion if tied/no matches
      final maxScore = phaseScores.values.reduce((a, b) => a > b ? a : b);
      final dominantPhase = maxScore > 0
          ? phaseScores.entries.where((e) => e.value == maxScore).first.key
          : 'Expansion'; // Default phase

      phaseCounts[dominantPhase] = (phaseCounts[dominantPhase] ?? 0) + 1;
    }

    print('DEBUG: Phase counts: $phaseCounts');

    // Compute SAGE coverage
    final sageCoverage = <String, double>{};
    final sageCounts = <String, int>{
      'situation': 0,
      'action': 0,
      'growth': 0,
      'essence': 0,
    };

    for (final entry in entries) {
      if (entry.sageAnnotation != null) {
        final sage = entry.sageAnnotation!;
        if (sage.situation.isNotEmpty) sageCounts['situation'] = sageCounts['situation']! + 1;
        if (sage.action.isNotEmpty) sageCounts['action'] = sageCounts['action']! + 1;
        if (sage.growth.isNotEmpty) sageCounts['growth'] = sageCounts['growth']! + 1;
        if (sage.essence.isNotEmpty) sageCounts['essence'] = sageCounts['essence']! + 1;
      }
    }

    // Convert to percentages of total entries (not just SAGE entries)
    if (entries.isNotEmpty) {
      sageCounts.forEach((key, count) {
        sageCoverage[key] = count / entries.length;
      });
    }

    print('DEBUG: SAGE counts: $sageCounts');
    print('DEBUG: SAGE coverage: $sageCoverage');

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
        const alignThreshold = 0.6;
        const traceThreshold = 0.6;
        if (rivetState.align < alignThreshold || rivetState.trace < traceThreshold) {
          return false;
        }
      }

      // Evaluate rule conditions
      switch (rule.id) {
        case 'R1_TOP_THEMES':
          return signals.topWords.length >= (when['topWordsMin'] as int? ?? 1);
        
        case 'R2_PHASE_LEAN':
          final minPct = when['phaseLeanMinPct'] as double? ?? 0.3;
          final totalPhases = signals.phaseCounts.values.fold(0, (a, b) => a + b);
          if (totalPhases == 0) return false;
          final maxPhaseCount = signals.phaseCounts.values.fold(0, (a, b) => a > b ? a : b);
          return (maxPhaseCount / totalPhases) >= minPct;
        
        case 'R3_EMOTION_TILT':
          final minDelta = when['emotionDominantDeltaMin'] as double? ?? 0.1;
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

      switch (rule.templateKey) {
        case 'TOP_THEMES':
          final topWords = signals.topWords.take(3).toList();
          if (topWords.isEmpty) {
            // Fallback: use most frequent keywords from all entries
            final fallbackWords = signals.keywordFrequencies.entries
                .take(3)
                .map((e) => e.key)
                .toList();
            params = buildTopThemesParams(fallbackWords.isNotEmpty ? fallbackWords : ['reflection', 'thoughts', 'today']);
          } else {
            params = buildTopThemesParams(topWords);
          }
          break;

        case 'PHASE_LEAN':
          String dominantPhase = 'Expansion'; // Default phase
          if (signals.phaseCounts.isNotEmpty) {
            final maxEntry = signals.phaseCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b);
            dominantPhase = maxEntry.key;
          }
          params = buildPhaseLeanParams(dominantPhase, rivetPass: rivetPass);
          break;

        case 'EMOTION_TILT':
          String dominantEmotion = 'neutral';
          if (signals.emotionScores.isNotEmpty) {
            final maxEntry = signals.emotionScores.entries
                .reduce((a, b) => a.value > b.value ? a : b);
            dominantEmotion = maxEntry.key;
          }
          params = buildEmotionTiltParams(dominantEmotion);
          break;

        case 'SAGE_NUDGE':
          final sageEntries = signals.sageCoverage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          String maxTag = 'situation';
          String minTag = 'essence';

          if (sageEntries.isNotEmpty) {
            maxTag = sageEntries.first.key;
            if (sageEntries.length >= 2) {
              minTag = sageEntries.last.key;
            } else {
              // Find the least used SAGE category
              final allSage = ['situation', 'action', 'growth', 'essence'];
              minTag = allSage.firstWhere(
                (tag) => !sageEntries.any((e) => e.key == tag),
                orElse: () => 'essence',
              );
            }
          }

          params = {
            'maxTag': maxTag,
            'minTag': minTag,
          };
          break;

        case 'STUCK_NUDGE':
          final stuckWord = signals.topWords.firstWhere(
            (word) => ['stuck', 'drift', 'fog'].any((stuck) =>
                word.toLowerCase().contains(stuck)),
            orElse: () => 'uncertain');
          params = {'stuckWord': stuckWord};
          break;

        case 'THEME_STABILITY':
          // No parameters needed for this template
          break;

        default:
          return null;
      }

      print('DEBUG: Rule ${rule.id} params: $params');

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

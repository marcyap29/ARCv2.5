// lib/services/notification_content_generator.dart
// Generates content for temporal notifications using ARC's existing systems

import 'dart:math' as math;
import '../models/journal_entry_model.dart';
import '../models/temporal_notifications/resonance_prompt.dart';
import '../models/temporal_notifications/thread_review.dart';
import '../models/temporal_notifications/arc_view.dart';
import '../models/temporal_notifications/becoming_summary.dart';
import '../arc/internal/mira/journal_repository.dart';
import '../services/phase_regime_service.dart';
import '../services/analytics_service.dart';
import '../services/rivet_sweep_service.dart';
import '../arc/internal/prism/theme_analysis_service.dart';
import '../models/phase_models.dart';

/// Generates notification content by querying journal data and using ARC systems
class NotificationContentGenerator {
  final JournalRepository _journalRepo;
  final ThemeAnalysisService _themeService;

  NotificationContentGenerator({
    JournalRepository? journalRepo,
    ThemeAnalysisService? themeService,
  })  : _journalRepo = journalRepo ?? JournalRepository(),
        _themeService = themeService ?? ThemeAnalysisService();

  /// Daily: Find resonant themes from recent entries
  Future<ResonancePrompt> generateResonancePrompt(String userId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // Get entries from last 7 days
    final allEntries = await _journalRepo.getAllJournalEntries();
    final recentEntries = allEntries
        .where((e) => e.createdAt.isAfter(sevenDaysAgo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // If no recent entries, return open exploration prompt
    if (recentEntries.isEmpty) {
      return ResonancePrompt(
        type: ResonancePromptType.openExploration,
        promptText: "What's on your mind today?",
        relatedThemes: [],
        relevanceScore: 0.0,
      );
    }

    // Analyze themes from recent entries
    final themeFrequencies = _themeService.computeThemeFrequencies(recentEntries);
    
    // Get current phase
    final phaseInfo = await _getCurrentPhaseInfo();
    final currentPhase = phaseInfo['phase'] as String;
    final daysInPhase = phaseInfo['daysInPhase'] as int? ?? 0;

    // Check for temporal callbacks (30, 90, 365 days ago)
    final callbackEntry = await _findTemporalCallback(allEntries, now);
    
    if (callbackEntry != null) {
      final daysAgo = now.difference(callbackEntry.createdAt).inDays;
      return ResonancePrompt(
        type: ResonancePromptType.temporalCallback,
        promptText: "$daysAgo days ago you wrote about ${_extractMainTheme(callbackEntry)}. How's that sitting now?",
        sourceEntryId: callbackEntry.id,
        callbackDate: callbackEntry.createdAt,
        relatedThemes: callbackEntry.keywords,
        relevanceScore: 0.8,
      );
    }

    // Check for theme recurrence (mentioned 3+ times this week)
    final topThemes = themeFrequencies.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    
    if (topThemes.isNotEmpty && topThemes.first.value.count >= 3) {
      final theme = topThemes.first.key;
      return ResonancePrompt(
        type: ResonancePromptType.themeRecurrence,
        promptText: "You've touched on '$theme' ${topThemes.first.value.count} times this week. Worth exploring what's pulling at you?",
        sourceEntryId: recentEntries.first.id,
        relatedThemes: [theme],
        relevanceScore: math.min(1.0, topThemes.first.value.count / 5.0),
      );
    }

    // Check for patterns (energy shifts, emotional patterns)
    final pattern = _detectPattern(recentEntries);
    if (pattern != null) {
      return ResonancePrompt(
        type: ResonancePromptType.patternSurface,
        promptText: pattern['text'] as String,
        relatedThemes: pattern['themes'] as List<String>,
        relevanceScore: pattern['score'] as double,
      );
    }

    // Phase-relevant prompt
    if (daysInPhase > 30) {
      return ResonancePrompt(
        type: ResonancePromptType.phaseRelevant,
        promptText: "You've been in $currentPhase for $daysInPhase days. What's feeling most stable right now?",
        relatedThemes: [],
        relevanceScore: 0.6,
      );
    }

    // Default: open exploration
    return ResonancePrompt(
      type: ResonancePromptType.openExploration,
      promptText: "What's on your mind today?",
      relatedThemes: [],
      relevanceScore: 0.3,
    );
  }

  /// Monthly: Synthesize the month's threads
  Future<ThreadReview> generateThreadReview(String userId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final allEntries = await _journalRepo.getAllJournalEntries();
    final monthEntries = allEntries
        .where((e) => e.createdAt.isAfter(monthStart) && e.createdAt.isBefore(monthEnd))
        .toList();

    // Get phase status
    final phaseInfo = await _getCurrentPhaseInfo();
    final currentPhase = phaseInfo['phase'] as String;
    final daysInPhase = phaseInfo['daysInPhase'] as int? ?? 0;

    // Extract dominant emotional threads
    final themeFrequencies = _themeService.computeThemeFrequencies(monthEntries);
    final dominantThreads = themeFrequencies.entries
        .take(5)
        .map((e) => EmotionalThread(
              theme: e.key,
              intensityTrend: _calculateIntensityTrend(monthEntries, e.key),
              frequency: e.value.count,
              entryIds: monthEntries
                  .where((entry) => entry.keywords.contains(e.key))
                  .map((entry) => entry.id)
                  .toList(),
            ))
        .toList();

    // Detect patterns
    final patterns = _detectPatterns(monthEntries);

    // Find surprising contradictions
    final contradiction = _findContradiction(monthEntries);

    return ThreadReview(
      periodStart: monthStart,
      periodEnd: monthEnd,
      dominantThreads: dominantThreads,
      phaseStatus: PhaseStatus(
        currentPhase: currentPhase,
        daysInPhase: daysInPhase,
        microShifts: [], // TODO: Implement micro-shift detection
      ),
      patterns: patterns,
      surprisingContradiction: contradiction,
      entryCount: monthEntries.length,
    );
  }

  /// 6-Month: Build developmental trajectory
  Future<ArcView> generateArcView(String userId) async {
    final now = DateTime.now();
    final sixMonthsAgo = now.subtract(const Duration(days: 180));

    final allEntries = await _journalRepo.getAllJournalEntries();
    final periodEntries = allEntries
        .where((e) => e.createdAt.isAfter(sixMonthsAgo))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Get phase transitions from PhaseRegimeService
    final analyticsService = AnalyticsService();
    final rivetSweepService = RivetSweepService(analyticsService);
    final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
    await phaseRegimeService.initialize();

    final phaseIndex = phaseRegimeService.phaseIndex;
    final regimes = phaseIndex.regimesInRange(sixMonthsAgo, now);
    
    // Build phase journey
    final phaseJourney = <PhaseTransition>[];
    for (int i = 0; i < regimes.length - 1; i++) {
      final from = regimes[i];
      final to = regimes[i + 1];
      phaseJourney.add(PhaseTransition(
        fromPhase: _phaseLabelToString(from.label),
        toPhase: _phaseLabelToString(to.label),
        transitionDate: to.start,
        catalyst: _findCatalyst(periodEntries, to.start),
      ));
    }

    // Identify persistent themes
    final themeFrequencies = _themeService.computeThemeFrequencies(periodEntries);
    final persistentThemes = themeFrequencies.entries
        .where((e) => e.value.count >= 5)
        .map((e) => e.key)
        .toList();

    // Select key transformation moments
    final keyMoments = _identifyTransformationMoments(periodEntries);

    // Generate Arcform visualization data
    final phaseDistribution = <String, double>{};
    for (final regime in regimes) {
      final phaseName = _phaseLabelToString(regime.label);
      final duration = (regime.end ?? now).difference(regime.start).inDays;
      phaseDistribution[phaseName] = (phaseDistribution[phaseName] ?? 0.0) + duration;
    }
    final totalDays = phaseDistribution.values.fold(0.0, (a, b) => a + b);
    phaseDistribution.updateAll((key, value) => value / totalDays * 100);

    return ArcView(
      periodStart: sixMonthsAgo,
      periodEnd: now,
      phaseJourney: phaseJourney,
      persistentThemes: persistentThemes,
      keyMoments: keyMoments,
      arcformVisualization: ArcformData(
        phaseDistribution: phaseDistribution,
        timelinePoints: regimes.map((r) => {
          'date': r.start.toIso8601String(),
          'phase': _phaseLabelToString(r.label),
        }).toList(),
      ),
    );
  }

  /// Yearly: Create becoming narrative
  Future<BecomingSummary> generateBecomingSummary(String userId) async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    final allEntries = await _journalRepo.getAllJournalEntries();
    final yearEntries = allEntries
        .where((e) => e.createdAt.isAfter(yearStart) && e.createdAt.isBefore(yearEnd))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Get phase transitions
    final analyticsService = AnalyticsService();
    final rivetSweepService = RivetSweepService(analyticsService);
    final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
    await phaseRegimeService.initialize();

    final phaseIndex = phaseRegimeService.phaseIndex;
    final regimes = phaseIndex.regimesInRange(yearStart, yearEnd);
    
    final yearPhases = <PhaseTransition>[];
    for (int i = 0; i < regimes.length - 1; i++) {
      final from = regimes[i];
      final to = regimes[i + 1];
      yearPhases.add(PhaseTransition(
        fromPhase: _phaseLabelToString(from.label),
        toPhase: _phaseLabelToString(to.label),
        transitionDate: to.start,
      ));
    }

    // Categorize themes
    final themeFrequencies = _themeService.computeThemeFrequencies(yearEntries);
    final allThemes = themeFrequencies.keys.toList();
    
    // Themes resolved: appeared early but not recently
    final earlyThemes = _getThemesFromPeriod(yearEntries, yearStart, DateTime(now.year, 3, 31));
    final recentThemes = _getThemesFromPeriod(yearEntries, DateTime(now.year, 10, 1), yearEnd);
    final themesResolved = earlyThemes.where((t) => !recentThemes.contains(t)).toList();
    
    // Themes emergent: appeared recently but not early
    final themesEmergent = recentThemes.where((t) => !earlyThemes.contains(t)).toList();
    
    // Themes recurring: appeared throughout
    final themesRecurring = allThemes.where((t) {
      final entries = yearEntries.where((e) => e.keywords.contains(t)).toList();
      if (entries.length < 3) return false;
      final first = entries.first.createdAt;
      final last = entries.last.createdAt;
      return last.difference(first).inDays > 90; // Spans at least 3 months
    }).toList();

    // Generate emotional arc data
    final emotionalArcData = <String, double>{};
    for (int month = 1; month <= 12; month++) {
      final monthEntries = yearEntries.where((e) => e.createdAt.month == month).toList();
      if (monthEntries.isNotEmpty) {
        final avgIntensity = monthEntries.map((e) => _estimateEmotionalIntensity(e)).reduce((a, b) => a + b) / monthEntries.length;
        emotionalArcData[month.toString()] = avgIntensity;
      }
    }

    // Select milestone entries
    final significantEntries = _selectMilestoneEntries(yearEntries);

    // Generate narrative summary (simplified - in production, use LUMARA API)
    final narrativeSummary = _generateNarrativeSummary(yearPhases, themesResolved, themesEmergent, now.year);

    return BecomingSummary(
      year: now.year,
      narrativeSummary: narrativeSummary,
      yearPhases: yearPhases,
      themesResolved: themesResolved,
      themesEmergent: themesEmergent,
      themesRecurring: themesRecurring,
      emotionalArcData: emotionalArcData,
      significantEntries: significantEntries,
    );
  }

  // Helper methods

  Future<Map<String, dynamic>> _getCurrentPhaseInfo() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        final phase = _phaseLabelToString(currentRegime.label);
        final daysInPhase = DateTime.now().difference(currentRegime.start).inDays;
        return {'phase': phase, 'daysInPhase': daysInPhase};
      }
    } catch (e) {
      print('Error getting phase info: $e');
    }
    return {'phase': 'Discovery', 'daysInPhase': 0};
  }

  Future<JournalEntry?> _findTemporalCallback(List<JournalEntry> entries, DateTime now) async {
    final callbackDays = [30, 90, 365];
    for (final days in callbackDays) {
      final targetDate = now.subtract(Duration(days: days));
      final windowStart = targetDate.subtract(const Duration(days: 3));
      final windowEnd = targetDate.add(const Duration(days: 3));
      
      final candidates = entries.where((e) =>
          e.createdAt.isAfter(windowStart) && e.createdAt.isBefore(windowEnd)).toList();
      
      if (candidates.isNotEmpty) {
        // Return entry with most keywords (most substantial)
        candidates.sort((a, b) => b.keywords.length.compareTo(a.keywords.length));
        return candidates.first;
      }
    }
    return null;
  }

  String _extractMainTheme(JournalEntry entry) {
    if (entry.keywords.isNotEmpty) {
      return entry.keywords.first;
    }
    // Fallback: extract from content (first few words)
    final words = entry.content.split(' ').take(5).join(' ');
    return words.length > 30 ? '${words.substring(0, 30)}...' : words;
  }

  Map<String, dynamic>? _detectPattern(List<JournalEntry> entries) {
    // Simple pattern detection: look for energy shifts
    if (entries.length < 3) return null;
    
    // Check for positive/negative keyword shifts
    final positiveKeywords = ['happy', 'excited', 'grateful', 'confident', 'proud'];
    
    final earlyPositive = entries.take(entries.length ~/ 2).where((e) =>
        e.keywords.any((k) => positiveKeywords.contains(k.toLowerCase()))).length;
    final latePositive = entries.skip(entries.length ~/ 2).where((e) =>
        e.keywords.any((k) => positiveKeywords.contains(k.toLowerCase()))).length;
    
    if (latePositive > earlyPositive * 1.5) {
      return {
        'text': "Noticing your energy peaks when you write about positive themes. Something there?",
        'themes': positiveKeywords,
        'score': 0.7,
      };
    }
    
    return null;
  }

  double _calculateIntensityTrend(List<JournalEntry> entries, String theme) {
    final themeEntries = entries.where((e) => e.keywords.contains(theme)).toList();
    if (themeEntries.length < 2) return 0.0;
    
    themeEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final early = themeEntries.take(themeEntries.length ~/ 2);
    final late = themeEntries.skip(themeEntries.length ~/ 2);
    
    final earlyAvg = early.map((e) => _estimateEmotionalIntensity(e)).reduce((a, b) => a + b) / early.length;
    final lateAvg = late.map((e) => _estimateEmotionalIntensity(e)).reduce((a, b) => a + b) / late.length;
    
    return (lateAvg - earlyAvg).clamp(-1.0, 1.0);
  }

  List<PatternInsight> _detectPatterns(List<JournalEntry> entries) {
    // Simplified pattern detection
    final patterns = <PatternInsight>[];
    
    // Check for language shifts
    final earlyEntries = entries.take(entries.length ~/ 2).toList();
    final lateEntries = entries.skip(entries.length ~/ 2).toList();
    
    final earlyLanguage = _extractLanguagePattern(earlyEntries);
    final lateLanguage = _extractLanguagePattern(lateEntries);
    
    if (earlyLanguage != lateLanguage) {
      patterns.add(PatternInsight(
        description: "Your entries have shifted from '$earlyLanguage' language to '$lateLanguage' language.",
        supportingEntryIds: entries.map((e) => e.id).toList(),
      ));
    }
    
    return patterns;
  }

  String _extractLanguagePattern(List<JournalEntry> entries) {
    // Simple heuristic: check for common words
    final allText = entries.map((e) => e.content.toLowerCase()).join(' ');
    if (allText.contains('surviving') || allText.contains('struggling')) return 'surviving';
    if (allText.contains('building') || allText.contains('creating')) return 'building';
    if (allText.contains('exploring') || allText.contains('discovering')) return 'exploring';
    return 'reflecting';
  }

  String? _findContradiction(List<JournalEntry> entries) {
    // Simplified: look for entries with opposite emotional tones
    if (entries.length < 2) return null;
    
    final positiveEntries = entries.where((e) => _estimateEmotionalIntensity(e) > 0.5).toList();
    final negativeEntries = entries.where((e) => _estimateEmotionalIntensity(e) < -0.5).toList();
    
    if (positiveEntries.isNotEmpty && negativeEntries.isNotEmpty) {
      return "Your entries show both high and low emotional intensity this month, suggesting complex processing.";
    }
    
    return null;
  }

  String? _findCatalyst(List<JournalEntry> entries, DateTime transitionDate) {
    // Find entry closest to transition date
    final candidates = entries.where((e) =>
        (e.createdAt.difference(transitionDate).inDays).abs() <= 7).toList();
    
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) =>
          a.createdAt.difference(transitionDate).abs().compareTo(
          b.createdAt.difference(transitionDate).abs()));
      return _extractMainTheme(candidates.first);
    }
    
    return null;
  }

  List<TransformationMoment> _identifyTransformationMoments(List<JournalEntry> entries) {
    // Find entries with high emotional intensity or significant length
    final moments = <TransformationMoment>[];
    
    for (final entry in entries) {
      final intensity = _estimateEmotionalIntensity(entry);
      final length = entry.content.length;
      
      if (intensity.abs() > 0.7 || length > 500) {
        moments.add(TransformationMoment(
          date: entry.createdAt,
          description: _extractMainTheme(entry),
          significanceScore: (intensity.abs() * 0.5 + (length > 500 ? 0.5 : 0.0)).clamp(0.0, 1.0),
          entryId: entry.id,
        ));
      }
    }
    
    // Sort by significance and take top 5
    moments.sort((a, b) => b.significanceScore.compareTo(a.significanceScore));
    return moments.take(5).toList();
  }

  List<String> _getThemesFromPeriod(List<JournalEntry> entries, DateTime start, DateTime end) {
    final periodEntries = entries.where((e) =>
        e.createdAt.isAfter(start) && e.createdAt.isBefore(end)).toList();
    final themeFrequencies = _themeService.computeThemeFrequencies(periodEntries);
    return themeFrequencies.keys.toList();
  }

  List<MilestoneEntry> _selectMilestoneEntries(List<JournalEntry> entries) {
    // Select entries with highest significance
    final moments = _identifyTransformationMoments(entries);
    return moments.map((m) {
      final entry = entries.firstWhere((e) => e.id == m.entryId);
      final quote = entry.content.split(' ').take(15).join(' ');
      return MilestoneEntry(
        entryId: entry.id,
        date: entry.createdAt,
        quote: quote,
        significance: m.description,
      );
    }).toList();
  }

  String _generateNarrativeSummary(List<PhaseTransition> phases, List<String> resolved, List<String> emergent, int year) {
    // Simplified narrative - in production, use LUMARA API
    final buffer = StringBuffer();
    buffer.write("$year: A Year of Becoming\n\n");
    
    if (phases.isNotEmpty) {
      buffer.write("You began the year in ${phases.first.fromPhase}.");
      if (phases.length > 1) {
        buffer.write(" By ${phases.last.transitionDate.month}/${phases.last.transitionDate.day}, you'd entered ${phases.last.toPhase}.");
      }
    }
    
    if (resolved.isNotEmpty) {
      buffer.write("\n\nThemes resolved: ${resolved.take(3).join(', ')}");
    }
    
    if (emergent.isNotEmpty) {
      buffer.write("\n\nThemes emerging: ${emergent.take(3).join(', ')}");
    }
    
    return buffer.toString();
  }

  double _estimateEmotionalIntensity(JournalEntry entry) {
    // Simple heuristic based on keywords and content length
    final positiveKeywords = ['happy', 'excited', 'grateful', 'confident', 'proud', 'joy'];
    final negativeKeywords = ['anxious', 'stressed', 'tired', 'frustrated', 'worried', 'sad'];
    
    final hasPositive = entry.keywords.any((k) => positiveKeywords.contains(k.toLowerCase()));
    final hasNegative = entry.keywords.any((k) => negativeKeywords.contains(k.toLowerCase()));
    
    if (hasPositive && !hasNegative) return 0.5;
    if (hasNegative && !hasPositive) return -0.5;
    if (hasPositive && hasNegative) return 0.0; // Mixed
    
    // Fallback: use content length as proxy (longer = more intense processing)
    return (entry.content.length / 1000).clamp(-1.0, 1.0) * 0.3;
  }

  String _phaseLabelToString(PhaseLabel label) {
    final str = label.toString().split('.').last;
    return str[0].toUpperCase() + str.substring(1);
  }
}


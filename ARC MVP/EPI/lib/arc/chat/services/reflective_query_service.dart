// lib/arc/chat/services/reflective_query_service.dart
// Core service implementing three EPI-standard reflective queries

import 'dart:math' as math;
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/prism/extractors/sentinel_risk_detector.dart';
import 'package:my_app/arc/chat/models/reflective_query_models.dart';
import 'package:my_app/core/models/reflective_entry_data.dart';

/// Core service for reflective queries
class ReflectiveQueryService {
  final JournalRepository _journalRepository;
  EnhancedMiraMemoryService? _memoryService;
  PhaseHistoryRepository? _phaseHistory;
  
  ReflectiveQueryService({
    required JournalRepository journalRepository,
    EnhancedMiraMemoryService? memoryService,
    PhaseHistoryRepository? phaseHistory,
  }) : _journalRepository = journalRepository,
       _memoryService = memoryService,
       _phaseHistory = phaseHistory;

  /// Update dependencies after initialization
  void updateDependencies({
    EnhancedMiraMemoryService? memoryService,
    PhaseHistoryRepository? phaseHistory,
  }) {
    if (memoryService != null) _memoryService = memoryService;
    if (phaseHistory != null) _phaseHistory = phaseHistory;
  }

  /// Query 1: "Show me three times I handled something hard"
  Future<HandledHardQueryResult> queryHandledHard({
    String? userId,
    String? currentPhase,
    bool nightMode = false,
  }) async {
    final allEntries = _journalRepository.getAllJournalEntries();
    
    // Filter for entries with SAGE tags (Action + Growth moments)
    final candidateEntries = allEntries.where((entry) {
      final sage = entry.sageAnnotation;
      if (sage == null) return false;
      
      // Check for Action and Growth tags
      final hasAction = sage.action.isNotEmpty;
      final hasGrowth = sage.growth.isNotEmpty;
      
      return hasAction || hasGrowth;
    }).toList();

    // Detect negative→positive emotional transitions
    final transitionEntries = <JournalEntry>[];
    for (final entry in candidateEntries) {
      if (_hasNegativeToPositiveTransition(entry)) {
        transitionEntries.add(entry);
      }
    }

    // Keyword matching for hard situations
    final keywordMatches = transitionEntries.where((entry) {
      final content = entry.content.toLowerCase();
      final keywords = ['hard', 'overwhelmed', 'scared', 'uncertain', 'stuck', 
                        'broke through', 'resolved', 'difficult', 'challenge', 
                        'struggle', 'tough', 'managed', 'handled', 'got through'];
      return keywords.any((kw) => content.contains(kw));
    }).toList();

    // Rank by similarity to current distress (if we have memory service)
    List<JournalEntry> rankedEntries = keywordMatches;
    if (_memoryService != null && userId != null) {
      // Use semantic search to find entries similar to current state
      try {
        final memoryResult = await _memoryService!.retrieveMemories(
          query: 'handled difficult situation overcame challenge',
          domains: [MemoryDomain.personal],
          limit: 50,
          similarityThreshold: 0.3,
        );
        
        // Match memory nodes to journal entries
        final entryIds = memoryResult.nodes
            .map((node) => node.metadata?['entryId'] as String?)
            .whereType<String>()
            .toSet();
        
        rankedEntries = keywordMatches.where((e) => entryIds.contains(e.id)).toList();
        if (rankedEntries.length < 3) {
          // Add remaining entries
          final remaining = keywordMatches.where((e) => !entryIds.contains(e.id)).toList();
          rankedEntries.addAll(remaining);
        }
      } catch (e) {
        print('ReflectiveQuery: Memory service error: $e');
      }
    }

    // Apply diversity constraints (not all same month/topic)
    final diverseEntries = _applyDiversityConstraints(rankedEntries, limit: 3);

    // VEIL filtering for restorative content
    final filteredEntries = _applyVeilFiltering(diverseEntries, nightMode: nightMode);

    // Check for trauma content
    final hasTrauma = _hasTraumaContent(filteredEntries);
    String? safetyMessage;
    if (hasTrauma) {
      safetyMessage = 'You have handled difficult things. Some involve sensitive material. '
          'Do you want me to show you gentler examples, or skip this?';
    }

    // Build results
    final results = filteredEntries.take(3).map((entry) {
      final phase = entry.phase ?? currentPhase ?? 'Unknown';
      final sage = entry.sageAnnotation;
      
      // Extract user words (≤20 words)
      final userWords = _extractShortQuote(entry.content, maxWords: 20);
      
      // Extract how handled from SAGE Action
      final howHandled = sage?.action.isNotEmpty == true ? sage!.action : 'You navigated through it';
      
      // Extract outcome from SAGE Growth or Essence
      final outcome = (sage?.growth.isNotEmpty == true) 
          ? sage!.growth 
          : (sage?.essence.isNotEmpty == true) 
              ? sage!.essence 
              : 'You moved forward';
      
      // Context summary
      final context = _generateContext(entry, sage);

      return HandledHardResult(
        when: entry.originalCreatedAt, // Use original creation time, not edited time
        context: context,
        userWords: userWords,
        howHandled: howHandled,
        outcome: outcome,
        phase: phase,
        entry: entry,
      );
    }).toList();

    return HandledHardQueryResult(
      entries: results,
      hasTraumaContent: hasTrauma,
      safetyMessage: safetyMessage,
    );
  }

  /// Query 2: "What was I struggling with around this time last year?"
  Future<TemporalStruggleQueryResult> queryTemporalStruggle({
    String? userId,
    String? currentPhase,
    bool nightMode = false,
  }) async {
    final now = DateTime.now();
    final targetDate = DateTime(now.year - 1, now.month, now.day);
    final startDate = targetDate.subtract(const Duration(days: 14));
    final endDate = targetDate.add(const Duration(days: 14));

    final allEntries = _journalRepository.getAllJournalEntries();
    
    // Get entries from ±2 weeks around same date in prior years
    // Use originalCreatedAt to ensure we get entries from the correct historical date
    final temporalEntries = allEntries.where((entry) {
      final entryDate = entry.originalCreatedAt; // Use original creation time
      // Check if same month/day but different year, or within ±2 weeks
      final sameMonthDay = entryDate.month == targetDate.month && 
                          entryDate.day == targetDate.day &&
                          entryDate.year < now.year;
      final withinWindow = entryDate.isAfter(startDate) && 
                          entryDate.isBefore(endDate) &&
                          entryDate.year < now.year;
      return sameMonthDay || withinWindow;
    }).toList();

    if (temporalEntries.isEmpty) {
      return TemporalStruggleQueryResult(
        themes: [],
        isGriefAnniversary: false,
        groundingPreface: 'There is not much here from around this time in your past entries. '
            'Would you like to start a new reflection for this season of your life?',
      );
    }

    // Extract SAGE tags and cluster by themes
    final themes = _clusterByThemes(temporalEntries);
    
    // Filter for entries with narrative arcs (problem → insight/adjustment)
    final narrativeThemes = themes.where((theme) {
      return _hasNarrativeArc(theme.entries);
    }).toList();

    // Check for grief anniversary
    final isGriefAnniversary = _isGriefAnniversary(temporalEntries);
    String? groundingPreface;
    if (isGriefAnniversary) {
      groundingPreface = 'Last year was a hard season. I can show you:\n'
          '1. What you struggled with\n'
          '2. How it changed\n'
          '3. Or we can skip this entirely.';
    }

    // Get phase from that time period
    final pastPhase = await _getPhaseAtTime(targetDate);

    // Build results (up to 3 themes)
    final results = narrativeThemes.take(3).map((theme) {
      final entry = theme.entries.first;
      final sage = entry.sageAnnotation;
      
      final userWords = _extractShortQuote(entry.content, maxWords: 30);
      final howResolved = _findResolution(theme.entries);

      return TemporalStruggleResult(
        theme: theme.theme,
        userWords: userWords,
        phase: pastPhase ?? entry.phase ?? 'Unknown',
        howResolved: howResolved,
        date: entry.originalCreatedAt, // Use original creation time
        entry: entry,
      );
    }).toList();

    // Apply night mode if active
    if (nightMode) {
      // Emphasize soothing summaries
      for (final result in results) {
        if (result.howResolved == null) {
          // Skip entries without resolution in night mode
        }
      }
    }

    return TemporalStruggleQueryResult(
      themes: results,
      isGriefAnniversary: isGriefAnniversary,
      groundingPreface: groundingPreface,
    );
  }

  /// Query 3: "Which themes have softened in the last six months?"
  Future<ThemeSofteningQueryResult> queryThemeSoftening({
    String? userId,
  }) async {
    final now = DateTime.now();
    final recentStart = now.subtract(const Duration(days: 90)); // 0-3 months
    final pastStart = now.subtract(const Duration(days: 180)); // 3-6 months
    final pastEnd = now.subtract(const Duration(days: 90));

    final allEntries = _journalRepository.getAllJournalEntries();
    
    // Split into two windows using original creation time
    final recentEntries = allEntries.where((e) => 
      e.originalCreatedAt.isAfter(recentStart)
    ).toList();
    
    final pastEntries = allEntries.where((e) => 
      e.originalCreatedAt.isAfter(pastStart) && e.originalCreatedAt.isBefore(pastEnd)
    ).toList();

    if (recentEntries.isEmpty || pastEntries.isEmpty) {
      return ThemeSofteningQueryResult(
        themes: [],
        hasFalsePositives: true,
        note: 'Not enough entries in both time periods for comparison.',
      );
    }

    // Compute theme frequencies
    final recentThemes = _computeThemeFrequencies(recentEntries);
    final pastThemes = _computeThemeFrequencies(pastEntries);

    // Find themes that have softened (decreased frequency)
    final softeningThemes = <String, ThemeFrequency>{};
    for (final theme in pastThemes.keys) {
      final pastFreq = pastThemes[theme]!;
      final recentFreq = recentThemes[theme] ?? ThemeFrequency(theme: theme, count: 0, intensity: 0.0);
      
      if (pastFreq.count > recentFreq.count && pastFreq.count >= 3) {
        // Theme has decreased in frequency
        softeningThemes[theme] = ThemeFrequency(
          theme: theme,
          count: pastFreq.count - recentFreq.count,
          intensity: pastFreq.intensity - recentFreq.intensity,
        );
      }
    }

    // Filter false positives (lack of journaling vs actual softening)
    final validSoftening = <String, ThemeFrequency>{};
    for (final entry in softeningThemes.entries) {
      // Check if there's actual journaling activity in both periods
      final pastActivity = pastEntries.length;
      final recentActivity = recentEntries.length;
      
      // Only consider if both periods have reasonable activity
      if (pastActivity >= 5 && recentActivity >= 5) {
        validSoftening[entry.key] = entry.value;
      }
    }

    // Sort by intensity delta (biggest softening first)
    final sorted = validSoftening.entries.toList()
      ..sort((a, b) => b.value.intensity.compareTo(a.value.intensity));

    // Get phase dynamics
    final recentPhase = await _getPhaseAtTime(recentStart);
    final pastPhase = await _getPhaseAtTime(pastStart);

    // Build results (top 3)
    final results = sorted.take(3).map((entry) {
      final theme = entry.key;
      final pastFreq = pastThemes[theme]!;
      final recentFreq = recentThemes[theme] ?? ThemeFrequency(theme: theme, count: 0, intensity: 0.0);
      
      // Find example entries
      final pastExample = _findExampleEntry(pastEntries, theme);
      final recentExample = _findExampleEntry(recentEntries, theme);

      final userWordsThen = pastExample != null 
          ? _extractShortQuote(pastExample.content, maxWords: 25)
          : 'Reflecting on this theme';
      
      final userWordsNow = recentExample != null
          ? _extractShortQuote(recentExample.content, maxWords: 25)
          : 'This theme appears less frequently';

      final phaseDynamics = _explainPhaseDynamics(theme, pastPhase, recentPhase);

      return ThemeSofteningResult(
        theme: theme,
        pastIntensity: pastFreq.count,
        recentIntensity: recentFreq.count,
        userWordsThen: userWordsThen,
        userWordsNow: userWordsNow,
        phaseDynamics: phaseDynamics,
        pastEntry: pastExample,
        recentEntry: recentExample,
      );
    }).toList();

    return ThemeSofteningQueryResult(
      themes: results,
      hasFalsePositives: validSoftening.length < softeningThemes.length,
      note: validSoftening.length < softeningThemes.length
          ? 'Some apparent softening may be due to reduced journaling activity.'
          : null,
    );
  }

  // Helper methods

  bool _hasNegativeToPositiveTransition(JournalEntry entry) {
    final content = entry.content.toLowerCase();
    // Look for negative keywords followed by positive resolution
    final negativeKeywords = ['hard', 'difficult', 'struggle', 'overwhelmed', 
                             'scared', 'uncertain', 'stuck', 'worried'];
    final positiveKeywords = ['resolved', 'broke through', 'managed', 'handled',
                             'overcame', 'got through', 'figured out', 'worked out'];
    
    bool hasNegative = negativeKeywords.any((kw) => content.contains(kw));
    bool hasPositive = positiveKeywords.any((kw) => content.contains(kw));
    
    return hasNegative && hasPositive;
  }

  List<JournalEntry> _applyDiversityConstraints(
    List<JournalEntry> entries, {
    required int limit,
  }) {
    if (entries.length <= limit) return entries;
    
    final diverse = <JournalEntry>[];
    final usedMonths = <int>{};
    final usedTopics = <String>{};
    
    for (final entry in entries) {
      if (diverse.length >= limit) break;
      
      final month = entry.originalCreatedAt.month; // Use original creation time for diversity
      final keywords = entry.keywords.take(3).join(' ').toLowerCase();
      
      // Prefer entries from different months and topics
      if (!usedMonths.contains(month) || !usedTopics.contains(keywords)) {
        diverse.add(entry);
        usedMonths.add(month);
        usedTopics.add(keywords);
      }
    }
    
    // Fill remaining slots if needed
    if (diverse.length < limit) {
      for (final entry in entries) {
        if (diverse.length >= limit) break;
        if (!diverse.contains(entry)) {
          diverse.add(entry);
        }
      }
    }
    
    return diverse;
  }

  List<JournalEntry> _applyVeilFiltering(
    List<JournalEntry> entries, {
    required bool nightMode,
  }) {
    // Prefer stories with closure
    final withClosure = entries.where((entry) {
      final content = entry.content.toLowerCase();
      final closureKeywords = ['resolved', 'worked out', 'got through', 
                               'figured out', 'managed', 'handled'];
      return closureKeywords.any((kw) => content.contains(kw));
    }).toList();
    
    if (withClosure.isNotEmpty) {
      return withClosure;
    }
    
    // If night mode, only return low-arousal examples
    if (nightMode) {
      return entries.where((entry) {
        final content = entry.content.toLowerCase();
        final highArousal = ['panic', 'terrified', 'devastated', 'crisis',
                            'emergency', 'urgent', 'desperate'];
        return !highArousal.any((kw) => content.contains(kw));
      }).toList();
    }
    
    return entries;
  }

  bool _hasTraumaContent(List<JournalEntry> entries) {
    // Use SENTINEL to detect trauma
    try {
      final reflectiveData = entries.map((e) => ReflectiveEntryData.fromJournalEntry(
        timestamp: e.originalCreatedAt, // Use original creation time for trauma detection
        keywords: e.keywords,
        phase: e.phase ?? 'Unknown',
      )).toList();
      
      final analysis = SentinelRiskDetector.analyzeRisk(
        entries: reflectiveData,
        timeWindow: TimeWindow.month,
      );
      
      // Check for high risk patterns that might indicate trauma
      return analysis.riskLevel == RiskLevel.severe || 
             analysis.riskLevel == RiskLevel.high;
    } catch (e) {
      print('ReflectiveQuery: Error checking trauma: $e');
      return false;
    }
  }

  String _extractShortQuote(String content, {required int maxWords}) {
    final words = content.split(' ');
    if (words.length <= maxWords) return content;
    
    // Try to find a meaningful sentence
    final sentences = content.split(RegExp(r'[.!?]'));
    for (final sentence in sentences) {
      final sentenceWords = sentence.trim().split(' ');
      if (sentenceWords.length <= maxWords && sentenceWords.length > 3) {
        return sentence.trim();
      }
    }
    
    // Fallback: first N words
    return words.take(maxWords).join(' ') + '...';
  }

  String _generateContext(JournalEntry entry, SAGEAnnotation? sage) {
    if (sage?.situation.isNotEmpty == true) {
      return sage!.situation;
    }
    
    // Fallback: first sentence or first 50 chars
    final sentences = entry.content.split(RegExp(r'[.!?]'));
    if (sentences.isNotEmpty) {
      return sentences.first.trim();
    }
    return entry.content.substring(0, math.min(50, entry.content.length));
  }

  List<ThemeCluster> _clusterByThemes(List<JournalEntry> entries) {
    final themeMap = <String, List<JournalEntry>>{};
    
    for (final entry in entries) {
      final keywords = entry.keywords;
      if (keywords.isEmpty) continue;
      
      // Use first keyword as theme
      final theme = keywords.first.toLowerCase();
      themeMap.putIfAbsent(theme, () => []).add(entry);
    }
    
    return themeMap.entries.map((e) => ThemeCluster(
      theme: e.key,
      entries: e.value,
    )).toList();
  }

  bool _hasNarrativeArc(List<JournalEntry> entries) {
    // Check if entries show progression from problem to insight
    if (entries.length < 2) return false;
    
    entries.sort((a, b) => a.originalCreatedAt.compareTo(b.originalCreatedAt));
    final first = entries.first;
    final last = entries.last;
    
    final firstContent = first.content.toLowerCase();
    final lastContent = last.content.toLowerCase();
    
    // Check for problem keywords in first, resolution in last
    final problemKeywords = ['struggle', 'difficult', 'hard', 'problem', 'issue'];
    final resolutionKeywords = ['resolved', 'understood', 'realized', 'learned', 'insight'];
    
    final hasProblem = problemKeywords.any((kw) => firstContent.contains(kw));
    final hasResolution = resolutionKeywords.any((kw) => lastContent.contains(kw));
    
    return hasProblem && hasResolution;
  }

  bool _isGriefAnniversary(List<JournalEntry> entries) {
    // Check for grief-related keywords
    final griefKeywords = ['grief', 'grieving', 'loss', 'death', 'died', 
                          'funeral', 'mourning', 'passed away'];
    
    return entries.any((entry) {
      final content = entry.content.toLowerCase();
      return griefKeywords.any((kw) => content.contains(kw));
    });
  }

  String? _findResolution(List<JournalEntry> entries) {
    entries.sort((a, b) => b.originalCreatedAt.compareTo(a.originalCreatedAt));
    
    for (final entry in entries) {
      final sage = entry.sageAnnotation;
      if (sage != null) {
        if (sage.growth.isNotEmpty) {
          return sage.growth;
        }
        if (sage.essence.isNotEmpty) {
          return sage.essence;
        }
      }
    }
    
    return null;
  }

  Future<String?> _getPhaseAtTime(DateTime date) async {
    if (_phaseHistory == null) return null;
    
    try {
      final allEntries = await PhaseHistoryRepository.getAllEntries();
      // Find entry closest to date
      PhaseHistoryEntry? closest;
      Duration? minDiff;
      
      for (final entry in allEntries) {
        final diff = (entry.timestamp.difference(date)).abs();
        if (minDiff == null || diff < minDiff) {
          minDiff = diff;
          closest = entry;
        }
      }
      
      if (closest != null) {
        // Get phase with highest score
        final phaseScores = closest.phaseScores;
        if (phaseScores.isNotEmpty) {
          final sorted = phaseScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return sorted.first.key;
        }
      }
    } catch (e) {
      print('ReflectiveQuery: Error getting phase: $e');
    }
    
    return null;
  }

  Map<String, ThemeFrequency> _computeThemeFrequencies(List<JournalEntry> entries) {
    final themeMap = <String, int>{};
    final intensityMap = <String, double>{};
    
    for (final entry in entries) {
      final keywords = entry.keywords;
      for (final keyword in keywords) {
        final theme = keyword.toLowerCase();
        themeMap[theme] = (themeMap[theme] ?? 0) + 1;
        
        // Compute intensity (simple: based on entry length and emotion)
        final intensity = entry.content.length / 1000.0; // Normalize
        intensityMap[theme] = (intensityMap[theme] ?? 0.0) + intensity;
      }
    }
    
    return themeMap.map((theme, count) => MapEntry(
      theme,
      ThemeFrequency(
        theme: theme,
        count: count,
        intensity: intensityMap[theme] ?? 0.0,
      ),
    ));
  }

  JournalEntry? _findExampleEntry(List<JournalEntry> entries, String theme) {
    return entries.firstWhere(
      (e) => e.keywords.any((k) => k.toLowerCase() == theme),
      orElse: () => entries.first,
    );
  }

  String _explainPhaseDynamics(String theme, String? pastPhase, String? recentPhase) {
    if (pastPhase == null || recentPhase == null) {
      return 'This softening occurred during a phase transition.';
    }
    
    if (pastPhase == recentPhase) {
      return 'This softening occurred while you were in $pastPhase phase.';
    }
    
    return 'This softening coincided with transitioning from $pastPhase to $recentPhase.';
  }
}

// Helper classes

class ThemeCluster {
  final String theme;
  final List<JournalEntry> entries;

  ThemeCluster({
    required this.theme,
    required this.entries,
  });
}

class ThemeFrequency {
  final String theme;
  final int count;
  final double intensity;

  ThemeFrequency({
    required this.theme,
    required this.count,
    required this.intensity,
  });
}


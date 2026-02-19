import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';
import 'package:my_app/services/keyword_aggregator.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/arcform/share/arcform_share_composition_screen.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/core/constants/phase_colors.dart';

/// Compact preview widget showing current phase Arcform visualization
/// Uses the same architecture as Insights->Phase->Arcform visualizations
/// Displays above timeline icons in the Timeline view
class CurrentPhaseArcformPreview extends StatefulWidget {
  /// When set, tap opens this instead of FullScreenPhaseViewer (e.g. main Phase menu).
  final VoidCallback? onTapOverride;

  const CurrentPhaseArcformPreview({super.key, this.onTapOverride});

  @override
  State<CurrentPhaseArcformPreview> createState() => _CurrentPhaseArcformPreviewState();
}

class _CurrentPhaseArcformPreviewState extends State<CurrentPhaseArcformPreview> {
  @override
  Widget build(BuildContext context) {
    // Use the same SimplifiedArcformView3D component but extract just the first snapshot card
    // and display it in a compact format
    return _CompactArcformPreview(onTapOverride: widget.onTapOverride);
  }
}

/// Compact preview that uses the same data loading as SimplifiedArcformView3D
class _CompactArcformPreview extends StatefulWidget {
  final VoidCallback? onTapOverride;

  const _CompactArcformPreview({this.onTapOverride});

  @override
  State<_CompactArcformPreview> createState() => _CompactArcformPreviewState();
}

class _CompactArcformPreviewState extends State<_CompactArcformPreview> {
  // Use the same state management as SimplifiedArcformView3D
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;
  String? _currentPhase;
  
  // Phase transition trend data
  String? _approachingPhase;
  int _trendPercent = 0;

  @override
  void initState() {
    super.initState();
    // Always reload on init - ensures fresh data after imports/restores
    _loadSnapshots();
    
    // Listen for phase changes from multiple sources and reload the preview to stay in sync:
    // 1. UserPhaseService: manual phase changes (quiz, "Change Phase" button)
    // 2. PhaseRegimeService: RIVET/ATLAS regime changes, ARCX import, backup restore
    UserPhaseService.phaseChangeNotifier.addListener(_onPhaseChanged);
    PhaseRegimeService.regimeChangeNotifier.addListener(_onPhaseChanged);
  }
  
  @override
  void didUpdateWidget(_CompactArcformPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when widget is updated (e.g. after navigation back to feed)
    _loadSnapshots();
  }
  
  @override
  void dispose() {
    UserPhaseService.phaseChangeNotifier.removeListener(_onPhaseChanged);
    PhaseRegimeService.regimeChangeNotifier.removeListener(_onPhaseChanged);
    super.dispose();
  }
  
  void _onPhaseChanged() {
    if (mounted) {
      print('DEBUG: Phase preview detected phase/regime change, reloading...');
      _loadSnapshots();
    }
  }

  // Resolve phase using the same order as the Phase tab so Conversations preview stays in sync.
  // Order: 1) current regime, 2) most recent regime, 3) UserProfile/quiz.
  String _capitalizePhase(String raw) {
    if (raw.trim().isEmpty) return 'Discovery';
    final p = raw.trim();
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }

  Future<void> _loadSnapshots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use getDisplayPhase so user's chosen phase (quiz or manual) takes priority over regime
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      String? regimePhase;
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
      if (currentRegime != null) {
        regimePhase = currentRegime.label.toString().split('.').last;
      } else if (allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
        regimePhase = sortedRegimes.first.label.toString().split('.').last;
      }
      bool rivetGateOpen = false;
      try {
        final rivetProvider = RivetProvider();
        if (!rivetProvider.isAvailable) await rivetProvider.initialize('default_user');
        rivetGateOpen = rivetProvider.service?.wouldGateOpen() ?? false;
      } catch (_) {}
      final profilePhase = await UserPhaseService.getCurrentPhase();
      print('🔍 Phase Preview: regimePhase=$regimePhase, rivetGateOpen=$rivetGateOpen, profilePhase=$profilePhase');
      final displayPhase = UserPhaseService.getDisplayPhase(
        regimePhase: regimePhase?.trim().isEmpty == true ? null : regimePhase,
        rivetGateOpen: rivetGateOpen,
        profilePhase: profilePhase,
      );
      final currentPhaseCapitalized = displayPhase.trim().isNotEmpty
          ? _capitalizePhase(displayPhase)
          : 'Discovery';
      print('🎯 Phase Preview: Final display phase = $currentPhaseCapitalized');

      // Check if user has entries for this phase
      final isUserPhase = await _hasEntriesForPhase(currentPhaseCapitalized);

      // Generate arcform using SimplifiedArcformView3D's method
      final arcform = await _generatePhaseConstellation(currentPhaseCapitalized, isUserPhase: isUserPhase);

      // Calculate phase transition trend
      await _calculatePhaseTrend();

      if (mounted) {
        setState(() {
          if (arcform != null) {
            final snapshot = {
              'id': arcform.id,
              'title': arcform.title,
              'phaseHint': arcform.phase,
              'keywords': arcform.nodes.map((node) => node.label).toList(),
              'createdAt': arcform.createdAt.toIso8601String(),
              'content': arcform.content,
              'arcformData': arcform.toJson(),
            };
            _snapshots = [snapshot];
            _currentPhase = currentPhaseCapitalized;
          } else {
            _snapshots = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading arcform preview: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Calculate trend toward next phase using RIVET-based analysis
  /// Uses PhaseRecommender for content analysis and respects userPhaseOverride (chisel)
  Future<void> _calculatePhaseTrend() async {
    try {
      final journalRepo = JournalRepository();
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Get current phase name
      String currentPhaseName;
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        currentPhaseName = currentRegime.label.toString().split('.').last;
        currentPhaseName = currentPhaseName[0].toUpperCase() + currentPhaseName.substring(1);
      } else if (phaseRegimeService.phaseIndex.allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(phaseRegimeService.phaseIndex.allRegimes)
          ..sort((a, b) => b.start.compareTo(a.start));
        currentPhaseName = sortedRegimes.first.label.toString().split('.').last;
        currentPhaseName = currentPhaseName[0].toUpperCase() + currentPhaseName.substring(1);
      } else {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Get all entries and sort chronologically
      final allEntries = journalRepo.getAllJournalEntriesSync();
      if (allEntries.isEmpty) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      final sortedEntries = allEntries.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Build RIVET events from entries using PhaseRecommender
      final rivetService = RivetService();
      final events = <RivetEvent>[];
      RivetEvent? lastEvent;

      for (final entry in sortedEntries) {
        // Use PhaseRecommender to analyze content
        final recommendedPhase = PhaseRecommender.recommend(
          emotion: entry.emotion ?? '',
          reason: entry.emotionReason ?? '',
          text: entry.content,
          selectedKeywords: entry.keywords,
        );

        // Use userPhaseOverride as refPhase if set (chisel), otherwise use regime baseline
        final entryRefPhase = entry.userPhaseOverride ?? currentPhaseName;

        final event = RivetEvent(
          eventId: entry.id,
          date: entry.createdAt,
          source: EvidenceSource.text,
          keywords: entry.keywords.toSet(),
          predPhase: recommendedPhase,
          refPhase: entryRefPhase,  // User corrections feed into RIVET
          tolerance: const {},
        );

        events.add(event);
        rivetService.ingest(event, lastEvent: lastEvent);
        lastEvent = event;
      }

      if (events.length < 3) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Calculate transition insights using last 10 events
      final recentEvents = events.length > 10 
          ? events.sublist(events.length - 10) 
          : events;
      
      final phaseCounts = <String, int>{};
      for (final event in recentEvents) {
        phaseCounts[event.predPhase] = (phaseCounts[event.predPhase] ?? 0) + 1;
      }

      // Find most common phase that's NOT the current phase
      String? approachingPhase;
      double maxCount = 0;
      for (final entry in phaseCounts.entries) {
        if (entry.key.toLowerCase() != currentPhaseName.toLowerCase() && entry.value > maxCount) {
          maxCount = entry.value.toDouble();
          approachingPhase = entry.key;
        }
      }

      if (approachingPhase == null) {
        _approachingPhase = null;
        _trendPercent = 0;
        print('DEBUG: Phase trend (RIVET) - stable in $currentPhaseName');
        return;
      }

      // Calculate shift percentage by comparing early vs recent predictions
      final midPoint = recentEvents.length ~/ 2;
      final earlyPhases = recentEvents.sublist(0, midPoint).map((e) => e.predPhase).toList();
      final recentPhases = recentEvents.sublist(midPoint).map((e) => e.predPhase).toList();
      
      final earlyApproachCount = earlyPhases.where((p) => p.toLowerCase() == approachingPhase!.toLowerCase()).length;
      final recentApproachCount = recentPhases.where((p) => p.toLowerCase() == approachingPhase!.toLowerCase()).length;
      
      final earlyPercent = earlyPhases.isEmpty ? 0.0 : (earlyApproachCount / earlyPhases.length) * 100;
      final recentPercent = recentPhases.isEmpty ? 0.0 : (recentApproachCount / recentPhases.length) * 100;
      
      final shiftPercentage = (recentPercent - earlyPercent).abs();
      final isToward = recentPercent > earlyPercent;

      // Only show trend if shift > 5% and trending toward
      if (shiftPercentage > 5.0 && isToward) {
        _approachingPhase = approachingPhase[0].toUpperCase() + approachingPhase.substring(1).toLowerCase();
        _trendPercent = shiftPercentage.round();
      } else {
        _approachingPhase = null;
        _trendPercent = 0;
      }
      
      print('DEBUG: Phase trend (RIVET) - approaching: $_approachingPhase, percent: $_trendPercent%, '
            'early: ${earlyPercent.toStringAsFixed(1)}%, recent: ${recentPercent.toStringAsFixed(1)}%');
    } catch (e) {
      print('DEBUG: Error calculating phase trend: $e');
      _approachingPhase = null;
      _trendPercent = 0;
    }
  }

  // Copy helper methods from SimplifiedArcformView3D
  Future<bool> _hasEntriesForPhase(String phase) async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      
      if (allEntries.isEmpty) return false;
      
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
      final regimes = allRegimes
          .where((r) => r.label.toString().split('.').last.toLowerCase() == phase.toLowerCase())
          .toList();
      
      if (regimes.isNotEmpty) {
        for (final regime in regimes) {
          final regimeStart = regime.start;
          final regimeEnd = regime.end ?? DateTime.now();
          final entriesInRegime = allEntries
              .where((entry) => entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) && 
                                entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1))))
              .toList();
          if (entriesInRegime.isNotEmpty) return true;
        }
      }
      
      if (phase.toLowerCase() == 'discovery' && allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(allRegimes)..sort((a, b) => a.start.compareTo(b.start));
        final firstRegime = sortedRegimes.first;
        final entriesBeforeFirstRegime = allEntries
            .where((entry) => entry.createdAt.isBefore(firstRegime.start))
            .toList();
        if (entriesBeforeFirstRegime.isNotEmpty) return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getActualPhaseKeywords(String phase) async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
        
        final phaseRegimes = phaseRegimeService.phaseIndex.allRegimes
            .where((r) => r.label.toString().split('.').last.toLowerCase() == phase.toLowerCase())
            .toList();
        
        List<JournalEntry> regimeEntries = [];
        
        if (phaseRegimes.isNotEmpty) {
          for (final regime in phaseRegimes) {
            final regimeStart = regime.start;
            final regimeEnd = regime.end ?? DateTime.now();
            final entriesInRegime = allEntries
                .where((entry) => 
                    entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) && 
                    entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1))))
                .toList();
            regimeEntries.addAll(entriesInRegime);
          }
        } else if (phase.toLowerCase() == 'discovery') {
          final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
          if (allRegimes.isNotEmpty) {
            final sortedRegimes = List.from(allRegimes)..sort((a, b) => a.start.compareTo(b.start));
            final firstRegime = sortedRegimes.first;
            regimeEntries = allEntries
                .where((entry) => entry.createdAt.isBefore(firstRegime.start))
                .toList();
          } else {
            regimeEntries = allEntries;
          }
        } else {
          final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
          regimeEntries = allEntries
              .where((entry) => entry.createdAt.isAfter(recentCutoff))
              .toList();
        }
        
        if (regimeEntries.isEmpty) {
          return _getHardcodedPhaseKeywords(phase);
        }

        final allKeywords = <String>[];
        for (final entry in regimeEntries) {
          allKeywords.addAll(entry.keywords);
        }

        final keywordCounts = <String, int>{};
        for (final keyword in allKeywords) {
          keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
        }

        final sortedKeywords = keywordCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final topKeywords = sortedKeywords
            .take(20)
            .map((e) => e.key)
            .where((kw) => kw.isNotEmpty)
            .toList();
        
        final journalTexts = regimeEntries.map((e) => e.content).toList();
        final aggregatedKeywords = KeywordAggregator.getTopAggregatedKeywords(
          journalTexts,
          topN: 10,
        );

        final combinedKeywords = <String>[];
        combinedKeywords.addAll(topKeywords);
        combinedKeywords.addAll(aggregatedKeywords);
        
        return combinedKeywords.toSet().toList().take(20).toList();
      } catch (e) {
        return _getHardcodedPhaseKeywords(phase);
      }
    } catch (e) {
      return _getHardcodedPhaseKeywords(phase);
    }
  }

  List<String> _getHardcodedPhaseKeywords(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return [
          'growth', 'insight', 'learning', 'curiosity', 'exploration',
          'discovery', 'wonder', 'creativity', 'innovation', 'breakthrough',
          'transformation', 'journey', 'adventure', 'possibility', 'potential',
          'excitement', 'enthusiasm', 'energy', 'inspiration', 'vision'
        ];
      case 'exploration':
      case 'expansion':
        return [
          'expansion', 'growth', 'opportunity', 'success', 'achievement',
          'progress', 'momentum', 'confidence', 'strength', 'power',
          'ambition', 'drive', 'determination', 'focus', 'clarity',
          'vision', 'purpose', 'direction', 'leadership', 'influence'
        ];
      case 'transition':
        return [
          'change', 'transition', 'shift', 'adaptation', 'flexibility',
          'uncertainty', 'anxiety', 'hope', 'anticipation', 'preparation',
          'letting go', 'moving forward', 'new beginnings', 'closure',
          'reflection', 'integration', 'balance', 'harmony', 'patience', 'trust'
        ];
      case 'consolidation':
        return [
          'stability', 'consolidation', 'integration', 'synthesis', 'wholeness',
          'completion', 'mastery', 'expertise', 'wisdom', 'understanding',
          'peace', 'contentment', 'satisfaction', 'fulfillment', 'gratitude',
          'appreciation', 'celebration', 'joy', 'serenity', 'tranquility'
        ];
      case 'recovery':
        return [
          'healing', 'recovery', 'restoration', 'renewal', 'rejuvenation',
          'resilience', 'strength', 'courage', 'perseverance', 'endurance',
          'support', 'care', 'compassion', 'understanding', 'acceptance',
          'forgiveness', 'letting go', 'moving on', 'hope', 'optimism'
        ];
      case 'breakthrough':
        return [
          'breakthrough', 'transformation', 'revelation', 'enlightenment', 'awakening',
          'clarity', 'understanding', 'insight', 'wisdom', 'knowledge',
          'freedom', 'liberation', 'empowerment', 'confidence', 'strength',
          'purpose', 'direction', 'vision', 'mission', 'destiny'
        ];
      default:
        return [
          'growth', 'insight', 'learning', 'curiosity', 'exploration',
          'discovery', 'wonder', 'creativity', 'innovation', 'breakthrough'
        ];
    }
  }

  double _getPhaseValence(String keyword, String phase) {
    final lower = keyword.toLowerCase();
    if (lower.contains('happy') || lower.contains('joy') || lower.contains('love') || 
        lower.contains('success') || lower.contains('growth') || lower.contains('positive')) {
      return 0.5 + (keyword.length / 40.0);
    } else if (lower.contains('sad') || lower.contains('angry') || lower.contains('fear') ||
               lower.contains('worry') || lower.contains('stress') || lower.contains('negative')) {
      return -0.5 - (keyword.length / 40.0);
    }
    return 0.0;
  }

  Future<Arcform3DData?> _generatePhaseConstellation(String phase, {bool isUserPhase = false}) async {
    try {
      final skin = ArcformSkin.forUser('user', 'phase_$phase');

      final List<String> keywords;
      if (isUserPhase) {
        keywords = await _getActualPhaseKeywords(phase);
      } else {
        keywords = _getHardcodedPhaseKeywords(phase);
      }

      final nonEmptyKeywords = keywords.where((kw) => kw.isNotEmpty).toList();

      final nodes = layout3D(
        keywords: nonEmptyKeywords.isNotEmpty ? nonEmptyKeywords : ['Phase'],
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in nonEmptyKeywords) kw: 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in nonEmptyKeywords) kw: _getPhaseValence(kw, phase)},
      );

      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: phase,
        maxEdgesPerNode: 4,
        maxDistance: 1.4,
      );

      return Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: phase,
        skin: skin,
        title: '$phase Constellation',
        content: isUserPhase
            ? 'Your personal 3D constellation for $phase phase'
            : 'Example 3D constellation for $phase phase',
        createdAt: DateTime.now(),
        id: 'phase_${phase.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      print('Error generating phase constellation for $phase: $e');
      return null;
    }
  }

  // Copy the exact card building logic from SimplifiedArcformView3D
  Arcform3DData? _generateArcformData(Map<String, dynamic> snapshot, String phase) {
    try {
      if (snapshot['arcformData'] != null) {
        final arcformJson = snapshot['arcformData'] as Map<String, dynamic>;
        return Arcform3DData.fromJson(arcformJson);
      }
      
      final keywords = List<String>.from(snapshot['keywords'] ?? []);
      if (keywords.isEmpty) return null;

      final skin = ArcformSkin.forUser('user', snapshot['id']?.toString() ?? 'default');
      
      final nodes = layout3D(
        keywords: keywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.5 + (kw.length / 20.0)},
        keywordValences: {for (var kw in keywords) kw: _getPhaseValence(kw, phase)},
      );

      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: phase,
        maxEdgesPerNode: 3,
        maxDistance: 1.2,
      );

      return Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: phase,
        skin: skin,
        title: snapshot['title'] ?? 'Constellation Visualization',
        content: snapshot['content']?.toString(),
        createdAt: DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now(),
        id: snapshot['id']?.toString() ?? 'unknown',
      );
    } catch (e) {
      print('Error generating ARCForm data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200, // Match Phase tab preview height
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor.withOpacity(0.2)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_snapshots.isEmpty) {
      return Container(
        height: 200, // Match Phase tab preview height
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor.withOpacity(0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: kcSecondaryTextColor,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'No Arcform data available',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use the exact same card building logic from SimplifiedArcformView3D
    final snapshot = _snapshots.first;
    final phaseHintRaw = snapshot['phaseHint'] ?? 'Discovery';
    // Capitalize the phase name (e.g., "transition" -> "Transition")
    final phaseHint = phaseHintRaw.isEmpty 
        ? 'Discovery' 
        : phaseHintRaw[0].toUpperCase() + phaseHintRaw.substring(1).toLowerCase();
    final arcformData = _generateArcformData(snapshot, phaseHint);

    // Fixed height layout - no LayoutBuilder to avoid semantics/parentDataDirty issues
    return GestureDetector(
      onTap: () {
        if (widget.onTapOverride != null) {
          widget.onTapOverride!();
        } else if (arcformData != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullScreenPhaseViewer(arcform: arcformData),
            ),
          );
        }
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kcPrimaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: kcPrimaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _currentPhase ?? phaseHint,
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_full,
                      size: 18,
                      color: kcSecondaryTextColor,
                    ),
                  ],
                ),
              ),
              // Arcform preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: arcformData != null
                        ? IgnorePointer(
                            ignoring: true,
                            child: Arcform3D(
                              nodes: arcformData.nodes,
                              edges: arcformData.edges,
                              phase: arcformData.phase,
                              skin: arcformData.skin,
                              showNebula: true,
                              enableLabels: false,
                              initialZoom: 0.5,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_outlined,
                                  color: kcPrimaryColor.withOpacity(0.7),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generating constellation...',
                                  style: TextStyle(
                                    color: kcPrimaryColor.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Full-screen Phase viewer - shared across Journal and Phase screens
class FullScreenPhaseViewer extends StatelessWidget {
  final Arcform3DData arcform;
  final GlobalKey _arcformRepaintBoundaryKey = GlobalKey();

  FullScreenPhaseViewer({super.key, required this.arcform});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text(arcform.title, style: heading1Style(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _showShareSheet(context, arcform),
            tooltip: 'Share Phase',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _arcformRepaintBoundaryKey,
        child: Arcform3D(
          nodes: arcform.nodes,
          edges: arcform.edges,
          phase: arcform.phase,
          skin: arcform.skin,
          showNebula: true,
          enableLabels: true,
          initialZoom: 1.2, // Zoomed in 1.5x from 0.8 for better initial view
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final canonicalPhase = arcform.phase.isEmpty
        ? 'Discovery'
        : arcform.phase.substring(0, 1).toUpperCase() + arcform.phase.substring(1).toLowerCase();
    final phaseDescription = PhaseColors.getPhaseDescription(canonicalPhase);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phase Info', style: heading2Style(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phase: ${arcform.phase}', style: heading3Style(context)),
              const SizedBox(height: 12),
              Text(arcform.content ?? '', style: bodyStyle(context).copyWith(fontSize: 13, fontStyle: FontStyle.italic)),
              if (phaseDescription.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('About this phase:', style: bodyStyle(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Text('$canonicalPhase: $phaseDescription', style: bodyStyle(context).copyWith(fontSize: 13, height: 1.35)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(BuildContext context, Arcform3DData arcform) async {
    final keywords = arcform.nodes.map((node) => node.label).toList();
    
    // Capture from a separate hidden widget with zoom settings for image generation
    // Use 1.6 (same as preview) - this was the previous setting that was just right
    // Labels disabled by default for privacy on public networks (can be enabled via toggle)
    final captureKey = GlobalKey();
    final captureWidget = RepaintBoundary(
      key: captureKey,
      child: Arcform3D(
        nodes: arcform.nodes,
        edges: arcform.edges,
        phase: arcform.phase,
        skin: arcform.skin,
        showNebula: true,
        enableLabels: false, // Hide labels by default for privacy
        initialZoom: 1.6, // Same as preview - previous setting that was just right
      ),
    );
    
    // Build the capture widget offscreen
    final captureContext = context;
    final overlay = Overlay.of(captureContext);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000, // Position offscreen
        top: -10000,
        child: SizedBox(
          width: 400,
          height: 400,
          child: captureWidget,
        ),
      ),
    );
    overlay.insert(overlayEntry);
    
    // Wait for widget to render
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Capture the Phase image from the hidden widget
    Uint8List? arcformImageBytes;
    try {
      final captureContext = captureKey.currentContext;
      if (captureContext != null) {
        final RenderRepaintBoundary? boundary = 
            captureContext.findRenderObject() as RenderRepaintBoundary?;
        
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          arcformImageBytes = byteData?.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Error capturing Phase before share: $e');
    } finally {
      // Remove the overlay entry
      overlayEntry.remove();
    }
    
    if (arcformImageBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture Phase image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Use ArcformShareCompositionScreen with pre-captured image
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArcformShareCompositionScreen(
            phase: arcform.phase,
            keywords: keywords,
            arcformId: arcform.id,
            preCapturedImage: arcformImageBytes,
            arcformData: arcform, // Pass arcform data for re-capturing with label settings
          ),
        ),
      );
    }
  }
}

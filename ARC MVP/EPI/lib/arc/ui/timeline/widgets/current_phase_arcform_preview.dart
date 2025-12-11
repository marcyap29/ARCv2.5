import 'package:flutter/material.dart';
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
import 'package:my_app/arc/arcform/share/arcform_share_models.dart';
import 'package:my_app/arc/arcform/share/arcform_share_sheet.dart';
import 'package:my_app/models/phase_models.dart';

/// Compact preview widget showing current phase Arcform visualization
/// Uses the same architecture as Insights->Phase->Arcform visualizations
/// Displays above timeline icons in the Timeline view
class CurrentPhaseArcformPreview extends StatefulWidget {
  const CurrentPhaseArcformPreview({super.key});

  @override
  State<CurrentPhaseArcformPreview> createState() => _CurrentPhaseArcformPreviewState();
}

class _CurrentPhaseArcformPreviewState extends State<CurrentPhaseArcformPreview> {
  @override
  Widget build(BuildContext context) {
    // Use the same SimplifiedArcformView3D component but extract just the first snapshot card
    // and display it in a compact format
    return _CompactArcformPreview();
  }
}

/// Compact preview that uses the same data loading as SimplifiedArcformView3D
class _CompactArcformPreview extends StatefulWidget {
  const _CompactArcformPreview();

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
    _loadSnapshots();
  }

  // Copy the exact same loading logic from SimplifiedArcformView3D
  Future<void> _loadSnapshots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current phase from phase regimes (same as SimplifiedArcformView3D)
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      String currentPhase;
      
      if (currentRegime != null) {
        final phaseName = currentRegime.label.toString().split('.').last;
        currentPhase = phaseName.isEmpty 
            ? 'Discovery' 
            : phaseName[0].toUpperCase() + phaseName.substring(1).toLowerCase();
      } else {
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
          final phaseName = sortedRegimes.first.label.toString().split('.').last;
          currentPhase = phaseName.isEmpty 
              ? 'Discovery' 
              : phaseName[0].toUpperCase() + phaseName.substring(1).toLowerCase();
        } else {
          currentPhase = 'Discovery';
        }
      }

      // Check if user has entries for this phase
      final isUserPhase = await _hasEntriesForPhase(currentPhase);

      // Generate arcform using SimplifiedArcformView3D's method
      // We need to access the private method, so we'll duplicate the logic
      final arcform = await _generatePhaseConstellation(currentPhase, isUserPhase: isUserPhase);

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
            _currentPhase = currentPhase;
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

  /// Calculate trend toward next phase (same logic as phase_analysis_view.dart)
  Future<void> _calculatePhaseTrend() async {
    try {
      final journalRepo = JournalRepository();
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime == null) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Get recent entries (last 10 days - matches regime minimum)
      final allEntries = journalRepo.getAllJournalEntriesSync();
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final recentEntries = allEntries
          .where((entry) => entry.createdAt.isAfter(tenDaysAgo))
          .toList();

      if (recentEntries.length < 3) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Count phases in recent entries
      final phaseCounts = <String, int>{};
      for (final entry in recentEntries) {
        final entryPhase = entry.computedPhase?.toLowerCase();
        if (entryPhase != null && entryPhase.isNotEmpty) {
          phaseCounts[entryPhase] = (phaseCounts[entryPhase] ?? 0) + 1;
        }
      }

      if (phaseCounts.isEmpty) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Current phase name normalized
      final currentPhaseName = currentRegime.label.toString().split('.').last.toLowerCase();

      // Find the most common phase that's NOT the current phase
      String? nextMostCommon;
      int nextMostCount = 0;
      for (final entry in phaseCounts.entries) {
        if (entry.key != currentPhaseName && entry.value > nextMostCount) {
          nextMostCount = entry.value;
          nextMostCommon = entry.key;
        }
      }

      if (nextMostCommon == null || nextMostCount == 0) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Calculate percentage: (entries with next phase) / (total recent entries) * 100
      final totalRecentWithPhase = phaseCounts.values.fold(0, (sum, c) => sum + c);
      final percent = ((nextMostCount / totalRecentWithPhase) * 100).round();

      // Only show trend if it's meaningful (> 15%)
      if (percent > 15) {
        _approachingPhase = nextMostCommon[0].toUpperCase() + nextMostCommon.substring(1);
        _trendPercent = percent;
      } else {
        _approachingPhase = null;
        _trendPercent = 0;
      }
      
      print('DEBUG: Phase trend - approaching: $_approachingPhase, percent: $_trendPercent%');
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
        height: 180,
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
        height: 180,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
      onTap: () {
        // Navigate directly to full-screen 3D Arcform viewer (same as clicking in Arcform Visualizations)
        if (arcformData != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullScreenPhaseViewer(arcform: arcformData),
            ),
          );
        }
      },
      child: Container(
        height: 180,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Increased top margin to prevent clipping with pinned calendar
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - same as SimplifiedArcformView3D's card header
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
                  Expanded(
                    child: Text(
                      _currentPhase ?? phaseHint,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: kcSecondaryTextColor,
                  ),
                ],
              ),
            ),
            // Arcform preview - fills remaining space
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
                            enableLabels: false, // Disable labels for compact preview
                            initialZoom: 0.5, // Compact zoom level (zoomed out further)
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
        // Change Phase button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OutlinedButton(
            onPressed: () => _showChangePhaseDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: kcPrimaryColor,
              backgroundColor: Colors.black,
              side: BorderSide(color: kcPrimaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Change Phase',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Phase Transition Readiness card (always shown)
        _buildPhaseTransitionReadinessCard(),
      ],
    );
  }

  Widget _buildPhaseTransitionReadinessCard() {
    final hasTrend = _approachingPhase != null && _trendPercent > 0;
    final phaseColor = hasTrend 
        ? _getPhaseColor(_approachingPhase!) 
        : kcSecondaryTextColor;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: phaseColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info button
          Row(
            children: [
              Icon(
                hasTrend ? Icons.trending_up : Icons.trending_flat,
                color: phaseColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phase Transition Readiness',
                  style: TextStyle(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showTransitionReadinessInfo(context),
                child: Icon(
                  Icons.info_outline,
                  color: kcSecondaryTextColor,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Trend text
          Text(
            hasTrend
                ? 'Your reflection patterns have shifted $_trendPercent% toward $_approachingPhase'
                : 'Your reflection patterns are stable in ${_currentPhase ?? "your current phase"}',
            style: TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Background bar (100%)
                Container(
                  height: 8,
                  width: double.infinity,
                  color: phaseColor.withOpacity(0.2),
                ),
                // Filled bar (trend percent) - show 0% if no trend
                if (_trendPercent > 0)
                  FractionallySizedBox(
                    widthFactor: _trendPercent / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: phaseColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Percentage label
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_trendPercent%',
              style: TextStyle(
                color: phaseColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransitionReadinessInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: kcPrimaryColor),
            const SizedBox(width: 8),
            Text(
              'Phase Transition Readiness',
              style: heading3Style(ctx).copyWith(color: kcPrimaryTextColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This indicator shows how your recent journal entries align with different phases.',
              style: bodyStyle(ctx).copyWith(color: kcPrimaryTextColor),
            ),
            const SizedBox(height: 12),
            Text(
              'Based on your last 10 days of entries, your reflection patterns suggest a trend toward a new phase.',
              style: bodyStyle(ctx).copyWith(color: kcSecondaryTextColor),
            ),
            const SizedBox(height: 12),
            Text(
              'A higher percentage indicates stronger alignment with the approaching phase.',
              style: captionStyle(ctx).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it', style: TextStyle(color: kcPrimaryColor)),
          ),
        ],
      ),
    );
  }

  void _showChangePhaseDialog(BuildContext context) {
    final phases = [
      'Discovery',
      'Expansion',
      'Transition',
      'Consolidation',
      'Recovery',
      'Breakthrough',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Change Phase',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will update the last 10 days\' phase regime',
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            ...phases.map((phase) => ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: _getPhaseColor(phase),
              ),
              title: Text(
                phase,
                style: TextStyle(
                  color: kcPrimaryTextColor,
                  fontWeight: _currentPhase?.toLowerCase() == phase.toLowerCase() 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
              trailing: _currentPhase?.toLowerCase() == phase.toLowerCase()
                  ? Icon(Icons.check, color: kcPrimaryColor)
                  : null,
              onTap: () async {
                Navigator.of(context).pop();
                await _changePhaseRegime(phase);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhaseRegime(String phaseName) async {
    try {
      // Convert phase name to PhaseLabel
      final phaseLabel = PhaseLabel.values.firstWhere(
        (label) => label.name.toLowerCase() == phaseName.toLowerCase(),
        orElse: () => PhaseLabel.consolidation,
      );

      // Initialize services
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Change the current phase
      await phaseRegimeService.changeCurrentPhase(phaseLabel, updateHashtags: true);

      // Refresh the snapshots
      await _loadSnapshots();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase changed to $phaseName'),
            backgroundColor: kcSuccessColor,
          ),
        );
      }
    } catch (e) {
      print('Error changing phase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change phase: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF7C3AED); // Purple
      case 'expansion':
        return const Color(0xFF059669); // Green
      case 'transition':
        return const Color(0xFFD97706); // Orange
      case 'consolidation':
        return const Color(0xFF2563EB); // Blue
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFFFBBF24); // Yellow
      default:
        return kcPrimaryColor;
    }
  }
}

/// Full-screen Phase viewer - shared across Journal and Phase screens
class FullScreenPhaseViewer extends StatelessWidget {
  final Arcform3DData arcform;

  const FullScreenPhaseViewer({super.key, required this.arcform});

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
      body: Arcform3D(
        nodes: arcform.nodes,
        edges: arcform.edges,
        phase: arcform.phase,
        skin: arcform.skin,
        showNebula: true,
        enableLabels: true,
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phase Info', style: heading2Style(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase: ${arcform.phase}'),
            const SizedBox(height: 16),
            const Text('About this Phase:'),
            Text(arcform.content ?? '', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
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

  void _showShareSheet(BuildContext context, Arcform3DData arcform) {
    final keywords = arcform.nodes.map((node) => node.label).toList();
    
    final payload = ArcformSharePayload(
      shareMode: ArcShareMode.social,
      arcformId: arcform.id,
      phase: arcform.phase,
      keywords: keywords,
    );

    showArcformShareSheet(
      context: context,
      payload: payload,
      fromView: 'arcform_view',
      arcformPreview: Arcform3D(
        nodes: arcform.nodes,
        edges: arcform.edges,
        phase: arcform.phase,
        skin: arcform.skin,
        showNebula: true,
        enableLabels: true,
      ),
    );
  }
}

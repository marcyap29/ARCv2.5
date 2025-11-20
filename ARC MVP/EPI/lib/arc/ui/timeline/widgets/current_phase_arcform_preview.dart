import 'package:flutter/material.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/keyword_aggregator.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Compact preview widget showing current phase Arcform visualization
/// Displays above timeline icons in the Timeline view
/// Uses the same data source as Insights->Phase->Arcform visualizations
class CurrentPhaseArcformPreview extends StatefulWidget {
  const CurrentPhaseArcformPreview({super.key});

  @override
  State<CurrentPhaseArcformPreview> createState() => _CurrentPhaseArcformPreviewState();
}

class _CurrentPhaseArcformPreviewState extends State<CurrentPhaseArcformPreview> {
  Arcform3DData? _arcformData;
  String? _currentPhase;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArcformData();
  }

  Future<void> _loadArcformData() async {
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
        currentPhase = currentRegime.label.toString().split('.').last;
      } else {
        // Get the most recent regime if no current ongoing regime
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
          currentPhase = sortedRegimes.first.label.toString().split('.').last;
        } else {
          currentPhase = 'Discovery';
        }
      }

      // Check if user has entries for this phase
      final isUserPhase = await _hasEntriesForPhase(currentPhase);

      // Generate arcform using the same method as SimplifiedArcformView3D
      final arcform = await _generatePhaseConstellation(currentPhase, isUserPhase: isUserPhase);

      if (mounted) {
        setState(() {
          _arcformData = arcform;
          _currentPhase = currentPhase;
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

  /// Check if user has journal entries for a given phase
  Future<bool> _hasEntriesForPhase(String phase) async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      
      if (allEntries.isEmpty) {
        return false;
      }
      
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
      
      // Find regime for this phase
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
          
          if (entriesInRegime.isNotEmpty) {
            return true;
          }
        }
      }
      
      // Special case for Discovery: check if there are entries before the first regime
      if (phase.toLowerCase() == 'discovery' && allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(allRegimes)..sort((a, b) => a.start.compareTo(b.start));
        final firstRegime = sortedRegimes.first;
        
        final entriesBeforeFirstRegime = allEntries
            .where((entry) => entry.createdAt.isBefore(firstRegime.start))
            .toList();
        
        if (entriesBeforeFirstRegime.isNotEmpty) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking entries for phase $phase: $e');
      return false;
    }
  }

  /// Get actual keywords from user's journal entries for their current phase
  /// Uses the same method as SimplifiedArcformView3D
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
        print('Error accessing phase regime data: $e');
        return _getHardcodedPhaseKeywords(phase);
      }
    } catch (e) {
      print('ERROR: Failed to load actual keywords for $phase: $e');
      return _getHardcodedPhaseKeywords(phase);
    }
  }

  /// Get hardcoded demo keywords for example/demo phases
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

  /// Generate phase constellation using the same method as SimplifiedArcformView3D
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

    if (_arcformData == null || _currentPhase == null) {
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

    return GestureDetector(
      onTap: () {
        // Navigate to Phase Analysis view (Insights->Phase->Arcform visualizations)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PhaseAnalysisView(),
          ),
        );
      },
      child: Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            // Header with phase name and expand icon
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: kcPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPhase!,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16, // Reduced from 24 to 16 (2/3 of original)
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
            // Arcform preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Arcform3D(
                    nodes: _arcformData!.nodes,
                    edges: _arcformData!.edges,
                    phase: _arcformData!.phase,
                    skin: _arcformData!.skin,
                    showNebula: true,
                    enableLabels: false,
                    initialZoom: 2.0, // Compact zoom level
                  ),
                ),
              ),
            ),
            // Phase elements info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  _buildInfoChip(
                    Icons.circle,
                    '${_arcformData!.nodes.length} Nodes',
                    context,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.link,
                    '${_arcformData!.edges.length} Edges',
                    context,
                  ),
                  const Spacer(),
                  Text(
                    'Tap to expand',
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: kcPrimaryColor,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: captionStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

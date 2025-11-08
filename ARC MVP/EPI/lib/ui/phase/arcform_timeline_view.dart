// lib/ui/phase/arcform_timeline_view.dart
// ARCForm Timeline - Shows historical ARCForms based on phase regimes

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/keyword_aggregator.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';

/// ARCForm Timeline View - Shows historical ARCForms for each phase regime
class ArcformTimelineView extends StatefulWidget {
  final PhaseIndex phaseIndex;
  
  const ArcformTimelineView({
    super.key,
    required this.phaseIndex,
  });

  @override
  State<ArcformTimelineView> createState() => _ArcformTimelineViewState();
}

class _ArcformTimelineViewState extends State<ArcformTimelineView> {
  final Map<String, Arcform3DData?> _arcformCache = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regimes = widget.phaseIndex.allRegimes;
    
    // Sort regimes by start date (oldest first)
    final sortedRegimes = List<PhaseRegime>.from(regimes)
      ..sort((a, b) => a.start.compareTo(b.start));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ARCForm Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedRegimes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No phase regimes found. Run Phase Analysis to generate ARCForm timeline.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedRegimes.length,
                  itemBuilder: (context, index) {
                    final regime = sortedRegimes[index];
                    return _buildArcformTimelineItem(theme, regime, index == sortedRegimes.length - 1);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArcformTimelineItem(ThemeData theme, PhaseRegime regime, bool isCurrent) {
    final phaseName = _getPhaseLabelName(regime.label);
    final color = _getPhaseColor(regime.label);
    final duration = regime.duration;
    
    return FutureBuilder<Arcform3DData?>(
      future: _getArcformForRegime(regime),
      builder: (context, snapshot) {
        final arcform = snapshot.data;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            color: color.withOpacity(0.05),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phase header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        phaseName.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'CURRENT',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Date range
                Text(
                  '${_formatDate(regime.start)} - ${regime.end != null ? _formatDate(regime.end!) : 'Ongoing'} (${duration.inDays} days)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                
                // ARCForm preview
                if (snapshot.connectionState == ConnectionState.waiting)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (arcform != null)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Arcform3D(
                        nodes: arcform.nodes,
                        edges: arcform.edges,
                        phase: arcform.phase,
                        skin: arcform.skin,
                        showNebula: true,
                        enableLabels: false,
                        initialZoom: 1.5,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'No ARCForm data available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                
                // Keywords preview
                if (arcform != null && arcform.nodes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: arcform.nodes.take(8).map((node) {
                      return Chip(
                        label: Text(
                          node.label,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                        backgroundColor: color.withOpacity(0.1),
                        side: BorderSide(color: color.withOpacity(0.3)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Arcform3DData?> _getArcformForRegime(PhaseRegime regime) async {
    final cacheKey = '${regime.id}_${regime.updatedAt.millisecondsSinceEpoch}';
    
    if (_arcformCache.containsKey(cacheKey)) {
      return _arcformCache[cacheKey];
    }

    try {
      // Get keywords for this phase regime
      final keywords = await _getKeywordsForRegime(regime);
      
      if (keywords.isEmpty) {
        _arcformCache[cacheKey] = null;
        return null;
      }

      // Create skin for this phase
      final phaseName = _getPhaseLabelName(regime.label);
      final skin = ArcformSkin.forUser('user', 'regime_${regime.id}');

      // Generate 3D layout
      final nodes = layout3D(
        keywords: keywords,
        phase: phaseName,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in keywords) kw: 0.0},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: phaseName,
        maxEdgesPerNode: 4,
        maxDistance: 1.4,
      );

      final arcform = Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: phaseName,
        skin: skin,
        title: '$phaseName Constellation',
        content: 'ARCForm for ${phaseName} phase (${_formatDate(regime.start)} - ${regime.end != null ? _formatDate(regime.end!) : 'ongoing'})',
        createdAt: regime.start,
        id: 'regime_${regime.id}',
      );

      _arcformCache[cacheKey] = arcform;
      return arcform;
    } catch (e) {
      print('ERROR: Failed to generate ARCForm for regime ${regime.id}: $e');
      _arcformCache[cacheKey] = null;
      return null;
    }
  }

  Future<List<String>> _getKeywordsForRegime(PhaseRegime regime) async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      
      // Get entries within this regime's date range
      final regimeStart = regime.start;
      final regimeEnd = regime.end ?? DateTime.now();
      
      final regimeEntries = allEntries
          .where((entry) => 
              entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) && 
              entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1))))
          .toList();
      
      if (regimeEntries.isEmpty) {
        print('DEBUG: No entries found for regime ${_getPhaseLabelName(regime.label)}, using hardcoded keywords');
        return _getHardcodedPhaseKeywords(_getPhaseLabelName(regime.label));
      }

      // Get all keywords from entries in this regime
      final allKeywords = <String>[];
      for (final entry in regimeEntries) {
        allKeywords.addAll(entry.keywords);
      }

      // Count keyword frequency
      final keywordCounts = <String, int>{};
      for (final keyword in allKeywords) {
        keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
      }

      // Sort by frequency and get top keywords
      final sortedKeywords = keywordCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top 15-20 keywords (most popular from this phase)
      final topKeywords = sortedKeywords
          .take(20)
          .map((e) => e.key)
          .where((kw) => kw.isNotEmpty)
          .toList();

      print('DEBUG: Found ${topKeywords.length} top keywords for ${_getPhaseLabelName(regime.label)} phase');
      
      // Also get aggregated keywords from entry content
      final journalTexts = regimeEntries.map((e) => e.content).toList();
      final aggregatedKeywords = KeywordAggregator.getTopAggregatedKeywords(
        journalTexts,
        topN: 10,
      );

      // Combine and deduplicate
      final combinedKeywords = <String>[];
      combinedKeywords.addAll(topKeywords);
      combinedKeywords.addAll(aggregatedKeywords);
      
      final uniqueKeywords = combinedKeywords.toSet().toList();
      
      return uniqueKeywords.take(20).toList();
    } catch (e) {
      print('ERROR: Failed to get keywords for regime: $e');
      return [];
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
          'healing', 'recovery', 'restoration', 'renewal', 'rebirth',
          'gentleness', 'self-care', 'compassion', 'patience', 'acceptance',
          'forgiveness', 'release', 'letting go', 'peace', 'tranquility',
          'serenity', 'calm', 'stillness', 'rest', 'nurturing'
        ];
      case 'breakthrough':
        return [
          'breakthrough', 'revelation', 'epiphany', 'awakening', 'enlightenment',
          'transcendence', 'liberation', 'freedom', 'clarity', 'understanding',
          'wisdom', 'transformation', 'evolution', 'ascension', 'elevation',
          'illumination', 'realization', 'insight', 'clarity', 'vision'
        ];
      default:
        return [
          'balance', 'harmony', 'equilibrium', 'stability', 'peace',
          'contentment', 'satisfaction', 'well-being', 'health', 'vitality',
          'growth', 'progress', 'development', 'evolution', 'transformation'
        ];
    }
  }

  String _getPhaseLabelName(PhaseLabel label) {
    return label.toString().split('.').last;
  }

  Color _getPhaseColor(PhaseLabel label) {
    const colors = {
      PhaseLabel.discovery: Colors.blue,
      PhaseLabel.expansion: Colors.green,
      PhaseLabel.transition: Colors.orange,
      PhaseLabel.consolidation: Colors.purple,
      PhaseLabel.recovery: Colors.red,
      PhaseLabel.breakthrough: Colors.amber,
    };
    return colors[label] ?? Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}


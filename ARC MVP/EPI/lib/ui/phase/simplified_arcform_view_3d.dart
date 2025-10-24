// lib/ui/phase/simplified_arcform_view_3d.dart
// 3D Constellation ARCForms view - updated with 3D renderer

import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arcform/models/arcform_models.dart';
import '../../arcform/layouts/layouts_3d.dart';
import '../../arcform/render/arcform_renderer_3d.dart';
import '../../arcform/util/seeded.dart';
import '../../services/patterns_data_service.dart';
import '../../services/keyword_aggregator.dart';
import '../../arc/core/journal_repository.dart';

/// Simplified ARCForms view with 3D constellation renderer
class SimplifiedArcformView3D extends StatefulWidget {
  final String? currentPhase;
  
  const SimplifiedArcformView3D({
    super.key,
    this.currentPhase,
  });

  @override
  State<SimplifiedArcformView3D> createState() => _SimplifiedArcformView3DState();
}

class _SimplifiedArcformView3DState extends State<SimplifiedArcformView3D> {
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;
  Set<String> _userExperiencedPhases = {}; // Track phases user has been in

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  void _loadSnapshots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Discover which phases the user has experienced
      await _discoverUserPhases();

      // Generate a single constellation for the current phase (user's actual phase)
      final currentPhase = widget.currentPhase ?? 'Discovery';
      final constellation = await _generatePhaseConstellation(currentPhase, isUserPhase: true);

      setState(() {
        if (constellation != null) {
          // Convert Arcform3DData to the expected snapshot format
          final snapshot = {
            'id': constellation.id,
            'title': constellation.title,
            'phaseHint': constellation.phase,
            'keywords': constellation.nodes.map((node) => node.label).toList(),
            'createdAt': constellation.createdAt.toIso8601String(),
            'content': constellation.content,
            'arcformData': constellation.toJson(), // Store the full 3D data
          };
          _snapshots = [snapshot];
        } else {
          _snapshots = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading constellation: $e');
      setState(() {
        _snapshots = [];
        _isLoading = false;
      });
    }
  }

  /// Discover which phases the user has actually experienced from their journal entries
  Future<void> _discoverUserPhases() async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();

      // Extract unique phases from journal entries
      final phases = allEntries
          .where((entry) => entry.phase != null && entry.phase!.isNotEmpty)
          .map((entry) => entry.phase!)
          .toSet();

      // Also add current phase
      if (widget.currentPhase != null) {
        phases.add(widget.currentPhase!);
      }

      _userExperiencedPhases = phases.map((p) => p.toLowerCase()).toSet();

      print('DEBUG: User has experienced ${_userExperiencedPhases.length} phases: $_userExperiencedPhases');
    } catch (e) {
      print('ERROR: Failed to discover user phases: $e');
      _userExperiencedPhases = {};
    }
  }

  void refreshSnapshots() {
    _loadSnapshots();
  }

  void updatePhase(String? newPhase) {
    if (newPhase != widget.currentPhase) {
      _loadSnapshots();
    }
  }

  @override
  void didUpdateWidget(SimplifiedArcformView3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPhase != widget.currentPhase) {
      _loadSnapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
        ),
      );
    }

    if (_snapshots.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _snapshots.length,
      itemBuilder: (context, index) {
        return _buildSnapshotCard(_snapshots[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: kcPrimaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Constellation Visualization',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to generate constellation for your current phase. This may be due to insufficient phase data.',
              textAlign: TextAlign.center,
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Phase Analysis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(Map<String, dynamic> snapshot) {
    final keywords = List<String>.from(snapshot['keywords'] ?? []);
    final phaseHint = snapshot['phaseHint'] ?? 'Discovery';
    final createdAt = DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now();
    
    // Generate 3D constellation data
    final arcformData = _generateArcformData(snapshot, phaseHint);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: kcSurfaceColor,
      child: InkWell(
        onTap: () {
          // Go directly to full-screen 3D view
          _showFullScreenArcform(phaseHint);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with constellation icon
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: kcPrimaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                  child: Text(
                    '$phaseHint Phase',
                    style: heading3Style(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kcPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kcPrimaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      phaseHint.toUpperCase(),
                      style: TextStyle(
                        color: kcPrimaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 3D Constellation Preview
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kcBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: arcformData != null
                      ? IgnorePointer(
                          // Prevent touch events from triggering any animation in preview
                          child: Arcform3D(
                            nodes: arcformData.nodes,
                            edges: arcformData.edges,
                            phase: arcformData.phase,
                            skin: arcformData.skin,
                            showNebula: true,
                            enableLabels: true, // Enable keyword labels
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
                              Text(
                                '${keywords.length} stars',
                                style: TextStyle(
                                  color: kcSecondaryTextColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Keywords as constellation points
              if (keywords.isNotEmpty) ...[
                Text(
                  'Phase Elements:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: kcSecondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: keywords.take(6).map((keyword) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kcPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kcPrimaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      keyword,
                      style: TextStyle(
                        color: kcPrimaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
                
                if (keywords.length > 6) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${keywords.length - 6} more points',
                    style: TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // OTHER PHASE SHAPES PREVIEW
              _buildOtherPhasesSection(phaseHint),

              const SizedBox(height: 16),

              // Metadata
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: kcSecondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to view 3D',
                    style: TextStyle(
                      color: kcPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Arcform3DData? _generateArcformData(Map<String, dynamic> snapshot, String phase) {
    try {
      // Check if we have stored 3D data
      if (snapshot['arcformData'] != null) {
        final arcformJson = snapshot['arcformData'] as Map<String, dynamic>;
        return Arcform3DData.fromJson(arcformJson);
      }
      
      // Fallback: generate from keywords if no 3D data
      final keywords = List<String>.from(snapshot['keywords'] ?? []);
      if (keywords.isEmpty) return null;

      final skin = ArcformSkin.forUser('user', snapshot['id']?.toString() ?? 'default');
      
      // Generate 3D layout
      final nodes = layout3D(
        keywords: keywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.5 + (kw.length / 20.0)},
        keywordValences: {for (var kw in keywords) kw: _estimateValence(kw)},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
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

  double _estimateValence(String keyword) {
    // Simple valence estimation based on keyword content
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
      // Create skin for this phase
      final skin = ArcformSkin.forUser('user', 'phase_$phase');

      // Get keywords: actual from journal if this is user's phase, hardcoded if demo/example
      final List<String> keywords;
      if (isUserPhase) {
        // User's actual phase - use real keywords from journal entries
        keywords = await _getActualPhaseKeywords(phase);
      } else {
        // Demo/example phase - use hardcoded keywords
        keywords = _getHardcodedPhaseKeywords(phase);
      }

      // Generate 3D layout
      final nodes = layout3D(
        keywords: keywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: kw.isEmpty ? 0.0 : 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in keywords) kw: kw.isEmpty ? 0.0 : _getPhaseValence(kw, phase)},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
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

    /// Get actual keywords from user's journal entries for their current phase
    Future<List<String>> _getActualPhaseKeywords(String phase) async {
        const int targetNodeCount = 20; // Maintain helix shape with 20 nodes

        try {
          // Get actual keywords from user's journal entries
          final journalRepo = JournalRepository();
          final patternsService = PatternsDataService(journalRepository: journalRepo);

          // Get patterns data (emotion keywords from user's actual journal)
          final (nodes, _) = await patternsService.getPatternsData(
            maxNodes: 50, // Get more than we need to have options
            minCoOccurrenceWeight: 0.3,
          );

          // Get emotion keywords that match this phase
          final emotionKeywords = nodes
              .where((node) => node.phase?.toLowerCase() == phase.toLowerCase() || node.phase == null)
              .map((node) => node.label)
              .toList();

          // Get aggregated concept keywords from journal entries
          final allEntries = journalRepo.getAllJournalEntriesSync();
          final journalTexts = allEntries
              .where((entry) => entry.phase?.toLowerCase() == phase.toLowerCase() || phase.toLowerCase() == 'discovery')
              .map((entry) => entry.content)
              .toList();

          final aggregatedKeywords = KeywordAggregator.getTopAggregatedKeywords(
            journalTexts,
            topN: 10, // Get top 10 concept keywords
          );

          // Combine emotion keywords and aggregated concept keywords
          final allKeywords = <String>[];
          allKeywords.addAll(emotionKeywords);
          allKeywords.addAll(aggregatedKeywords);

          // Remove duplicates and take up to targetNodeCount
          final uniqueKeywords = allKeywords.toSet().take(targetNodeCount).toList();

          print('DEBUG: Found ${emotionKeywords.length} emotion keywords and ${aggregatedKeywords.length} concept keywords for user\'s $phase phase');
          print('DEBUG: Total unique keywords: ${uniqueKeywords.length}');

          // If we have some keywords but not enough, fill remaining with blanks
          if (uniqueKeywords.isNotEmpty) {
            final keywordsWithBlanks = List<String>.from(uniqueKeywords);

            // Add empty strings for blank nodes to maintain total count of 20
            while (keywordsWithBlanks.length < targetNodeCount) {
              keywordsWithBlanks.add(''); // Blank node
            }

            print('DEBUG: Returning ${keywordsWithBlanks.length} total nodes (${uniqueKeywords.length} with keywords, ${keywordsWithBlanks.length - uniqueKeywords.length} blank)');
            return keywordsWithBlanks;
          }

          // If no actual keywords found, return all blank nodes but maintain the count
          print('DEBUG: No actual keywords found for $phase phase, using ${targetNodeCount} blank nodes');
          return List.generate(targetNodeCount, (_) => '');

        } catch (e) {
          print('ERROR: Failed to load actual keywords for $phase: $e');
          // On error, return blank nodes to maintain helix shape
          return List.generate(20, (_) => '');
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
          'energy', 'strength', 'resilience', 'adaptability', 'flexibility',
          'growth', 'learning', 'development', 'wisdom', 'understanding'
        ];
    }
  }

  double _getPhaseValence(String keyword, String phase) {
    final lower = keyword.toLowerCase();
    
    // Phase-specific valence mapping
    switch (phase.toLowerCase()) {
      case 'discovery':
        if (lower.contains('growth') || lower.contains('learning') || lower.contains('curiosity') ||
            lower.contains('exploration') || lower.contains('wonder') || lower.contains('creativity') ||
            lower.contains('innovation') || lower.contains('breakthrough') || lower.contains('excitement')) {
          return 0.6 + (keyword.length / 50.0);
        }
        return 0.2 + (keyword.length / 60.0);
        
      case 'exploration':
      case 'expansion':
        if (lower.contains('success') || lower.contains('achievement') || lower.contains('progress') ||
            lower.contains('confidence') || lower.contains('strength') || lower.contains('power') ||
            lower.contains('ambition') || lower.contains('drive') || lower.contains('leadership')) {
          return 0.7 + (keyword.length / 40.0);
        }
        return 0.3 + (keyword.length / 50.0);
        
      case 'transition':
        if (lower.contains('hope') || lower.contains('anticipation') || lower.contains('new beginnings') ||
            lower.contains('balance') || lower.contains('harmony') || lower.contains('trust')) {
          return 0.3 + (keyword.length / 60.0);
        } else if (lower.contains('uncertainty') || lower.contains('anxiety') || lower.contains('letting go')) {
          return -0.2 - (keyword.length / 80.0);
        }
        return 0.0;
        
      case 'consolidation':
        if (lower.contains('stability') || lower.contains('mastery') || lower.contains('wisdom') ||
            lower.contains('peace') || lower.contains('contentment') || lower.contains('fulfillment') ||
            lower.contains('gratitude') || lower.contains('celebration') || lower.contains('joy')) {
          return 0.8 + (keyword.length / 45.0);
        }
        return 0.4 + (keyword.length / 55.0);
        
      case 'recovery':
        if (lower.contains('healing') || lower.contains('renewal') || lower.contains('gentleness') ||
            lower.contains('compassion') || lower.contains('acceptance') || lower.contains('forgiveness') ||
            lower.contains('peace') || lower.contains('serenity') || lower.contains('nurturing')) {
          return 0.5 + (keyword.length / 50.0);
        }
        return 0.1 + (keyword.length / 70.0);
        
      case 'breakthrough':
        if (lower.contains('breakthrough') || lower.contains('revelation') || lower.contains('epiphany') ||
            lower.contains('awakening') || lower.contains('enlightenment') || lower.contains('transcendence') ||
            lower.contains('liberation') || lower.contains('freedom') || lower.contains('illumination')) {
          return 0.9 + (keyword.length / 35.0);
        }
        return 0.6 + (keyword.length / 45.0);
        
      default:
        if (lower.contains('balance') || lower.contains('harmony') || lower.contains('peace') ||
            lower.contains('contentment') || lower.contains('well-being') || lower.contains('growth')) {
          return 0.4 + (keyword.length / 50.0);
        }
        return 0.0;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  /// Show full-screen 3D ARCForm viewer for a specific phase
  void _showFullScreenArcform(String phase) async {
    // Check if this is a phase the user has experienced (current OR past phases)
    final isUserPhase = _userExperiencedPhases.contains(phase.toLowerCase());

    print('DEBUG: Viewing $phase phase - isUserPhase: $isUserPhase (experienced phases: $_userExperiencedPhases)');

    // Generate constellation data for this phase
    final arcform = await _generatePhaseConstellation(phase, isUserPhase: isUserPhase);

    if (arcform == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate constellation for $phase phase')),
        );
      }
      return;
    }

    // Navigate directly to full-screen viewer
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenArcformViewer(arcform: arcform),
        ),
      );
    }
  }

  /// Build section showing other phase shapes as examples
  Widget _buildOtherPhasesSection(String currentPhase) {
    // Get list of other phases to show (exclude current phase)
    final allPhases = [
      'Discovery',
      'Expansion',
      'Transition',
      'Consolidation',
      'Recovery',
      'Breakthrough',
    ];

    final otherPhases = allPhases
        .where((phase) => phase.toLowerCase() != currentPhase.toLowerCase())
        .toList();

    if (otherPhases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other Phase Shapes:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: kcSecondaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: otherPhases.map((phase) => _buildPhasePreviewChip(phase)).toList(),
        ),
      ],
    );
  }

  /// Build a small chip showing a phase preview
  Widget _buildPhasePreviewChip(String phase) {
    return GestureDetector(
      onTap: () {
        // Navigate to this phase's full 3D view
        _showFullScreenArcform(phase);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kcBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phase icon (different for each phase type)
            Icon(
              _getPhaseIcon(phase),
              color: kcPrimaryColor.withOpacity(0.7),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              phase,
              style: TextStyle(
                color: kcPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for each phase type
  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.air;
      case 'transition':
        return Icons.shuffle;
      case 'consolidation':
        return Icons.verified;
      case 'recovery':
        return Icons.spa;
      case 'breakthrough':
        return Icons.auto_awesome;
      default:
        return Icons.auto_awesome_outlined;
    }
  }
}

/// Full-screen ARCForm viewer
class _FullScreenArcformViewer extends StatelessWidget {
  final Arcform3DData arcform;

  const _FullScreenArcformViewer({required this.arcform});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text(arcform.title, style: heading1Style(context)),
        actions: [
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
        title: Text('ARCForm Info', style: heading2Style(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase: ${arcform.phase}'),
            Text('Nodes: ${arcform.nodes.length}'),
            Text('Edges: ${arcform.edges.length}'),
            const SizedBox(height: 16),
            const Text('About this ARCForm:'),
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
}

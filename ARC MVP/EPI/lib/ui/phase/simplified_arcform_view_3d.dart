// lib/ui/phase/simplified_arcform_view_3d.dart
// 3D Constellation ARCForms view - updated with 3D renderer

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arcform/models/arcform_models.dart';
import '../../arcform/layouts/layouts_3d.dart';
import '../../arcform/render/arcform_renderer_3d.dart';
import '../../arcform/util/seeded.dart';
import 'phase_arcform_3d_screen.dart';

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
      // Generate a single constellation for the current phase
      final currentPhase = widget.currentPhase ?? 'Discovery';
      final constellation = _generatePhaseConstellation(currentPhase);
      
      setState(() {
        _snapshots = constellation != null ? [constellation.toJson()] : [];
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
    final title = snapshot['title'] ?? 'Untitled Constellation';
    
    // Generate 3D constellation data
    final arcformData = _generateArcformData(snapshot, phaseHint);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: kcSurfaceColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PhaseArcform3DScreen(
                phase: phaseHint,
                title: 'Constellation View',
              ),
            ),
          );
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
                    '$phaseHint Constellation',
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
                      ? Arcform3D(
                          nodes: arcformData.nodes,
                          edges: arcformData.edges,
                          phase: arcformData.phase,
                          skin: arcformData.skin,
                          showNebula: true,
                          enableLabels: false,
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

  Arcform3DData? _generatePhaseConstellation(String phase) {
    try {
      // Create skin for this phase
      final skin = ArcformSkin.forUser('user', 'phase_$phase');
      
      // Generate phase-specific keywords and constellation
      final keywords = _getPhaseKeywords(phase);
      
      // Generate 3D layout
      final nodes = layout3D(
        keywords: keywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in keywords) kw: _getPhaseValence(kw, phase)},
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
        content: 'A beautiful 3D constellation representing your current $phase phase',
        createdAt: DateTime.now(),
        id: 'phase_${phase.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      print('Error generating phase constellation for $phase: $e');
      return null;
    }
  }

  List<String> _getPhaseKeywords(String phase) {
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
}

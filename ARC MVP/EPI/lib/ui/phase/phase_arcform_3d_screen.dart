// lib/ui/phase/phase_arcform_3d_screen.dart
// Integration screen for 3D Constellation ARCForms in Phase Analysis

import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arcform/models/arcform_models.dart';
import '../../arcform/layouts/layouts_3d.dart';
import '../../arcform/render/arcform_renderer_3d.dart';
import '../../arcform/util/seeded.dart';
import '../../arc/core/journal_repository.dart';
import '../../models/journal_entry_model.dart';

/// Full-screen 3D Constellation ARCForm viewer
class PhaseArcform3DScreen extends StatefulWidget {
  final String? phase;
  final String? title;

  const PhaseArcform3DScreen({
    super.key,
    this.phase,
    this.title,
  });

  @override
  State<PhaseArcform3DScreen> createState() => _PhaseArcform3DScreenState();
}

class _PhaseArcform3DScreenState extends State<PhaseArcform3DScreen> {
  List<Arcform3DData> _arcforms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArcforms();
  }

  Future<void> _loadArcforms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get the current phase from the most recent phase regime
      final currentPhase = widget.phase ?? 'Discovery';
      
      // Generate ONE constellation for the current phase
      final arcform = _generatePhaseConstellation(currentPhase);

      setState(() {
        _arcforms = arcform != null ? [arcform] : [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        // Discovery phase tends to be more positive and energetic
        if (lower.contains('growth') || lower.contains('learning') || lower.contains('curiosity') ||
            lower.contains('exploration') || lower.contains('wonder') || lower.contains('creativity') ||
            lower.contains('innovation') || lower.contains('breakthrough') || lower.contains('excitement')) {
          return 0.6 + (keyword.length / 50.0);
        }
        return 0.2 + (keyword.length / 60.0);
        
      case 'exploration':
      case 'expansion':
        // Expansion phase is very positive and confident
        if (lower.contains('success') || lower.contains('achievement') || lower.contains('progress') ||
            lower.contains('confidence') || lower.contains('strength') || lower.contains('power') ||
            lower.contains('ambition') || lower.contains('drive') || lower.contains('leadership')) {
          return 0.7 + (keyword.length / 40.0);
        }
        return 0.3 + (keyword.length / 50.0);
        
      case 'transition':
        // Transition phase is more neutral with some uncertainty
        if (lower.contains('hope') || lower.contains('anticipation') || lower.contains('new beginnings') ||
            lower.contains('balance') || lower.contains('harmony') || lower.contains('trust')) {
          return 0.3 + (keyword.length / 60.0);
        } else if (lower.contains('uncertainty') || lower.contains('anxiety') || lower.contains('letting go')) {
          return -0.2 - (keyword.length / 80.0);
        }
        return 0.0;
        
      case 'consolidation':
        // Consolidation phase is very positive and peaceful
        if (lower.contains('stability') || lower.contains('mastery') || lower.contains('wisdom') ||
            lower.contains('peace') || lower.contains('contentment') || lower.contains('fulfillment') ||
            lower.contains('gratitude') || lower.contains('celebration') || lower.contains('joy')) {
          return 0.8 + (keyword.length / 45.0);
        }
        return 0.4 + (keyword.length / 55.0);
        
      case 'recovery':
        // Recovery phase is gentle and healing-focused
        if (lower.contains('healing') || lower.contains('renewal') || lower.contains('gentleness') ||
            lower.contains('compassion') || lower.contains('acceptance') || lower.contains('forgiveness') ||
            lower.contains('peace') || lower.contains('serenity') || lower.contains('nurturing')) {
          return 0.5 + (keyword.length / 50.0);
        }
        return 0.1 + (keyword.length / 70.0);
        
      case 'breakthrough':
        // Breakthrough phase is highly positive and transformative
        if (lower.contains('breakthrough') || lower.contains('revelation') || lower.contains('epiphany') ||
            lower.contains('awakening') || lower.contains('enlightenment') || lower.contains('transcendence') ||
            lower.contains('liberation') || lower.contains('freedom') || lower.contains('illumination')) {
          return 0.9 + (keyword.length / 35.0);
        }
        return 0.6 + (keyword.length / 45.0);
        
      default:
        // Default neutral to positive
        if (lower.contains('balance') || lower.contains('harmony') || lower.contains('peace') ||
            lower.contains('contentment') || lower.contains('well-being') || lower.contains('growth')) {
          return 0.4 + (keyword.length / 50.0);
        }
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text(
          widget.title ?? '3D Constellation',
          style: heading1Style(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: _loadArcforms,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading ARCForms', style: heading2Style(context)),
            const SizedBox(height: 8),
            Text(_error!, style: bodyStyle(context)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadArcforms,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_arcforms.isEmpty) {
      return _buildEmptyState();
    }

    return _buildArcformList();
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
              'No Constellation Visualizations',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to generate constellation for ${widget.phase ?? 'current'} phase',
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

  Widget _buildArcformList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _arcforms.length,
      itemBuilder: (context, index) {
        final arcform = _arcforms[index];
        return _buildArcformCard(arcform);
      },
    );
  }

  Widget _buildArcformCard(Arcform3DData arcform) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showArcformViewer(arcform),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: kcPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      arcform.title,
                      style: heading3Style(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kcPrimaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      arcform.phase.toUpperCase(),
                      style: TextStyle(
                        color: kcPrimaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 3D Preview placeholder
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kcBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
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
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Metadata
              Row(
                children: [
                  _buildMetadataChip('Nodes', '${arcform.nodes.length}', kcSecondaryColor),
                  const SizedBox(width: 8),
                  _buildMetadataChip('Edges', '${arcform.edges.length}', kcAccentColor),
                  const SizedBox(width: 8),
                  _buildMetadataChip('Created', _formatDate(arcform.createdAt), kcSuccessColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showArcformViewer(Arcform3DData arcform) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ArcformViewerScreen(arcform: arcform),
      ),
    );
  }
}

/// Full-screen ARCForm viewer
class _ArcformViewerScreen extends StatelessWidget {
  final Arcform3DData arcform;

  const _ArcformViewerScreen({required this.arcform});

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
        title: Text('Constellation Info', style: heading2Style(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase: ${arcform.phase}'),
            Text('Nodes: ${arcform.nodes.length}'),
            Text('Edges: ${arcform.edges.length}'),
            Text('Created: ${arcform.createdAt.toString().split(' ')[0]}'),
            const SizedBox(height: 16),
            const Text('Controls:'),
            const Text('• Drag to rotate'),
            const Text('• Pinch to zoom'),
            const Text('• Tap nodes for details'),
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

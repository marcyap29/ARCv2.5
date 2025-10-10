import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../arcform_mvp_implementation.dart';
import '../services/emotional_valence_service.dart';
import 'constellation_layout_service.dart';
import 'constellation_painter.dart';

/// Keyword score model for constellation rendering
class KeywordScore {
  final String text;
  final double score;
  final double sentiment;

  const KeywordScore({
    required this.text,
    required this.score,
    required this.sentiment,
  });

  @override
  String toString() => 'KeywordScore(text: $text, score: $score, sentiment: $sentiment)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordScore &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          score == other.score &&
          sentiment == other.sentiment;

  @override
  int get hashCode => text.hashCode ^ score.hashCode ^ sentiment.hashCode;
}

/// Node model for constellation layout
class ConstellationNode {
  final Offset pos;
  final KeywordScore data;
  final double radius;
  final Color color;
  final String id;

  const ConstellationNode({
    required this.pos,
    required this.data,
    required this.radius,
    required this.color,
    required this.id,
  });

  @override
  String toString() => 'ConstellationNode(id: $id, pos: $pos, radius: $radius)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstellationNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pos == other.pos &&
          radius == other.radius &&
          color == other.color;

  @override
  int get hashCode => id.hashCode ^ pos.hashCode ^ radius.hashCode ^ color.hashCode;
}

/// Edge model for constellation connections
class ConstellationEdge {
  final int a;
  final int b;
  final double weight;

  const ConstellationEdge({
    required this.a,
    required this.b,
    required this.weight,
  });

  @override
  String toString() => 'ConstellationEdge($a -> $b, weight: $weight)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstellationEdge &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b &&
          weight == other.weight;

  @override
  int get hashCode => a.hashCode ^ b.hashCode ^ weight.hashCode;
}

/// Emotion palette for constellation colors
class EmotionPalette {
  final List<Color> primaryColors;
  final Color neutralColor;
  final Color backgroundColor;

  const EmotionPalette({
    required this.primaryColors,
    required this.neutralColor,
    required this.backgroundColor,
  });

  static const EmotionPalette defaultPalette = EmotionPalette(
    primaryColors: [
      Color(0xFF4F46E5), // Primary blue
      Color(0xFF7C3AED), // Purple
      Color(0xFFD1B3FF), // Light purple
      Color(0xFF6BE3A0), // Green
      Color(0xFFF7D774), // Yellow
      Color(0xFFFF6B6B), // Red
      Color(0xFFFF8E53), // Orange
      Color(0xFF4ECDC4), // Teal
    ],
    neutralColor: Color(0xFFD1B3FF),
    backgroundColor: Color(0xFF0A0A0F),
  );
}

/// ATLAS phase enum for constellation rendering
enum AtlasPhase {
  discovery,    // Spiral
  expansion,    // Flower
  transition,   // Branch
  consolidation, // Weave
  recovery,     // Glow Core
  breakthrough, // Fractal
}

/// Constellation Arcform Renderer - Main widget for constellation visualization
class ConstellationArcformRenderer extends StatefulWidget {
  final AtlasPhase phase;
  final List<KeywordScore> keywords;
  final EmotionPalette palette;
  final int seed;
  final bool reducedMotion;
  final bool showLabels;
  final double density;
  final double lineOpacity;
  final double glowIntensity;
  final Function(String)? onNodeTapped;
  final Function()? onExport;

  const ConstellationArcformRenderer({
    super.key,
    required this.phase,
    required this.keywords,
    required this.palette,
    required this.seed,
    this.reducedMotion = false,
    this.showLabels = true,
    this.density = 0.6,
    this.lineOpacity = 0.25,
    this.glowIntensity = 0.7,
    this.onNodeTapped,
    this.onExport,
  });

  @override
  State<ConstellationArcformRenderer> createState() => _ConstellationArcformRendererState();
}

class _ConstellationArcformRendererState extends State<ConstellationArcformRenderer>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _fadeInController;
  late AnimationController _selectionPulseController;
  
  final ConstellationLayoutService _layoutService = ConstellationLayoutService();
  final EmotionalValenceService _emotionalService = EmotionalValenceService();
  
  List<ConstellationNode> _nodes = [];
  List<ConstellationEdge> _edges = [];
  String? _selectedNodeId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize twinkle animation
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    if (!widget.reducedMotion) {
      _twinkleController.repeat(reverse: true);
    }
    
    // Initialize fade-in animation
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Initialize selection pulse animation
    _selectionPulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Generate constellation layout
    _generateConstellation();
    
    // Start fade-in animation
    _fadeInController.forward();
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _fadeInController.dispose();
    _selectionPulseController.dispose();
    super.dispose();
  }

  void _generateConstellation() {
    try {
      // Validate inputs
      if (widget.keywords.isEmpty) {
        print('WARNING: No keywords provided for constellation');
        _nodes = [];
        _edges = [];
        _isInitialized = true;
        return;
      }
      
      // Generate nodes using layout service
      _nodes = _layoutService.placeStars(
        widget.phase,
        widget.keywords,
        widget.seed,
        widget.palette,
        _emotionalService,
      );
      
      // Generate edges using layout service
      _edges = _layoutService.weaveConstellation(
        _nodes,
        widget.phase,
        widget.seed,
      );
      
      _isInitialized = true;
      print('DEBUG: Generated ${_nodes.length} nodes and ${_edges.length} edges');
    } catch (e) {
      print('ERROR: Failed to generate constellation: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      // Fallback to empty constellation
      _nodes = [];
      _edges = [];
      _isInitialized = true;
    }
  }

  void _handleNodeTapped(String nodeId) {
    if (widget.onNodeTapped == null) return;
    
    setState(() {
      _selectedNodeId = _selectedNodeId == nodeId ? null : nodeId;
    });
    
    if (_selectedNodeId != null) {
      _selectionPulseController.forward().then((_) {
        _selectionPulseController.reverse();
      });
    }
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    widget.onNodeTapped!(nodeId);
  }

  void _handleDoubleTap() {
    setState(() {
      _selectedNodeId = null;
    });
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void didUpdateWidget(ConstellationArcformRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Regenerate constellation if phase or keywords changed
    if (oldWidget.phase != widget.phase || 
        oldWidget.keywords != widget.keywords ||
        oldWidget.seed != widget.seed) {
      print('DEBUG: Constellation widget updated, regenerating...');
      _generateConstellation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD1B3FF),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.palette.backgroundColor,
      child: GestureDetector(
        onTap: () => _handleDoubleTap(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _twinkleController,
            _fadeInController,
            _selectionPulseController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: ConstellationPainter(
                nodes: _nodes,
                edges: _edges,
                twinkleValue: _twinkleController.value,
                fadeInValue: _fadeInController.value,
                selectedNodeId: _selectedNodeId,
                selectionPulse: _selectionPulseController.value,
                showLabels: widget.showLabels,
                lineOpacity: widget.lineOpacity,
                glowIntensity: widget.glowIntensity,
                onNodeTapped: _handleNodeTapped,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Extension to convert from existing ArcformGeometry to AtlasPhase
extension AtlasPhaseExtension on ArcformGeometry {
  AtlasPhase toAtlasPhase() {
    switch (this) {
      case ArcformGeometry.spiral:
        return AtlasPhase.discovery;
      case ArcformGeometry.flower:
        return AtlasPhase.expansion;
      case ArcformGeometry.branch:
        return AtlasPhase.transition;
      case ArcformGeometry.weave:
        return AtlasPhase.consolidation;
      case ArcformGeometry.glowCore:
        return AtlasPhase.recovery;
      case ArcformGeometry.fractal:
        return AtlasPhase.breakthrough;
    }
  }
}

/// Extension for AtlasPhase display names
extension AtlasPhaseDisplayExtension on AtlasPhase {
  String get displayName {
    switch (this) {
      case AtlasPhase.discovery:
        return 'Discovery';
      case AtlasPhase.expansion:
        return 'Expansion';
      case AtlasPhase.transition:
        return 'Transition';
      case AtlasPhase.consolidation:
        return 'Consolidation';
      case AtlasPhase.recovery:
        return 'Recovery';
      case AtlasPhase.breakthrough:
        return 'Breakthrough';
    }
  }
}

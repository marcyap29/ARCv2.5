// lib/arcform/demo/arcform_demo.dart
// Demo data for testing 3D Constellation ARCForms

import '../models/arcform_models.dart';
import '../layouts/layouts_3d.dart';
import '../util/seeded.dart';

/// Demo data generator for testing 3D Constellation ARCForms
class ArcformDemo {
  /// Generate demo constellation with 18 nodes, 22 edges, Discovery phase
  static Arcform3DData generateDiscoveryDemo() {
    final keywords = [
      'growth', 'insight', 'learning', 'curiosity', 'exploration',
      'discovery', 'wonder', 'creativity', 'innovation', 'breakthrough',
      'transformation', 'journey', 'adventure', 'possibility', 'potential',
      'excitement', 'enthusiasm', 'energy'
    ];

    final skin = ArcformSkin(seed: 304987231);
    
    // Generate 3D layout
    final nodes = layout3D(
      keywords: keywords,
      phase: 'Discovery',
      skin: skin,
      keywordWeights: {for (var kw in keywords) kw: 0.6 + (kw.length / 30.0)},
      keywordValences: {for (var kw in keywords) kw: _getDemoValence(kw)},
    );

    // Generate edges
    final rng = Seeded('${skin.seed}:edges');
    final edges = generateEdges(
      nodes: nodes,
      rng: rng,
      phase: 'Discovery', // Demo uses Discovery phase
      maxEdgesPerNode: 3,
      maxDistance: 1.2,
    );

    return Arcform3DData(
      nodes: nodes,
      edges: edges,
      phase: 'Discovery',
      skin: skin,
      title: 'Discovery Constellation Demo',
      content: 'A demonstration of the 3D constellation visualization system showing emotional patterns in the Discovery phase.',
      createdAt: DateTime.now(),
      id: 'demo_discovery_001',
    );
  }

  /// Generate demo for different phases
  static Arcform3DData generatePhaseDemo(String phase) {
    final keywords = _getPhaseKeywords(phase);
    final skin = ArcformSkin(seed: phase.hashCode);
    
    final nodes = layout3D(
      keywords: keywords,
      phase: phase,
      skin: skin,
      keywordWeights: {for (var kw in keywords) kw: 0.5 + (kw.length / 25.0)},
      keywordValences: {for (var kw in keywords) kw: _getDemoValence(kw)},
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
      title: '$phase Constellation Demo',
      content: 'A demonstration of the 3D constellation visualization system for the $phase phase.',
      createdAt: DateTime.now(),
      id: 'demo_${phase.toLowerCase()}_001',
    );
  }

  /// Get keywords appropriate for each phase
  static List<String> _getPhaseKeywords(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return [
          'growth', 'insight', 'learning', 'curiosity', 'exploration',
          'discovery', 'wonder', 'creativity', 'innovation', 'breakthrough',
          'transformation', 'journey', 'adventure', 'possibility', 'potential',
          'excitement', 'enthusiasm', 'energy'
        ];
      case 'exploration':
      case 'expansion':
        return [
          'expansion', 'growth', 'opportunity', 'success', 'achievement',
          'progress', 'momentum', 'confidence', 'strength', 'power',
          'ambition', 'drive', 'determination', 'focus', 'clarity',
          'vision', 'purpose', 'direction'
        ];
      case 'transition':
        return [
          'change', 'transition', 'shift', 'adaptation', 'flexibility',
          'uncertainty', 'anxiety', 'hope', 'anticipation', 'preparation',
          'letting go', 'moving forward', 'new beginnings', 'closure',
          'reflection', 'integration', 'balance', 'harmony'
        ];
      case 'consolidation':
        return [
          'stability', 'consolidation', 'integration', 'synthesis', 'wholeness',
          'completion', 'mastery', 'expertise', 'wisdom', 'understanding',
          'peace', 'contentment', 'satisfaction', 'fulfillment', 'gratitude',
          'appreciation', 'celebration', 'joy'
        ];
      case 'recovery':
        return [
          'healing', 'recovery', 'restoration', 'renewal', 'rebirth',
          'gentleness', 'self-care', 'compassion', 'patience', 'acceptance',
          'forgiveness', 'release', 'letting go', 'peace', 'tranquility',
          'serenity', 'calm', 'stillness'
        ];
      case 'breakthrough':
        return [
          'breakthrough', 'revelation', 'epiphany', 'awakening', 'enlightenment',
          'transcendence', 'liberation', 'freedom', 'clarity', 'understanding',
          'wisdom', 'transformation', 'evolution', 'ascension', 'elevation',
          'illumination', 'realization', 'insight'
        ];
      default:
        return [
          'balance', 'harmony', 'equilibrium', 'stability', 'peace',
          'contentment', 'satisfaction', 'well-being', 'health', 'vitality',
          'energy', 'strength', 'resilience', 'adaptability', 'flexibility',
          'growth', 'learning', 'development'
        ];
    }
  }

  /// Get demo valence for keywords
  static double _getDemoValence(String keyword) {
    final lower = keyword.toLowerCase();
    
    // Very positive
    if (lower.contains('joy') || lower.contains('love') || lower.contains('happiness') ||
        lower.contains('success') || lower.contains('breakthrough') || lower.contains('celebration') ||
        lower.contains('excitement') || lower.contains('enthusiasm') || lower.contains('energy')) {
      return 0.7 + (keyword.length / 50.0);
    }
    
    // Positive
    if (lower.contains('growth') || lower.contains('learning') || lower.contains('progress') ||
        lower.contains('achievement') || lower.contains('confidence') || lower.contains('strength') ||
        lower.contains('wisdom') || lower.contains('understanding') || lower.contains('clarity')) {
      return 0.3 + (keyword.length / 60.0);
    }
    
    // Neutral
    if (lower.contains('balance') || lower.contains('harmony') || lower.contains('stability') ||
        lower.contains('peace') || lower.contains('calm') || lower.contains('stillness') ||
        lower.contains('reflection') || lower.contains('integration') || lower.contains('synthesis')) {
      return 0.0;
    }
    
    // Slightly negative
    if (lower.contains('uncertainty') || lower.contains('anxiety') || lower.contains('change') ||
        lower.contains('transition') || lower.contains('letting go') || lower.contains('release')) {
      return -0.2 - (keyword.length / 80.0);
    }
    
    // Negative
    if (lower.contains('healing') || lower.contains('recovery') || lower.contains('restoration') ||
        lower.contains('gentleness') || lower.contains('patience') || lower.contains('acceptance')) {
      return -0.4 - (keyword.length / 100.0);
    }
    
    // Default neutral
    return 0.0;
  }

  /// Generate multiple demo constellations for testing
  static List<Arcform3DData> generateAllPhaseDemos() {
    final phases = ['Discovery', 'Exploration', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'];
    return phases.map((phase) => generatePhaseDemo(phase)).toList();
  }

  /// Generate demo with specific parameters
  static Arcform3DData generateCustomDemo({
    required List<String> keywords,
    required String phase,
    int seed = 12345,
    String title = 'Custom Demo',
  }) {
    final skin = ArcformSkin(seed: seed);
    
    final nodes = layout3D(
      keywords: keywords,
      phase: phase,
      skin: skin,
      keywordWeights: {for (var kw in keywords) kw: 0.5 + (kw.length / 20.0)},
      keywordValences: {for (var kw in keywords) kw: _getDemoValence(kw)},
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
      title: title,
      content: 'Custom demo constellation with ${keywords.length} keywords in $phase phase.',
      createdAt: DateTime.now(),
      id: 'demo_custom_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}

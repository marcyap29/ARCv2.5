// lib/arcform/services/unified_constellation_service.dart
// Unified constellation service using layouts_3d.dart

import '../layouts/layouts_3d.dart';
import '../models/arcform_models.dart';
import '../util/seeded.dart';
import '../../arc/ui/arcforms/services/emotional_valence_service.dart';

/// Unified service to generate constellation data for all renderers
/// This replaces ConstellationLayoutService, Geometry3DLayouts, and duplicates
class UnifiedConstellationService {
  final EmotionalValenceService _emotionalService = EmotionalValenceService();

  /// Generate 3D constellation data from keywords and phase
  /// Returns ArcNode3D and ArcEdge3D for use with Arcform3D widget
  UnifiedConstellationData generateConstellation({
    required List<String> keywords,
    required String phase,
    required int seed,
    Map<String, double>? keywordWeights,
    Map<String, double>? keywordValences,
  }) {
    // Create skin for deterministic variations
    final skin = ArcformSkin.forUser('user', 'phase_$phase');

    // Generate 3D layout using the unified layouts_3d.dart system
    final nodes = layout3D(
      keywords: keywords,
      phase: phase,
      skin: skin,
      keywordWeights: keywordWeights,
      keywordValences: keywordValences,
    );

    // Generate phase-specific edges that respect the shape patterns
    final rng = Seeded('${skin.seed}:edges');
    final edges = generateEdges(
      nodes: nodes,
      rng: rng,
      phase: phase,
      maxEdgesPerNode: 4,
      maxDistance: 1.4,
    );

    return UnifiedConstellationData(
      nodes: nodes,
      edges: edges,
      phase: phase,
      skin: skin,
    );
  }

  /// Convert old Node/Edge format to ArcNode3D/ArcEdge3D
  /// For migration from Simple3DArcform
  UnifiedConstellationData convertFromOldFormat({
    required List<String> keywords,
    required String phase,
    required int seed,
  }) {
    return generateConstellation(
      keywords: keywords,
      phase: phase,
      seed: seed,
    );
  }

  /// Convert ConstellationNode/ConstellationEdge to ArcNode3D/ArcEdge3D
  /// For migration from ConstellationArcformRenderer
  UnifiedConstellationData convertFromConstellationFormat({
    required List<String> keywords,
    required String phase,
    required int seed,
  }) {
    // Get emotional valences for keywords
    final keywordValences = <String, double>{};
    final keywordWeights = <String, double>{};
    
    for (final keyword in keywords) {
      keywordValences[keyword] = _emotionalService.getEmotionalValence(keyword);
      keywordWeights[keyword] = 0.5 + (keyword.length / 30.0); // Weight based on length
    }

    return generateConstellation(
      keywords: keywords,
      phase: phase,
      seed: seed,
      keywordWeights: keywordWeights,
      keywordValences: keywordValences,
    );
  }
}

/// Container for unified constellation data
class UnifiedConstellationData {
  final List<ArcNode3D> nodes;
  final List<ArcEdge3D> edges;
  final String phase;
  final ArcformSkin skin;

  const UnifiedConstellationData({
    required this.nodes,
    required this.edges,
    required this.phase,
    required this.skin,
  });
}


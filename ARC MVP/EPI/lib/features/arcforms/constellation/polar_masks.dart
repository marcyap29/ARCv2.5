import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'constellation_arcform_renderer.dart';

/// Polar masks for each ATLAS phase to guide star placement
class PolarMasks {
  /// Get radial bias mask for a given phase
  static List<double> getRadialBias(AtlasPhase phase, int numPoints) {
    switch (phase) {
      case AtlasPhase.discovery:
        return _getSpiralRadialBias(numPoints);
      case AtlasPhase.expansion:
        return _getFlowerRadialBias(numPoints);
      case AtlasPhase.transition:
        return _getBranchRadialBias(numPoints);
      case AtlasPhase.consolidation:
        return _getWeaveRadialBias(numPoints);
      case AtlasPhase.recovery:
        return _getGlowCoreRadialBias(numPoints);
      case AtlasPhase.breakthrough:
        return _getFractalRadialBias(numPoints);
    }
  }

  /// Get angular bias mask for a given phase
  static List<double> getAngularBias(AtlasPhase phase, int numPoints) {
    switch (phase) {
      case AtlasPhase.discovery:
        return _getSpiralAngularBias(numPoints);
      case AtlasPhase.expansion:
        return _getFlowerAngularBias(numPoints);
      case AtlasPhase.transition:
        return _getBranchAngularBias(numPoints);
      case AtlasPhase.consolidation:
        return _getWeaveAngularBias(numPoints);
      case AtlasPhase.recovery:
        return _getGlowCoreAngularBias(numPoints);
      case AtlasPhase.breakthrough:
        return _getFractalAngularBias(numPoints);
    }
  }

  /// Generate positions using polar mask
  static List<Offset> generatePositions(
    AtlasPhase phase,
    int numPoints,
    double maxRadius,
    int seed,
  ) {
    final random = math.Random(seed);
    final positions = <Offset>[];
    
    final radialBias = getRadialBias(phase, numPoints);
    final angularBias = getAngularBias(phase, numPoints);
    
    for (int i = 0; i < numPoints; i++) {
      // Apply radial bias
      final baseRadius = (i / (numPoints - 1)) * maxRadius;
      final radialMultiplier = radialBias[i];
      final radius = baseRadius * radialMultiplier;
      
      // Apply angular bias
      final baseAngle = (i / numPoints) * 2 * math.pi;
      final angularMultiplier = angularBias[i];
      final angle = baseAngle * angularMultiplier;
      
      // Add some randomness
      final radiusVariation = (random.nextDouble() - 0.5) * 20.0;
      final angleVariation = (random.nextDouble() - 0.5) * 0.5;
      
      final finalRadius = (radius + radiusVariation).clamp(10.0, maxRadius);
      final finalAngle = angle + angleVariation;
      
      final x = finalRadius * math.cos(finalAngle);
      final y = finalRadius * math.sin(finalAngle);
      
      positions.add(Offset(x, y));
    }
    
    return positions;
  }

  // Discovery / Spiral: Golden-angle spiral radii with gentle outward drift
  static List<double> _getSpiralRadialBias(int numPoints) {
    final bias = <double>[];
    const goldenAngle = 2.39996322972865332; // Golden angle in radians
    
    for (int i = 0; i < numPoints; i++) {
      final angle = i * goldenAngle;
      // Create gentle outward drift
      final drift = math.sin(angle * 0.1) * 0.2 + 1.0;
      bias.add(drift);
    }
    
    return bias;
  }

  static List<double> _getSpiralAngularBias(int numPoints) {
    // Spiral maintains consistent angular progression
    return List.filled(numPoints, 1.0);
  }

  // Expansion / Flower: k-petal polar mask with peaks at petal tips
  static List<double> _getFlowerRadialBias(int numPoints) {
    final bias = <double>[];
    const petals = 6;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Create petal peaks
      final petalAngle = (angle % (2 * math.pi / petals)) * petals;
      final petalStrength = math.cos(petalAngle) * 0.3 + 0.7;
      bias.add(petalStrength);
    }
    
    return bias;
  }

  static List<double> _getFlowerAngularBias(int numPoints) {
    final bias = <double>[];
    const petals = 6;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Concentrate angles at petal tips
      final petalAngle = (angle % (2 * math.pi / petals)) * petals;
      final concentration = (math.cos(petalAngle)).abs() * 0.5 + 0.5;
      bias.add(concentration);
    }
    
    return bias;
  }

  // Transition / Branch: a few longer arcs with side shoots and higher sparsity
  static List<double> _getBranchRadialBias(int numPoints) {
    final bias = <double>[];
    const mainBranches = 3;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Create main branch structure
      final branchAngle = (angle % (2 * math.pi / mainBranches)) * mainBranches;
      final branchStrength = math.cos(branchAngle) * 0.4 + 0.6;
      
      // Add sparsity variation
      final sparsity = math.sin(angle * 2) * 0.3 + 0.7;
      
      bias.add(branchStrength * sparsity);
    }
    
    return bias;
  }

  static List<double> _getBranchAngularBias(int numPoints) {
    final bias = <double>[];
    const mainBranches = 3;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Concentrate on main branch directions
      final branchAngle = (angle % (2 * math.pi / mainBranches)) * mainBranches;
      final concentration = (math.cos(branchAngle)).abs() * 0.6 + 0.4;
      bias.add(concentration);
    }
    
    return bias;
  }

  // Consolidation / Weave: inner lattice bias with tighter radii
  static List<double> _getWeaveRadialBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      final t = i / (numPoints - 1);
      // Create inner lattice bias - stronger towards center
      final innerBias = math.cos(t * math.pi) * 0.3 + 0.7;
      bias.add(innerBias);
    }
    
    return bias;
  }

  static List<double> _getWeaveAngularBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Create lattice-like angular distribution
      final latticeAngle = angle * 4; // 4-fold symmetry
      final latticeStrength = (math.cos(latticeAngle)).abs() * 0.4 + 0.6;
      bias.add(latticeStrength);
    }
    
    return bias;
  }

  // Recovery / Glow Core: bright centroid with sparse dim outliers
  static List<double> _getGlowCoreRadialBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      if (i == 0) {
        // Bright centroid
        bias.add(0.1);
      } else {
        // Sparse dim outliers
        final t = i / (numPoints - 1);
        final outlierBias = math.pow(t, 2) * 0.8 + 0.2;
        bias.add(outlierBias);
      }
    }
    
    return bias;
  }

  static List<double> _getGlowCoreAngularBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      if (i == 0) {
        // Centroid has no angular bias
        bias.add(1.0);
      } else {
        // Outliers have random angular distribution
        bias.add(0.5 + math.sin(i * 1.7) * 0.3);
      }
    }
    
    return bias;
  }

  // Breakthrough / Fractal: clustered bursts with short bridges
  static List<double> _getFractalRadialBias(int numPoints) {
    final bias = <double>[];
    const clusters = 3;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Create cluster centers
      final clusterAngle = (angle % (2 * math.pi / clusters)) * clusters;
      final clusterStrength = math.cos(clusterAngle) * 0.5 + 0.5;
      
      // Add burst variation
      final burst = math.sin(angle * 3) * 0.2 + 0.8;
      
      bias.add(clusterStrength * burst);
    }
    
    return bias;
  }

  static List<double> _getFractalAngularBias(int numPoints) {
    final bias = <double>[];
    const clusters = 3;
    
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      // Concentrate on cluster directions
      final clusterAngle = (angle % (2 * math.pi / clusters)) * clusters;
      final concentration = (math.cos(clusterAngle)).abs() * 0.7 + 0.3;
      
      // Add fractal variation
      final fractal = math.sin(angle * 5) * 0.1 + 0.9;
      
      bias.add(concentration * fractal);
    }
    
    return bias;
  }

  /// Get phase-specific density multiplier
  static double getDensityMultiplier(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return 0.8; // Sparse exploration
      case AtlasPhase.expansion:
        return 1.2; // Dense growth
      case AtlasPhase.transition:
        return 0.6; // Sparse transition
      case AtlasPhase.consolidation:
        return 1.4; // Very dense weaving
      case AtlasPhase.recovery:
        return 0.4; // Very sparse recovery
      case AtlasPhase.breakthrough:
        return 1.0; // Balanced breakthrough
    }
  }

  /// Get phase-specific edge density
  static double getEdgeDensity(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return 0.6; // Few connections
      case AtlasPhase.expansion:
        return 1.0; // Many connections
      case AtlasPhase.transition:
        return 0.4; // Minimal connections
      case AtlasPhase.consolidation:
        return 1.2; // Maximum connections
      case AtlasPhase.recovery:
        return 0.2; // Very few connections
      case AtlasPhase.breakthrough:
        return 0.8; // Moderate connections
    }
  }
}

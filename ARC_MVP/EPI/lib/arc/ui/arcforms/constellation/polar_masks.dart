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
        return _getBridgeRadialBias(numPoints);
      case AtlasPhase.consolidation:
        return _getWeaveRadialBias(numPoints);
      case AtlasPhase.recovery:
        return _getAscendingSpiralRadialBias(numPoints);
      case AtlasPhase.breakthrough:
        return _getSupernovaRadialBias(numPoints);
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
        return _getBridgeAngularBias(numPoints);
      case AtlasPhase.consolidation:
        return _getWeaveAngularBias(numPoints);
      case AtlasPhase.recovery:
        return _getAscendingSpiralAngularBias(numPoints);
      case AtlasPhase.breakthrough:
        return _getSupernovaAngularBias(numPoints);
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

  // Transition / Bridge: two clusters (left/right) with central bridge
  static List<double> _getBridgeRadialBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      final t = i / (numPoints - 1);
      
      // Two clusters: left (0-0.4), bridge (0.4-0.6), right (0.6-1.0)
      if (t < 0.4) {
        // Left cluster - tighter radius
        final clusterT = t / 0.4;
        bias.add(0.5 + clusterT * 0.3);
      } else if (t < 0.6) {
        // Bridge - centered, moderate radius
        bias.add(0.6);
      } else {
        // Right cluster - tighter radius
        final clusterT = (t - 0.6) / 0.4;
        bias.add(0.5 + clusterT * 0.3);
      }
    }
    
    return bias;
  }

  static List<double> _getBridgeAngularBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      final t = i / (numPoints - 1);
      
      // Left cluster: semicircle on left (90° to 270°)
      if (t < 0.4) {
        bias.add(1.0); // Full angular spread for semicircle
      } else if (t < 0.6) {
        // Bridge: horizontal emphasis
        bias.add(0.7);
      } else {
        // Right cluster: semicircle on right (-90° to 90°)
        bias.add(1.0); // Full angular spread for semicircle
      }
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

  // Recovery / Ascending Spiral: upward-winding spiral
  static List<double> _getAscendingSpiralRadialBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      final t = i / (numPoints - 1);
      // Spiral expands outward as it winds
      // Start tight, expand gradually
      final spiralExpansion = t * 0.8 + 0.2;
      bias.add(spiralExpansion);
    }
    
    return bias;
  }

  static List<double> _getAscendingSpiralAngularBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      // Maintain consistent angular progression for spiral
      // Spiral winds in golden angle pattern
      bias.add(1.0);
    }
    
    return bias;
  }

  // Breakthrough / Supernova: central core with radiating rays
  static List<double> _getSupernovaRadialBias(int numPoints) {
    final bias = <double>[];
    
    for (int i = 0; i < numPoints; i++) {
      if (i == 0) {
        // Central core - minimal radius
        bias.add(0.05);
      } else {
        final t = i / (numPoints - 1);
        // Power distribution: more nodes near center (burst effect)
        final powerBias = math.pow(t, 0.6).toDouble();
        bias.add(powerBias * 0.8 + 0.2);
      }
    }
    
    return bias;
  }

  static List<double> _getSupernovaAngularBias(int numPoints) {
    final bias = <double>[];
    const rayCount = 8;
    
    for (int i = 0; i < numPoints; i++) {
      if (i == 0) {
        // Central core - no angular bias
        bias.add(1.0);
      } else {
        final angle = (i / numPoints) * 2 * math.pi;
        // Concentrate on ray directions (every 45 degrees)
        final rayAngle = (angle % (2 * math.pi / rayCount)) * rayCount;
        final rayConcentration = (math.cos(rayAngle)).abs() * 0.8 + 0.2;
        bias.add(rayConcentration);
      }
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

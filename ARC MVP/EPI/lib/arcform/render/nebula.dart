// lib/arcform/render/nebula.dart
// Phase-aware nebula scatter volumes for 3D constellation backgrounds

import 'dart:math' as math;
import '../util/seeded.dart';
import '../models/arcform_models.dart';

/// Nebula particle data for rendering
class NebulaParticle {
  final double x, y, z;
  final double size;
  final double alpha;
  final double r, g, b; // Color components

  const NebulaParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.alpha,
    required this.r,
    required this.g,
    required this.b,
  });
}

/// Generate phase-aware nebula particles
class NebulaGenerator {
  /// Generate nebula particles based on phase
  static List<NebulaParticle> generate({
    required String phase,
    required ArcformSkin skin,
    int particleCount = 18,
  }) {
    final rng = Seeded('${skin.seed}:nebula');
    final particles = <NebulaParticle>[];

    switch (phase.toLowerCase()) {
      case 'discovery':
        // Much wider spiral/helix volume for expansive nebula
        particles.addAll(_generateSpiralNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          radius: 6.0, // Much larger spatial spread
          height: 8.0, // Much taller nebula field
          turns: 2.5,
        ));
        break;

      case 'exploration':
      case 'expansion':
        // Much larger petal rings spanning wider area
        particles.addAll(_generatePetalNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          layers: 4, // More layers for depth
          radius: 5.5, // Much larger radius
        ));
        break;

      case 'transition':
        // Forked branches with much wider z offsets for transformation phase
        particles.addAll(_generateBranchedNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          branches: 4, // More branches
          spread: 8.5, // Extra wide spread for transformation auras
        ));
        break;

      case 'consolidation':
        // Much larger woven lattice/shell
        particles.addAll(_generateLatticeNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          radius: 5.0, // Much larger lattice
        ));
        break;

      case 'recovery':
        // Larger cluster spanning more space
        particles.addAll(_generateClusteredNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          radius: 4.0, // Much larger cluster radius
        ));
        break;

      case 'breakthrough':
        // Extra large sparse bursts for breakthrough phase auras
        particles.addAll(_generateBurstNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          burstRadius: 9.0, // Extra large burst radius for breakthrough auras
        ));
        break;

      default:
        // Default: large spherical distribution for expansive nebula
        particles.addAll(_generateSphericalNebula(
          rng: rng,
          skin: skin,
          count: particleCount,
          radius: 5.5, // Much larger default radius
        ));
    }

    return particles;
  }

  /// Generate spiral/helix nebula (Discovery phase)
  static List<NebulaParticle> _generateSpiralNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required double radius,
    required double height,
    required double turns,
  }) {
    final particles = <NebulaParticle>[];
    
    for (int i = 0; i < count; i++) {
      final t = i / count;
      final angle = t * turns * 2 * math.pi;
      final spiralRadius = radius * (0.3 + t * 0.7);
      
      final x = spiralRadius * math.cos(angle) + rng.nextRange(-0.3, 0.3);
      final y = spiralRadius * math.sin(angle) + rng.nextRange(-0.3, 0.3);
      final z = (t - 0.5) * height + rng.nextRange(-0.2, 0.2);
      
      particles.add(_createParticle(rng, skin, x, y, z));
    }
    
    return particles;
  }

  /// Generate petal-ring nebula (Exploration phase)
  static List<NebulaParticle> _generatePetalNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required int layers,
    required double radius,
  }) {
    final particles = <NebulaParticle>[];
    final particlesPerLayer = count ~/ layers;
    
    for (int layer = 0; layer < layers; layer++) {
      final z = (layer / (layers - 1) - 0.5) * 2.0;
      final layerRadius = radius * (0.8 + 0.2 * (layer / layers));
      
      for (int i = 0; i < particlesPerLayer; i++) {
        final angle = (i / particlesPerLayer) * 2 * math.pi;
        final r = layerRadius + rng.nextRange(-0.2, 0.2);
        
        final x = r * math.cos(angle);
        final y = r * math.sin(angle);
        
        particles.add(_createParticle(rng, skin, x, y, z));
      }
    }
    
    return particles;
  }

  /// Generate branched nebula (Transition phase)
  static List<NebulaParticle> _generateBranchedNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required int branches,
    required double spread,
  }) {
    final particles = <NebulaParticle>[];
    final particlesPerBranch = count ~/ branches;
    
    for (int branch = 0; branch < branches; branch++) {
      final branchAngle = (branch / branches) * 2 * math.pi;
      final branchDir = (
        x: math.cos(branchAngle),
        y: math.sin(branchAngle),
      );
      
      for (int i = 0; i < particlesPerBranch; i++) {
        final t = i / particlesPerBranch;
        final distance = t * spread;
        
        final x = branchDir.x * distance + rng.nextRange(-0.3, 0.3);
        final y = branchDir.y * distance + rng.nextRange(-0.3, 0.3);
        final z = rng.nextRange(-0.5, 0.5);
        
        particles.add(_createParticle(rng, skin, x, y, z));
      }
    }
    
    return particles;
  }

  /// Generate lattice nebula (Consolidation phase)
  static List<NebulaParticle> _generateLatticeNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required double radius,
  }) {
    final particles = <NebulaParticle>[];
    
    for (int i = 0; i < count; i++) {
      final point = rng.nextUnitSphere();
      final r = radius * (0.7 + rng.nextDouble() * 0.3);
      
      final x = point.x * r;
      final y = point.y * r;
      final z = point.z * r;
      
      particles.add(_createParticle(rng, skin, x, y, z));
    }
    
    return particles;
  }

  /// Generate clustered nebula (Recovery phase)
  static List<NebulaParticle> _generateClusteredNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required double radius,
  }) {
    final particles = <NebulaParticle>[];
    
    for (int i = 0; i < count; i++) {
      // Gaussian distribution for tight cluster
      final x = rng.nextGaussian() * radius * 0.3;
      final y = rng.nextGaussian() * radius * 0.3;
      final z = rng.nextGaussian() * radius * 0.3;
      
      particles.add(_createParticle(rng, skin, x, y, z));
    }
    
    return particles;
  }

  /// Generate burst nebula (Breakthrough phase)
  static List<NebulaParticle> _generateBurstNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required double burstRadius,
  }) {
    final particles = <NebulaParticle>[];
    
    for (int i = 0; i < count; i++) {
      final point = rng.nextUnitSphere();
      // Bias toward outer radius for burst effect
      final t = rng.nextDouble();
      final r = burstRadius * math.pow(t, 0.3).toDouble();
      
      final x = point.x * r;
      final y = point.y * r;
      final z = point.z * r;
      
      particles.add(_createParticle(rng, skin, x, y, z));
    }
    
    return particles;
  }

  /// Generate spherical nebula (default)
  static List<NebulaParticle> _generateSphericalNebula({
    required Seeded rng,
    required ArcformSkin skin,
    required int count,
    required double radius,
  }) {
    final particles = <NebulaParticle>[];
    
    for (int i = 0; i < count; i++) {
      final point = rng.nextUnitSphere();
      final r = radius * math.pow(rng.nextDouble(), 0.5);
      
      final x = point.x * r;
      final y = point.y * r;
      final z = point.z * r;
      
      particles.add(_createParticle(rng, skin, x, y, z));
    }
    
    return particles;
  }

  /// Create a single nebula particle with randomized properties
  static NebulaParticle _createParticle(
    Seeded rng,
    ArcformSkin skin,
    double x,
    double y,
    double z,
  ) {
    // Moderately larger base size with jitter
    final baseSize = 0.25 + rng.nextDouble() * 0.35; // Moderately larger than original
    final size = baseSize * (1.0 + (rng.nextDouble() - 0.5) * skin.nebulaJitter);
    
    // Alpha with jitter
    final baseAlpha = 0.3 + rng.nextDouble() * 0.4;
    final alpha = (baseAlpha * (1.0 + (rng.nextDouble() - 0.5) * skin.nebulaJitter)).clamp(0.1, 0.7);
    
    // Subtle purple/blue tint for nebula
    final hue = 0.6 + rng.nextRange(-0.1, 0.1); // Blue-purple range
    final saturation = 0.5 + rng.nextDouble() * 0.3;
    final lightness = 0.4 + rng.nextDouble() * 0.2;
    
    // Simple HSL to RGB conversion
    final rgb = _hslToRgb(hue, saturation, lightness);
    
    return NebulaParticle(
      x: x,
      y: y,
      z: z,
      size: size,
      alpha: alpha,
      r: rgb.r,
      g: rgb.g,
      b: rgb.b,
    );
  }

  /// Simple HSL to RGB conversion for nebula colors
  static ({double r, double g, double b}) _hslToRgb(double h, double s, double l) {
    h = h.clamp(0.0, 1.0);
    s = s.clamp(0.0, 1.0);
    l = l.clamp(0.0, 1.0);

    if (s == 0.0) {
      return (r: l, g: l, b: l);
    }

    double hue2rgb(double p, double q, double t) {
      if (t < 0.0) t += 1.0;
      if (t > 1.0) t -= 1.0;
      if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
      if (t < 1.0 / 2.0) return q;
      if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
      return p;
    }

    final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    final p = 2.0 * l - q;

    return (
      r: hue2rgb(p, q, h + 1.0 / 3.0),
      g: hue2rgb(p, q, h),
      b: hue2rgb(p, q, h - 1.0 / 3.0),
    );
  }
}


/// Sigil Particle System
/// 
/// CustomPainter that renders particles flowing along the sigil paths.
/// Particles flow:
/// - INWARD toward center when LISTENING (collecting words)
/// - OUTWARD from center when SPEAKING (emanating response)
/// - ORBITAL around center when IDLE (ambient presence)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../voice_sigil.dart';
import 'sigil_path_utils.dart';

/// Individual particle data
class Particle {
  Offset position;
  double progress;     // 0.0 to 1.0 along path
  double speed;        // Movement speed multiplier
  double opacity;      // Fade effect
  double size;         // Particle size
  int pathIndex;       // Which path the particle is on
  
  Particle({
    required this.position,
    required this.progress,
    required this.speed,
    required this.opacity,
    required this.size,
    required this.pathIndex,
  });
}

/// Sigil Particle System Painter
class SigilParticleSystem extends CustomPainter {
  final VoiceSigilState state;
  final Color phaseColor;
  final ParticleFlowDirection flowDirection;
  final double animationValue; // 0.0 to 1.0, loops
  final List<Particle> particles;
  
  SigilParticleSystem({
    required this.state,
    required this.phaseColor,
    required this.flowDirection,
    required this.animationValue,
    required this.particles,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.45;
    
    for (final particle in particles) {
      // Calculate particle position based on flow direction
      Offset particlePos;
      double particleOpacity = particle.opacity;
      
      switch (flowDirection) {
        case ParticleFlowDirection.inward:
          // Flow from outer edge toward center
          final progress = (particle.progress + animationValue * particle.speed) % 1.0;
          final distance = maxRadius * (1 - progress); // Reverse: 1.0 = outer, 0.0 = center
          final angle = (particle.pathIndex * 60 - 90 + progress * 30) * math.pi / 180;
          particlePos = Offset(
            center.dx + distance * math.cos(angle),
            center.dy + distance * math.sin(angle),
          );
          // Fade out as approaching center
          particleOpacity = particle.opacity * (0.3 + 0.7 * (1 - progress));
          break;
          
        case ParticleFlowDirection.outward:
          // Flow from center toward outer edge
          final progress = (particle.progress + animationValue * particle.speed) % 1.0;
          final distance = maxRadius * progress;
          final angle = (particle.pathIndex * 60 - 90 + progress * 15) * math.pi / 180;
          particlePos = Offset(
            center.dx + distance * math.cos(angle),
            center.dy + distance * math.sin(angle),
          );
          // Fade out as moving away
          particleOpacity = particle.opacity * (1 - progress * 0.5);
          break;
          
        case ParticleFlowDirection.orbital:
          // Gentle orbital motion around center
          final orbitRadius = maxRadius * 0.3 + maxRadius * 0.3 * particle.progress;
          final angle = (animationValue * 360 * particle.speed + particle.pathIndex * 60) * math.pi / 180;
          particlePos = Offset(
            center.dx + orbitRadius * math.cos(angle),
            center.dy + orbitRadius * math.sin(angle),
          );
          // Gentle pulsing opacity
          particleOpacity = particle.opacity * (0.5 + 0.5 * math.sin(animationValue * 2 * math.pi));
          break;
      }
      
      // Draw particle
      final paint = Paint()
        ..color = phaseColor.withOpacity(particleOpacity * 0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(particlePos, particle.size, paint);
      
      // Draw glow around particle
      final glowPaint = Paint()
        ..color = phaseColor.withOpacity(particleOpacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      canvas.drawCircle(particlePos, particle.size * 2, glowPaint);
    }
  }
  
  @override
  bool shouldRepaint(SigilParticleSystem oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.state != state ||
           oldDelegate.flowDirection != flowDirection;
  }
}

/// Manager for particle system
class ParticleSystemManager {
  final List<Particle> particles = [];
  final math.Random _random = math.Random();
  
  /// Initialize particles
  void initialize({int count = 30}) {
    particles.clear();
    
    for (int i = 0; i < count; i++) {
      particles.add(Particle(
        position: Offset.zero,
        progress: _random.nextDouble(),
        speed: 0.3 + _random.nextDouble() * 0.7,
        opacity: 0.3 + _random.nextDouble() * 0.7,
        size: 1.5 + _random.nextDouble() * 2.5,
        pathIndex: _random.nextInt(6),
      ));
    }
  }
  
  /// Get flow direction based on state
  ParticleFlowDirection getFlowDirection(VoiceSigilState state) {
    switch (state) {
      case VoiceSigilState.idle:
        return ParticleFlowDirection.orbital;
      case VoiceSigilState.listening:
      case VoiceSigilState.commitment:
        return ParticleFlowDirection.inward;
      case VoiceSigilState.accelerating:
      case VoiceSigilState.thinking:
        return ParticleFlowDirection.inward; // Compress to center
      case VoiceSigilState.speaking:
        return ParticleFlowDirection.outward;
    }
  }
}

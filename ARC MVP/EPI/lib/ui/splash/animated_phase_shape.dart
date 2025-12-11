import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated 3D phase shape widget for splash screen
/// Shows a spinning wireframe representation of the user's current phase
class AnimatedPhaseShape extends StatefulWidget {
  final String phase;
  final double size;
  final Duration rotationDuration;
  
  const AnimatedPhaseShape({
    super.key,
    required this.phase,
    this.size = 150,
    this.rotationDuration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedPhaseShape> createState() => _AnimatedPhaseShapeState();
}

class _AnimatedPhaseShapeState extends State<AnimatedPhaseShape>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: widget.rotationDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Color get _phaseColor {
    switch (widget.phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFFD1B3FF); // Light purple default
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PhaseShapePainter(
            phase: widget.phase,
            rotation: _rotationController.value * 2 * math.pi,
            color: _phaseColor,
          ),
        );
      },
    );
  }
}

class _PhaseShapePainter extends CustomPainter {
  final String phase;
  final double rotation;
  final Color color;

  _PhaseShapePainter({
    required this.phase,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Create gradient for glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final brightLinePaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    switch (phase.toLowerCase()) {
      case 'discovery':
        _drawDiscoveryHelix(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      case 'expansion':
        _drawExpansionFlower(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      case 'transition':
        _drawTransitionBridge(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      case 'consolidation':
        _drawConsolidationLattice(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      case 'recovery':
        _drawRecoveryCore(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      case 'breakthrough':
        _drawBreakthroughSupernova(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
        break;
      default:
        _drawDiscoveryHelix(canvas, center, radius, glowPaint, linePaint, brightLinePaint);
    }
  }

  /// Discovery: Spinning helix/DNA shape
  void _drawDiscoveryHelix(Canvas canvas, Offset center, double radius, 
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    final path = Path();
    final path2 = Path();
    
    const turns = 2.0;
    const segments = 40;
    
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = t * turns * 2 * math.pi + rotation;
      
      // First helix strand
      final x1 = center.dx + radius * 0.7 * math.cos(angle);
      final y1 = center.dy + (t - 0.5) * radius * 2;
      final z1 = math.sin(angle) * 0.3;
      final projectedX1 = x1 + z1 * 20;
      
      // Second helix strand (opposite phase)
      final x2 = center.dx + radius * 0.7 * math.cos(angle + math.pi);
      final y2 = y1;
      final z2 = math.sin(angle + math.pi) * 0.3;
      final projectedX2 = x2 + z2 * 20;
      
      if (i == 0) {
        path.moveTo(projectedX1, y1);
        path2.moveTo(projectedX2, y2);
      } else {
        path.lineTo(projectedX1, y1);
        path2.lineTo(projectedX2, y2);
      }
      
      // Draw connecting rungs every few segments
      if (i % 8 == 0 && i > 0 && i < segments) {
        canvas.drawLine(
          Offset(projectedX1, y1),
          Offset(projectedX2, y2),
          linePaint..color = color.withOpacity(0.4),
        );
      }
    }
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, brightLinePaint);
    canvas.drawPath(path2, glowPaint);
    canvas.drawPath(path2, linePaint);
  }

  /// Expansion: Rotating flower/petal shape
  void _drawExpansionFlower(Canvas canvas, Offset center, double radius,
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    const petals = 6;
    
    for (int i = 0; i < petals; i++) {
      final baseAngle = (i / petals) * 2 * math.pi + rotation;
      
      final path = Path();
      path.moveTo(center.dx, center.dy);
      
      // Draw petal curve
      for (int j = 0; j <= 20; j++) {
        final t = j / 20;
        final petalAngle = baseAngle + (t - 0.5) * 0.8;
        final petalRadius = radius * (0.3 + 0.7 * math.sin(t * math.pi));
        
        // Add 3D depth
        final depth = math.cos(baseAngle) * 0.2;
        final x = center.dx + petalRadius * math.cos(petalAngle) * (1 + depth);
        final y = center.dy + petalRadius * math.sin(petalAngle);
        
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      // Draw with depth-based opacity
      final depthFactor = (math.cos(baseAngle) + 1) / 2;
      canvas.drawPath(path, glowPaint..color = color.withOpacity(0.2 + depthFactor * 0.2));
      canvas.drawPath(path, linePaint..color = color.withOpacity(0.5 + depthFactor * 0.5));
    }
    
    // Center point
    canvas.drawCircle(center, 4, Paint()..color = color);
  }

  /// Transition: Rotating bridge/fork structure
  void _drawTransitionBridge(Canvas canvas, Offset center, double radius,
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    const branches = 3;
    
    // Draw main trunk
    final trunkStart = Offset(center.dx - radius * 0.6, center.dy);
    final trunkEnd = Offset(center.dx, center.dy);
    
    // Rotate trunk
    final rotatedTrunkStart = _rotatePoint(trunkStart, center, rotation);
    final rotatedTrunkEnd = _rotatePoint(trunkEnd, center, rotation);
    
    canvas.drawLine(rotatedTrunkStart, rotatedTrunkEnd, glowPaint);
    canvas.drawLine(rotatedTrunkStart, rotatedTrunkEnd, brightLinePaint);
    
    // Draw branches
    for (int i = 0; i < branches; i++) {
      final branchAngle = (i - 1) * 0.5;
      final branchEnd = Offset(
        center.dx + radius * 0.8 * math.cos(branchAngle),
        center.dy + radius * 0.6 * math.sin(branchAngle),
      );
      
      final rotatedBranchEnd = _rotatePoint(branchEnd, center, rotation);
      
      canvas.drawLine(rotatedTrunkEnd, rotatedBranchEnd, glowPaint);
      canvas.drawLine(rotatedTrunkEnd, rotatedBranchEnd, linePaint);
      
      // Sub-branches
      for (int j = 0; j < 2; j++) {
        final subAngle = branchAngle + (j - 0.5) * 0.4;
        final subEnd = Offset(
          branchEnd.dx + radius * 0.4 * math.cos(subAngle),
          branchEnd.dy + radius * 0.3 * math.sin(subAngle),
        );
        final rotatedSubEnd = _rotatePoint(subEnd, center, rotation);
        canvas.drawLine(rotatedBranchEnd, rotatedSubEnd, linePaint..color = color.withOpacity(0.6));
      }
    }
  }

  /// Consolidation: Rotating geodesic lattice
  void _drawConsolidationLattice(Canvas canvas, Offset center, double radius,
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    const rings = 4;
    const pointsPerRing = 6;
    
    final points = <List<Offset>>[];
    
    // Generate points on rings
    for (int ring = 0; ring < rings; ring++) {
      final ringPoints = <Offset>[];
      final ringRadius = radius * (0.3 + ring * 0.25);
      final ringZ = (ring - rings / 2) * 0.3;
      
      for (int i = 0; i < pointsPerRing; i++) {
        final angle = (i / pointsPerRing) * 2 * math.pi + rotation + ring * 0.2;
        final x = center.dx + ringRadius * math.cos(angle);
        final y = center.dy + ringRadius * math.sin(angle) * 0.6 + ringZ * 30;
        ringPoints.add(Offset(x, y));
      }
      points.add(ringPoints);
    }
    
    // Draw connections within rings
    for (int ring = 0; ring < rings; ring++) {
      for (int i = 0; i < pointsPerRing; i++) {
        final next = (i + 1) % pointsPerRing;
        canvas.drawLine(points[ring][i], points[ring][next], linePaint);
      }
    }
    
    // Draw connections between rings
    for (int ring = 0; ring < rings - 1; ring++) {
      for (int i = 0; i < pointsPerRing; i++) {
        canvas.drawLine(points[ring][i], points[ring + 1][i], 
            linePaint..color = color.withOpacity(0.5));
        canvas.drawLine(points[ring][i], points[ring + 1][(i + 1) % pointsPerRing],
            linePaint..color = color.withOpacity(0.3));
      }
    }
  }

  /// Recovery: Rotating core with shell
  void _drawRecoveryCore(Canvas canvas, Offset center, double radius,
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    // Inner glowing core
    for (int i = 3; i > 0; i--) {
      final coreRadius = radius * 0.15 * i;
      canvas.drawCircle(
        center,
        coreRadius,
        Paint()
          ..color = color.withOpacity(0.3 / i)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreRadius * 0.5),
      );
    }
    
    // Core solid
    canvas.drawCircle(center, radius * 0.12, Paint()..color = color);
    
    // Orbiting shell particles
    const shellParticles = 8;
    for (int i = 0; i < shellParticles; i++) {
      final angle = (i / shellParticles) * 2 * math.pi + rotation;
      final orbitRadius = radius * (0.5 + math.sin(rotation * 2 + i) * 0.15);
      
      // 3D wobble
      final z = math.sin(angle + rotation) * 0.3;
      final x = center.dx + orbitRadius * math.cos(angle);
      final y = center.dy + orbitRadius * math.sin(angle) * 0.7 + z * 20;
      
      // Draw particle trail
      final trailPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      
      for (int t = 1; t <= 3; t++) {
        final trailAngle = angle - t * 0.1;
        final tx = center.dx + orbitRadius * math.cos(trailAngle);
        final ty = center.dy + orbitRadius * math.sin(trailAngle) * 0.7;
        canvas.drawCircle(Offset(tx, ty), 2 - t * 0.5, trailPaint);
      }
      
      // Particle
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      
      // Connection to core
      canvas.drawLine(center, Offset(x, y), linePaint..color = color.withOpacity(0.2));
    }
  }

  /// Breakthrough: Rotating supernova explosion
  void _drawBreakthroughSupernova(Canvas canvas, Offset center, double radius,
      Paint glowPaint, Paint linePaint, Paint brightLinePaint) {
    // Central burst
    canvas.drawCircle(
      center,
      radius * 0.15,
      Paint()
        ..color = color.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(center, radius * 0.08, Paint()..color = color);
    
    // Rays shooting outward
    const rays = 12;
    for (int i = 0; i < rays; i++) {
      final angle = (i / rays) * 2 * math.pi + rotation;
      final isMainRay = i % 2 == 0;
      final rayLength = radius * (isMainRay ? 1.0 : 0.6);
      
      // Pulsing effect
      final pulse = 1.0 + math.sin(rotation * 3 + i) * 0.1;
      
      final endX = center.dx + rayLength * pulse * math.cos(angle);
      final endY = center.dy + rayLength * pulse * math.sin(angle);
      
      // Draw ray with gradient effect
      final rayPath = Path();
      rayPath.moveTo(center.dx, center.dy);
      rayPath.lineTo(endX, endY);
      
      if (isMainRay) {
        canvas.drawPath(rayPath, glowPaint);
        canvas.drawPath(rayPath, brightLinePaint);
        
        // Sparkle at end
        canvas.drawCircle(
          Offset(endX, endY),
          3,
          Paint()..color = color,
        );
      } else {
        canvas.drawPath(rayPath, linePaint..color = color.withOpacity(0.5));
      }
    }
    
    // Expanding ring
    final ringRadius = radius * 0.7 * (1 + math.sin(rotation * 2) * 0.1);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Offset _rotatePoint(Offset point, Offset center, double angle) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      center.dx + dx * cos - dy * sin,
      center.dy + dx * sin + dy * cos,
    );
  }

  @override
  bool shouldRepaint(_PhaseShapePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.phase != phase;
  }
}


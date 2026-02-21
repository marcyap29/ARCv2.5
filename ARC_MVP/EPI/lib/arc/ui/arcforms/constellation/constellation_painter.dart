import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'constellation_arcform_renderer.dart';

/// Custom painter for constellation visualization
class ConstellationPainter extends CustomPainter {
  final List<ConstellationNode> nodes;
  final List<ConstellationEdge> edges;
  final double twinkleValue;
  final double fadeInValue;
  final String? selectedNodeId;
  final double selectionPulse;
  final bool showLabels;
  final double lineOpacity;
  final double glowIntensity;
  final Function(String)? onNodeTapped;

  ConstellationPainter({
    required this.nodes,
    required this.edges,
    required this.twinkleValue,
    required this.fadeInValue,
    this.selectedNodeId,
    required this.selectionPulse,
    required this.showLabels,
    required this.lineOpacity,
    required this.glowIntensity,
    this.onNodeTapped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw in layers for proper depth
    _drawBackgroundStars(canvas, size);
    _drawConstellationLines(canvas, center);
    _drawStarHalos(canvas, center);
    _drawStarCores(canvas, center);
    if (showLabels) {
      _drawLabels(canvas, center);
    }
  }

  /// Draw background starfield
  void _drawBackgroundStars(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistent background
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Generate background stars
    final numStars = (size.width * size.height / 8000).round();
    
    for (int i = 0; i < numStars; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      // Vary star size and brightness
      final starSize = random.nextDouble() * 1.5 + 0.5;
      final brightness = random.nextDouble() * 0.3 + 0.1;
      
      // Add subtle twinkling
      final twinkle = random.nextDouble() > 0.7;
      final twinkleOffset = twinkle ? (math.sin(twinkleValue * 2 * math.pi + i * 0.5) + 1) * 0.5 * 0.2 : 0.0;
      final finalBrightness = (brightness + twinkleOffset).clamp(0.05, 0.4);
      
      paint.color = Colors.white.withOpacity(finalBrightness);
      canvas.drawCircle(Offset(x, y), starSize, paint);
      
      // Add sparkle to brightest stars
      if (finalBrightness > 0.25 && starSize > 1.0) {
        _drawSparkle(canvas, Offset(x, y), starSize, finalBrightness);
      }
    }
  }

  /// Draw constellation lines between stars
  void _drawConstellationLines(Canvas canvas, Offset center) {
    if (edges.isEmpty) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    
    for (final edge in edges) {
      if (edge.a >= nodes.length || edge.b >= nodes.length) continue;
      
      final nodeA = nodes[edge.a];
      final nodeB = nodes[edge.b];
      
      final startPos = center + nodeA.pos;
      final endPos = center + nodeB.pos;
      
      // Calculate line properties based on weight and distance
      final distance = (startPos - endPos).distance;
      final weight = edge.weight;
      
      // Line opacity based on weight and distance
      final baseOpacity = lineOpacity * weight;
      final distanceOpacity = (1.0 - (distance / 200.0).clamp(0.0, 0.8));
      final finalOpacity = (baseOpacity * distanceOpacity).clamp(0.05, lineOpacity);
      
      // Draw line with gradient effect
      _drawGradientLine(canvas, startPos, endPos, finalOpacity);
    }
  }

  /// Draw gradient line with end-to-end opacity fade
  void _drawGradientLine(Canvas canvas, Offset start, Offset end, double opacity) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    
    // Create gradient from start to end
    final gradient = ui.Gradient.linear(
      start,
      end,
      [
        Colors.white.withOpacity(opacity),
        Colors.white.withOpacity(opacity * 0.3),
      ],
    );
    
    paint.shader = gradient;
    canvas.drawLine(start, end, paint);
  }

  /// Draw star halos (glow effects)
  void _drawStarHalos(Canvas canvas, Offset center) {
    for (final node in nodes) {
      final pos = center + node.pos;
      final isSelected = selectedNodeId == node.id;
      
      // Calculate halo properties
      final baseRadius = node.radius * 2.0;
      final selectionMultiplier = isSelected ? (1.0 + selectionPulse * 0.5) : 1.0;
      final finalRadius = baseRadius * selectionMultiplier;
      
      // Create halo with radial gradient
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            node.color.withOpacity(0.3 * glowIntensity),
            node.color.withOpacity(0.1 * glowIntensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: finalRadius));
      
      canvas.drawCircle(pos, finalRadius, haloPaint);
    }
  }

  /// Draw star cores
  void _drawStarCores(Canvas canvas, Offset center) {
    for (final node in nodes) {
      final pos = center + node.pos;
      final isSelected = selectedNodeId == node.id;
      
      // Calculate core properties
      final coreRadius = node.radius * 0.4;
      final selectionMultiplier = isSelected ? (1.0 + selectionPulse * 0.3) : 1.0;
      final finalRadius = coreRadius * selectionMultiplier;
      
      // Add individual twinkle
      final nodeIndex = nodes.indexOf(node);
      final twinkleOffset = (nodeIndex * 0.37) % (2 * math.pi);
      final individualTwinkle = (math.sin(twinkleValue * 2 * math.pi + twinkleOffset) + 1) * 0.5;
      final twinkleOpacity = 0.85 + individualTwinkle * 0.15;
      
      // Draw core
      final corePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = node.color.withOpacity(twinkleOpacity);
      
      canvas.drawCircle(pos, finalRadius, corePaint);
      
      // Draw selection ring
      if (isSelected) {
        final ringRadius = finalRadius * (2.0 + selectionPulse * 0.8);
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withOpacity((1.0 - selectionPulse) * 0.8);
        
        canvas.drawCircle(pos, ringRadius, ringPaint);
      }
      
      // Draw sparkle lines for bright stars
      if (twinkleOpacity > 0.9 || isSelected) {
        _drawStarSparkle(canvas, pos, finalRadius, isSelected);
      }
    }
  }

  /// Draw sparkle lines for stars
  void _drawStarSparkle(Canvas canvas, Offset center, double radius, bool isSelected) {
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = isSelected ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;
    
    final sparkleSize = radius * (isSelected ? 2.5 : 2.0);
    
    // Vertical and horizontal lines
    canvas.drawLine(
      center + Offset(0, -sparkleSize),
      center + Offset(0, sparkleSize),
      sparklePaint,
    );
    canvas.drawLine(
      center + Offset(-sparkleSize, 0),
      center + Offset(sparkleSize, 0),
      sparklePaint,
    );
    
    // Diagonal lines for selected stars
    if (isSelected) {
      canvas.drawLine(
        center + Offset(-sparkleSize * 0.7, -sparkleSize * 0.7),
        center + Offset(sparkleSize * 0.7, sparkleSize * 0.7),
        sparklePaint,
      );
      canvas.drawLine(
        center + Offset(sparkleSize * 0.7, -sparkleSize * 0.7),
        center + Offset(-sparkleSize * 0.7, sparkleSize * 0.7),
        sparklePaint,
      );
    }
  }

  /// Draw sparkle for background stars
  void _drawSparkle(Canvas canvas, Offset center, double size, double brightness) {
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(brightness * 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    final sparkleSize = size * 1.5;
    
    // Simple cross sparkle
    canvas.drawLine(
      center + Offset(-sparkleSize, 0),
      center + Offset(sparkleSize, 0),
      sparklePaint,
    );
    canvas.drawLine(
      center + Offset(0, -sparkleSize),
      center + Offset(0, sparkleSize),
      sparklePaint,
    );
  }

  /// Draw labels for stars
  void _drawLabels(Canvas canvas, Offset center) {
    for (final node in nodes) {
      final pos = center + node.pos;
      final isSelected = selectedNodeId == node.id;
      
      // Only show labels for larger stars or selected stars
      if (node.radius < 6.0 && !isSelected) continue;
      
      final label = node.data.text;
      final fontSize = isSelected ? 12.0 : 10.0;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label.length > 12 ? '${label.substring(0, 12)}...' : label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
            fontSize: fontSize,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: isSelected ? 3.0 : 2.0,
                color: Colors.black.withOpacity(0.8),
              ),
              if (isSelected)
                Shadow(
                  offset: Offset.zero,
                  blurRadius: 6,
                  color: node.color.withOpacity(0.5),
                ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Position label offset from star
      final labelOffset = isSelected ? const Offset(16, -12) : const Offset(12, -8);
      final labelPos = pos + labelOffset;
      
      // Ensure label stays within bounds
      final adjustedPos = Offset(
        labelPos.dx.clamp(0, 400 - textPainter.width), // Use reasonable bounds
        labelPos.dy.clamp(textPainter.height, 600),
      );
      
      textPainter.paint(canvas, adjustedPos);
    }
  }

  @override
  bool hitTest(Offset position) {
    if (onNodeTapped == null) return false;
    
    // Test each star for tap hits
    for (final node in nodes) {
      final center = Offset(200, 300); // Use reasonable center coordinates
      final starPos = center + node.pos;
      
      // Expand hit area for better touch interaction
      final hitRadius = math.max(node.radius * 2, 20.0);
      
      if ((position - starPos).distance <= hitRadius) {
        onNodeTapped!(node.id);
        return true;
      }
    }
    
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! ConstellationPainter) return true;
    
    return twinkleValue != oldDelegate.twinkleValue ||
           fadeInValue != oldDelegate.fadeInValue ||
           selectedNodeId != oldDelegate.selectedNodeId ||
           selectionPulse != oldDelegate.selectionPulse ||
           showLabels != oldDelegate.showLabels ||
           lineOpacity != oldDelegate.lineOpacity ||
           glowIntensity != oldDelegate.glowIntensity;
  }
}

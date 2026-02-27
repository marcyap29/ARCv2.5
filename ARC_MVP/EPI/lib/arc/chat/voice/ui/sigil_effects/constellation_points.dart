/// Constellation Points
/// 
/// CustomPainter that renders pulsing dots at intersection nodes.
/// These appear during the THINKING state to show LUMARA processing.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sigil_path_utils.dart';

/// Constellation Points Painter
class ConstellationPoints extends CustomPainter {
  final Color phaseColor;
  final double animationValue; // 0.0 to 1.0, loops
  final double intensity; // Overall intensity multiplier
  
  ConstellationPoints({
    required this.phaseColor,
    required this.animationValue,
    this.intensity = 1.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final nodes = SigilPath.getIntersectionNodes(size);
    
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      
      // Stagger the pulse for each node
      final pulseOffset = i * 0.1;
      final pulsePhase = (animationValue + pulseOffset) % 1.0;
      
      // Pulse effect: expand and fade
      final pulseFactor = math.sin(pulsePhase * math.pi);
      final nodeOpacity = 0.3 + pulseFactor * 0.7 * intensity;
      final nodeSize = 3 + pulseFactor * 3;
      
      // Core point
      final corePaint = Paint()
        ..color = phaseColor.withOpacity(nodeOpacity * 0.9)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(node, nodeSize, corePaint);
      
      // Glow ring
      final glowPaint = Paint()
        ..color = phaseColor.withOpacity(nodeOpacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(node, nodeSize + 4 + pulseFactor * 2, glowPaint);
      
      // Outer halo (only for center node and during strong pulse)
      if (i == 0 && pulseFactor > 0.5) {
        final haloPaint = Paint()
          ..color = phaseColor.withOpacity(nodeOpacity * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        
        canvas.drawCircle(node, nodeSize + 10 + pulseFactor * 5, haloPaint);
      }
    }
    
    // Draw connecting lines between nearby nodes (constellation effect)
    _drawConstellationLines(canvas, size, nodes);
  }
  
  void _drawConstellationLines(Canvas canvas, Size size, List<Offset> nodes) {
    final center = nodes[0];
    final maxDistance = size.width * 0.25;
    
    final linePaint = Paint()
      ..color = phaseColor.withOpacity(0.15 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // Connect center to inner ring
    for (int i = 1; i <= 6; i++) {
      // Animated opacity for connection lines
      final linePhase = (animationValue + i * 0.05) % 1.0;
      final lineOpacity = 0.1 + math.sin(linePhase * math.pi) * 0.15;
      
      final animatedLinePaint = Paint()
        ..color = phaseColor.withOpacity(lineOpacity * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      canvas.drawLine(center, nodes[i], animatedLinePaint);
    }
    
    // Connect inner ring to outer ring
    for (int i = 1; i <= 6; i++) {
      final innerNode = nodes[i];
      final outerNode = nodes[i + 6];
      
      final linePhase = (animationValue + (i + 6) * 0.05) % 1.0;
      final lineOpacity = 0.1 + math.sin(linePhase * math.pi) * 0.1;
      
      final animatedLinePaint = Paint()
        ..color = phaseColor.withOpacity(lineOpacity * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      canvas.drawLine(innerNode, outerNode, animatedLinePaint);
    }
    
    // Connect outer ring nodes to adjacent nodes
    for (int i = 7; i <= 12; i++) {
      final node1 = nodes[i];
      final node2Index = i == 12 ? 7 : i + 1;
      final node2 = nodes[node2Index];
      
      final linePhase = (animationValue + i * 0.03) % 1.0;
      final lineOpacity = 0.05 + math.sin(linePhase * math.pi) * 0.1;
      
      final animatedLinePaint = Paint()
        ..color = phaseColor.withOpacity(lineOpacity * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      canvas.drawLine(node1, node2, animatedLinePaint);
    }
  }
  
  @override
  bool shouldRepaint(ConstellationPoints oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.phaseColor != phaseColor ||
           oldDelegate.intensity != intensity;
  }
}

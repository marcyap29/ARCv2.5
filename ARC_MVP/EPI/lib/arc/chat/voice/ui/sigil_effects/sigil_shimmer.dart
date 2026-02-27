/// Sigil Shimmer Effect
/// 
/// CustomPainter that renders a traveling light effect along the sigil paths.
/// Creates an ethereal, living quality to the sigil.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../voice_sigil.dart';

/// Sigil Shimmer Painter
class SigilShimmer extends CustomPainter {
  final VoiceSigilState state;
  final Color phaseColor;
  final double animationValue; // 0.0 to 1.0, loops
  
  SigilShimmer({
    required this.state,
    required this.phaseColor,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.4;
    
    // Determine shimmer intensity based on state
    double intensity;
    double speed;
    
    switch (state) {
      case VoiceSigilState.idle:
        intensity = 0.3;
        speed = 0.5;
        break;
      case VoiceSigilState.listening:
        intensity = 0.6;
        speed = 1.0;
        break;
      case VoiceSigilState.commitment:
        intensity = 0.7;
        speed = 1.2;
        break;
      case VoiceSigilState.accelerating:
        intensity = 0.9;
        speed = 2.0;
        break;
      case VoiceSigilState.thinking:
        intensity = 0.5;
        speed = 0.8;
        break;
      case VoiceSigilState.speaking:
        intensity = 0.8;
        speed = 1.5;
        break;
    }
    
    // Draw shimmer along each path
    for (int i = 0; i < 6; i++) {
      final baseAngle = (i * 60 - 90) * math.pi / 180;
      
      // Calculate shimmer position along path
      final shimmerProgress = ((animationValue * speed) + i * 0.1) % 1.0;
      
      // Shimmer travels from outer to center and back
      final shimmerDistance = state == VoiceSigilState.speaking
          ? outerRadius * shimmerProgress // Outward
          : outerRadius * (1 - shimmerProgress); // Inward
      
      final shimmerPos = Offset(
        center.dx + shimmerDistance * math.cos(baseAngle),
        center.dy + shimmerDistance * math.sin(baseAngle),
      );
      
      // Draw shimmer point with gradient
      final shimmerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            phaseColor.withOpacity(intensity * 0.8),
            phaseColor.withOpacity(intensity * 0.3),
            phaseColor.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: shimmerPos, radius: 12));
      
      canvas.drawCircle(shimmerPos, 12, shimmerPaint);
      
      // Draw trailing effect
      const trailCount = 3;
      for (int j = 1; j <= trailCount; j++) {
        final trailProgress = (shimmerProgress - j * 0.05).clamp(0.0, 1.0);
        final trailDistance = state == VoiceSigilState.speaking
            ? outerRadius * trailProgress
            : outerRadius * (1 - trailProgress);
        
        final trailPos = Offset(
          center.dx + trailDistance * math.cos(baseAngle),
          center.dy + trailDistance * math.sin(baseAngle),
        );
        
        final trailOpacity = intensity * (1 - j / (trailCount + 1)) * 0.5;
        final trailPaint = Paint()
          ..color = phaseColor.withOpacity(trailOpacity)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(trailPos, 6 - j * 1.5, trailPaint);
      }
    }
    
    // Draw connecting shimmer between outer points
    for (int i = 0; i < 6; i++) {
      final angle1 = (i * 60 - 90) * math.pi / 180;
      final angle2 = ((i + 1) % 6 * 60 - 90) * math.pi / 180;
      
      final point1 = Offset(
        center.dx + outerRadius * math.cos(angle1),
        center.dy + outerRadius * math.sin(angle1),
      );
      final point2 = Offset(
        center.dx + outerRadius * math.cos(angle2),
        center.dy + outerRadius * math.sin(angle2),
      );
      
      // Shimmer along edge
      final edgeProgress = ((animationValue * speed * 0.7) + i * 0.15) % 1.0;
      final edgeShimmerPos = Offset(
        point1.dx + (point2.dx - point1.dx) * edgeProgress,
        point1.dy + (point2.dy - point1.dy) * edgeProgress,
      );
      
      final edgePaint = Paint()
        ..color = phaseColor.withOpacity(intensity * 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(edgeShimmerPos, 5, edgePaint);
    }
  }
  
  @override
  bool shouldRepaint(SigilShimmer oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.state != state ||
           oldDelegate.phaseColor != phaseColor;
  }
}

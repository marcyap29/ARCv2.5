/// Commitment Ring Painter
/// 
/// Custom painter for visual countdown showing commitment to end turn
/// - Inner ring contracts inward as silence duration increases
/// - Opacity increases to show commitment level
/// - Smooth animations for natural feel
/// - Phase-adaptive colors
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Commitment Ring Painter
/// 
/// Draws an inner contracting ring that visualizes the endpoint commitment level
class CommitmentRingPainter extends CustomPainter {
  final double commitmentLevel; // 0.0 (no commitment) to 1.0 (about to commit)
  final bool isShowingIntent;
  final Color phaseColor;
  final double strokeWidth;
  
  const CommitmentRingPainter({
    required this.commitmentLevel,
    required this.isShowingIntent,
    required this.phaseColor,
    this.strokeWidth = 3.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isShowingIntent || commitmentLevel <= 0.0) {
      return; // Don't draw if not showing commitment
    }
    
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.25;
    
    // Calculate current radius (contracts inward)
    // When commitmentLevel = 0.0: radius = maxRadius
    // When commitmentLevel = 1.0: radius = maxRadius * 0.3 (shrinks to 30% of max)
    const minRadiusScale = 0.3;
    final radiusScale = 1.0 - (commitmentLevel * (1.0 - minRadiusScale));
    final currentRadius = maxRadius * radiusScale;
    
    // Calculate opacity (increases with commitment)
    // Start at 0.3, go up to 0.8
    final opacity = 0.3 + (commitmentLevel * 0.5);
    
    // Draw contracting ring
    final ringPaint = Paint()
      ..color = phaseColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, currentRadius, ringPaint);
    
    // Draw subtle inner glow
    if (commitmentLevel > 0.5) {
      final glowPaint = Paint()
        ..color = phaseColor.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(center, currentRadius, glowPaint);
    }
    
    // Draw pulsing dots at high commitment (> 0.8)
    if (commitmentLevel > 0.8) {
      _drawCommitmentDots(canvas, center, currentRadius, phaseColor, opacity);
    }
  }
  
  /// Draw pulsing dots around the ring at high commitment
  void _drawCommitmentDots(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final dotPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    
    const dotCount = 4;
    final dotRadius = 3.0 + (commitmentLevel * 2.0); // Grows with commitment
    
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * math.pi;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }
  }
  
  @override
  bool shouldRepaint(CommitmentRingPainter oldDelegate) {
    return oldDelegate.commitmentLevel != commitmentLevel ||
           oldDelegate.isShowingIntent != isShowingIntent ||
           oldDelegate.phaseColor != phaseColor;
  }
}

/// Shimmer Painter (for accelerating phase)
/// 
/// Draws accelerating shimmer effect when commitment level is high
class ShimmerPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0 animation progress
  final Color phaseColor;
  final bool isAccelerating;
  
  const ShimmerPainter({
    required this.animationValue,
    required this.phaseColor,
    required this.isAccelerating,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isAccelerating) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    
    // Create accelerating ripples
    const rippleCount = 3;
    
    for (int i = 0; i < rippleCount; i++) {
      final rippleProgress = (animationValue + (i * 0.33)) % 1.0;
      final rippleRadius = radius * (0.8 + (rippleProgress * 0.4));
      final rippleOpacity = (1.0 - rippleProgress) * 0.4;
      
      final ripplePaint = Paint()
        ..color = phaseColor.withOpacity(rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }
  }
  
  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.isAccelerating != isAccelerating ||
           oldDelegate.phaseColor != phaseColor;
  }
}

/// Audio Reactive Ripple Painter
/// 
/// Draws ripples that respond to audio levels during listening
class AudioReactiveRipplePainter extends CustomPainter {
  final double audioLevel; // 0.0 to 1.0
  final double animationValue; // For breathing animation
  final Color phaseColor;
  final bool isListening;
  
  const AudioReactiveRipplePainter({
    required this.audioLevel,
    required this.animationValue,
    required this.phaseColor,
    required this.isListening,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.3;
    
    // Base breathing ring
    final breathingRadius = baseRadius * (0.95 + (animationValue * 0.05));
    final breathingPaint = Paint()
      ..color = phaseColor.withOpacity(0.2 + (animationValue * 0.1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, breathingRadius, breathingPaint);
    
    // Audio-reactive rings (only when there's audio)
    if (audioLevel > 0.1) {
      final reactiveRadius = baseRadius * (1.0 + (audioLevel * 0.2));
      final reactivePaint = Paint()
        ..color = phaseColor.withOpacity(0.3 * audioLevel)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 + audioLevel);
      
      canvas.drawCircle(center, reactiveRadius, reactivePaint);
      
      // Second ring for stronger audio
      if (audioLevel > 0.5) {
        final secondRing = reactiveRadius * 1.15;
        final secondPaint = Paint()
          ..color = phaseColor.withOpacity(0.2 * audioLevel)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        
        canvas.drawCircle(center, secondRing, secondPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(AudioReactiveRipplePainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isListening != isListening ||
           oldDelegate.phaseColor != phaseColor;
  }
}

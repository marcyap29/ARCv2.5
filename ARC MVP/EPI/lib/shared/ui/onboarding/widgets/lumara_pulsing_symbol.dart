// lib/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart
// Pulsing LUMARA golden symbol widget

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Pulsing LUMARA symbol with golden texture
/// Pulse via opacity/brightness layers (0.7 → 1.0 → 0.7, 3s cycle)
class LumaraPulsingSymbol extends StatefulWidget {
  final double size;

  const LumaraPulsingSymbol({
    super.key,
    this.size = 120,
  });

  @override
  State<LumaraPulsingSymbol> createState() => _LumaraPulsingSymbolState();
}

class _LumaraPulsingSymbolState extends State<LumaraPulsingSymbol>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // Calculate opacity for pulse (0.7 → 1.0 → 0.7)
        final opacity = _pulseAnimation.value;
        // Create brightness effect (darker when opacity is lower)
        final brightness = opacity;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.3 * opacity),
                blurRadius: 20 * opacity,
                spreadRadius: 5 * opacity,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _LumaraSymbolPainter(
              opacity: opacity,
              brightness: brightness,
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for LUMARA symbol (Celtic knot pattern)
class _LumaraSymbolPainter extends CustomPainter {
  final double opacity;
  final double brightness;

  _LumaraSymbolPainter({
    required this.opacity,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Golden color with opacity and brightness
    final goldenColor = Color.lerp(
      const Color(0xFFD4AF37),
      const Color(0xFFF4D03F),
      brightness,
    )!.withOpacity(opacity);

    final paint = Paint()
      ..color = goldenColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw outer circle
    canvas.drawCircle(center, radius, paint);

    // Draw inner knot pattern (4 interwoven bands)
    final innerRadius = radius * 0.6;
    final bandWidth = radius * 0.15;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (math.pi / 180);
      final startX = center.dx + math.cos(angle) * innerRadius;
      final startY = center.dy + math.sin(angle) * innerRadius;
      final endX = center.dx - math.cos(angle) * innerRadius;
      final endY = center.dy - math.sin(angle) * innerRadius;

      // Draw curved band
      final path = Path();
      path.moveTo(startX, startY);
      path.quadraticBezierTo(
        center.dx,
        center.dy,
        endX,
        endY,
      );

      canvas.drawPath(path, paint);
    }

    // Draw central intersection
    canvas.drawCircle(center, bandWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _LumaraSymbolPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.brightness != brightness;
  }
}

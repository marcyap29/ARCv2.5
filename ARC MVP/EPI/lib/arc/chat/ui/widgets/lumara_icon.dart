import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom LUMARA icon widget featuring the golden geometric symbol
class LumaraIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const LumaraIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return CustomPaint(
      size: Size(size, size),
      painter: _LumaraIconPainter(
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _LumaraIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _LumaraIconPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw the outer circle
    canvas.drawCircle(center, radius, paint);

    // Draw the inner interlocking pattern - four overlapping circles
    // This creates the beautiful geometric pattern from the golden symbol
    final innerRadius = radius * 0.45;
    final offset = radius * 0.25;

    // Draw four interlocking circles positioned at cardinal directions
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (math.pi / 180); // Convert to radians

      final circleCenter = Offset(
        center.dx + offset * math.cos(angle),
        center.dy + offset * math.sin(angle),
      );

      canvas.drawCircle(circleCenter, innerRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
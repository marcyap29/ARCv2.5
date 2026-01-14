// lib/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart
// Pulsing LUMARA golden symbol widget

import 'package:flutter/material.dart';

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

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.3 * opacity),
                blurRadius: 20 * opacity,
                spreadRadius: 5 * opacity,
              ),
            ],
          ),
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              'assets/images/LUMARA_Symbol-Final.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to a simple icon if image not found
                return Icon(
                  Icons.psychology,
                  size: widget.size,
                  color: const Color(0xFFD4AF37),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

/// Floating Action Button for LUMARA with idle animations and nudge effects
class LumaraFab extends StatefulWidget {
  final VoidCallback onTap;
  final bool nudge; // true when user typed ≥ threshold or tapped Continue
  final bool reducedMotion;

  const LumaraFab({
    super.key,
    required this.onTap,
    this.nudge = false,
    this.reducedMotion = false,
  });

  @override
  State<LumaraFab> createState() => _LumaraFabState();
}

class _LumaraFabState extends State<LumaraFab> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _nudge;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.05,
    );

    _scale = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _offset = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _nudge, curve: Curves.easeOut));

    if (!widget.reducedMotion) _startIdlePulse();
  }

  void _startIdlePulse() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 7));
      if (!mounted || widget.reducedMotion) break;
      await _pulse.forward();
      await _pulse.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant LumaraFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nudge && !_nudge.isAnimating && !widget.reducedMotion) {
      _nudge.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton(
      heroTag: 'lumara_fab',
      onPressed: widget.onTap,
      tooltip: 'Reflect with LUMARA',
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 24,
      ),
    );

    return SlideTransition(
      position: _offset,
      child: ScaleTransition(scale: _scale, child: fab),
    );
  }
}

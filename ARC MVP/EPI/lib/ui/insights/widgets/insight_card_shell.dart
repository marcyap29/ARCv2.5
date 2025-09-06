import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class InsightCardShell extends StatelessWidget {
  const InsightCardShell({super.key, required this.child, this.radius = 20});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ClipRRect(                         // ← contains EVERYTHING inside the card
          borderRadius: br,
          child: Stack(
            clipBehavior: Clip.hardEdge,          // ← stop leaks
            children: [
              // purely decorative gradient
              const ExcludeSemantics(child: IgnorePointer(child: _CardGradient())),
              // any blur must be both clipped and excluded
              ExcludeSemantics(
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(), // Use Container instead of SizedBox.expand()
                    ),
                  ),
                ),
              ),
              // real content only below
              Material(color: Colors.transparent, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardGradient extends StatelessWidget {
  const _CardGradient();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0x332A6CF3), Color(0x332AF398)],
          ),
        ),
        child: Container(), // Use Container instead of SizedBox.expand()
      );
}

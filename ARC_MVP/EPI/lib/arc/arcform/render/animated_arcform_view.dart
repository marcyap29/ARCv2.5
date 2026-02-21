import 'package:flutter/material.dart';

import '../../ui/arcforms/constellation/constellation_arcform_renderer.dart';

/// Animated wrapper around ConstellationArcformRenderer.
///
/// - First load: dramatic reveal (fade in + slight zoom + rise).
/// - On change (phase or keywords): cross-fade and scale between old and new
///   constellations so it feels like one Arcform morphing into another.
///
/// This does not modify ConstellationArcformRenderer. It only wraps it.
class AnimatedArcformView extends StatelessWidget {
  final AtlasPhase phase;
  final List<KeywordScore> keywords;
  final EmotionPalette palette;
  final int seed;
  final bool reducedMotion;
  final bool showLabels;
  final double density;
  final double lineOpacity;
  final double glowIntensity;
  final Function(String)? onNodeTapped;
  final VoidCallback? onExport;

  const AnimatedArcformView({
    super.key,
    required this.phase,
    required this.keywords,
    required this.palette,
    required this.seed,
    this.reducedMotion = false,
    this.showLabels = true,
    this.density = 0.6,
    this.lineOpacity = 0.25,
    this.glowIntensity = 0.7,
    this.onNodeTapped,
    this.onExport,
  });

  /// Build a stable key that changes only when the meaningfully visible
  /// Arcform changes (phase or keyword mix).
  ///
  /// This is what tells AnimatedSwitcher that "this is now a new child".
  String _buildConstellationKey() {
    final buffer = StringBuffer(phase.toString());

    // Only use a light fingerprint, we do not need perfect hashing.
    for (final k in keywords.take(12)) {
      buffer
        ..write('|')
        ..write(k.text)
        ..write(':')
        ..write(k.score.toStringAsFixed(2));
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // If user has reduced motion enabled, skip the fancy transitions.
    if (reducedMotion) {
      return ConstellationArcformRenderer(
        key: ValueKey(_buildConstellationKey()),
        phase: phase,
        keywords: keywords,
        palette: palette,
        seed: seed,
        reducedMotion: true,
        showLabels: showLabels,
        density: density,
        lineOpacity: lineOpacity,
        glowIntensity: glowIntensity,
        onNodeTapped: onNodeTapped,
        onExport: onExport,
      );
    }

    final childKey = ValueKey(_buildConstellationKey());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1100),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        // Stack old and new so they cross-fade cleanly.
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        // Incoming children: fade in, scale up slightly, and rise.
        // Outgoing children get the reverse automatically.
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        final scale = Tween<double>(
          begin: 0.88,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        final offset = Tween<Offset>(
          begin: const Offset(0.0, 0.06),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: offset,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: ConstellationArcformRenderer(
        key: childKey,
        phase: phase,
        keywords: keywords,
        palette: palette,
        seed: seed,
        reducedMotion: reducedMotion,
        showLabels: showLabels,
        density: density,
        lineOpacity: lineOpacity,
        glowIntensity: glowIntensity,
        onNodeTapped: onNodeTapped,
        onExport: onExport,
      ),
    );
  }
}

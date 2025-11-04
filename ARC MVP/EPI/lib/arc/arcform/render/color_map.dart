// lib/arcform/render/color_map.dart
// Sentiment-aware color mapping for 3D constellation nodes

import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import '../util/seeded.dart';
import '../models/arcform_models.dart';

/// Map valence (-1..1) to RGB color with warm/cool hues
/// Positive valence → warm colors (orange/pink/red)
/// Negative valence → cool colors (blue/cyan/purple)
/// Neutral → lavender/purple transition
vm.Vector3 arcRgb({
  required double valence, // -1..1
  required Seeded rng,
  required ArcformSkin skin,
}) {
  // Clamp valence to valid range
  valence = valence.clamp(-1.0, 1.0);

  // Base hue calculation with warm/cool mapping
  double baseHue;
  if (valence >= 0) {
    // Warm band: 280°→360°→18° (0.78→1.0→0.05 in normalized hue)
    // Map valence 0..1 to this wrapped range
    final warmRange = valence * (0.05 + 0.22); // 0.27 total range
    baseHue = 0.78 + warmRange + skin.warmBias;
    // Handle wrap-around
    if (baseHue > 1.0) baseHue -= 1.0;
  } else {
    // Cool band: 200°–230° (0.56–0.64 in normalized hue)
    // Map valence -1..0 to this range
    final coolPosition = (valence + 1.0) / 2.0; // 0..1
    baseHue = 0.56 + (coolPosition * 0.08) + skin.coolBias;
  }

  // Apply per-node hue jitter
  final hueJitter = (rng.nextDouble() - 0.5) * 2.0 * skin.hueJitter;
  double finalHue = (baseHue + hueJitter).clamp(0.0, 1.0);

  // Slight saturation and lightness variations for uniqueness
  final baseSaturation = 0.7 + rng.nextDouble() * 0.2; // 0.7-0.9
  final saturationJitter = (rng.nextDouble() - 0.5) * 0.1;
  final saturation = (baseSaturation + saturationJitter).clamp(0.5, 1.0);

  final baseLightness = 0.5 + rng.nextDouble() * 0.15; // 0.5-0.65
  final lightnessJitter = (rng.nextDouble() - 0.5) * 0.1;
  final lightness = (baseLightness + lightnessJitter).clamp(0.4, 0.7);

  // Convert HSL to RGB
  return hslToRgb(finalHue, saturation, lightness);
}

/// Convert HSL to RGB (linear RGB in 0..1 range)
vm.Vector3 hslToRgb(double h, double s, double l) {
  // Ensure values are in valid ranges
  h = h.clamp(0.0, 1.0);
  s = s.clamp(0.0, 1.0);
  l = l.clamp(0.0, 1.0);

  if (s == 0.0) {
    // Achromatic (grey)
    return vm.Vector3(l, l, l);
  }

  double hue2rgb(double p, double q, double t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
  }

  final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
  final p = 2.0 * l - q;

  final r = hue2rgb(p, q, h + 1.0 / 3.0);
  final g = hue2rgb(p, q, h);
  final b = hue2rgb(p, q, h - 1.0 / 3.0);

  return vm.Vector3(r, g, b);
}

/// Generate color for edge with jitter
vm.Vector3 arcEdgeColor({
  required vm.Vector3 baseColor,
  required Seeded rng,
  required ArcformSkin skin,
}) {
  // Convert RGB to HSL
  final hsl = rgbToHsl(baseColor);
  
  // Apply line hue jitter
  final jitter = (rng.nextDouble() - 0.5) * 2.0 * skin.lineHueJitter;
  final newHue = (hsl.x + jitter).clamp(0.0, 1.0);
  
  // Slightly reduce saturation and lightness for edges
  final newSat = (hsl.y * 0.9).clamp(0.0, 1.0);
  final newLight = (hsl.z * 0.95).clamp(0.0, 1.0);
  
  return hslToRgb(newHue, newSat, newLight);
}

/// Convert RGB to HSL
vm.Vector3 rgbToHsl(vm.Vector3 rgb) {
  final r = rgb.x.clamp(0.0, 1.0);
  final g = rgb.y.clamp(0.0, 1.0);
  final b = rgb.z.clamp(0.0, 1.0);

  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final delta = max - min;

  // Lightness
  final l = (max + min) / 2.0;

  if (delta == 0.0) {
    // Achromatic
    return vm.Vector3(0.0, 0.0, l);
  }

  // Saturation
  final s = l > 0.5 ? delta / (2.0 - max - min) : delta / (max + min);

  // Hue
  double h;
  if (max == r) {
    h = ((g - b) / delta + (g < b ? 6.0 : 0.0)) / 6.0;
  } else if (max == g) {
    h = ((b - r) / delta + 2.0) / 6.0;
  } else {
    h = ((r - g) / delta + 4.0) / 6.0;
  }

  return vm.Vector3(h, s, l);
}

/// Interpolate between two colors
vm.Vector3 lerpColor(vm.Vector3 a, vm.Vector3 b, double t) {
  t = t.clamp(0.0, 1.0);
  return vm.Vector3(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
  );
}

/// Generate gradient colors for multi-node visualization
List<vm.Vector3> generateGradient({
  required int count,
  required double startValence,
  required double endValence,
  required Seeded rng,
  required ArcformSkin skin,
}) {
  final colors = <vm.Vector3>[];
  for (int i = 0; i < count; i++) {
    final t = count > 1 ? i / (count - 1) : 0.5;
    final valence = startValence + (endValence - startValence) * t;
    final childRng = rng.derive('gradient_$i');
    colors.add(arcRgb(valence: valence, rng: childRng, skin: skin));
  }
  return colors;
}


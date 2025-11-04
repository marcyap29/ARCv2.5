# Constellation Arcform Renderer - Polar Layout Visualization System

**Last Updated:** October 10, 2025
**Status:** Production Ready ✅
**Module:** Arcforms (Visualization Layer)
**Location:** `lib/features/arcforms/constellation/`

## Overview

The **Constellation Arcform Renderer** is EPI's advanced visualization system that transforms journal keywords into dynamic, phase-aware constellation patterns using **polar coordinate layouts**. Each ATLAS phase maps to a unique geometric pattern (spiral, flower, weave, glow core, fractal, branch), creating an intuitive visual representation of the user's mental landscape.

## Table of Contents

1. [Architecture](#architecture)
2. [Phase-Specific Layouts](#phase-specific-layouts)
3. [Animation System](#animation-system)
4. [Layout Algorithm](#layout-algorithm)
5. [Emotion Palette](#emotion-palette)
6. [Usage Examples](#usage-examples)
7. [Technical Reference](#technical-reference)

---

## Architecture

### Module Structure

```
lib/features/arcforms/constellation/
├── constellation_arcform_renderer.dart  # Main widget and models (346 lines)
├── constellation_layout_service.dart    # Polar layout algorithms (464 lines)
├── constellation_painter.dart           # Custom canvas painter
├── constellation_demo.dart              # Demo/testing widget
├── graph_utils.dart                     # k-NN and graph utilities
└── polar_masks.dart                     # Polar coordinate masks
```

### Core Components

#### 1. **ConstellationArcformRenderer** (Main Widget)
- Stateful widget with animation controllers
- Manages constellation lifecycle
- Handles user interactions (tap, double-tap)
- Integrates with ATLAS phase system

#### 2. **ConstellationLayoutService** (Layout Engine)
- Phase-specific polar coordinate generation
- k-Nearest Neighbors (k-NN) edge weaving
- Collision avoidance
- Satellite positioning

#### 3. **ConstellationPainter** (Rendering Engine)
- Custom canvas painting
- Glow effects and animations
- Label rendering
- Interaction hit detection

#### 4. **EmotionalValenceService** (Color Mapping)
- Keyword → emotion mapping
- Sentiment analysis
- Color palette selection

---

## Phase-Specific Layouts

Each ATLAS phase has a unique geometric pattern generated using polar coordinate masks:

### 1. Discovery Phase (Spiral)

**Geometry**: Fibonacci spiral with golden angle
**k-NN Value**: 2 (light connections)
**Characteristics**: Outward expansion, gentle drift

```dart
// Spiral generation
const goldenAngle = 2.39996322972865332; // 137.5°
for (int i = 0; i < count; i++) {
  final angle = i * goldenAngle;
  final radius = (i / (count - 1)) * maxRadius;

  final x = radius * cos(angle);
  final y = radius * sin(angle);

  // Add gentle outward drift
  final drift = random.nextDouble() * 20.0 - 10.0;
  positions.add(Offset(x + drift, y + drift));
}
```

**Visual Effect**: Keywords spiral outward from center, reflecting exploration and curiosity

---

### 2. Expansion Phase (Flower)

**Geometry**: 6-petal radial layout
**k-NN Value**: 3 (stronger connections)
**Characteristics**: Branching blooms, petal distribution

```dart
// Flower generation
const petals = 6;
for (int i = 0; i < count; i++) {
  final petalIndex = i % petals;
  final petalAngle = (petalIndex / petals) * 2 * pi;

  // Vary radius within petal
  final radius = (random.nextDouble() * 0.7 + 0.3) * maxRadius;

  // Add randomness to petal shape
  final angleOffset = (random.nextDouble() - 0.5) * 0.5;
  final angle = petalAngle + angleOffset;

  positions.add(Offset(radius * cos(angle), radius * sin(angle)));
}
```

**Visual Effect**: Keywords bloom outward in 6 distinct petals, reflecting growth and branching

---

### 3. Transition Phase (Branch)

**Geometry**: 3-branch layout with side shoots
**k-NN Value**: 2 (moderate connections)
**Characteristics**: Directional growth, side shoots

```dart
// Branch generation
const mainBranches = 3;
for (int i = 0; i < count; i++) {
  final branchIndex = i % mainBranches;
  final branchAngle = (branchIndex / mainBranches) * 2 * pi;

  // Create longer arcs with side shoots
  final t = random.nextDouble();
  final radius = t * maxRadius;

  // Add side shoot variation (30% chance)
  final sideShoot = random.nextDouble() > 0.7;
  final angle = sideShoot
      ? branchAngle + (random.nextDouble() - 0.5) * 1.0
      : branchAngle;

  positions.add(Offset(radius * cos(angle), radius * sin(angle)));
}
```

**Visual Effect**: Keywords form 3 main branches with occasional side shoots, reflecting directional change

---

### 4. Consolidation Phase (Weave)

**Geometry**: Inner lattice with tight radii
**k-NN Value**: 4 (strongest connections)
**Characteristics**: Dense core, lattice-like distribution

```dart
// Weave generation
const innerRadius = 40.0;
const outerRadius = 100.0;
for (int i = 0; i < count; i++) {
  // Create inner lattice bias
  final t = random.nextDouble();
  final radius = innerRadius + t * (outerRadius - innerRadius);

  // Lattice-like angular distribution
  final angle = (i * 2 * pi / count) + (random.nextDouble() - 0.5) * 0.5;

  positions.add(Offset(radius * cos(angle), radius * sin(angle)));
}
```

**Visual Effect**: Keywords weave tightly together, reflecting coherence and consolidation

---

### 5. Recovery Phase (Glow Core)

**Geometry**: Bright centroid with sparse outliers
**k-NN Value**: 1 (minimal connections)
**Characteristics**: Central glow, dim satellites

```dart
// Glow core generation
const coreRadius = 30.0;
for (int i = 0; i < count; i++) {
  if (i == 0) {
    // Bright centroid at origin
    positions.add(Offset.zero);
  } else {
    // Sparse dim outliers
    final angle = random.nextDouble() * 2 * pi;
    final radius = coreRadius + random.nextDouble() * (maxRadius - coreRadius);

    positions.add(Offset(radius * cos(angle), radius * sin(angle)));
  }
}
```

**Visual Effect**: Single bright center with scattered outliers, reflecting rest and containment

---

### 6. Breakthrough Phase (Fractal)

**Geometry**: 3-cluster bursts with bridges
**k-NN Value**: 3 (balanced connections)
**Characteristics**: Clustered bursts, bridging

```dart
// Fractal generation
const clusters = 3;
for (int i = 0; i < count; i++) {
  final clusterIndex = i % clusters;
  final clusterAngle = (clusterIndex / clusters) * 2 * pi;

  // Create clustered bursts
  final clusterCenter = Offset(
    clusterRadius * cos(clusterAngle),
    clusterRadius * sin(clusterAngle),
  );

  // Add bridges between clusters
  final t = random.nextDouble();
  final radius = t * (maxRadius - clusterRadius);
  final angle = random.nextDouble() * 2 * pi;

  final offset = Offset(radius * cos(angle), radius * sin(angle));
  positions.add(clusterCenter + offset);
}
```

**Visual Effect**: Keywords cluster in 3 bursts connected by bridges, reflecting sudden insights

---

## Animation System

The constellation uses **three independent animation controllers**:

### 1. Twinkle Animation (3 seconds, repeating)

```dart
_twinkleController = AnimationController(
  duration: const Duration(seconds: 3),
  vsync: this,
);

if (!widget.reducedMotion) {
  _twinkleController.repeat(reverse: true);
}
```

**Effect**: Stars subtly pulse in brightness, creating a "twinkling" effect

### 2. Fade-In Animation (600ms, once)

```dart
_fadeInController = AnimationController(
  duration: const Duration(milliseconds: 600),
  vsync: this,
);

_fadeInController.forward();
```

**Effect**: Constellation fades in smoothly when first rendered

### 3. Selection Pulse Animation (800ms, on-demand)

```dart
_selectionPulseController = AnimationController(
  duration: const Duration(milliseconds: 800),
  vsync: this,
);

// Triggered on node tap
_selectionPulseController.forward().then((_) {
  _selectionPulseController.reverse();
});
```

**Effect**: Selected nodes pulse outward with a ring animation

---

## Layout Algorithm

### Node Placement Algorithm

```
1. Sort keywords by score (descending)
2. Take top 10 as primary stars, next 10 as satellites
3. Generate primary positions using phase-specific polar mask
4. Apply collision avoidance (max 10 attempts, 40px threshold)
5. Calculate node radius based on score (4px - 12px range)
6. Assign color based on emotional valence
7. Generate satellite positions around primaries
8. Return ConstellationNode list
```

### Edge Weaving Algorithm (k-NN)

```
1. For each node, find k nearest neighbors
   - k varies by phase (1-4)
2. Calculate edge weight:
   - Base: 1.0 / (1.0 + distance / 50.0)
   - Apply phase multiplier (0.4x - 1.4x)
3. Filter edges by phase-specific threshold
4. Return ConstellationEdge list
```

### Collision Avoidance

```dart
Offset _avoidCollisions(Offset pos, List<ConstellationNode> existingNodes, Random random) {
  Offset finalPos = pos;
  int attempts = 0;
  const maxAttempts = 10;

  while (attempts < maxAttempts) {
    bool hasCollision = false;

    for (final node in existingNodes) {
      final distance = (finalPos - node.pos).distance;
      if (distance < _collisionThreshold) {
        hasCollision = true;
        break;
      }
    }

    if (!hasCollision) break;

    // Nudge position randomly
    final offset = Offset(
      (random.nextDouble() - 0.5) * 20.0,
      (random.nextDouble() - 0.5) * 20.0,
    );
    finalPos = pos + offset;
    attempts++;
  }

  return finalPos;
}
```

---

## Emotion Palette

The constellation uses an **8-color emotion palette** for visual diversity:

### Default Palette

```dart
static const EmotionPalette defaultPalette = EmotionPalette(
  primaryColors: [
    Color(0xFF4F46E5), // Primary blue (positive)
    Color(0xFF7C3AED), // Purple
    Color(0xFFD1B3FF), // Light purple (negative/cool)
    Color(0xFF6BE3A0), // Green
    Color(0xFFF7D774), // Yellow
    Color(0xFFFF6B6B), // Red
    Color(0xFFFF8E53), // Orange
    Color(0xFF4ECDC4), // Teal
  ],
  neutralColor: Color(0xFFD1B3FF),  // Light purple for neutral
  backgroundColor: Color(0xFF0A0A0F), // Deep space black
);
```

### Color Mapping Logic

```dart
Color _getNodeColor(KeywordScore keyword, EmotionPalette palette, EmotionalValenceService emotionalService) {
  final valence = emotionalService.getEmotionalValence(keyword.text);

  if (valence > 0.3) {
    return palette.primaryColors[0]; // Blue (positive)
  } else if (valence < -0.3) {
    return palette.primaryColors[2]; // Light purple (negative)
  } else {
    return palette.neutralColor; // Neutral
  }
}
```

---

## Usage Examples

### Basic Usage

```dart
import 'package:my_app/features/arcforms/constellation/constellation_arcform_renderer.dart';

// Prepare keyword scores
final keywords = [
  KeywordScore(text: 'mindfulness', score: 0.9, sentiment: 0.7),
  KeywordScore(text: 'learning', score: 0.85, sentiment: 0.5),
  KeywordScore(text: 'creativity', score: 0.8, sentiment: 0.6),
  // ... more keywords
];

// Render constellation
Widget build(BuildContext context) {
  return ConstellationArcformRenderer(
    phase: AtlasPhase.discovery,
    keywords: keywords,
    palette: EmotionPalette.defaultPalette,
    seed: DateTime.now().millisecondsSinceEpoch,
    showLabels: true,
    density: 0.6,
    lineOpacity: 0.25,
    glowIntensity: 0.7,
    onNodeTapped: (nodeId) {
      print('Tapped node: $nodeId');
    },
  );
}
```

### Integration with ATLAS Phase

```dart
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';

// Convert ArcformGeometry to AtlasPhase
final geometry = ArcformGeometry.spiral;
final atlasPhase = geometry.toAtlasPhase(); // AtlasPhase.discovery

// Use in constellation
ConstellationArcformRenderer(
  phase: atlasPhase,
  keywords: keywords,
  palette: EmotionPalette.defaultPalette,
  seed: seed,
);
```

### Custom Emotion Palette

```dart
// Create custom palette
const customPalette = EmotionPalette(
  primaryColors: [
    Color(0xFFFF6B6B), // Red
    Color(0xFFFFD93D), // Yellow
    Color(0xFF6BCF7F), // Green
    Color(0xFF4D96FF), // Blue
    Color(0xFF9D4EDD), // Purple
    Color(0xFFFF8E53), // Orange
    Color(0xFFF72585), // Pink
    Color(0xFF4ECDC4), // Teal
  ],
  neutralColor: Color(0xFFCCCCCC),
  backgroundColor: Color(0xFF1A1A2E),
);

// Use custom palette
ConstellationArcformRenderer(
  palette: customPalette,
  // ... other properties
);
```

### Reduced Motion Mode

```dart
// Disable animations for accessibility
ConstellationArcformRenderer(
  reducedMotion: true, // Disables twinkle animation
  // ... other properties
);
```

---

## Technical Reference

### Data Models

#### KeywordScore

```dart
class KeywordScore {
  final String text;      // Keyword text
  final double score;     // Relevance score (0.0 - 1.0)
  final double sentiment; // Sentiment score (-1.0 to 1.0)
}
```

#### ConstellationNode

```dart
class ConstellationNode {
  final Offset pos;           // Position in 2D space
  final KeywordScore data;    // Associated keyword
  final double radius;        // Node size (4px - 12px)
  final Color color;          // Node color
  final String id;            // Unique identifier
}
```

#### ConstellationEdge

```dart
class ConstellationEdge {
  final int a;           // Source node index
  final int b;           // Target node index
  final double weight;   // Connection strength (0.0 - 1.0)
}
```

### Phase Parameters Table

| Phase | k-NN | Edge Weight Multiplier | Edge Threshold Multiplier | Max Radius |
|-------|------|------------------------|---------------------------|------------|
| Discovery | 2 | 0.8x | 0.8x | 150px |
| Expansion | 3 | 1.2x | 0.6x | 120px |
| Transition | 2 | 0.6x | 1.2x | 140px |
| Consolidation | 4 | 1.4x | 0.5x | 100px |
| Recovery | 1 | 0.4x | 1.5x | 120px |
| Breakthrough | 3 | 1.0x | 0.7x | 130px |

### Performance Characteristics

- **Node Count**: 5-20 optimal (10 primary + 10 satellite)
- **Render Time**: < 16ms (60 FPS)
- **Memory Usage**: ~50 KB per constellation
- **Animation Overhead**: Minimal (GPU-accelerated)

---

## Related Documentation

- **EPI Architecture**: `docs/architecture/EPI_Architecture.md`
- **ATLAS Phase Detection**: `docs/architecture/EPI_Architecture.md#atlas-phase-detection`
- **Arcform System**: `lib/features/arcforms/`
- **MIRA Basics**: `docs/architecture/MIRA_Basics.md`

---

**Status:** Production Ready ✅
**Version:** 1.0.0
**Last Updated:** October 10, 2025
**Maintainer:** EPI Development Team

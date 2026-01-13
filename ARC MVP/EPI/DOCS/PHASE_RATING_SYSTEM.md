# Phase Rating System & Health Integration

## Overview

The Phase Rating System provides a 10-100 operational readiness score that combines user mental state (phase) with physical health metrics. This system is designed for military applications where commanders need to understand personnel readiness for duty.

**Key Features:**
- **10-100 Rating Scale**: Lower scores (10-30) indicate need for rest/recovery; higher scores (70-100) indicate readiness for duty
- **Health Integration**: Automatically calculates sleep quality and energy levels from Apple Health data
- **Phase Correlation**: Health data influences phase detection (e.g., poor sleep → Recovery phase)
- **Hybrid Mode**: Supports both automatic (from health data) and manual health input

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Phase Rating System                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  PhaseAwareAnalysisService                                   │
│  ├─ Detects user phase from journal text                     │
│  ├─ Integrates health data into phase scoring                 │
│  └─ Calculates operational readiness score (10-100)          │
│                                                               │
│  HealthDataService                                           │
│  ├─ Auto-detects sleep quality from Apple Health             │
│  ├─ Auto-detects energy level from Apple Health              │
│  └─ Supports manual override                                 │
│                                                               │
│  PhaseRatingRanges                                           │
│  └─ Defines rating ranges for each phase                     │
│                                                               │
│  PhaseRatingService                                          │
│  └─ Centralized rating calculation and interpretation        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase Rating Ranges

Each user phase maps to a specific rating range:

| Phase | Range | Interpretation |
|-------|-------|----------------|
| **Recovery** | 10-25 | Lowest readiness. Personnel needs rest, healing, or medical attention. Not fit for duty. |
| **Transition** | 35-50 | In-between state. Uncertain, uncomfortable, navigating change. Low readiness - may need support. |
| **Discovery** | 50-65 | Active exploration phase. Learning, seeking new things. Moderate readiness - suitable for moderate tasks. |
| **Reflection** | 55-70 | Analysis phase. Contemplative, evaluating. Moderate-high readiness - suitable for moderate operational tasks. |
| **Consolidation** | 70-85 | Integration phase. Stable, organized, structured. High readiness - ready for standard operational duties. |
| **Breakthrough** | 85-100 | Peak performance. Highest readiness - ready for high-stress, critical operations. |

**Note**: Ranges intentionally overlap at boundaries to allow smooth transitions between phases.

---

## Health Data Integration

### Auto-Detection Algorithms

#### Sleep Quality Calculation (0.0 - 1.0)

Sleep quality is calculated from:
- **Sleep Duration**: Primary factor
  - 8+ hours: 0.9
  - 6-8 hours: 0.7
  - 4-6 hours: 0.4
  - <4 hours: 0.2
- **HRV (Heart Rate Variability)**: ±10% adjustment
  - High HRV (>50ms): +0.1
  - Low HRV (<30ms): -0.1
- **Resting Heart Rate**: -10% if elevated
  - Resting HR >75 bpm: -0.1

**Implementation**: `HealthDataService.calculateSleepQuality()`

#### Energy Level Calculation (0.0 - 1.0)

Energy level is calculated from:
- **Steps**: Base score
  - 10,000+ steps: 0.8
  - 5,000-10,000: 0.6
  - 2,500-5,000: 0.4
  - <2,500: 0.3
- **Exercise Time**: +15% bonus
  - 30+ minutes: +0.15
- **Active Calories**: ±5% adjustment
  - >500 kcal: +0.05
  - <200 kcal: -0.05

**Implementation**: `HealthDataService.calculateEnergyLevel()`

### Health-to-Phase Correlation

Health data influences phase detection:

1. **Recovery Phase Boost**:
   - Low sleep quality (<0.4) → +0.15 to Recovery score
   - Low energy level (<0.4) → +0.15 to Recovery score
   - Both low → +0.3 to Recovery score

2. **Breakthrough Phase Boost**:
   - High sleep quality (>0.8) + High energy (>0.8) → +0.1 to Breakthrough score

3. **Consolidation Phase Boost**:
   - Stable health (0.5-0.7 range) → +0.05 to Consolidation score

---

## Rating Calculation

### Base Rating

The base rating is calculated from the detected phase and confidence:

```dart
baseRating = phaseMin + (phaseMax - phaseMin) * confidence
```

Where:
- `phaseMin` / `phaseMax`: From `PhaseRatingRanges` for the detected phase
- `confidence`: Phase detection confidence (0.0-1.0)

### Health Adjustment

The base rating is adjusted based on health data:

```dart
healthFactor = (sleepQuality + energyLevel) / 2.0

if (healthFactor < 0.4) {
  // Poor health: Reduce by up to 20 points
  adjustedRating = baseRating - (20 * (0.4 - healthFactor) / 0.4)
} else if (healthFactor > 0.8) {
  // Excellent health: Boost by up to 10 points (cap at 100)
  adjustedRating = baseRating + (10 * (healthFactor - 0.8) / 0.2)
} else {
  // Moderate health: No adjustment
  adjustedRating = baseRating
}
```

**Final Score**: Clamped to 10-100 range

---

## Data Flow

```
┌─────────────────┐
│ Apple Health    │
│ (iOS)           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Health Import    │
│ (JSON files)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ HealthDataService│
│ getAutoDetected │
│ HealthData()    │
└────────┬────────┘
         │
         ├─► calculateSleepQuality()
         └─► calculateEnergyLevel()
         │
         ▼
┌─────────────────┐
│ HealthData      │
│ (sleepQuality,  │
│  energyLevel)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ PhaseAware      │
│ AnalysisService │
│ analyzePhase()  │
└────────┬────────┘
         │
         ├─► Phase Detection (text analysis)
         ├─► Health Phase Adjustments
         └─► Rating Calculation
         │
         ▼
┌─────────────────┐
│ PhaseContext    │
│ - primaryPhase  │
│ - confidence    │
│ - healthData   │
│ - operational   │
│   ReadinessScore│
└─────────────────┘
```

---

## Usage Examples

### Basic Phase Analysis

```dart
final phaseService = PhaseAwareAnalysisService();
final context = await phaseService.analyzePhase(
  "I'm feeling tired and overwhelmed today. Need to rest.",
);

print('Phase: ${context.primaryPhase}');
print('Readiness Score: ${context.operationalReadinessScore}');
// Output: Phase: recovery, Readiness Score: 18
```

### With Health Data

```dart
// Health data is automatically fetched if available
final context = await phaseService.analyzePhase(
  "Had a breakthrough today! Everything clicked.",
);

// Health data influences both phase detection and rating
if (context.healthData != null) {
  print('Sleep Quality: ${context.healthData!.sleepQuality}');
  print('Energy Level: ${context.healthData!.energyLevel}');
}
print('Readiness Score: ${context.operationalReadinessScore}');
```

### Manual Health Override

```dart
// Manually set health data
await HealthDataService.instance.updateHealthData(
  sleepQuality: 0.3,  // Poor sleep
  energyLevel: 0.4,   // Low energy
);

// This will influence phase detection
final context = await phaseService.analyzePhase(
  "Feeling okay today.",
);
// Even with neutral text, poor health may push toward Recovery phase
```

### Getting Readiness Interpretation

```dart
import 'package:my_app/services/phase_rating_service.dart';

final score = context.operationalReadinessScore;
final interpretation = PhaseRatingService.getReadinessInterpretation(score);
final category = PhaseRatingService.getReadinessCategory(score);

print('Score: $score');
print('Interpretation: $interpretation');
print('Category: $category');
```

---

## API Reference

### PhaseRatingRanges

**Location**: `lib/services/phase_rating_ranges.dart`

```dart
// Get rating range for a phase
Range getRange(String phaseName)

// Get minimum rating
int getMin(String phaseName)

// Get maximum rating
int getMax(String phaseName)

// Calculate rating from phase + confidence
int getRating(String phaseName, double confidence)
```

### HealthDataService

**Location**: `lib/services/health_data_service.dart`

```dart
// Auto-detect health from imported data
Future<HealthData> getAutoDetectedHealthData()

// Calculate sleep quality from metrics
static double calculateSleepQuality({
  required int sleepMin,
  double? hrvSdnn,
  double? restingHr,
})

// Calculate energy level from metrics
static double calculateEnergyLevel({
  required int steps,
  double? activeKcal,
  int? exerciseMin,
})
```

### PhaseAwareAnalysisService

**Location**: `lib/services/phase_aware_analysis_service.dart`

```dart
// Analyze phase with optional health data
Future<PhaseContext> analyzePhase(
  String journalText, {
  HealthData? healthData,
})
```

### PhaseRatingService

**Location**: `lib/services/phase_rating_service.dart`

```dart
// Get readiness score from context
static int calculateReadinessScore(PhaseContext context)

// Get human-readable interpretation
static String getReadinessInterpretation(int score)

// Get readiness category for UI
static ReadinessCategory getReadinessCategory(int score)
```

---

## Commander Dashboard Integration

### Readiness Categories

| Category | Score Range | Color | Interpretation |
|----------|------------|-------|----------------|
| **Excellent** | 85-100 | Green | Peak Performance - Ready for high-stress operations |
| **Good** | 70-84 | Light Green | High Readiness - Ready for standard operational duties |
| **Moderate** | 50-69 | Yellow | Moderate Readiness - Suitable for moderate tasks |
| **Low** | 30-49 | Orange | Low Readiness - May need support or reduced tempo |
| **Critical** | 10-29 | Red | Recovery Needed - Requires rest, medical attention, or reduced duties |

### Alert Thresholds

- **< 30**: Critical alert - Personnel requires immediate attention
- **< 50**: Warning - Personnel may need support
- **≥ 70**: Normal - Personnel ready for duty

---

## Health Data Sources

### Apple Health Import

Health data is imported from Apple Health (iOS) and stored in JSON files organized by month:

- **Location**: `mcp/health/YYYY-MM.json`
- **Format**: One JSON object per line with `type: "health.timeslice.daily"`
- **Data Fields**:
  - `steps`: Daily step count
  - `sleep_min`: Total sleep minutes
  - `active_energy_kcal`: Active calories burned
  - `exercise_min`: Exercise minutes
  - `resting_hr`: Resting heart rate (bpm)
  - `hrv_sdnn`: Heart rate variability (ms)
  - `avg_hr`: Average heart rate (bpm)

### Manual Override

Users can manually set health data via `HealthSettingsDialog`:
- Sleep Quality slider (0.0-1.0)
- Energy Level slider (0.0-1.0)

**Hybrid Mode** (Future):
- Auto mode: Uses imported health data
- Manual mode: User sets sliders
- Override: User can always adjust auto values

---

## Phase History Tracking

Phase history entries now include:
- `operationalReadinessScore`: The calculated 10-100 rating
- `healthData`: Snapshot of health data at time of analysis

**Location**: `lib/prism/atlas/phase/phase_history_repository.dart`

```dart
final entry = PhaseHistoryEntry(
  // ... other fields ...
  operationalReadinessScore: context.operationalReadinessScore,
  healthData: context.healthData?.toJson(),
);
```

---

## Testing

### Unit Tests

Test rating calculations:

```dart
// Test base rating
final baseRating = PhaseRatingRanges.getRating('recovery', 0.5);
expect(baseRating, 17); // (10 + 25) / 2 = 17.5 ≈ 18

// Test health adjustment
final adjusted = PhaseRatingService.calculateHealthAdjustedRating(
  phase: UserPhase.recovery,
  confidence: 0.5,
  healthData: HealthData(sleepQuality: 0.2, energyLevel: 0.3),
);
expect(adjusted, lessThan(17)); // Poor health reduces rating
```

### Integration Tests

Test full flow:

```dart
// Test phase analysis with health
final context = await phaseService.analyzePhase(
  "I'm exhausted and need rest.",
);
expect(context.primaryPhase, UserPhase.recovery);
expect(context.operationalReadinessScore, lessThan(30));
```

---

## Future Enhancements

1. **Hybrid Mode UI**: Toggle between auto/manual health input
2. **Morning Auto-Sync**: Automatically update health data at 8 AM
3. **Health Trends**: Track health patterns over time
4. **Baseline Calculation**: Learn user's normal HRV/HR ranges
5. **Medication Integration**: Factor medication status into ratings
6. **Commander Dashboard**: Visual dashboard showing readiness scores
7. **Alert System**: Notifications for low readiness scores

---

## Related Documentation

- [RIVET Architecture](RIVET_ARCHITECTURE.md) - Phase detection system
- [Health Service](../lib/prism/services/health_service.dart) - Health data import
- [Phase History Repository](../lib/prism/atlas/phase/phase_history_repository.dart) - Historical tracking

---

## Changelog

### 2025-01-09
- Initial implementation of phase rating system
- Health data integration
- Auto-detection algorithms
- Health-to-phase correlation
- Operational readiness score calculation


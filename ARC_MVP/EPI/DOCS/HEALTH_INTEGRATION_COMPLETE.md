# Health Integration - Complete Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Integration](#architecture-integration)
3. [Health Data Flow](#health-data-flow)
4. [Auto-Detection Algorithms](#auto-detection-algorithms)
5. [Health-to-Phase Correlation](#health-to-phase-correlation)
6. [Health-Adjusted Rating](#health-adjusted-rating)
7. [Usage Examples](#usage-examples)
8. [Troubleshooting](#troubleshooting)

---

## Overview

Health data from Apple Health is integrated into the phase rating system to automatically detect sleep quality and energy levels, and how this influences phase detection and operational readiness ratings.

**Core Principle:** Apple Health data should **enhance phase detection confidence** and **detect phase-body misalignment**, not replace the journal-based classification. The body tells a story that sometimes contradicts what we write.

---

## Architecture Integration

### Integration Point

```
Journal Entry → Phase Classifier → Phase Probabilities (0.6 confidence)
                                          ↓
Apple Health Data (last 7 days) → Biometric Analyzer
                                          ↓
                            Biometric Phase Signals
                                          ↓
                    Phase Probability Adjuster
                                          ↓
              Final Phase Classification (0.85 confidence)
                                          ↓
                          RIVET + SENTINEL
```

**Key insight:** Health data doesn't classify phases directly. It validates or challenges the text-based classification, increasing or decreasing confidence.

---

## Health Data Flow

### 1. Import from Apple Health

Health data is imported from Apple Health (iOS) via the `HealthIngest` service:

```dart
final ingest = HealthIngest(health);
final lines = await ingest.importDays(daysBack: 30, uid: 'user_123');
```

**Data Stored**:
- Daily metrics aggregated by day (YYYY-MM-DD)
- Stored in JSON files: `mcp/health/YYYY-MM.json`
- Format: One JSON object per line with `type: "health.timeslice.daily"`

### 2. Auto-Detection

The `HealthDataService` automatically reads the latest health day and calculates:

- **Sleep Quality** (0.0-1.0): From sleep duration, HRV, resting HR
- **Energy Level** (0.0-1.0): From steps, exercise time, active calories

```dart
final healthData = await HealthDataService.instance.getAutoDetectedHealthData();
// Returns HealthData with calculated sleepQuality and energyLevel
```

### 3. Integration with Phase Analysis

Health data is automatically used in phase analysis:

```dart
final context = await PhaseAwareAnalysisService().analyzePhase(
  journalText,
  // healthData is optional - if not provided, auto-detected
);
```

**What Happens**:
1. Health data influences phase detection (poor health → Recovery phase)
2. Health data adjusts operational readiness score
3. Health data is included in `PhaseContext` for tracking

---

## Auto-Detection Algorithms

### Sleep Quality Calculation (0.0 - 1.0)

Sleep quality is calculated from:

#### Input Metrics
- **sleepMin**: Total sleep minutes (from `SLEEP_ASLEEP` data)
- **hrvSdnn**: Heart rate variability in milliseconds (optional)
- **restingHr**: Resting heart rate in bpm (optional)

#### Calculation Steps

1. **Base Score from Sleep Duration**:
   ```
   if sleepMin >= 480 (8+ hours):     baseScore = 0.9
   else if sleepMin >= 360 (6-8 hrs): baseScore = 0.7
   else if sleepMin >= 240 (4-6 hrs): baseScore = 0.4
   else (<4 hours):                   baseScore = 0.2
   ```

2. **HRV Adjustment** (±10%):
   ```
   if hrvSdnn > 50ms:  baseScore += 0.1  (high recovery)
   if hrvSdnn < 30ms:  baseScore -= 0.1  (poor recovery)
   ```

3. **Resting HR Adjustment** (-10% if elevated):
   ```
   if restingHr > 75 bpm:  baseScore -= 0.1  (elevated = poor recovery)
   ```

4. **Final Score**: Clamped to 0.0-1.0

**Implementation**: `HealthDataService.calculateSleepQuality()`

**Example:**
```dart
final sleepQuality = HealthDataService.calculateSleepQuality(
  sleepMin: 270,      // 4.5 hours
  hrvSdnn: 25.0,      // Low HRV
  restingHr: 78.0,    // Elevated
);

// Base: 0.4 (4-6 hours)
// HRV: -0.1 (low)
// Resting HR: -0.1 (elevated)
// Result: 0.2 (poor sleep quality)
```

### Energy Level Calculation (0.0 - 1.0)

Energy level is calculated from:

#### Input Metrics
- **steps**: Daily step count
- **activeKcal**: Active calories burned (optional)
- **exerciseMin**: Exercise minutes (optional)

#### Calculation Steps

1. **Base Score from Steps**:
   ```
   if steps >= 10000:     baseScore = 0.8
   else if steps >= 5000: baseScore = 0.6
   else if steps >= 2500: baseScore = 0.4
   else:                  baseScore = 0.3
   ```

2. **Exercise Bonus** (+15% if 30+ min):
   ```
   if exerciseMin >= 30:  baseScore += 0.15
   ```

3. **Active Calories Adjustment** (±5%):
   ```
   if activeKcal > 500:   baseScore += 0.05
   if activeKcal < 200:   baseScore -= 0.05
   ```

4. **Final Score**: Clamped to 0.0-1.0

**Implementation**: `HealthDataService.calculateEnergyLevel()`

**Example:**
```dart
final energyLevel = HealthDataService.calculateEnergyLevel(
  steps: 3500,
  activeKcal: 450.0,
  exerciseMin: 45,
);

// Base: 0.4 (2,500-5,000 steps)
// Exercise: +0.15 (45 min)
// Calories: +0.05 (>500)
// Result: 0.6 (moderate energy)
```

---

## Apple Health Data Points to Track

### Tier 1: High Signal (Direct Phase Indicators)

**Sleep Data:**
- Hours slept per night
- Sleep consistency (bedtime variance)
- Sleep quality (deep/REM percentages if available)
- Wake-up count

**Activity Data:**
- Active energy burned
- Exercise minutes
- Step count
- Sedentary hours

**Heart Rate Variability (HRV):**
- Resting heart rate
- HRV (autonomic nervous system indicator)
- Heart rate during day

### Tier 2: Medium Signal (Contextual Indicators)

**Mindfulness/Mental Health:**
- Meditation minutes
- Time in daylight
- Mindful minutes logged

**Body Metrics:**
- Weight trends (if tracked)
- Body temperature (illness detection)

### Tier 3: Low Signal (Nice to Have)

**Nutrition:**
- Water intake
- Caffeine consumption

**Environmental:**
- Time outdoors
- Audio exposure levels

---

## Biometric Signatures by Phase

### Recovery Phase

**Expected biometric pattern:**
- **Sleep:** Increased sleep duration (8-10 hours), irregular schedule
- **Activity:** Low energy expenditure, high sedentary time
- **HRV:** Low or recovering, elevated resting heart rate
- **Exercise:** Minimal or none

**Confidence adjustment:**
- If journal says Recovery but biometrics show high activity/low sleep → **Reduce confidence** (possible denial or forced productivity)
- If journal says Recovery and biometrics confirm → **Increase confidence**

### Transition Phase

**Expected biometric pattern:**
- **Sleep:** Disrupted patterns, inconsistent bedtime, frequent waking
- **Activity:** Erratic - some days high, some days low
- **HRV:** Variable, unstable
- **Exercise:** Inconsistent

**Confidence adjustment:**
- Transition is chaotic by nature. Erratic biometrics **increase confidence** in Transition classification.
- If journal says Transition but biometrics are highly stable → **Question classification** (might be Consolidation)

### Breakthrough Phase

**Expected biometric pattern:**
- **Sleep:** High quality, consistent schedule, deep sleep percentages elevated
- **Activity:** High energy expenditure, consistent exercise
- **HRV:** High, stable
- **Exercise:** Regular, high intensity

**Confidence adjustment:**
- If journal says Breakthrough and biometrics confirm → **Strong confidence boost**
- If journal says Breakthrough but biometrics show low energy → **Reduce confidence** (might be aspirational, not actual)

### Discovery Phase

**Expected biometric pattern:**
- **Sleep:** Moderate, slightly disrupted (exploration excitement)
- **Activity:** Increasing, exploratory patterns
- **HRV:** Moderate, improving
- **Exercise:** New routines being tested

**Confidence adjustment:**
- Discovery often shows improving trends. Rising activity/HRV **increases confidence**.
- If journal says Discovery but biometrics are declining → **Question classification**

### Expansion Phase

**Expected biometric pattern:**
- **Sleep:** Good quality, consistent
- **Activity:** High, sustained
- **HRV:** High, stable
- **Exercise:** Regular, high volume

**Confidence adjustment:**
- Expansion requires physical capacity. High biometrics **strongly support** Expansion classification.
- If journal says Expansion but biometrics are low → **Reduce confidence** (might be aspirational)

### Consolidation Phase

**Expected biometric pattern:**
- **Sleep:** Stable, consistent schedule
- **Activity:** Moderate, consistent
- **HRV:** Moderate, stable
- **Exercise:** Regular, moderate intensity

**Confidence adjustment:**
- Consolidation shows stability. Stable, moderate biometrics **increase confidence**.
- If journal says Consolidation but biometrics are erratic → **Question classification**

---

## Health-to-Phase Correlation

Health data influences which phase is detected:

### Recovery Phase Boost

Poor health increases the likelihood of Recovery phase:

```dart
if (sleepQuality < 0.4 || energyLevel < 0.4) {
  if (sleepQuality < 0.4 && energyLevel < 0.4) {
    recoveryScore += 0.3;  // Strong signal
  } else {
    recoveryScore += 0.15;  // Moderate signal
  }
}
```

**Example**: User with 4 hours sleep and 2,000 steps → Recovery phase more likely

### Breakthrough Phase Boost

Excellent health supports Breakthrough phase:

```dart
if (sleepQuality > 0.8 && energyLevel > 0.8) {
  breakthroughScore += 0.1;
}
```

**Example**: User with 8+ hours sleep and 12,000 steps → Breakthrough phase more likely

### Consolidation Phase Boost

Stable, moderate health supports Consolidation:

```dart
if (sleepQuality >= 0.5 && sleepQuality <= 0.7 &&
    energyLevel >= 0.5 && energyLevel <= 0.7) {
  consolidationScore += 0.05;
}
```

---

## Health-Adjusted Rating

The operational readiness score (10-100) is adjusted based on health:

### Calculation

```dart
healthFactor = (sleepQuality + energyLevel) / 2.0

if (healthFactor < 0.4) {
  // Poor health: Reduce rating
  reduction = 20 * (0.4 - healthFactor) / 0.4
  adjustedRating = baseRating - reduction
} else if (healthFactor > 0.8) {
  // Excellent health: Boost rating
  boost = 10 * (healthFactor - 0.8) / 0.2
  adjustedRating = baseRating + boost  // Cap at 100
} else {
  // Moderate health: No adjustment
  adjustedRating = baseRating
}
```

**Final Score**: Clamped to 10-100 range

### Examples

**Example 1: Poor Health**
- Phase: Consolidation (base range 65-80)
- Confidence: 0.7 → Base rating: 75
- Health: sleepQuality=0.2, energyLevel=0.3
- Health factor: 0.25 (< 0.4)
- Reduction: 20 * (0.4 - 0.25) / 0.4 = 7.5
- **Final rating: 67** (reduced from 75)

**Example 2: Excellent Health**
- Phase: Reflection (base range 50-65)
- Confidence: 0.8 → Base rating: 62
- Health: sleepQuality=0.9, energyLevel=0.85
- Health factor: 0.875 (> 0.8)
- Boost: 10 * (0.875 - 0.8) / 0.2 = 3.75
- **Final rating: 66** (boosted from 62)

**Example 3: Moderate Health**
- Phase: Planning (base range 40-55)
- Confidence: 0.6 → Base rating: 49
- Health: sleepQuality=0.6, energyLevel=0.65
- Health factor: 0.625 (0.4-0.8 range)
- **Final rating: 49** (no adjustment)

---

## Reading Health Data from Files

### File Structure

Health data is stored in monthly JSON files:
- **Path**: `mcp/health/YYYY-MM.json`
- **Format**: One JSON object per line

### Example JSON Object

```json
{
  "type": "health.timeslice.daily",
  "timeslice": {
    "start": "2025-01-09T00:00:00Z",
    "end": "2025-01-10T00:00:00Z"
  },
  "data": {
    "steps": 8500,
    "sleep_min": 420,
    "active_energy_kcal": 650.0,
    "exercise_min": 30,
    "resting_hr": 62.0,
    "hrv_sdnn": 45.0,
    "avg_hr": 72.0
  }
}
```

### Reading Latest Day

```dart
// Get today's or yesterday's health data
final healthData = await HealthDataService.instance.getAutoDetectedHealthData();

// Internally, this:
// 1. Reads health files for current month
// 2. Finds latest day (today or yesterday)
// 3. Parses HealthDaily object
// 4. Calculates sleep quality and energy level
```

---

## Manual Override

Users can manually set health data, which overrides auto-detection:

```dart
// Set manually
await HealthDataService.instance.updateHealthData(
  sleepQuality: 0.3,
  energyLevel: 0.5,
);

// This will be used in phase analysis instead of auto-detected values
```

**Note**: Manual values persist until changed or cleared.

---

## Hybrid Mode (Future)

Planned feature to toggle between auto and manual modes:

### Auto Mode
- Automatically calculates from imported health data
- Updates daily (e.g., at 8 AM)
- Shows source: "From Apple Health: 4.5 hrs"

### Manual Mode
- User sets sliders manually
- Overrides auto values
- Shows: "Manual"

### Override
- User can always adjust auto values
- "Reset to Auto" button restores auto-detection

---

## Usage Examples

### Basic Phase Analysis with Health

```dart
final phaseService = PhaseAwareAnalysisService();
final context = await phaseService.analyzePhase(
  "I'm feeling tired and overwhelmed today. Need to rest.",
);

print('Phase: ${context.primaryPhase}');
print('Readiness Score: ${context.operationalReadinessScore}');
// Output: Phase: recovery, Readiness Score: 18
```

### With Auto-Detected Health Data

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

---

## Troubleshooting

### No Health Data Available

If no health data is imported:
- `getAutoDetectedHealthData()` returns `HealthData.defaults` (0.7, 0.7)
- Phase analysis continues without health adjustments
- Rating uses base phase rating only

### Stale Health Data

Health data is considered stale if older than 24 hours:
- `HealthData.isStale` returns `true`
- `getEffectiveHealthData()` returns defaults
- Auto-detection will try to find recent data

### Missing Metrics

If some metrics are missing (e.g., no HRV data):
- Algorithm uses available metrics only
- Missing metrics don't affect calculation (no penalty)
- Base score from primary metric (sleep duration, steps) is used

---

## Best Practices

1. **Import Health Data Regularly**: Import at least weekly for accurate auto-detection
2. **Check Data Quality**: Ensure Apple Health has sufficient data (sleep tracking, steps)
3. **Manual Override When Needed**: Use manual mode if auto-detection seems inaccurate
4. **Monitor Trends**: Track health data over time to understand patterns
5. **Baseline Establishment**: System may learn user baselines in future versions

---

## Related Documentation

- [Phase Rating System](./PHASE_RATING_COMPLETE.md) - Complete rating system documentation
- [Health Service](../lib/prism/services/health_service.dart) - Health data import implementation
- [Health Data Service](../lib/services/health_data_service.dart) - Auto-detection implementation

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Maintainer**: ARC Development Team

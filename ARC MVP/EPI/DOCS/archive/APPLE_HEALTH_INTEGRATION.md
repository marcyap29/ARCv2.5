# Apple Health Integration for Phase Detection

## Core Principle

Apple Health data should **enhance phase detection confidence** and **detect phase-body misalignment**, not replace the journal-based classification. The body tells a story that sometimes contradicts what we write.

---

## Architecture Integration Point

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

---

### Transition Phase

**Expected biometric pattern:**
- **Sleep:** Disrupted patterns, inconsistent bedtime, frequent waking
- **Activity:** Erratic - some days high, some days low
- **HRV:** Variable, unstable
- **Exercise:** Inconsistent

**Confidence adjustment:**
- Transition is chaotic by nature. Erratic biometrics **increase confidence** in Transition classification.
- If journal says Transition but biometrics are highly stable → **Question classification** (might be Consolidation)

---

### Breakthrough Phase

**Expected biometric pattern:**
- **Sleep:** May be disrupted due to cognitive intensity, but recovering
- **Activity:** Variable - breakthrough moment itself might be low activity, but energy follows
- **HRV:** Often improves after breakthrough moment
- **Exercise:** Not predictive

**Confidence adjustment:**
- Breakthrough is primarily cognitive, so biometrics are **weak validators**. Don't adjust confidence much based on health data alone.
- However: If biometrics show severe depletion during claimed Breakthrough → **Flag as possible misclassification** (might be Recovery with insight)

---

### Discovery Phase

**Expected biometric pattern:**
- **Sleep:** Good duration (7-9 hours), relatively consistent
- **Activity:** Moderate to high energy, increasing trend
- **HRV:** Improving or stable-positive
- **Exercise:** Increasing frequency or consistent

**Confidence adjustment:**
- If journal says Discovery but biometrics show depletion → **Reduce confidence** (might be forced optimism during Recovery)
- If journal says Discovery and biometrics show energy → **Increase confidence**

---

### Expansion Phase

**Expected biometric pattern:**
- **Sleep:** Consistent, good quality (7-9 hours)
- **Activity:** High energy expenditure, sustained
- **HRV:** High and stable (good stress resilience)
- **Exercise:** Regular, possibly increasing intensity

**Confidence adjustment:**
- If journal says Expansion but biometrics show exhaustion → **Strong confidence reduction** (possible burnout denial)
- If journal says Expansion and biometrics confirm capacity → **Strong confidence increase**

---

### Consolidation Phase

**Expected biometric pattern:**
- **Sleep:** Highly consistent schedule, good quality
- **Activity:** Stable patterns, not extreme
- **HRV:** Stable and good
- **Exercise:** Routine and consistent (not necessarily high intensity)

**Confidence adjustment:**
- If journal says Consolidation but biometrics are chaotic → **Reduce confidence** (might be Transition)
- If journal says Consolidation and biometrics show stability → **Increase confidence**

---

## Implementation: Biometric Phase Analyzer

```dart
class BiometricPhaseAnalyzer {
  final HealthKitService _healthKit;
  
  BiometricPhaseAnalyzer(this._healthKit);
  
  /// Analyzes last 7 days of health data and returns phase signals
  Future<BiometricPhaseSignals> analyzeHealthData() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(Duration(days: 7));
    
    // Fetch health data
    final sleepData = await _healthKit.getSleepAnalysis(
      start: sevenDaysAgo,
      end: now,
    );
    
    final activityData = await _healthKit.getActivitySummary(
      start: sevenDaysAgo,
      end: now,
    );
    
    final hrvData = await _healthKit.getHeartRateVariability(
      start: sevenDaysAgo,
      end: now,
    );
    
    final exerciseData = await _healthKit.getExerciseMinutes(
      start: sevenDaysAgo,
      end: now,
    );
    
    // Calculate metrics
    final sleepMetrics = _analyzeSleep(sleepData);
    final activityMetrics = _analyzeActivity(activityData);
    final hrvMetrics = _analyzeHRV(hrvData);
    final exerciseMetrics = _analyzeExercise(exerciseData);
    
    // Generate phase signals
    return BiometricPhaseSignals(
      recovery: _calculateRecoverySignal(sleepMetrics, activityMetrics, hrvMetrics),
      transition: _calculateTransitionSignal(sleepMetrics, activityMetrics, hrvMetrics),
      breakthrough: _calculateBreakthroughSignal(sleepMetrics, hrvMetrics),
      discovery: _calculateDiscoverySignal(sleepMetrics, activityMetrics, hrvMetrics, exerciseMetrics),
      expansion: _calculateExpansionSignal(sleepMetrics, activityMetrics, hrvMetrics, exerciseMetrics),
      consolidation: _calculateConsolidationSignal(sleepMetrics, activityMetrics, hrvMetrics, exerciseMetrics),
      confidence: _calculateOverallConfidence(sleepMetrics, activityMetrics, hrvMetrics),
      dataQuality: _assessDataQuality(sleepData, activityData, hrvData),
    );
  }
}
```

---

## Sleep Metrics Analysis

```dart
SleepMetrics _analyzeSleep(List<SleepSample> data) {
  if (data.isEmpty) {
    return SleepMetrics.insufficient();
  }
  
  final avgDuration = data
    .map((s) => s.duration.inMinutes)
    .reduce((a, b) => a + b) / data.length / 60.0;
  
  // Calculate bedtime variance
  final bedtimes = data.map((s) => s.bedtime.hour + s.bedtime.minute / 60.0).toList();
  final avgBedtime = bedtimes.reduce((a, b) => a + b) / bedtimes.length;
  final bedtimeVariance = bedtimes
    .map((t) => pow(t - avgBedtime, 2))
    .reduce((a, b) => a + b) / bedtimes.length;
  final bedtimeStdDev = sqrt(bedtimeVariance);
  
  return SleepMetrics(
    avgHoursPerNight: avgDuration,
    consistency: 1.0 - (bedtimeStdDev / 12.0), // 0-1 scale
    quality: data.map((s) => s.quality).reduce((a, b) => a + b) / data.length,
    hasSufficientData: data.length >= 5,
  );
}
```

---

## Activity Metrics Analysis

```dart
ActivityMetrics _analyzeActivity(List<ActivitySummary> data) {
  if (data.isEmpty) {
    return ActivityMetrics.insufficient();
  }
  
  final avgActiveEnergy = data
    .map((a) => a.activeEnergyBurned)
    .reduce((a, b) => a + b) / data.length;
  
  final avgSteps = data
    .map((a) => a.stepCount)
    .reduce((a, b) => a + b) / data.length;
  
  // Calculate variability (high = erratic, low = consistent)
  final energyValues = data.map((a) => a.activeEnergyBurned).toList();
  final avgEnergy = energyValues.reduce((a, b) => a + b) / energyValues.length;
  final variance = energyValues
    .map((e) => pow(e - avgEnergy, 2))
    .reduce((a, b) => a + b) / energyValues.length;
  final coefficientOfVariation = sqrt(variance) / avgEnergy;
  
  return ActivityMetrics(
    avgActiveEnergy: avgActiveEnergy,
    avgSteps: avgSteps,
    variability: coefficientOfVariation, // High = erratic
    trend: _calculateTrend(energyValues),
    hasSufficientData: data.length >= 5,
  );
}
```

---

## HRV Metrics Analysis

```dart
HRVMetrics _analyzeHRV(List<HRVSample> data) {
  if (data.isEmpty) {
    return HRVMetrics.insufficient();
  }
  
  final avgHRV = data
    .map((h) => h.value)
    .reduce((a, b) => a + b) / data.length;
  
  final hrvValues = data.map((h) => h.value).toList();
  final trend = _calculateTrend(hrvValues);
  
  // Calculate stability
  final avgValue = hrvValues.reduce((a, b) => a + b) / hrvValues.length;
  final variance = hrvValues
    .map((v) => pow(v - avgValue, 2))
    .reduce((a, b) => a + b) / hrvValues.length;
  final coefficientOfVariation = sqrt(variance) / avgValue;
  
  return HRVMetrics(
    avgHRV: avgHRV,
    trend: trend,
    stability: 1.0 - coefficientOfVariation.clamp(0.0, 1.0),
    hasSufficientData: data.length >= 5,
  );
}
```

---

## Phase Signal Calculations

### Recovery Signal (0-1)

```dart
double _calculateRecoverySignal(
  SleepMetrics sleep,
  ActivityMetrics activity,
  HRVMetrics hrv,
) {
  if (!sleep.hasSufficientData) return 0.0;
  
  var signal = 0.0;
  
  // High sleep duration indicates recovery need
  if (sleep.avgHoursPerNight > 8.5) signal += 0.3;
  else if (sleep.avgHoursPerNight > 7.5) signal += 0.1;
  
  // Low activity indicates recovery
  if (activity.hasSufficientData && activity.avgActiveEnergy < 300) {
    signal += 0.3;
  }
  
  // Low or recovering HRV
  if (hrv.hasSufficientData) {
    if (hrv.avgHRV < 50) signal += 0.2;
    if (hrv.trend > 0) signal += 0.2; // Improving = recovering
  }
  
  return signal.clamp(0.0, 1.0);
}
```

### Transition Signal (erratic patterns)

```dart
double _calculateTransitionSignal(
  SleepMetrics sleep,
  ActivityMetrics activity,
  HRVMetrics hrv,
) {
  if (!sleep.hasSufficientData) return 0.0;
  
  var signal = 0.0;
  
  // Disrupted sleep consistency
  if (sleep.consistency < 0.6) signal += 0.4;
  
  // Erratic activity
  if (activity.hasSufficientData && activity.variability > 0.5) {
    signal += 0.3;
  }
  
  // Unstable HRV
  if (hrv.hasSufficientData && hrv.stability < 0.6) {
    signal += 0.3;
  }
  
  return signal.clamp(0.0, 1.0);
}
```

### Breakthrough Signal (weak - cognitive phase)

```dart
double _calculateBreakthroughSignal(
  SleepMetrics sleep,
  HRVMetrics hrv,
) {
  // Breakthroughs are cognitive - biometrics are not reliable predictors
  // Only signal if there's obvious depletion (might be misclassified Recovery)
  
  if (sleep.hasSufficientData && sleep.avgHoursPerNight < 6.0) {
    return -0.3; // Negative signal = doubt
  }
  
  return 0.0; // Neutral
}
```

### Discovery Signal

```dart
double _calculateDiscoverySignal(
  SleepMetrics sleep,
  ActivityMetrics activity,
  HRVMetrics hrv,
  ExerciseMetrics exercise,
) {
  if (!sleep.hasSufficientData) return 0.0;
  
  var signal = 0.0;
  
  // Good sleep indicates energy for exploration
  if (sleep.avgHoursPerNight >= 7.0 && sleep.avgHoursPerNight <= 9.0) {
    signal += 0.2;
  }
  
  // Moderate to high activity with increasing trend
  if (activity.hasSufficientData) {
    if (activity.avgActiveEnergy > 400 && activity.trend > 0) {
      signal += 0.4;
    }
  }
  
  // Good HRV
  if (hrv.hasSufficientData && hrv.avgHRV > 60) {
    signal += 0.2;
  }
  
  // Increasing exercise frequency
  if (exercise.hasSufficientData && exercise.frequency > 2) {
    signal += 0.2;
  }
  
  return signal.clamp(0.0, 1.0);
}
```

### Expansion Signal

```dart
double _calculateExpansionSignal(
  SleepMetrics sleep,
  ActivityMetrics activity,
  HRVMetrics hrv,
  ExerciseMetrics exercise,
) {
  if (!activity.hasSufficientData) return 0.0;
  
  var signal = 0.0;
  
  // Consistent good sleep
  if (sleep.hasSufficientData && 
      sleep.avgHoursPerNight >= 7.0 && 
      sleep.consistency > 0.7) {
    signal += 0.2;
  }
  
  // High sustained activity
  if (activity.avgActiveEnergy > 500 && activity.trend >= 0) {
    signal += 0.4;
  }
  
  // High stable HRV (resilience)
  if (hrv.hasSufficientData && 
      hrv.avgHRV > 65 && 
      hrv.stability > 0.7) {
    signal += 0.3;
  }
  
  // Regular exercise
  if (exercise.hasSufficientData && exercise.frequency >= 4) {
    signal += 0.1;
  }
  
  return signal.clamp(0.0, 1.0);
}
```

### Consolidation Signal

```dart
double _calculateConsolidationSignal(
  SleepMetrics sleep,
  ActivityMetrics activity,
  HRVMetrics hrv,
  ExerciseMetrics exercise,
) {
  if (!sleep.hasSufficientData) return 0.0;
  
  var signal = 0.0;
  
  // Highly consistent sleep
  if (sleep.consistency > 0.8) signal += 0.3;
  
  // Stable activity patterns (low variability)
  if (activity.hasSufficientData && activity.variability < 0.3) {
    signal += 0.3;
  }
  
  // Stable HRV
  if (hrv.hasSufficientData && hrv.stability > 0.8) {
    signal += 0.2;
  }
  
  // Established exercise routine
  if (exercise.hasSufficientData && exercise.hasRoutine) {
    signal += 0.2;
  }
  
  return signal.clamp(0.0, 1.0);
}
```

---

## Phase Probability Adjuster

```dart
class PhaseProbabilityAdjuster {
  /// Adjusts text-based phase classification with biometric signals
  Map<String, double> adjustWithBiometrics({
    required Map<String, double> textBasedProbs,
    required BiometricPhaseSignals bioSignals,
    required double textConfidence,
  }) {
    // If biometric data quality is low, don't adjust much
    if (bioSignals.dataQuality == DataQuality.low) {
      return textBasedProbs;
    }
    
    // Weight for biometric influence (0.2 = 20% influence max)
    final bioWeight = bioSignals.confidence * 0.2;
    final textWeight = 1.0 - bioWeight;
    
    // Create adjusted probabilities
    final adjusted = <String, double>{};
    
    adjusted['recovery'] = (textBasedProbs['recovery']! * textWeight) + 
                           (bioSignals.recovery * bioWeight);
    
    adjusted['transition'] = (textBasedProbs['transition']! * textWeight) + 
                             (bioSignals.transition * bioWeight);
    
    adjusted['breakthrough'] = textBasedProbs['breakthrough']!; 
    // Breakthrough is cognitive - don't adjust much with biometrics
    if (bioSignals.breakthrough < 0) {
      // Negative signal = reduce confidence
      adjusted['breakthrough'] = adjusted['breakthrough']! * 0.8;
    }
    
    adjusted['discovery'] = (textBasedProbs['discovery']! * textWeight) + 
                            (bioSignals.discovery * bioWeight);
    
    adjusted['expansion'] = (textBasedProbs['expansion']! * textWeight) + 
                            (bioSignals.expansion * bioWeight);
    
    adjusted['consolidation'] = (textBasedProbs['consolidation']! * textWeight) + 
                                (bioSignals.consolidation * bioWeight);
    
    // Normalize to sum to 1.0
    final sum = adjusted.values.reduce((a, b) => a + b);
    adjusted.forEach((key, value) {
      adjusted[key] = value / sum;
    });
    
    return adjusted;
  }
  
  /// Calculate new confidence after biometric adjustment
  double calculateAdjustedConfidence({
    required double textConfidence,
    required BiometricPhaseSignals bioSignals,
    required Map<String, double> originalProbs,
    required Map<String, double> adjustedProbs,
  }) {
    final topPhaseOriginal = originalProbs.entries
      .reduce((a, b) => a.value > b.value ? a : b).key;
    
    final topPhaseAdjusted = adjustedProbs.entries
      .reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Check agreement
    if (topPhaseOriginal == topPhaseAdjusted) {
      // Biometrics agree - boost confidence
      return (textConfidence + (bioSignals.confidence * 0.15)).clamp(0.0, 0.95);
    } else {
      // Biometrics disagree - reduce confidence
      return (textConfidence - (bioSignals.confidence * 0.2)).clamp(0.3, 1.0);
    }
  }
}
```

---

## Integration into Phase Classifier Flow

```dart
class EnhancedPhaseClassifier {
  final LLMService _llm;
  final BiometricPhaseAnalyzer _bioAnalyzer;
  final PhaseProbabilityAdjuster _adjuster;
  
  Future<ClassifiedEntry> classifyEntry({
    required String entryText,
    required bool includeHealthData,
  }) async {
    // 1. Get text-based classification from LLM
    final textClassification = await _llm.classifyPhase(entryText);
    
    // 2. If health integration disabled, return text classification
    if (!includeHealthData) {
      return ClassifiedEntry.fromLLM(textClassification);
    }
    
    // 3. Get biometric signals
    final bioSignals = await _bioAnalyzer.analyzeHealthData();
    
    // 4. Adjust probabilities with biometrics
    final adjustedProbs = _adjuster.adjustWithBiometrics(
      textBasedProbs: textClassification.phases,
      bioSignals: bioSignals,
      textConfidence: textClassification.confidence,
    );
    
    // 5. Calculate new confidence
    final adjustedConfidence = _adjuster.calculateAdjustedConfidence(
      textConfidence: textClassification.confidence,
      bioSignals: bioSignals,
      originalProbs: textClassification.phases,
      adjustedProbs: adjustedProbs,
    );
    
    // 6. Return enhanced classification
    return ClassifiedEntry(
      phases: adjustedProbs,
      confidence: adjustedConfidence,
      reasoning: textClassification.reasoning,
      sentinel: textClassification.sentinel,
      biometricSignals: bioSignals,
      dataSource: DataSource.textAndBiometric,
    );
  }
}
```

---

## Data Models

```dart
class BiometricPhaseSignals {
  final double recovery;       // 0-1 signal strength
  final double transition;
  final double breakthrough;
  final double discovery;
  final double expansion;
  final double consolidation;
  final double confidence;     // 0-1 how confident are these signals
  final DataQuality dataQuality;
  
  BiometricPhaseSignals({
    required this.recovery,
    required this.transition,
    required this.breakthrough,
    required this.discovery,
    required this.expansion,
    required this.consolidation,
    required this.confidence,
    required this.dataQuality,
  });
}

class SleepMetrics {
  final double avgHoursPerNight;
  final double consistency;  // 0-1, higher = more consistent bedtime
  final double quality;      // 0-1 if available
  final bool hasSufficientData;
  
  SleepMetrics({
    required this.avgHoursPerNight,
    required this.consistency,
    required this.quality,
    required this.hasSufficientData,
  });
  
  factory SleepMetrics.insufficient() => SleepMetrics(
    avgHoursPerNight: 0,
    consistency: 0,
    quality: 0,
    hasSufficientData: false,
  );
}

class ActivityMetrics {
  final double avgActiveEnergy;
  final double avgSteps;
  final double variability;  // coefficient of variation
  final double trend;        // positive = increasing, negative = decreasing
  final bool hasSufficientData;
  
  ActivityMetrics({
    required this.avgActiveEnergy,
    required this.avgSteps,
    required this.variability,
    required this.trend,
    required this.hasSufficientData,
  });
  
  factory ActivityMetrics.insufficient() => ActivityMetrics(
    avgActiveEnergy: 0,
    avgSteps: 0,
    variability: 0,
    trend: 0,
    hasSufficientData: false,
  );
}

class HRVMetrics {
  final double avgHRV;
  final double trend;
  final double stability;  // 0-1, higher = more stable
  final bool hasSufficientData;
  
  HRVMetrics({
    required this.avgHRV,
    required this.trend,
    required this.stability,
    required this.hasSufficientData,
  });
  
  factory HRVMetrics.insufficient() => HRVMetrics(
    avgHRV: 0,
    trend: 0,
    stability: 0,
    hasSufficientData: false,
  );
}

class ExerciseMetrics {
  final double avgMinutesPerDay;
  final int frequency;        // workouts in 7 days
  final bool hasRoutine;      // consistent pattern
  final bool hasSufficientData;
  
  ExerciseMetrics({
    required this.avgMinutesPerDay,
    required this.frequency,
    required this.hasRoutine,
    required this.hasSufficientData,
  });
  
  factory ExerciseMetrics.insufficient() => ExerciseMetrics(
    avgMinutesPerDay: 0,
    frequency: 0,
    hasRoutine: false,
    hasSufficientData: false,
  );
}

enum DataQuality {
  high,
  medium,
  low,
}
```

---

## User-Facing Settings UI

```
┌─────────────────────────────────────────┐
│ Apple Health Integration                 │
│                                          │
│ Connect Apple Health to help LUMARA      │
│ understand your full story - not just    │
│ what you write, but how your body is     │
│ doing.                                   │
│                                          │
│ What LUMARA uses:                        │
│ • Sleep patterns (duration, consistency) │
│ • Activity levels (energy, steps)        │
│ • Heart rate variability (stress)        │
│ • Exercise frequency                     │
│                                          │
│ How it helps:                            │
│ Health data validates or challenges your │
│ written reflections. Sometimes we write  │
│ "I'm fine" when our body says otherwise. │
│                                          │
│ Your data:                               │
│ Last 7 days analyzed locally on device.  │
│ No health data leaves your phone.        │
│                                          │
│ Current Status:                          │
│ ○ Connected  ● Not Connected            │
│                                          │
│ [Connect Apple Health]                   │
│                                          │
│ Data Quality: N/A                        │
│ Confidence Boost: N/A                    │
└─────────────────────────────────────────┘
```

---

## Key Principles

1. **Health data enhances, never replaces** text-based classification
2. **Max 20% influence** on phase probabilities
3. **Validates contradictions** - if someone writes "I'm expanding" but biometrics show exhaustion, reduce confidence
4. **Local processing only** - health data never leaves device
5. **Optional feature** - works perfectly fine without health integration
6. **Transparency** - show user how health data influenced classification

---

## Biometric Signature Summary Table

| Phase | Sleep | Activity | HRV | Exercise | Key Signal |
|-------|-------|----------|-----|----------|------------|
| **Recovery** | 8-10 hrs, irregular | Low energy, high sedentary | Low/recovering | Minimal | High sleep + low activity |
| **Transition** | Disrupted, inconsistent | Erratic (high/low days) | Variable, unstable | Inconsistent | All metrics erratic |
| **Breakthrough** | May be disrupted | Variable | Often improves after | Not predictive | Cognitive - weak signal |
| **Discovery** | 7-9 hrs, consistent | Moderate-high, increasing | Improving/stable | Increasing | Energy + improving trend |
| **Expansion** | 7-9 hrs, good quality | High, sustained | High and stable | Regular | High sustained capacity |
| **Consolidation** | Highly consistent | Stable patterns | Stable and good | Routine | All metrics stable |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-14 | Initial documentation |

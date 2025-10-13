# SENTINEL: Reverse RIVET for Emotional Risk Detection

**SENTINEL** — **S**everity **E**valuation and **N**egative **T**rend **I**dentification for **E**motional **L**ongitudinal tracking

**Version:** 1.0.0
**Date:** October 12, 2025
**Author:** Marc Yap
**Module Location:** `lib/prism/extractors/sentinel_risk_detector.dart`

---

## Abstract

**SENTINEL** provides a transparent, domain-specific method to detect when emotional distress patterns warrant intervention. It is the conceptual inverse of RIVET: where RIVET decides when to **reduce testing** (gate DOWN), SENTINEL decides when to **escalate concern** (gate UP). Like RIVET, it uses two independent signals:

- **Base Risk Score** — Normalized (0–1) measure of emotional intensity across journal entries, analogous to RIVET's alignment metric but measuring distress severity rather than model fidelity.

- **Pattern Severity** — Weighted (0–1) index of concerning behavioral patterns (clustering, persistence, escalation, isolation, hopelessness), analogous to RIVET's evidence accumulation but detecting risk signals rather than validation confidence.

Intervention is recommended only when both signals exceed thresholds through a sustainment window that includes validated pattern types. The core formulation mirrors RIVET's simplicity while inverting its purpose: **"two dials, both must be red" triggers escalation instead of authorization**.

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Reverse RIVET Concept](#the-reverse-rivet-concept)
3. [Core Concepts](#core-concepts)
4. [Risk Detection Plan](#risk-detection-plan)
5. [Pattern Detection Methods](#pattern-detection-methods)
6. [Reverse Gating Logic](#reverse-gating-logic)
7. [Comparison: RIVET vs SENTINEL](#comparison-rivet-vs-sentinel)
8. [Use Cases & Integration](#use-cases--integration)
9. [Conclusion](#conclusion)
10. [Symbol & Acronym Glossary](#symbol--acronym-glossary)

---

## Chapter 1: Introduction

### The Challenge

Mental health professionals and users of journaling systems face two critical questions:
- *When is emotional distress severe enough to warrant immediate intervention?*
- *When can patterns be safely monitored without escalation?*

Traditional mental health monitoring privileges symptom checklists (presence/absence) over **trend analysis** (deterioration patterns and accumulating evidence). This bias leads to either:
- **Over-alerting** (alarm fatigue, ignored warnings)
- **Under-alerting** (missed crises, delayed intervention)

### The Solution

**SENTINEL** resolves this ambiguity with two independent, explainable signals:
- **Base Risk Score** for severity measurement
- **Pattern Detection** for evidence accumulation

Both must exceed thresholds over a sustainment window before escalating to intervention recommendations. The formulation is deliberately **parallel to RIVET** but inverted: easy to explain ("two warning dials, both must be red") and lightweight to implement.

---

## Chapter 2: The Reverse RIVET Concept

### RIVET's Original Purpose

From *RIVET: Bridging Simulation and Testing for System Trust* (Marc Yap, October 2025):

> **RIVET** (Risk–Validation Evidence Tracker) decides when it is defensible to **reduce costly physical testing** and rely more on models.

**RIVET's Two Signals:**
1. **ALIGN** — Alignment between predictions and measurements (fidelity)
2. **TRACE** — Test evidence accumulation (sufficiency)

**RIVET Decision Rule:**
- Enter **reduced testing mode** when ALIGN ≥ A* AND TRACE ≥ T*
- Sustained for W steps with ≥1 independent event
- **Philosophy**: Trust has been earned → **REDUCE testing**

### SENTINEL's Inverted Purpose

**SENTINEL** decides when emotional distress patterns are severe enough to **escalate intervention recommendations**.

**SENTINEL's Two Signals:**
1. **Base Risk Score** — Emotional amplitude and negative keyword density (severity)
2. **Pattern Severity** — Accumulated concerning behavioral evidence (confidence in risk)

**SENTINEL Decision Rule:**
- Enter **elevated risk mode** when BaseScore ≥ R* AND PatternSeverity ≥ P*
- Sustained for W steps with validated pattern types
- **Philosophy**: Risk has been identified → **ESCALATE intervention**

### The Inversion

| Aspect | RIVET (Original) | SENTINEL (Reverse) |
|--------|------------------|-------------------|
| **Domain** | Engineering testing | Emotional health monitoring |
| **Goal** | Reduce testing when trust earned | Escalate care when risk detected |
| **Signal 1** | ALIGN: Prediction fidelity (↑ good) | Base Score: Distress severity (↑ bad) |
| **Signal 2** | TRACE: Evidence sufficiency (↑ good) | Patterns: Risk accumulation (↑ bad) |
| **Threshold Logic** | Both HIGH → Gate OPENS (authorize reduction) | Both HIGH → Gate CLOSES (require intervention) |
| **Gating Direction** | DOWN (reduce activity) | UP (increase response) |
| **Philosophy** | "Both dials green" = trust | "Both dials red" = concern |

**Key Insight**: SENTINEL is RIVET's **conceptual inverse**. Where RIVET gates testing **down** based on positive signals (trust), SENTINEL gates concern **up** based on negative signals (risk).

---

## Chapter 3: Core Concepts

### Base Risk Score (Analog to RIVET's ALIGN)

**Purpose**: Normalized measure of emotional distress severity across journal entries.

**Calculation**:

```
BaseScore = (0.3 × AvgAmplitude) +
            (0.3 × HighAmplitudeRate) +
            (0.2 × NegativeKeywordRatio) +
            (0.2 × MaxPatternSeverity)
```

Where:
- **AvgAmplitude**: Mean emotional amplitude across all keywords (0.0 = calm, 1.0 = extreme)
- **HighAmplitudeRate**: Fraction of entries with amplitude ≥ 0.75
- **NegativeKeywordRatio**: Fraction of keywords that are negative (anxious, sad, angry, etc.)
- **MaxPatternSeverity**: Highest severity from detected patterns

**Range**: 0 ≤ BaseScore ≤ 1

**Interpretation**:
- 0.00–0.24: Minimal distress
- 0.25–0.39: Low distress
- 0.40–0.54: Moderate distress
- 0.55–0.69: Elevated distress
- 0.70–0.84: High distress
- 0.85–1.00: Severe/critical distress

---

### Pattern Severity (Analog to RIVET's TRACE)

**Purpose**: Cumulative measure of concerning behavioral patterns with emphasis on pattern type diversity and recency.

**Pattern Types Detected**:

1. **Clustering** (Severity: 0.6–0.9)
   - 3+ high-amplitude entries within 48 hours
   - Indicates acute distress spike

2. **Persistent** (Severity: 0.5–0.8)
   - 5+ consecutive days with negative keywords
   - Indicates chronic distress

3. **Escalating** (Severity: 0.3–0.7)
   - Linear trend showing increasing amplitude
   - Indicates deterioration

4. **Phase Mismatch** (Severity: 0.3–0.9)
   - High negative emotions during expected positive phases
   - Indicates context-inappropriate distress

5. **Isolation** (Severity: 0.4–0.9)
   - 30%+ entries contain withdrawal keywords
   - Indicates social disconnection

6. **Hopelessness** (Severity: 0.85–1.0) ⚠️ **CRITICAL**
   - ANY instance of despair/suicidal keywords
   - Immediate intervention trigger

**Aggregation**:

```
PatternSeverity = max(p₁, p₂, ..., pₙ) × (1 + 0.1 × NumPatternTypes)
```

Where pᵢ is the severity of each detected pattern.

**Range**: 0 ≤ PatternSeverity ≤ 1

---

### Reverse RIVET Gating (Analog to RIVET's Sustainment)

**Decision Rule**: Escalate to intervention recommendations only if:

1. **BaseScore ≥ R*** (default: 0.60)
2. **PatternSeverity ≥ P*** (default: 0.60)
3. Both thresholds sustained for **W steps** (default: 2 time windows)
4. At least **one validated pattern type** detected

**Typical Defaults**:
- R* = 0.60 (moderate-high base distress)
- P* = 0.60 (clear pattern evidence)
- W = 2 (sustained over 2 analysis periods)
- Min patterns = 1 (at least one concerning pattern)

---

## Chapter 4: Risk Detection Plan

### Verification Properties

1. **Boundedness**: BaseScore and PatternSeverity ∈ [0, 1]
2. **Monotonicity**: Patterns can only add severity, never reduce it within a time window
3. **Saturation**: Pattern severity has diminishing returns (repeated patterns don't infinitely escalate)
4. **Gate Discipline**: Premature escalations suppressed; sustained patterns admitted after validation

### Risk Level Mapping

```
RiskLevel = f(GatedScore)

where GatedScore = BaseScore (after reverse RIVET gating applied)

if GatedScore ≥ 0.85: RiskLevel = SEVERE
if GatedScore ≥ 0.70: RiskLevel = HIGH
if GatedScore ≥ 0.55: RiskLevel = ELEVATED
if GatedScore ≥ 0.40: RiskLevel = MODERATE
if GatedScore ≥ 0.25: RiskLevel = LOW
else:                 RiskLevel = MINIMAL
```

---

## Chapter 5: Pattern Detection Methods

### 1. Clustering Detection

**Definition**: Multiple high-amplitude entries in short time window.

**Algorithm**:
```
For each entry i:
  window = [i.timestamp, i.timestamp + 48 hours]
  cluster = entries in window with amplitude ≥ 0.75

  if len(cluster) ≥ 3:
    severity = 0.6 + (0.1 × len(cluster))
    severity = min(severity, 0.9)
```

**Example**:
```
Day 1, 2pm:  Keywords: "devastated", "hopeless" (amp: 0.95, 0.92)
Day 1, 8pm:  Keywords: "broken", "crushed" (amp: 0.85, 0.92)
Day 2, 10am: Keywords: "worthless", "alone" (amp: 0.72, 0.60)

→ 3 entries in 20 hours with high amplitude
→ CLUSTER DETECTED: Severity = 0.7
```

---

### 2. Persistent Distress Detection

**Definition**: Consecutive days with negative keywords.

**Algorithm**:
```
Group entries by day
For each consecutive day sequence:
  if day has keywords with amplitude ≥ 0.60:
    consecutiveDays += 1
  else:
    break sequence

if consecutiveDays ≥ 5:
  severity = min(0.5 + (0.05 × consecutiveDays), 0.8)
```

**Example**:
```
Mon: "sad", "tired" (amp: 0.75, 0.60)
Tue: "empty", "hollow" (amp: 0.62, 0.40)
Wed: "depressed", "numb" (amp: 0.80, 0.62)
Thu: "heavy", "burdened" (amp: 0.50, 0.50)
Fri: "defeated", "dark" (amp: 0.72, 0.50)

→ 5 consecutive days with negative keywords
→ PERSISTENT DETECTED: Severity = 0.75
```

---

### 3. Escalating Trend Detection

**Definition**: Linear trend showing increasing emotional amplitude over time.

**Algorithm**:
```
Calculate average amplitude per entry
Fit linear regression: amplitude = slope × time + intercept

if slope > 0.15:  // Significant upward trend
  severity = min(slope × 2, 0.7)
```

**Example**:
```
Week 1: avg amplitude 0.45 (anxious, worried)
Week 2: avg amplitude 0.58 (stressed, overwhelmed)
Week 3: avg amplitude 0.71 (sad, lonely)
Week 4: avg amplitude 0.82 (hopeless, defeated)

→ Slope = 0.185 per week (significant increase)
→ ESCALATING DETECTED: Severity = 0.68
```

---

### 4. Phase Mismatch Detection

**Definition**: High negative emotions during expected positive phases.

**Algorithm**:
```
positivePhases = ["Discovery", "Expansion", "Breakthrough"]

For each entry in positivePhase:
  if has keywords with (amplitude ≥ 0.75 AND isNegative):
    mismatches += 1

severity = (mismatches / totalEntries) clamped to [0.3, 0.9]
```

**Example**:
```
Phase: Expansion (expected: growing, confident, thriving)
Actual keywords: "devastated", "hopeless", "broken"

→ High-amplitude negative during positive phase
→ PHASE MISMATCH DETECTED: Severity = 0.65
```

---

### 5. Isolation Pattern Detection

**Definition**: Repeated use of social withdrawal keywords.

**Algorithm**:
```
isolationKeywords = ["isolated", "alone", "lonely", "avoiding",
                     "hiding", "disconnected", "abandoned", "rejected"]

entriesWithIsolation = entries containing any isolationKeyword
isolationRate = entriesWithIsolation / totalEntries

if isolationRate ≥ 0.30:
  severity = min(isolationRate, 0.95)
```

**Example**:
```
10 entries analyzed:
- 5 contain: "alone", "isolated", "disconnected"
- Isolation rate: 5/10 = 50%

→ ISOLATION DETECTED: Severity = 0.75
```

---

### 6. Hopelessness Detection ⚠️ CRITICAL

**Definition**: ANY instance of despair/suicidal ideation keywords.

**Algorithm**:
```
hopelessnessKeywords = ["hopeless", "no point", "give up",
                        "can't go on", "end it", "suicide"]

For each entry:
  if contains any hopelessnessKeyword:
    severity = 0.90  // High severity even for single occurrence
    severity += (0.02 × additionalOccurrences) up to 1.0
```

**Example**:
```
Entry: "I feel hopeless. There's no point anymore."

→ HOPELESSNESS DETECTED: Severity = 0.90 (CRITICAL)
→ Immediate escalation recommended
```

---

## Chapter 6: Reverse Gating Logic

### RIVET Gating vs SENTINEL Gating

#### RIVET (Original)
**Purpose**: Decide when model trust is HIGH enough to REDUCE testing

```
RIVET Gates (Authorization Logic):
1. If ALIGN ≥ A*:         Model predictions are accurate
2. If TRACE ≥ T*:         Evidence is sufficient
3. If sustained W steps:   Not a temporary fluke
4. If ≥1 independent:      Diverse validation

→ ALL CONDITIONS MET = OPEN GATE (authorize reduction)
```

#### SENTINEL (Reverse)
**Purpose**: Decide when emotional risk is HIGH enough to ESCALATE care

```
SENTINEL Gates (Escalation Logic):
1. If BaseScore ≥ R*:      Distress level is high
2. If PatternSev ≥ P*:     Pattern evidence is strong
3. If sustained W steps:    Not a temporary spike
4. If ≥1 pattern type:      Validated concern

→ ALL CONDITIONS MET = CLOSE GATE (escalate intervention)
```

### Reverse RIVET Gating Algorithm

```dart
double calculateGatedRiskScore(
  double baseScore,
  List<RiskPattern> patterns,
  Map<String, dynamic> metrics,
) {
  // Start with base score (analogous to RIVET's raw alignment)
  double gatedScore = baseScore;
  List<String> gatingReasons = [];

  // REVERSE GATE 1: High base score escalates (+0.10)
  if (baseScore > 0.60) {
    gatedScore += 0.10;
    gatingReasons.add('REVERSE_GATE_1_HIGH_BASE_SCORE');
  }

  // REVERSE GATE 2: Multiple patterns escalate (+0.15)
  if (patterns.length >= 3) {
    gatedScore += 0.15;
    gatingReasons.add('REVERSE_GATE_2_MULTIPLE_PATTERNS');
  }

  // REVERSE GATE 3: Critical patterns escalate significantly (+0.20)
  if (patterns.any((p) => p.type == 'hopelessness' || p.type == 'isolation')) {
    gatedScore += 0.20;
    gatingReasons.add('REVERSE_GATE_3_CRITICAL_PATTERN');
  }

  // REVERSE GATE 4: High negative density escalates (+0.10)
  if (metrics['negative_keyword_ratio'] > 0.70) {
    gatedScore += 0.10;
    gatingReasons.add('REVERSE_GATE_4_HIGH_NEGATIVE_DENSITY');
  }

  // REVERSE GATE 5: Escalating trend escalates (+0.12)
  if (patterns.any((p) => p.type == 'escalating')) {
    gatedScore += 0.12;
    gatingReasons.add('REVERSE_GATE_5_ESCALATING_TREND');
  }

  // REVERSE GATE 6: Persistent distress escalates (+0.08)
  if (patterns.any((p) => p.type == 'persistent')) {
    gatedScore += 0.08;
    gatingReasons.add('REVERSE_GATE_6_PERSISTENT_DISTRESS');
  }

  // Store gating trace for transparency
  metrics['reverse_rivet_gates'] = gatingReasons;
  metrics['base_score'] = baseScore;
  metrics['gated_score'] = gatedScore;

  return gatedScore.clamp(0.0, 1.0);
}
```

### Gating Comparison Table

| Aspect | RIVET Gates | SENTINEL Reverse Gates |
|--------|-------------|------------------------|
| **Direction** | Open (authorize) | Close (escalate) |
| **Trigger** | High positive signals | High negative signals |
| **Gate 1** | Strong alignment → OPEN | High base score → ESCALATE |
| **Gate 2** | Sufficient evidence → OPEN | Multiple patterns → ESCALATE |
| **Gate 3** | Independent validation → OPEN | Critical patterns → ESCALATE |
| **Result** | Reduce testing | Increase intervention |
| **Philosophy** | Trust earned, reduce effort | Risk detected, increase care |

---

## Chapter 7: Comparison: RIVET vs SENTINEL

### Side-by-Side Comparison

| Aspect | RIVET (Original) | SENTINEL (Reverse) |
|--------|------------------|-------------------|
| **Full Name** | Risk–Validation Evidence Tracker | Severity Evaluation & Negative Trend Identification for Emotional Longitudinal tracking |
| **Domain** | Engineering: Model validation vs testing | Mental Health: Emotional distress detection |
| **Primary Goal** | Decide when to REDUCE testing | Decide when to ESCALATE care |
| **Signal 1 Name** | ALIGN (Alignment Index) | Base Risk Score |
| **Signal 1 Meaning** | Model prediction accuracy | Emotional distress severity |
| **Signal 1 Good/Bad** | HIGH is GOOD (accurate) | HIGH is BAD (severe) |
| **Signal 2 Name** | TRACE (Test Evidence Accumulation) | Pattern Severity |
| **Signal 2 Meaning** | Validation test sufficiency | Concerning pattern confidence |
| **Signal 2 Good/Bad** | HIGH is GOOD (confident) | HIGH is BAD (concerning) |
| **Threshold Logic** | Both ≥ threshold → AUTHORIZE | Both ≥ threshold → ALERT |
| **Gating Direction** | OPEN gate (reduce activity) | CLOSE gate (increase response) |
| **Sustainment** | Sustained threshold for W steps | Sustained threshold for W windows |
| **Independence** | Requires ≥1 independent test | Requires ≥1 validated pattern type |
| **Formula Complexity** | Simple: EMA + saturator | Simple: weighted average + max |
| **Transparency** | "Two dials both green" | "Two dials both red" |
| **Use Case** | Aerospace, ADAS, medical devices | Mental health apps, journaling tools |

### Conceptual Parallelism

```
RIVET Equation:
  TRUST = (ALIGN ≥ A*) ∧ (TRACE ≥ T*) ∧ sustained(W) ∧ independent(≥1)

  If TRUST → REDUCE testing (gate opens)

SENTINEL Equation:
  RISK = (BaseScore ≥ R*) ∧ (PatternSev ≥ P*) ∧ sustained(W) ∧ validated(≥1)

  If RISK → ESCALATE care (gate closes)
```

### The Inversion Proof

**RIVET**:
- Signal quality ↑ + Evidence ↑ = Trust ↑ → Activity ↓ (reduce testing)

**SENTINEL**:
- Signal severity ↑ + Patterns ↑ = Risk ↑ → Response ↑ (increase care)

**Mathematical Inversion**:
```
RIVET:    f(quality↑, evidence↑) = authorization↑ → activity↓
SENTINEL: f(severity↑, patterns↑) = concern↑ → response↑

RIVET authorizes REDUCTION through OPENING a gate
SENTINEL requires ESCALATION by CLOSING safety margins
```

---

## Chapter 8: Use Cases & Integration

### Example 1: Crisis Detection

**Scenario**: User journaling shows rapid deterioration

**Day 1, 2pm**:
```
Entry: "Feeling devastated. Everything is falling apart."
Keywords: "devastated", "overwhelmed"
Amplitudes: 0.95, 0.85
BaseScore: 0.42
```

**Day 1, 8pm**:
```
Entry: "I can't do this anymore. Hopeless."
Keywords: "hopeless", "broken"
Amplitudes: 0.92, 0.85
BaseScore: 0.58
```

**Day 2, 10am**:
```
Entry: "No point in trying. Alone in this."
Keywords: "no point", "alone", "worthless"
Amplitudes: 0.92, 0.60, 0.72
BaseScore: 0.71
```

**SENTINEL Analysis**:
```
Patterns Detected:
1. Clustering (3 entries in 20 hours): Severity 0.85
2. Hopelessness ("hopeless", "no point"): Severity 0.95 ⚠️ CRITICAL

BaseScore: 0.71 (HIGH)
PatternSeverity: 0.95 (CRITICAL)

Reverse RIVET Gating:
- Gate 1: BaseScore > 0.60 → +0.10
- Gate 3: Hopelessness detected → +0.20
- Gate 4: Negative ratio 0.87 → +0.10

GatedScore: 0.71 + 0.40 = 1.00 (clamped)

RISK LEVEL: SEVERE
RECOMMENDATION: 🚨 IMMEDIATE INTERVENTION REQUIRED
- Contact crisis helpline: 988
- Notify emergency contact
- Do not leave user alone
```

---

### Example 2: Chronic Monitoring (No Escalation)

**Scenario**: User experiencing manageable stress

**Week 1-4**: 15 entries
```
Keywords: "stressed", "tired", "busy", "anxious", "overwhelmed" (scattered)
Average Amplitude: 0.52
Negative Ratio: 0.45
```

**SENTINEL Analysis**:
```
Patterns Detected: None
- No clustering (entries spread over 28 days)
- No persistence (breaks in negative streaks)
- No escalation (amplitude stable)
- No hopelessness

BaseScore: 0.38 (LOW-MODERATE)
PatternSeverity: 0.15 (minimal)

RISK LEVEL: LOW
RECOMMENDATION: ✓ Continue self-monitoring
- Maintain healthy habits
- Use stress-reduction tools
```

---

### Example 3: False Positive Suppression

**Scenario**: Single intense entry but no sustained pattern

**Day 1**:
```
Entry: "Had a terrible day. Feeling devastated."
Keywords: "devastated", "angry"
Amplitudes: 0.95, 0.75
BaseScore: 0.68
```

**Days 2-7**: No entries or positive entries

**SENTINEL Analysis**:
```
Patterns Detected:
1. Single high-amplitude event

BaseScore: 0.68 (ELEVATED)
PatternSeverity: 0.20 (insufficient)

Reverse RIVET Gating:
- Gate 1: BaseScore > 0.60 → +0.10
- No other gates triggered

GatedScore: 0.78 (HIGH)

BUT: Sustainment window NOT met (only 1 time period)
     Pattern diversity insufficient (only 1 type)

RISK LEVEL: MODERATE (no escalation)
RECOMMENDATION: ⚠️ Monitor closely
- Check in after 24-48 hours
- Encourage next journal entry
```

**Key Point**: SENTINEL prevents false alarms by requiring:
1. Sustained high scores (not just one spike)
2. Multiple pattern types (convergent evidence)
3. Validated pattern categories (not noise)

---

## Chapter 9: Conclusion

### SENTINEL's Core Innovation

**SENTINEL** successfully inverts RIVET's gating philosophy for emotional health:

1. **Parallel Structure**:
   - Two independent signals (severity + patterns)
   - Threshold-based gating
   - Sustainment requirements
   - Evidence diversity checks

2. **Inverted Purpose**:
   - RIVET: High quality → REDUCE activity
   - SENTINEL: High severity → INCREASE response

3. **Maintained Simplicity**:
   - "Two dials, both red" = escalate
   - Transparent scoring (0-1 scales)
   - Lightweight computation
   - Explainable decisions

### When to Use SENTINEL

**Appropriate Use Cases**:
- ✅ Mental health journaling apps
- ✅ Emotional wellness monitoring
- ✅ Self-care applications
- ✅ Therapeutic tool augmentation
- ✅ Research on emotional patterns

**Important Limitations**:
- ⚠️ Not a medical diagnostic tool
- ⚠️ Not a replacement for professional care
- ⚠️ Should supplement, not replace, human judgment
- ⚠️ Requires user consent and privacy protection

### The RIVET Legacy

By faithfully adapting RIVET's principles to emotional health, SENTINEL demonstrates the framework's versatility:

**RIVET** asks: *When have we tested enough?*
**SENTINEL** asks: *When must we act?*

Both answer through the same elegant logic: **two independent signals, jointly sustained, with validated evidence**. The difference is merely direction—one gates down (authorization), the other gates up (escalation).

---

## Appendix A: Symbol & Acronym Glossary

| Symbol | Meaning |
|--------|---------|
| **SENTINEL** | Severity Evaluation & Negative Trend Identification for Emotional Longitudinal tracking |
| **RIVET** | Risk–Validation Evidence Tracker (original framework) |
| **BaseScore** | Normalized emotional distress severity (0-1) |
| **PatternSeverity** | Maximum pattern severity with diversity multiplier (0-1) |
| **R*** | Base score threshold (default: 0.60) |
| **P*** | Pattern severity threshold (default: 0.60) |
| **W** | Sustainment window (default: 2 periods) |
| **GatedScore** | Risk score after reverse RIVET gates applied |
| **ALIGN** | RIVET's alignment index (model fidelity) |
| **TRACE** | RIVET's test evidence accumulation (sufficiency) |

---

## Appendix B: RIVET Citation

This work is based on:

**RIVET: Bridging Simulation and Testing for System Trust**
Marc Yap
October 13, 2025

SENTINEL adapts RIVET's two-signal gating framework from engineering validation to emotional health monitoring, maintaining the original's emphasis on:
- Independent signal verification
- Threshold-based decision logic
- Sustainment requirements
- Transparent, explainable outcomes

---

**Document Version**: 1.0.0
**Last Updated**: October 12, 2025
**Status**: Production Ready
**License**: Internal Use - EPI Project

---

*"RIVET opens gates when trust is high. SENTINEL closes them when risk is high. Same logic, opposite purpose, equal rigor."*

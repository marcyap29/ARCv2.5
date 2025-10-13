# Keyword System & SENTINEL Risk Detection Guide

**Version:** 1.0.0
**Date:** October 12, 2025
**Module Location:** `lib/prism/extractors/`

---

## Table of Contents

1. [Overview](#overview)
2. [Enhanced Keyword Extractor](#enhanced-keyword-extractor)
3. [SENTINEL Risk Detection](#sentinel-risk-detection)
4. [Temporal Analysis](#temporal-analysis)
5. [Configuration](#configuration)
6. [Integration Guide](#integration-guide)
7. [API Reference](#api-reference)

---

## Overview

The EPI keyword system consists of two complementary subsystems:

1. **RIVET (Enhanced Keyword Extractor)**: Gates keywords IN - selects relevant keywords from journal entries
2. **SENTINEL (Risk Detector)**: Gates risk levels UP - monitors patterns to detect concerning trends

### Philosophy

- **RIVET**: Quality control for keyword selection (forward gating)
- **SENTINEL**: Early warning system for mental health concerns (reverse gating)
- **Temporal Analysis**: Tracks usage patterns over time for both systems

---

## Enhanced Keyword Extractor

**File:** `enhanced_keyword_extractor.dart`

### Keyword Categories

The system now includes **200+ curated keywords** across semantic categories:

#### 1. Positive Emotions (45 keywords)
```dart
'grateful', 'hopeful', 'excited', 'calm', 'peaceful', 'confident', 'joyful',
'relaxed', 'energized', 'proud', 'happy', 'optimistic', 'content', 'satisfied',
'fulfilled', 'blessed', 'thankful', 'serene', 'empowered', 'loving', 'secure'...
```

#### 2. Negative Emotions - Anxiety & Fear (27 keywords)
```dart
'anxious', 'stressed', 'overwhelmed', 'worried', 'fearful', 'scared', 'terrified',
'panicked', 'nervous', 'tense', 'uneasy', 'restless', 'on edge', 'paranoid',
'threatened', 'insecure', 'helpless', 'powerless', 'trapped', 'suffocated'...
```

#### 3. Negative Emotions - Sadness & Depression (35 keywords)
```dart
'sad', 'depressed', 'heartbroken', 'devastated', 'grief', 'grieving', 'mourning',
'lonely', 'empty', 'hollow', 'numb', 'hopeless', 'despair', 'defeated', 'broken',
'shattered', 'crushed', 'miserable', 'isolated', 'alone', 'abandoned'...
```

#### 4. Negative Emotions - Anger & Frustration (24 keywords)
```dart
'angry', 'frustrated', 'irritated', 'annoyed', 'furious', 'enraged', 'bitter',
'resentful', 'hostile', 'aggressive', 'vengeful', 'disgusted', 'outraged'...
```

#### 5. Negative Emotions - Shame & Guilt (19 keywords)
```dart
'ashamed', 'guilty', 'embarrassed', 'humiliated', 'mortified', 'degraded',
'inadequate', 'unworthy', 'worthless', 'incompetent', 'failure', 'defective'...
```

#### 6. Negative Emotions - Confusion & Doubt (18 keywords)
```dart
'uncertain', 'confused', 'lost', 'disoriented', 'bewildered', 'perplexed',
'doubtful', 'skeptical', 'suspicious', 'conflicted', 'ambivalent', 'indecisive'...
```

#### 7. Negative Emotions - Disappointment & Regret (13 keywords)
```dart
'disappointed', 'let down', 'discouraged', 'disillusioned', 'dismayed', 'deflated',
'regretful', 'remorse', 'hindsight', 'wishing', 'if only', 'shouldve'...
```

#### 8. Struggles & Challenges (31 keywords - NEW)
```dart
'struggle', 'difficulty', 'obstacle', 'problem', 'crisis', 'conflict', 'tension',
'burden', 'pressure', 'hardship', 'suffering', 'pain', 'trauma', 'damage', 'loss'...
```

#### 9. Life Domains (26 keywords)
```dart
'work', 'family', 'relationship', 'health', 'creativity', 'spirituality', 'money',
'career', 'friendship', 'home', 'travel', 'learning', 'goals', 'purpose'...
```

#### 10. Growth & Transformation (37 keywords)
```dart
'growth', 'healing', 'breakthrough', 'challenge', 'transition', 'discovery',
'transformation', 'progress', 'balance', 'wisdom', 'resilience', 'recovery'...
```

### Emotion Amplitude Map

Emotional intensity ratings (0.0 - 1.0) for **100+ keywords**:

```dart
// Highest amplitude (0.90-1.0) - Critical intensity
'devastated': 0.95, 'terrified': 0.95, 'heartbroken': 0.95, 'hopeless': 0.92

// Very high amplitude (0.80-0.89) - Severe distress
'overwhelmed': 0.85, 'depressed': 0.80, 'humiliated': 0.80

// High amplitude (0.70-0.79) - Significant distress
'angry': 0.75, 'sad': 0.75, 'ashamed': 0.75, 'lonely': 0.72

// Medium amplitude (0.50-0.69) - Moderate distress/emotion
'disappointed': 0.62, 'confused': 0.60, 'happy': 0.65

// Low amplitude (0.30-0.49) - Mild emotion/neutral
'calm': 0.45, 'stable': 0.35, 'neutral': 0.35
```

### Phase-Keyword Mapping

Keywords are mapped to 7 emotional phases:

#### Discovery Phase (Mostly Positive)
- **Keywords:** curious, exploring, learning, wondering, beginning, new, excited, hopeful
- **Amplitude:** Generally low-medium (exploration is gentle)
- **Risk Level:** Low (normal uncertainty)

#### Expansion Phase (Positive + Growth Stress)
- **Keywords:** growing, building, thriving, confident, optimistic + pressure, stressed, overwhelmed
- **Amplitude:** Medium (growth can be demanding)
- **Risk Level:** Low-Moderate (stress from expansion is normal)

#### Transition Phase (Mixed)
- **Keywords:** changing, shifting, adapting + uncertain, anxious, vulnerable, letting go
- **Amplitude:** Medium-High (change is challenging)
- **Risk Level:** Moderate-Elevated (vulnerable period)

#### Consolidation Phase (Stabilizing)
- **Keywords:** integrating, stabilizing, grounding, balanced + tired, rebuilding, slowly improving
- **Amplitude:** Low-Medium (recovery in progress)
- **Risk Level:** Low-Moderate (normal fatigue from stabilization)

#### Recovery Phase (Healing)
- **Keywords:** healing, resting, nurturing, calm + wounded, trauma, grief, slowly healing
- **Amplitude:** High (active healing from significant distress)
- **Risk Level:** Elevated (fragile state, needs monitoring)

#### Crucible Phase (Pre-Breakthrough Pressure) - NEW
- **Keywords:** frustrated, stuck, struggling, determined, breaking point, at my limit
- **Amplitude:** High (intense pressure)
- **Risk Level:** Elevated (high intensity but purposeful struggle)

#### Breakthrough Phase (Positive Resolution)
- **Keywords:** clarity, insight, liberation, relief, enlightened, weight lifted, finally
- **Amplitude:** High (intense positive emotion)
- **Risk Level:** Low (positive transformation)

### RIVET Gating System

RIVET applies 6 quality gates to filter keyword candidates:

```dart
// Gate 1: Minimum score threshold
if (score < 0.15) reject();  // Too weak/irrelevant

// Gate 2: Evidence types threshold
if (supportTypes.length < 1) reject();  // Insufficient evidence

// Gate 3: Phase match threshold
if (!isDescriptive && phaseMatch < 0.10) reject();  // Doesn't fit phase

// Gate 4: Emotion amplitude for emotion-anchored terms
if (isEmotionAnchored && emotionAmp < 0.05) reject();  // Too weak emotion

// Gate 5: Overuse penalty (temporal)
if (usageRate > 0.4) applyPenalty();  // Used too frequently

// Gate 6: Diversity boost (temporal)
if (usageRate < 0.1 && score > 0.3) applyBoost();  // Underrepresented
```

### Scoring Equation (AS-IS)

```dart
score = (0.45 × TFIDF) +
        (0.15 × Centrality) +
        (0.10 × EmotionAmplitude) +
        (0.10 × Recency) +
        (0.10 × PhaseMatch) +
        (0.10 × PhraseQuality)
```

**Final Score:** Normalized to [0.0, 1.0]

---

## SENTINEL Risk Detection

**File:** `sentinel_risk_detector.dart`

SENTINEL is the **reverse RIVET** - instead of gating keywords in, it gates risk levels up.

### Risk Levels

```dart
enum RiskLevel {
  minimal,     // 0.00-0.24: Normal, healthy emotional range
  low,         // 0.25-0.39: Some distress but manageable
  moderate,    // 0.40-0.54: Noticeable concern, should monitor
  elevated,    // 0.55-0.69: Significant concern, consider intervention
  high,        // 0.70-0.84: Serious concern, immediate attention needed
  severe,      // 0.85-1.00: Critical concern, urgent professional help
}
```

### Time Windows

```dart
enum TimeWindow {
  day,         // Last 24 hours
  threeDay,    // Last 3 days
  week,        // Last 7 days
  twoWeek,     // Last 14 days
  month,       // Last 30 days
}
```

### Pattern Detection

SENTINEL detects 6 types of concerning patterns:

#### 1. Clustering Pattern
**Detection:** 3+ high-amplitude (>0.75) negative keywords within 48 hours

**Example:**
```
Day 1, 2pm: "devastated", "hopeless", "alone"
Day 1, 8pm: "broken", "can't go on"
Day 2, 10am: "worthless", "giving up"
→ CLUSTER DETECTED: Severity 0.85
```

#### 2. Persistent Distress Pattern
**Detection:** 5+ consecutive days with high-amplitude negative keywords

**Example:**
```
Mon: "sad", "tired"
Tue: "hopeless", "empty"
Wed: "depressed", "numb"
Thu: "hollow", "disconnected"
Fri: "defeated", "heavy"
→ PERSISTENT PATTERN: Severity 0.72
```

#### 3. Escalating Trend Pattern
**Detection:** Linear trend showing increasing emotional amplitude over time

**Example:**
```
Week 1: avg amplitude 0.45
Week 2: avg amplitude 0.58
Week 3: avg amplitude 0.71
Week 4: avg amplitude 0.82
→ ESCALATING TREND: Severity 0.68
```

#### 4. Phase Mismatch Pattern
**Detection:** High negative emotions during expected positive phases

**Example:**
```
Phase: Expansion (should be positive/growing)
Keywords: "devastated", "hopeless", "broken", "worthless"
→ PHASE MISMATCH: Severity 0.65
```

#### 5. Isolation Pattern
**Detection:** 30%+ of entries contain isolation/withdrawal keywords

**Example:**
```
Keywords: "isolated", "alone", "avoiding", "hiding", "disconnected"
Frequency: 5 out of 10 recent entries (50%)
→ ISOLATION PATTERN: Severity 0.75
```

#### 6. Hopelessness Pattern (CRITICAL)
**Detection:** ANY instance of hopelessness/despair keywords

**Example:**
```
Keywords: "hopeless", "no point", "give up", "can't go on"
→ HOPELESSNESS PATTERN: Severity 0.90+ (CRITICAL)
```

### Reverse RIVET Gating

SENTINEL applies 6 gates that **ESCALATE** risk scores:

```dart
// Base score calculation
baseScore = (0.3 × avgAmplitude) +
            (0.3 × highAmplitudeRate) +
            (0.2 × negativeRatio) +
            (0.2 × maxPatternSeverity)

// REVERSE GATE 1: High base score → +0.10
if (baseScore > 0.60) gatedScore += 0.10;

// REVERSE GATE 2: Multiple patterns → +0.15
if (patterns.length >= 3) gatedScore += 0.15;

// REVERSE GATE 3: Critical patterns → +0.20
if (hasHopelessness || hasIsolation) gatedScore += 0.20;

// REVERSE GATE 4: High negative density → +0.10
if (negativeRatio > 0.70) gatedScore += 0.10;

// REVERSE GATE 5: Escalating trend → +0.12
if (hasEscalation) gatedScore += 0.12;

// REVERSE GATE 6: Persistent distress → +0.08
if (hasPersistent) gatedScore += 0.08;
```

**Maximum escalation:** +0.75 (if all gates fire)

### Risk-Based Recommendations

#### Severe/High Risk (0.70-1.00)
```
🚨 Immediate action recommended
- Contact crisis helpline or emergency services
- Reach out to mental health professional immediately
- Inform trusted friend/family member
- Do not isolate - stay with someone if possible

Crisis Resources:
- 988 Suicide & Crisis Lifeline (US)
- Crisis Text Line: Text HOME to 741741
```

#### Elevated Risk (0.55-0.69)
```
⚠️ Significant concern - action needed
- Schedule appointment with therapist/counselor
- Practice daily self-care routines
- Reach out to supportive people
- Avoid major decisions during this period
```

#### Moderate Risk (0.40-0.54)
```
⚡ Monitor closely
- Consider speaking with mental health professional
- Engage in stress-reduction activities
- Maintain social connections
- Track patterns in journal
```

#### Low/Minimal Risk (0.00-0.39)
```
✓ Emotional health stable
- Continue healthy habits
- Maintain routines
- Stay connected with support network
```

---

## Temporal Analysis

### KeywordHistory Class

Tracks usage patterns over time:

```dart
class KeywordHistory {
  final String keyword;
  final int usageCount;          // Total times used
  final DateTime? lastUsed;       // Most recent usage
  final List<DateTime> usageDates;// All usage dates
  final double avgAmplitude;      // Average emotional intensity
}
```

### Temporal Adjustments (RIVET)

RIVET applies temporal adjustments to promote keyword diversity:

#### New Keywords (+15% boost)
```dart
if (keywordHistory[keyword] == null) {
  score *= 1.15;  // Encourage new vocabulary
}
```

#### Overused Keywords (-15% penalty)
```dart
if (usageRate > 0.40) {  // Used in >40% of recent entries
  score *= 0.85;  // Discourage repetition
}
```

#### Underrepresented Keywords (+15% boost)
```dart
if (usageRate < 0.10 && score > 0.3) {
  score *= 1.15;  // Surface neglected themes
}
```

#### Dormant Keywords (+10% boost)
```dart
if (lastUsed < 21 days ago) {
  score *= 1.10;  // Encourage variety
}
```

### Temporal Metrics (SENTINEL)

SENTINEL tracks these temporal metrics:

```dart
metrics = {
  'total_entries': 15,
  'day_span': 30,
  'entries_per_day': 0.5,
  'avg_amplitude': 0.62,
  'high_amplitude_rate': 0.33,  // 33% of entries have high-amp keywords
  'negative_keyword_ratio': 0.68, // 68% of keywords are negative
  'phase_distribution': {
    'Recovery': 8,
    'Transition': 4,
    'Consolidation': 3
  }
}
```

---

## Configuration

### RivetConfig

```dart
const RivetConfig({
  // Candidate limits
  this.maxCandidates = 20,      // Max keywords to show
  this.preselectTop = 15,       // Auto-select top N

  // Gating thresholds
  this.tauAdd = 0.15,           // Min score to add
  this.minEvidenceTypes = 1,    // Min evidence sources
  this.minPhaseMatch = 0.10,    // Min phase relevance
  this.minEmotionAmp = 0.05,    // Min emotion intensity

  // Temporal analysis
  this.enableTemporalAnalysis = true,
  this.temporalLookbackDays = 30,
  this.recencyBoostFactor = 1.2,
  this.overuseThreshold = 0.4,  // 40% usage rate
  this.underrepresentedBoost = 1.15,
});
```

### SentinelConfig

```dart
const SentinelConfig({
  // Amplitude thresholds
  this.highAmplitudeThreshold = 0.75,
  this.criticalAmplitudeThreshold = 0.90,

  // Frequency thresholds
  this.severeConcernFrequency = 3,     // Min cluster size
  this.persistentDistressMinDays = 5,  // Min consecutive days

  // Clustering detection
  this.clusterWindowHours = 48,        // 48-hour window
  this.clusterMinSize = 3,             // Min entries in cluster

  // Trend detection
  this.deteriorationThreshold = 0.15,  // Min trend slope
  this.trendAnalysisMinEntries = 7,    // Min entries for trend

  // Phase risk multipliers
  this.phaseRiskMultipliers = const {
    'Discovery': 0.8,      // Lower risk (exploration)
    'Expansion': 0.9,      // Slightly lower (growth stress)
    'Transition': 1.2,     // Higher risk (vulnerable)
    'Consolidation': 1.0,  // Baseline
    'Recovery': 1.3,       // Higher risk (fragile)
    'Crucible': 1.1,       // Slightly higher (intense but purposeful)
    'Breakthrough': 0.7,   // Lower risk (positive transformation)
  },
});
```

---

## Integration Guide

### Basic RIVET Usage

```dart
import 'package:my_app/prism/extractors/enhanced_keyword_extractor.dart';

// Extract keywords from journal entry
final response = EnhancedKeywordExtractor.extractKeywords(
  entryText: userInput,
  currentPhase: 'Recovery',
);

// Access results
final suggestedKeywords = response.candidates.map((c) => c.keyword).toList();
final preselectedKeywords = response.chips;
final metadata = response.meta;

print('Suggested: $suggestedKeywords');
print('Pre-selected: $preselectedKeywords');
```

### RIVET with Temporal Analysis

```dart
// Build keyword history from past entries
final keywordHistory = <String, KeywordHistory>{};

for (final pastEntry in userJournalHistory) {
  for (final keyword in pastEntry.keywords) {
    if (!keywordHistory.containsKey(keyword)) {
      keywordHistory[keyword] = KeywordHistory(
        keyword: keyword,
        usageCount: 1,
        lastUsed: pastEntry.timestamp,
        usageDates: [pastEntry.timestamp],
        avgAmplitude: getAmplitude(keyword),
      );
    } else {
      // Update existing history
      updateHistory(keywordHistory[keyword], pastEntry);
    }
  }
}

// Extract with temporal awareness
final response = EnhancedKeywordExtractor.extractKeywords(
  entryText: userInput,
  currentPhase: 'Transition',
  keywordHistory: keywordHistory,  // Enable temporal adjustments
);
```

### Basic SENTINEL Usage

```dart
import 'package:my_app/prism/extractors/sentinel_risk_detector.dart';

// Prepare journal entry data
final entries = userJournalHistory.map((entry) =>
  JournalEntryData(
    timestamp: entry.date,
    keywords: entry.selectedKeywords,
    phase: entry.phase,
    mood: entry.mood,
  )
).toList();

// Analyze risk
final analysis = SentinelRiskDetector.analyzeRisk(
  entries: entries,
  timeWindow: TimeWindow.week,
);

// Check results
print('Risk Level: ${analysis.riskLevel.name}');
print('Risk Score: ${analysis.riskScore}');
print('Patterns: ${analysis.patterns.length}');
print('Summary: ${analysis.summary}');

// Handle high risk
if (analysis.riskLevel == RiskLevel.high ||
    analysis.riskLevel == RiskLevel.severe) {
  showCrisisDialog(analysis.recommendations);
}
```

### Full Integration Example

```dart
class JournalService {
  Future<void> saveEntry({
    required String content,
    required String mood,
    required String phase,
  }) async {
    // Step 1: Extract keywords with RIVET
    final keywordHistory = await _buildKeywordHistory();

    final extraction = EnhancedKeywordExtractor.extractKeywords(
      entryText: content,
      currentPhase: phase,
      keywordHistory: keywordHistory,
    );

    // Step 2: Save entry with keywords
    final entry = JournalEntry(
      content: content,
      mood: mood,
      phase: phase,
      keywords: extraction.chips,
      timestamp: DateTime.now(),
    );
    await database.saveEntry(entry);

    // Step 3: Run SENTINEL risk analysis
    final recentEntries = await database.getRecentEntries(days: 7);
    final riskAnalysis = SentinelRiskDetector.analyzeRisk(
      entries: recentEntries,
      timeWindow: TimeWindow.week,
    );

    // Step 4: Store risk assessment
    await database.saveRiskAssessment(riskAnalysis);

    // Step 5: Alert if needed
    if (riskAnalysis.riskLevel.index >= RiskLevel.elevated.index) {
      await notificationService.sendRiskAlert(riskAnalysis);
    }

    // Step 6: Update keyword history
    await _updateKeywordHistory(extraction.chips);
  }
}
```

---

## API Reference

### EnhancedKeywordExtractor

#### extractKeywords()
```dart
static KeywordExtractionResponse extractKeywords({
  required String entryText,
  required String currentPhase,
  RivetConfig config = _defaultConfig,
  Map<String, KeywordHistory>? keywordHistory,
})
```

**Parameters:**
- `entryText`: User's journal entry text
- `currentPhase`: Current emotional phase (Discovery, Expansion, etc.)
- `config`: Optional RIVET configuration
- `keywordHistory`: Optional historical usage data for temporal analysis

**Returns:** `KeywordExtractionResponse`
- `candidates`: All keyword candidates with scores
- `chips`: Pre-selected keywords
- `meta`: Extraction metadata

---

### SentinelRiskDetector

#### analyzeRisk()
```dart
static SentinelAnalysis analyzeRisk({
  required List<JournalEntryData> entries,
  required TimeWindow timeWindow,
  SentinelConfig config = _defaultConfig,
})
```

**Parameters:**
- `entries`: List of journal entries to analyze
- `timeWindow`: Time window for analysis (day, week, month, etc.)
- `config`: Optional SENTINEL configuration

**Returns:** `SentinelAnalysis`
- `riskLevel`: Severity level (minimal to severe)
- `riskScore`: Numerical score (0.0 - 1.0)
- `patterns`: Detected concerning patterns
- `metrics`: Analysis metrics
- `recommendations`: Action items based on risk level
- `summary`: Human-readable summary

---

## Examples

### Example 1: New User (No History)

**Input:**
```dart
entryText: "I feel curious about this new journey. A bit uncertain but excited!"
currentPhase: "Discovery"
keywordHistory: null  // New user
```

**RIVET Output:**
```dart
suggestedKeywords: [
  "curious",      // Phase match: Discovery (0.9)
  "excited",      // Positive emotion (0.8)
  "uncertain",    // Discovery-appropriate (0.65)
  "new",          // Phase match (0.75)
  "journey"       // Metaphorical (0.55)
]

preselectedKeywords: ["curious", "excited", "new"]
```

**SENTINEL Output:**
```dart
riskLevel: RiskLevel.minimal
riskScore: 0.15
patterns: []
summary: "No concerning patterns detected. Emotional health appears stable."
```

---

### Example 2: User in Crisis

**Input:**
```dart
entries: [
  // Day 1
  JournalEntryData(
    keywords: ["devastated", "hopeless", "alone"],
    phase: "Recovery",
    timestamp: Oct 10, 2pm
  ),
  // Day 1 evening
  JournalEntryData(
    keywords: ["broken", "can't go on", "worthless"],
    phase: "Recovery",
    timestamp: Oct 10, 8pm
  ),
  // Day 2
  JournalEntryData(
    keywords: ["give up", "no point", "empty"],
    phase: "Recovery",
    timestamp: Oct 11, 10am
  ),
]
timeWindow: TimeWindow.threeDay
```

**SENTINEL Output:**
```dart
riskLevel: RiskLevel.severe
riskScore: 0.92

patterns: [
  RiskPattern(
    type: "cluster",
    description: "Detected 3 high-intensity entries within 48 hours",
    severity: 0.88
  ),
  RiskPattern(
    type: "hopelessness",
    description: "Critical: Indicators of hopelessness or despair detected",
    severity: 0.95
  ),
  RiskPattern(
    type: "isolation",
    description: "Pattern of isolation and social withdrawal detected",
    severity: 0.76
  )
]

recommendations: [
  "🚨 Immediate action recommended: Consider reaching out to a mental health professional",
  "Contact a crisis helpline if you're in immediate distress",
  "🆘 CRITICAL: Please contact a crisis helpline or emergency services",
  "📞 Consider reaching out to at least one person today"
]

summary: "Risk Level: SEVERE - Analyzed 3 entries. Detected 3 risk pattern(s): cluster, hopelessness, isolation."

reverse_rivet_gates: [
  "REVERSE_GATE_1_HIGH_BASE_SCORE",
  "REVERSE_GATE_2_MULTIPLE_PATTERNS",
  "REVERSE_GATE_3_CRITICAL_PATTERN",
  "REVERSE_GATE_4_HIGH_NEGATIVE_DENSITY"
]
```

---

### Example 3: Temporal Diversity

**Input:**
```dart
entryText: "Feeling overwhelmed again. Same as yesterday."
currentPhase: "Consolidation"

keywordHistory: {
  "overwhelmed": KeywordHistory(
    usageCount: 8,
    usageDates: [Oct 1, Oct 2, Oct 4, Oct 6, Oct 8, Oct 9, Oct 10, Oct 11],
    lastUsed: Oct 11,
    avgAmplitude: 0.85
  ),
  // 20 total entries in past 30 days
  // "overwhelmed" used in 8/20 = 40% (OVERUSE THRESHOLD)
}
```

**RIVET Temporal Adjustment:**
```dart
// Initial score for "overwhelmed": 0.68
// Usage rate: 0.40 (exactly at threshold)
// Temporal adjustment: OVERUSE_PENALTY
// Final score: 0.68 × 0.85 = 0.58

// Alternative keywords get boosted:
"stressed": 0.45 → 0.45 × 1.10 = 0.50 (dormant boost)
"burdened": 0.42 → 0.42 × 1.15 = 0.48 (underrepresented boost)
```

**Effect:** System encourages vocabulary diversity, helping user articulate feelings in new ways.

---

## Best Practices

### For RIVET

1. **Always provide phase context** - phase matching is crucial for relevance
2. **Enable temporal analysis** when history is available (>7 entries)
3. **Review preselected keywords** - they're suggestions, not requirements
4. **Consider custom config** for specialized use cases (e.g., clinical vs. personal journaling)

### For SENTINEL

1. **Run analysis regularly** - at least weekly for active users
2. **Use appropriate time windows**:
   - Daily: Check immediate crisis
   - Weekly: Monitor trends
   - Monthly: Assess long-term patterns
3. **Act on elevated+ risk** - don't ignore warnings
4. **Log all analyses** - patterns over time are valuable
5. **Respect privacy** - risk data is highly sensitive

### Combined Usage

1. **RIVET first, SENTINEL after** - extract keywords, then analyze patterns
2. **Store metadata** - RIVET trace data helps SENTINEL detect patterns
3. **Monitor both systems** - keyword diversity (RIVET) and risk levels (SENTINEL)
4. **Use phase progression** - phase changes can indicate risk shifts

---

## Troubleshooting

### RIVET Issues

**Problem:** Too many keywords suggested
- **Solution:** Lower `maxCandidates` in config
- **Solution:** Increase `tauAdd` threshold (more restrictive)

**Problem:** No keywords selected
- **Solution:** RIVET gating too strict - lower thresholds
- **Solution:** Check if text is too short (<20 words)
- **Solution:** Verify `curatedKeywords` contains relevant terms

**Problem:** Same keywords every time
- **Solution:** Enable temporal analysis with keyword history
- **Solution:** Check `overuseThreshold` - might be too high

### SENTINEL Issues

**Problem:** False positives (high risk for normal distress)
- **Solution:** Adjust phase risk multipliers (e.g., Recovery should allow distress)
- **Solution:** Increase `highAmplitudeThreshold` (make it less sensitive)
- **Solution:** Increase `clusterMinSize` (require more evidence)

**Problem:** False negatives (missing actual risk)
- **Solution:** Check if critical keywords are in `emotionAmplitudeMap`
- **Solution:** Lower `highAmplitudeThreshold` (more sensitive)
- **Solution:** Verify pattern detection logic for edge cases

**Problem:** No patterns detected with few entries
- **Solution:** This is expected - require minimum entries (7+) for reliable analysis
- **Solution:** Use shorter time windows (day/threeDay) for sparse data

---

## Future Enhancements

### Planned Features

1. **RIVET++**
   - Multi-language support
   - Custom keyword training
   - Semantic similarity matching (embeddings)
   - Contextual phrase extraction

2. **SENTINEL++**
   - Machine learning risk prediction
   - Integration with external health services
   - Personalized risk thresholds
   - Family/therapist notification system

3. **Integration**
   - Real-time risk monitoring dashboard
   - Automated intervention workflows
   - Research data export (anonymized)

---

## Support & Resources

### Crisis Resources

- **988 Suicide & Crisis Lifeline** (US): Call or text 988
- **Crisis Text Line**: Text HOME to 741741
- **International Association for Suicide Prevention**: https://www.iasp.info/resources/Crisis_Centres/

### Documentation

- Architecture: `docs/architecture/EPI_Architecture.md`
- MIRA Integration: `docs/architecture/MIRA_Basics.md`
- API Reference: `docs/api/` (coming soon)

### Contact

- **Issues**: GitHub Issues
- **Questions**: Discussions
- **Security**: security@epi.ai (for sensitive issues only)

---

**Last Updated:** October 12, 2025
**Version:** 1.0.0
**Authors:** EPI Development Team

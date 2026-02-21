# SENTINEL Risk Detection Factors - Comprehensive Breakdown

## Overview

SENTINEL (Severity Evaluation and Negative Trend Identification for Emotional Longitudinal tracking) is the reverse of RIVET - instead of filtering keywords to add, it monitors keyword patterns over time to detect escalating risk levels.

## Implementation Note

This document describes the **advanced SENTINEL implementation** (`SentinelRiskDetector`) which provides comprehensive risk pattern detection using keyword amplitude mapping, source weighting, and multiple pattern types. 

For the simpler real-time crisis detection implementation (`SentinelAnalyzer`), see `SENTINEL_ARCHITECTURE.md`.

## Current Factors

### 1. **Keyword Amplitude** (Primary Signal - 0.0-1.0 scale)
**Location**: `EnhancedKeywordExtractor.emotionAmplitudeMap`, `SentinelRiskDetector._calculateMetricsWithWeighting()`

**How it works**:
- Each keyword has a pre-defined amplitude value (0.0-1.0) in `emotionAmplitudeMap`
- Amplitude represents emotional intensity of the keyword
- Higher amplitude = stronger emotional signal
- Used to identify high-intensity vs low-intensity emotional states

**Amplitude Categories**:
- **Highest (0.90-1.0)**: `ecstatic`, `devastated`, `furious`, `terrified`, `overjoyed`, `heartbroken`, `enraged`, `panicked`, `shattered`, `crushed`, `livid`, `hopeless`, `despair`, `despairing`, `hateful`, `traumatized`
- **Very High (0.80-0.89)**: `overwhelmed`, `miserable`, `outraged`, `grief`, `grieving`, `broken`, `elated`, `infuriated`, `excited`, `anxious`, `depressed`, `bitter`, `resentful`, `humiliated`, `mortified`, `disgusted`
- **High (0.70-0.79)**: `angry`, `sad`, `ashamed`, `guilty`, `joyful`, `inspired`, `empowered`, `loving`, `worried`, `scared`, `lonely`, `abandoned`, `rejected`, `worthless`, `defeated`, `trapped`, `hopeful`, `frustrated`, `stressed`, `fearful`
- **Medium-High (0.60-0.69)**: `happy`, `nervous`, `upset`, `hurt`, `disappointed`, `grateful`, `irritated`, `annoyed`
- **Medium (0.50-0.59)**: `calm`, `content`, `peaceful`, `relaxed`, `tired`, `exhausted`
- **Low (0.30-0.49)**: `neutral`, `fine`, `okay`, `alright`
- **Very Low (0.0-0.29)**: No emotional signal

**Thresholds**:
- `highAmplitudeThreshold`: 0.75 (default) - Keywords above this are considered high-intensity
- `criticalAmplitudeThreshold`: 0.90 (default) - Keywords above this are considered critical

**Weight**: Primary metric - used in all calculations

---

### 2. **Source Weighting** (Confidence Adjustment)
**Location**: `SentinelRiskDetector._calculateMetricsWithWeighting()`, `ReflectiveEntryData.effectiveConfidence`

**How it works**:
- Different conversation sources have different confidence levels:
  - **Journal entries (conversations)**: High confidence (1.0)
  - **Draft entries**: Medium confidence (0.8)
  - **Chat entries**: Lower confidence (0.6)
- Amplitude is multiplied by source confidence: `weightedAmplitude = baseAmplitude * sourceWeight`
- Ensures journal conversations have more weight than casual chat

**Weight**: Applied to all amplitude calculations

---

### 3. **Temporal Clustering** (Time-Based Pattern Detection)
**Location**: `SentinelRiskDetector._detectClustering()`, `SentinelAnalyzer._calculateTemporalClustering()`

**How it works**:
- Detects when high-amplitude keywords cluster in short time periods
- Uses sliding window analysis (default: 48 hours)
- Identifies crisis patterns vs normal emotional variance

**Configuration**:
- `clusterWindowHours`: 48 (default) - Time window for detecting clusters
- `clusterMinSize`: 3 (default) - Minimum entries in cluster to trigger concern

**Pattern Detection**:
- Groups entries within time window
- Counts high-amplitude keywords per cluster
- Calculates cluster severity: `(avgAmplitude * 0.7) + (clusterSize * 0.3)`

**Weight**: Creates `RiskPattern` with severity 0.0-1.0

---

### 4. **Persistent Distress** (Multi-Day Pattern)
**Location**: `SentinelRiskDetector._detectPersistentDistress()`

**How it works**:
- Detects consecutive days with negative keywords
- Groups entries by day
- Finds longest streak of days with high-amplitude negative keywords

**Configuration**:
- `persistentDistressMinDays`: 5 (default) - Minimum consecutive days to trigger

**Severity Calculation**:
- `severity = (consecutiveDays / 10).clamp(0.5, 1.0)`
- Maxes out at 10 days (severity = 1.0)

**Weight**: Creates `RiskPattern` with severity 0.5-1.0

---

### 5. **Escalating Trend** (Deterioration Detection)
**Location**: `SentinelRiskDetector._detectEscalation()`

**How it works**:
- Uses linear regression to detect upward trend in amplitude over time
- Calculates slope of amplitude time series
- Positive slope = increasing intensity (worsening)

**Configuration**:
- `deteriorationThreshold`: 0.15 (default) - Minimum slope to trigger
- `trendAnalysisMinEntries`: 7 (default) - Minimum entries needed for trend analysis

**Formula**:
- Linear regression: `slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)`
- Severity: `(slope * 2).clamp(0.3, 1.0)`

**Weight**: Creates `RiskPattern` with severity 0.3-1.0

---

### 6. **Phase-Emotion Mismatch** (Contextual Anomaly)
**Location**: `SentinelRiskDetector._detectPhaseMismatch()`

**How it works**:
- Detects high negative emotions during "positive" phases
- Positive phases: `Expansion`, `Breakthrough`, `Discovery`
- Flags entries with high-amplitude negative keywords in positive phases

**Severity Calculation**:
- `severity = (mismatchCount / totalEntries).clamp(0.3, 0.9)`

**Weight**: Creates `RiskPattern` with severity 0.3-0.9

---

### 7. **Isolation Pattern** (Social Withdrawal)
**Location**: `SentinelRiskDetector._detectIsolationPattern()`

**How it works**:
- Detects keywords indicating social withdrawal
- Keywords: `isolated`, `alone`, `lonely`, `abandoned`, `rejected`, `unwanted`, `disconnected`, `withdrawal`, `hiding`, `avoiding`, `isolating`

**Configuration**:
- Minimum 2 entries with isolation keywords
- Minimum 30% of entries must contain isolation keywords

**Severity Calculation**:
- `severity = isolationRate.clamp(0.4, 0.95)`

**Weight**: Creates `RiskPattern` with severity 0.4-0.95

---

### 8. **Hopelessness Pattern** (Critical Signal)
**Location**: `SentinelRiskDetector._detectHopelessness()`

**How it works**:
- Detects explicit hopelessness/despair language
- Keywords: `hopeless`, `despair`, `despairing`, `give up`, `giving up`, `no point`, `pointless`, `meaningless`, `worthless`, `cant go on`, `ending`, `end it`

**Severity Calculation**:
- `severity = (0.85 + (entryCount * 0.05)).clamp(0.85, 1.0)`
- Even one occurrence = high severity (0.85+)

**Weight**: Creates `RiskPattern` with severity 0.85-1.0 (highest priority)

---

### 9. **Negative Keyword Ratio** (Emotional Valence)
**Location**: `SentinelRiskDetector._countNegativeKeywords()`, `_calculateMetricsWithWeighting()`

**How it works**:
- Counts keywords in negative emotion categories:
  - **Anxiety & Fear**: `anxious`, `stressed`, `overwhelmed`, `worried`, `fearful`, `scared`, `terrified`, `panicked`, `nervous`, `tense`, `uneasy`, `restless`, `threatened`, `insecure`, `helpless`, `powerless`, `trapped`, `suffocated`
  - **Sadness & Depression**: `sad`, `depressed`, `heartbroken`, `devastated`, `grief`, `grieving`, `mourning`, `lonely`, `empty`, `hollow`, `numb`, `hopeless`, `despair`, `defeated`, `broken`, `shattered`, `crushed`, `miserable`, `isolated`, `alone`, `abandoned`, `rejected`, `unwanted`, `unloved`
  - **Anger & Frustration**: `angry`, `frustrated`, `irritated`, `annoyed`, `furious`, `enraged`, `bitter`, `resentful`, `hostile`, `aggressive`, `disgusted`, `outraged`
  - **Shame & Guilt**: `ashamed`, `guilty`, `embarrassed`, `humiliated`, `mortified`, `inadequate`, `unworthy`, `worthless`, `failure`

**Calculation**:
- `negativeRatio = negativeKeywords / totalKeywords`

**Weight**: Used in base risk score calculation (20% weight)

---

### 10. **Phase Risk Multipliers** (Contextual Adjustment)
**Location**: `SentinelConfig.phaseRiskMultipliers`

**How it works**:
- Adjusts risk scores based on current phase
- Some phases are more vulnerable to distress than others

**Multipliers**:
- `Discovery`: 0.8 (lower - exploration is normal)
- `Expansion`: 0.9 (slightly lower - stress can be growth)
- `Transition`: 1.2 (higher - vulnerable period)
- `Consolidation`: 1.0 (baseline)
- `Recovery`: 1.3 (higher - fragile state)
- `Breakthrough`: 1.1 (slightly higher - intense period)

**Weight**: Applied to final risk score

---

### 11. **Self-Harm Language Detection** (Immediate Alert)
**Location**: `SentinelAnalyzer._detectSelfHarmLanguage()`

**How it works**:
- Detects explicit self-harm or suicide language
- Bypasses all other analysis - immediate alert

**Critical Phrases**:
- `want to die`, `kill myself`, `end my life`, `not worth living`, `better off dead`, `suicide`, `self harm`, `hurt myself`, `end it all`

**Behavior**:
- If detected → `riskScore = 1.0`, `alert = true`
- Triggers crisis mode immediately
- No temporal clustering analysis needed

**Weight**: Overrides all other factors (highest priority)

---

### 12. **RIVET Dangerous Transition** (Phase-Based Alert)
**Location**: `SentinelAnalyzer._checkRivetDangerousTransition()`

**How it works**:
- Checks RIVET system for dangerous phase transitions
- Currently placeholder (TODO: integrate with RIVET service)

**Behavior**:
- If detected → `riskScore = 1.0`, `alert = true`
- Triggers crisis mode immediately

**Weight**: Overrides temporal clustering (high priority)

---

### 13. **Temporal Windows** (Multi-Scale Analysis)
**Location**: `SentinelAnalyzer._calculateTemporalClustering()`

**How it works**:
- Analyzes entries across multiple time windows
- Recent windows weighted more heavily

**Windows**:
- **1 day**: Weight 1.0 (100%), Threshold 3 entries
- **3 days**: Weight 0.7 (70%), Threshold 5 entries
- **7 days**: Weight 0.4 (40%), Threshold 8 entries
- **30 days**: Weight 0.1 (10%), Threshold 15 entries

**Formula**:
- For each window: `score = (freq_score × avg_intensity) × weight`
- Final score: `(score_1day + score_3day + score_7day + score_30day) / 2.2`

**Weight**: Used in temporal clustering calculation

---

### 14. **Reverse RIVET Gating** (Score Escalation)
**Location**: `SentinelRiskDetector._calculateRiskScore()`

**How it works**:
- Reverse of RIVET gating - instead of filtering keywords, escalates risk levels
- Multiple gates can increase risk score

**Gates**:
- **Gate 1**: Base score > 0.60 → +0.10
- **Gate 2**: 3+ patterns detected → +0.15
- **Gate 3**: Critical patterns (hopelessness, isolation) → +0.20
- **Gate 4**: Negative keyword ratio > 0.70 → +0.10
- **Gate 5**: Escalating trend pattern → +0.12
- **Gate 6**: Persistent distress pattern → +0.08

**Final Score**:
- `gatedScore = baseScore + gateAdditions`
- Clamped to 0.0-1.0

**Weight**: Applied to final risk score calculation

---

### 15. **Base Risk Score Components** (Weighted Combination)
**Location**: `SentinelRiskDetector._calculateRiskScore()`

**How it works**:
- Combines multiple metrics into base score

**Components**:
- Average amplitude: 30% weight
- High amplitude rate: 30% weight
- Negative keyword ratio: 20% weight
- Pattern severity: 20% weight

**Formula**:
```
baseScore = (avgAmplitude × 0.3) + 
            (highAmplitudeRate × 0.3) + 
            (negativeRatio × 0.2) + 
            (maxPatternSeverity × 0.2)
```

**Weight**: Base for all gating calculations

---

### 16. **Source Confidence Metrics** (Data Quality)
**Location**: `SentinelRiskDetector._calculateMetricsWithWeighting()`

**How it works**:
- Tracks data quality and confidence
- Lower confidence = potentially higher risk (less reliable data)

**Metrics**:
- `avgConfidence`: Average confidence across all entries
- `highConfidenceRatio`: Percentage of entries with high confidence

**Weight**: Used in risk score calculation (10% each)

---

### 17. **Phase Transition Analysis** (Contextual Insights)
**Location**: `SentinelRiskDetector._analyzePhaseTransitions()`

**How it works**:
- Analyzes phase distribution and transitions
- Detects approaching phases
- Calculates shift percentage

**Metrics**:
- `current_phase`: Most common phase in entries
- `approaching_phase`: Phase with increasing activity
- `shift_percentage`: Percentage shift toward approaching phase
- `phase_risk_alignment`: Risk score aligned with phase context

**Weight**: Used for recommendations, not risk score

---

## Adaptive Configuration Factors (User Cadence-Based)

### 18. **User Cadence Detection** (Usage Pattern)
**Location**: `AdaptiveSentinelCalculator`, `SentinelConfig` factories

**How it works**:
- Detects user's journaling pattern
- Adapts configuration based on cadence

**User Types**:
- **Power User**: ≤ 2 days between entries (daily/near-daily)
- **Frequent**: 2-4 days between entries (2-3x/week)
- **Weekly**: 4-9 days between entries (once/week)
- **Sporadic**: > 9 days between entries (less than weekly)

**Weight**: Determines which `SentinelConfig` factory to use

---

### 19. **Emotional Intensity Weight** (Adaptive)
**Location**: `SentinelConfig.emotionalIntensityWeight`

**How it works**:
- Weight for emotional intensity component
- Varies by user cadence

**Values**:
- Power User: 0.25
- Frequent: 0.30
- Weekly: 0.35
- Sporadic: 0.40

**Weight**: Part of emotional density calculation

---

### 20. **Emotional Diversity Weight** (Adaptive)
**Location**: `SentinelConfig.emotionalDiversityWeight`

**How it works**:
- Weight for emotional diversity component
- Measures variety of emotions expressed

**Values**:
- Power User: 0.25
- Frequent: 0.20
- Weekly: 0.15
- Sporadic: 0.10

**Weight**: Part of emotional density calculation

---

### 21. **Thematic Coherence Weight** (Adaptive)
**Location**: `SentinelConfig.thematicCoherenceWeight`

**How it works**:
- Weight for thematic coherence component
- Measures consistency of themes

**Values**:
- Power User: 0.25
- Frequent: 0.20
- Weekly: 0.15
- Sporadic: 0.10

**Weight**: Part of emotional density calculation

---

### 22. **Temporal Dynamics Weight** (Adaptive)
**Location**: `SentinelConfig.temporalDynamicsWeight`

**How it works**:
- Weight for temporal dynamics component
- Measures changes over time

**Values**:
- Power User: 0.25
- Frequent: 0.20
- Weekly: 0.15
- Sporadic: 0.15

**Weight**: Part of emotional density calculation

---

### 23. **Emotional Concentration Weight** (Adaptive)
**Location**: `SentinelConfig.emotionalConcentrationWeight`

**How it works**:
- Weight for emotional concentration component
- Detects when multiple emotions from same family cluster
- Important for sparse journalers

**Values**:
- Power User: 0.0
- Frequent: 0.10
- Weekly: 0.20
- Sporadic: 0.25

**Weight**: Part of emotional density calculation

---

### 24. **Explicit Emotion Multiplier** (Adaptive)
**Location**: `SentinelConfig.explicitEmotionMultiplierMin/Max`

**How it works**:
- Multiplies score for explicit emotion statements
- Patterns: "I feel [emotion]", "I am [emotion]", "I'm [emotion]", "I'm so [emotion]", "I'm feeling [emotion]", "I can't cope/handle/deal"

**Values**:
- Power User: 1.0-1.0 (no boost)
- Frequent: 1.0-1.3
- Weekly: 1.0-1.5
- Sporadic: 1.0-1.5

**Weight**: Multiplies raw emotional density score

---

### 25. **Word Count Normalization** (Adaptive)
**Location**: `SentinelConfig.normalizationMethod`, `normalizationFloor`

**How it works**:
- Normalizes emotional density by entry length
- Prevents long entries from dominating

**Methods**:
- **Linear**: `score / word_count`
- **Sqrt**: `score / sqrt(word_count)`
- **Log**: `score / log(word_count + 1)`

**Selection**:
- Power User: Linear, Floor 50
- Frequent/Weekly/Sporadic: Sqrt, Floor 50/50/40

**Weight**: Applied to final emotional density score

---

### 26. **Temporal Decay Factor** (Adaptive)
**Location**: `SentinelConfig.temporalDecayFactor`

**How it works**:
- Decay factor for older entries
- Higher = less decay (more weight on history)

**Values**:
- Power User: 0.95
- Frequent: 0.97
- Weekly: 0.98
- Sporadic: 0.99

**Weight**: Applied to temporal dynamics calculation

---

### 27. **High Intensity Threshold** (Adaptive)
**Location**: `SentinelConfig.highIntensityThreshold`

**How it works**:
- Threshold for considering entry "high intensity"
- Lower threshold = more sensitive

**Values**:
- Power User: 0.7
- Frequent: 0.7
- Weekly: 0.65
- Sporadic: 0.6

**Weight**: Used in pattern detection

---

### 28. **Minimum Words for Full Score** (Adaptive)
**Location**: `SentinelConfig.minWordsForFullScore`

**How it works**:
- Minimum word count to achieve full emotional density score
- Lower for sparse journalers

**Values**:
- Power User: 100
- Frequent: 100
- Weekly: 75
- Sporadic: 50

**Weight**: Used in normalization calculation

---

## Risk Level Determination

### Risk Level Thresholds
**Location**: `SentinelRiskDetector._determineRiskLevel()`

**Mapping**:
- `score >= 0.85` → **Severe** (Critical concern, urgent professional help)
- `score >= 0.70` → **High** (Serious concern, immediate attention)
- `score >= 0.55` → **Elevated** (Significant concern, consider intervention)
- `score >= 0.40` → **Moderate** (Noticeable concern, should monitor)
- `score >= 0.25` → **Low** (Some distress but manageable)
- `score < 0.25` → **Minimal** (Normal, healthy emotional range)

---

## Current Issues

1. **Amplitude Map is Static**: Pre-defined values, no learning or adaptation
2. **Simple Keyword Matching**: Uses substring matching, not semantic understanding
3. **No Context from Previous Entries**: Each entry analyzed somewhat independently
4. **Binary Pattern Detection**: Patterns either detected or not, no confidence scores
5. **RIVET Integration Incomplete**: Placeholder for dangerous transition detection
6. **No User Feedback Loop**: Can't learn from false positives/negatives
7. **Temporal Windows Fixed**: Not adaptive to user's actual patterns
8. **Phase Multipliers Arbitrary**: No empirical basis for values

---

## Questions for Claude/ChatGPT Refinement

1. What's the optimal weighting between amplitude, patterns, and temporal factors?
2. Should we use semantic similarity instead of exact keyword matching?
3. How should we handle ambiguous cases (multiple patterns with similar severity)?
4. Should we consider user's baseline emotional state (personalized thresholds)?
5. What's the best way to incorporate user feedback/corrections?
6. Should amplitude values be learned/adapted per user?
7. How do we handle multilingual entries?
8. Should we use ML/NLP models for better semantic understanding?
9. How should we weight different entry sources (journal vs chat vs draft)?
10. What's the optimal temporal window configuration for different user cadences?
11. Should phase multipliers be data-driven rather than arbitrary?
12. How do we balance false positives (over-alerting) vs false negatives (missing crises)?

---

## Recommended Factors to Consider (Not Currently Implemented)

1. **Baseline Emotional State**: User's typical emotional range (personalized thresholds)
2. **Emotional Volatility**: Rate of change in emotions (stability vs instability)
3. **Social Context**: Frequency of social keywords (connected vs isolated)
4. **Sleep Patterns**: If available, correlate with emotional patterns
5. **Entry Frequency Changes**: Sudden increase/decrease in journaling frequency
6. **Keyword Co-occurrence**: Patterns of keywords appearing together
7. **Sentiment Trajectory**: Overall sentiment trend over time
8. **Crisis History**: Previous crisis episodes and patterns
9. **Recovery Indicators**: Positive keywords after negative periods
10. **External Triggers**: Time-based patterns (weekends, holidays, anniversaries)

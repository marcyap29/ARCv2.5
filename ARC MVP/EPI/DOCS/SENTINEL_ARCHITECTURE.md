# Sentinel Architecture Pseudocode

**Sentinel (Temporal Crisis Detection System)** - Emotional intensity clustering and crisis detection

## Overview

Sentinel detects crisis situations by analyzing temporal clustering of high emotional intensity in journal entries. It uses multi-window temporal analysis to identify when emotional distress is concentrated in time (indicating crisis) versus dispersed (indicating normal variance).

---

## Core Components

### 1. SentinelAnalyzer
Main service calculating Sentinel scores and detecting crisis conditions.

### 2. CrisisMode
Manages crisis mode activation/deactivation with 48-hour cooldown.

### 3. SentinelScore
Result containing:
- `score`: Crisis score (0.0-1.0)
- `alert`: Whether crisis mode should activate
- `reason`: Explanation of score
- `triggerEntries`: Entries that contributed to score
- `timespan`: Time period analyzed

### 4. CrisisEntry
Entry with elevated emotional intensity:
- `text`: Entry text
- `intensity`: Calculated emotional intensity (0.0-1.0)
- `timestamp`: When entry was created

---

## Core Algorithms

### Emotional Intensity Calculation

```
Emotional Intensity Detection
─────────────────────────────────────────────────────────────
Purpose: Quantify emotional distress level in entry text

Method:
  1. Scan text for high-intensity emotional markers
  2. Count occurrences of intensity markers
  3. Normalize to 0-1 scale

Intensity Markers:
  - devastated, destroyed, shattered, broken
  - overwhelmed, terrified, panic, desperate
  - anguish, agony, torture, unbearable, excruciating
  - "can't do this", "can't take it", "falling apart"
  - give up, hopeless, worthless

Formula:
  intensity = (marker_count × 0.25).clamp(0.0, 1.0)

Properties:
  - Each marker contributes 0.25 to intensity
  - Maximum intensity: 1.0 (4+ markers)
  - Range: [0.0, 1.0]
```

**Pseudocode:**
```python
def calculate_emotional_intensity(text):
    """
    Calculate emotional intensity from entry text
    
    Args:
        text: Journal entry text
    
    Returns:
        Intensity score (0.0-1.0)
    """
    lower_text = text.lower()
    
    intensity_markers = [
        'devastated', 'destroyed', 'shattered', 'broken',
        'overwhelmed', 'terrified', 'panic', 'desperate',
        'anguish', 'agony', 'torture', 'unbearable', 'excruciating',
        "can't do this", "can't take it", 'falling apart',
        'give up', 'hopeless', 'worthless'
    ]
    
    count = 0
    for marker in intensity_markers:
        if marker in lower_text:
            count += 1
    
    # Normalize: each marker = 0.25, max = 1.0
    intensity = (count * 0.25).clamp(0.0, 1.0)
    return intensity
```

---

### Self-Harm Language Detection

```
Self-Harm Language Detection
─────────────────────────────────────────────────────────────
Purpose: Immediate crisis detection for explicit self-harm language

Critical Phrases:
  - "want to die", "kill myself", "end my life"
  - "not worth living", "better off dead"
  - "suicide", "self harm", "hurt myself"
  - "end it all"

Behavior:
  - If detected → Immediate alert (score = 1.0)
  - Bypasses temporal clustering analysis
  - Triggers crisis mode immediately
```

**Pseudocode:**
```python
def detect_self_harm_language(text):
    """
    Detect explicit self-harm or suicide language
    
    Args:
        text: Journal entry text
    
    Returns:
        True if critical language detected
    """
    lower_text = text.lower()
    
    critical_phrases = [
        'want to die',
        'kill myself',
        'end my life',
        'not worth living',
        'better off dead',
        'suicide',
        'self harm',
        'hurt myself',
        'end it all'
    ]
    
    for phrase in critical_phrases:
        if phrase in lower_text:
            return True
    
    return False
```

---

### Temporal Clustering Analysis

```
Temporal Clustering Score
─────────────────────────────────────────────────────────────
Purpose: Detect if high-intensity emotions are clustered in time

Method:
  1. Analyze entries across multiple time windows
  2. Calculate frequency and average intensity per window
  3. Weight recent windows more heavily
  4. Combine into final clustering score

Time Windows:
  - 1 day: Most recent (weight: 1.0 = 100%)
  - 3 days: Short-term (weight: 0.7 = 70%)
  - 7 days: Medium-term (weight: 0.4 = 40%)
  - 30 days: Long-term (weight: 0.1 = 10%)

Frequency Thresholds (entries per window for max score):
  - 1 day: 3 entries
  - 3 days: 5 entries
  - 7 days: 8 entries
  - 30 days: 15 entries

Formula:
  For each window:
    freq_score = min(count / threshold, 1.0)
    avg_intensity = total_intensity / count
    window_score = (freq_score × avg_intensity) × weight
  
  final_score = (score_1day + score_3day + score_7day + score_30day) / 2.2

Properties:
  - Clustered emotions → High score (crisis)
  - Dispersed emotions → Low score (normal variance)
  - Range: [0.0, 1.0]
```

**Pseudocode:**
```python
def calculate_temporal_clustering(recent_entries, current_intensity):
    """
    Calculate temporal clustering score for crisis detection
    
    Args:
        recent_entries: List of CrisisEntry objects
        current_intensity: Intensity of current entry
    
    Returns:
        Clustering score (0.0-1.0)
    """
    if not recent_entries:
        # No history, just use current intensity
        return current_intensity
    
    now = datetime.now()
    
    # Initialize counters for each window
    windows = {
        '1day': {'count': 0, 'total_intensity': 0.0, 'threshold': 3.0, 'weight': 1.0},
        '3day': {'count': 0, 'total_intensity': 0.0, 'threshold': 5.0, 'weight': 0.7},
        '7day': {'count': 0, 'total_intensity': 0.0, 'threshold': 8.0, 'weight': 0.4},
        '30day': {'count': 0, 'total_intensity': 0.0, 'threshold': 15.0, 'weight': 0.1}
    }
    
    # Count entries in each window
    for entry in recent_entries:
        days_since = (now - entry.timestamp).days
        
        if days_since <= 1:
            windows['1day']['count'] += 1
            windows['1day']['total_intensity'] += entry.intensity
        if days_since <= 3:
            windows['3day']['count'] += 1
            windows['3day']['total_intensity'] += entry.intensity
        if days_since <= 7:
            windows['7day']['count'] += 1
            windows['7day']['total_intensity'] += entry.intensity
        if days_since <= 30:
            windows['30day']['count'] += 1
    
    # Add current entry to all windows
    for window in windows.values():
        window['count'] += 1
        if window['name'] in ['1day', '3day', '7day']:
            window['total_intensity'] += current_intensity
    
    # Calculate score for each window
    window_scores = []
    for window_name, window_data in windows.items():
        count = window_data['count']
        threshold = window_data['threshold']
        weight = window_data['weight']
        
        # Frequency score (normalized)
        freq_score = min(count / threshold, 1.0)
        
        # Average intensity
        if count > 0 and window_name in ['1day', '3day', '7day']:
            avg_intensity = window_data['total_intensity'] / count
        else:
            avg_intensity = 0.0
        
        # Window score = frequency × intensity × weight
        if window_name == '30day':
            # 30-day window only uses frequency
            window_score = freq_score * weight
        else:
            window_score = (freq_score * avg_intensity) * weight
        
        window_scores.append(window_score)
    
    # Final score is weighted average
    final_score = sum(window_scores) / 2.2  # Normalization factor
    return clamp(final_score, 0.0, 1.0)
```

---

### Sentinel Score Calculation

```
Sentinel Score Calculation Pipeline
─────────────────────────────────────────────────────────────

INPUT:
  - userId: User identifier
  - currentEntryText: Text of current journal entry

PROCESS:
  1. Get recent crisis entries (last 30 days, intensity ≥ 0.3)
  
  2. Calculate current entry intensity
     └─ intensity = calculate_emotional_intensity(currentEntryText)
  
  3. Check for self-harm language
     └─ IF detected → Return immediate alert (score = 1.0)
  
  4. Check RIVET for dangerous phase transitions
     └─ IF detected → Return immediate alert (score = 1.0)
  
  5. Calculate temporal clustering
     └─ cluster_score = calculate_temporal_clustering(recent_entries, current_intensity)
  
  6. Determine alert status
     └─ alert = (cluster_score >= ALERT_THRESHOLD) OR (self_harm_detected) OR (dangerous_transition)

OUTPUT: SentinelScore
  - score: Clustering score or 1.0 if immediate alert
  - alert: Whether crisis mode should activate
  - reason: Explanation of score
  - triggerEntries: Entries that contributed
  - timespan: Time period analyzed
```

**Pseudocode:**
```python
def calculate_sentinel_score(user_id, current_entry_text):
    """
    Calculate Sentinel score for crisis detection
    
    Args:
        user_id: User identifier
        current_entry_text: Text of current journal entry
    
    Returns:
        SentinelScore object
    """
    # 1. Get recent entries with crisis indicators
    recent_crisis_entries = get_recent_crisis_entries(user_id, days=30)
    
    # 2. Calculate current entry intensity
    current_intensity = calculate_emotional_intensity(current_entry_text)
    has_crisis_language = detect_self_harm_language(current_entry_text)
    
    # 3. Immediate alert for self-harm language
    if has_crisis_language:
        return SentinelScore(
            score=1.0,
            alert=True,
            reason='Explicit crisis language detected',
            trigger_entries=[current_entry_text],
            timespan=Duration.zero
        )
    
    # 4. Check RIVET for dangerous phase transitions
    try:
        dangerous_transition = check_rivet_dangerous_transition(user_id)
        if dangerous_transition:
            return SentinelScore(
                score=1.0,
                alert=True,
                reason='RIVET detected dangerous phase transition',
                trigger_entries=[current_entry_text],
                timespan=Duration.zero
            )
    except Exception as e:
        log_error(f'Error checking RIVET: {e}')
        # Continue with normal analysis
    
    # 5. Calculate temporal clustering
    cluster_score = calculate_temporal_clustering(
        recent_crisis_entries,
        current_intensity
    )
    
    # 6. Determine alert status
    alert = cluster_score >= ALERT_THRESHOLD  # Default: 0.7
    
    return SentinelScore(
        score=cluster_score,
        alert=alert,
        reason=(
            f'High emotional intensity clustered over {len(recent_crisis_entries)} entries'
            if alert
            else 'Normal emotional variance'
        ),
        trigger_entries=[e.text for e in recent_crisis_entries],
        timespan=(
            datetime.now() - recent_crisis_entries[-1].timestamp
            if recent_crisis_entries
            else Duration.zero
        )
    )
```

---

### Crisis Mode Management

```
Crisis Mode Lifecycle
─────────────────────────────────────────────────────────────

Activation:
  - Triggered when SentinelScore.alert == True
  - Stores activation timestamp
  - Stores Sentinel score and reason
  - Stores trigger entry count and timespan
  - Activates 48-hour cooldown period

Deactivation:
  - Automatic: After 48-hour cooldown expires
  - Manual: User or admin override
  - Deletes crisis mode document from Firestore

State Check:
  - Query Firestore for crisis_mode document
  - Check if activated_at + 48 hours < now
  - IF expired → Auto-deactivate
  - ELSE → Return crisis mode info
```

**Pseudocode:**
```python
def is_in_crisis_mode(user_id):
    """
    Check if user is currently in crisis mode
    
    Args:
        user_id: User identifier
    
    Returns:
        True if in crisis mode (and cooldown not expired)
    """
    doc = firestore.collection('users').doc(user_id) \
        .collection('sentinel_state').doc('crisis_mode').get()
    
    if not doc.exists:
        return False
    
    data = doc.data()
    activated_at = data['activated_at'].to_date()
    hours_since = (datetime.now() - activated_at).total_seconds() / 3600
    
    # Auto-deactivate after cooldown
    if hours_since >= CRISIS_COOLDOWN_HOURS:  # Default: 48
        deactivate_crisis_mode(user_id, reason='cooldown_expired')
        return False
    
    return True

def activate_crisis_mode(user_id, sentinel_score):
    """
    Activate crisis mode for user
    
    Args:
        user_id: User identifier
        sentinel_score: SentinelScore that triggered activation
    """
    firestore.collection('users').doc(user_id) \
        .collection('sentinel_state').doc('crisis_mode').set({
            'activated_at': FieldValue.server_timestamp(),
            'sentinel_score': sentinel_score.score,
            'reason': sentinel_score.reason,
            'trigger_count': len(sentinel_score.trigger_entries),
            'timespan_days': sentinel_score.timespan.days
        })
    
    log_crisis_activation(user_id, sentinel_score)

def deactivate_crisis_mode(user_id, reason):
    """
    Deactivate crisis mode for user
    
    Args:
        user_id: User identifier
        reason: Reason for deactivation
    """
    firestore.collection('users').doc(user_id) \
        .collection('sentinel_state').doc('crisis_mode').delete()
    
    log_crisis_deactivation(user_id, reason)
```

---

## Integration with LUMARA

```
Sentinel → LUMARA Integration
─────────────────────────────────────────────────────────────

Data Flow:
  Journal Entry Created
    ↓
  SentinelAnalyzer.calculateSentinelScore()
    ↓
  IF alert:
    → CrisisMode.activateCrisisMode()
    → Force LUMARA to Therapist persona
    → Enable emergency support mode
  ELSE:
    → Normal LUMARA persona selection
```

**Pseudocode:**
```python
def process_journal_entry_with_sentinel(entry, lumara_service):
    """
    Process journal entry with Sentinel crisis detection
    
    Args:
        entry: JournalEntry
        lumara_service: LUMARA service instance
    
    Returns:
        Tuple of (sentinel_score, persona_override)
    """
    # Calculate Sentinel score
    sentinel_score = SentinelAnalyzer.calculate_sentinel_score(
        user_id=entry.user_id,
        current_entry_text=entry.text
    )
    
    # Check if already in crisis mode
    already_in_crisis = CrisisMode.is_in_crisis_mode(entry.user_id)
    
    # Determine persona override
    persona_override = None
    safety_override = False
    
    if already_in_crisis or sentinel_score.alert:
        # Force Therapist persona
        persona_override = 'therapist'
        safety_override = True
        
        # Activate crisis mode if not already active
        if not already_in_crisis and sentinel_score.alert:
            CrisisMode.activate_crisis_mode(entry.user_id, sentinel_score)
    
    return (sentinel_score, persona_override, safety_override)
```

---

## Configuration Parameters

```
Sentinel Configuration
─────────────────────────────────────────────────────────────

Temporal Windows (days):
  WINDOW_1_DAY = 1
  WINDOW_3_DAY = 3
  WINDOW_7_DAY = 7
  WINDOW_30_DAY = 30

Frequency Thresholds (entries per window for max score):
  FREQ_THRESHOLD_1DAY = 3.0
  FREQ_THRESHOLD_3DAY = 5.0
  FREQ_THRESHOLD_7DAY = 8.0
  FREQ_THRESHOLD_30DAY = 15.0

Temporal Weighting:
  WEIGHT_1DAY = 1.0    # 100% (most recent)
  WEIGHT_3DAY = 0.7    # 70%
  WEIGHT_7DAY = 0.4    # 40%
  WEIGHT_30DAY = 0.1   # 10% (least recent)

Alert Threshold:
  ALERT_THRESHOLD = 0.7  # Score ≥ 0.7 triggers alert

Intensity Threshold:
  MIN_CRISIS_INTENSITY = 0.3  # Minimum intensity to count as crisis-related

Cooldown:
  CRISIS_COOLDOWN_HOURS = 48  # 48-hour cooldown after activation
```

---

## Data Flow

```
Sentinel Data Flow
─────────────────────────────────────────────────────────────

1. Entry Creation:
   Journal Entry → Firestore
     ↓
   Sentinel Analyzer (triggered)
     ↓
   Calculate intensity
     ↓
   Check self-harm language
     ↓
   Check RIVET transitions
     ↓
   Calculate temporal clustering
     ↓
   Generate SentinelScore

2. Crisis Detection:
   SentinelScore.alert == True
     ↓
   CrisisMode.activateCrisisMode()
     ↓
   Store in Firestore (sentinel_state/crisis_mode)
     ↓
   Force LUMARA to Therapist persona
     ↓
   Enable emergency support mode

3. Crisis Mode Check:
   LUMARA Request
     ↓
   CrisisMode.isInCrisisMode()
     ↓
   IF in crisis mode:
     → Override persona to Therapist
     → Enable safety_override flag
   ELSE:
     → Normal persona selection
```

---

## Error Handling & Edge Cases

```
Edge Cases
─────────────────────────────────────────────────────────────

1. No History:
   - First entry or no recent entries
   - Use current entry intensity as score
   - No clustering analysis possible

2. Firestore Errors:
   - Network failures
   - Permission errors
   - Return empty crisis entries list
   - Continue with available data

3. RIVET Integration Errors:
   - RIVET service unavailable
   - Log error and continue
   - Don't block Sentinel analysis

4. Cooldown Expiration:
   - Auto-deactivate after 48 hours
   - Clean up Firestore document
   - Return to normal mode

5. Multiple Alerts:
   - Self-harm language takes priority
   - RIVET dangerous transition takes priority
   - Temporal clustering is fallback
```

---

## Performance Considerations

```
Optimization Strategies
─────────────────────────────────────────────────────────────

1. Firestore Queries:
   - Limit to last 30 days
   - Order by timestamp descending
   - Filter by intensity threshold
   - Use indexes for efficient queries

2. Caching:
   - Cache recent crisis entries
   - Invalidate on new entry
   - Reduce Firestore reads

3. Batch Processing:
   - Process multiple entries in batch
   - Calculate clustering once per batch

4. Lazy Evaluation:
   - Only check RIVET if needed
   - Skip expensive calculations if early exit
```

---

## Privacy & Security

```
Privacy Considerations
─────────────────────────────────────────────────────────────

1. Data Storage:
   - Crisis entries stored in Firestore
   - User-specific collections
   - Encrypted in transit and at rest

2. Access Control:
   - Only user can access their crisis data
   - Admin override for emergencies
   - Audit logs for crisis activations

3. Data Retention:
   - Crisis entries kept for 30 days
   - Auto-cleanup after cooldown
   - Manual deletion available
```

---

## Testing Strategy

```
Test Scenarios
─────────────────────────────────────────────────────────────

1. Self-Harm Detection:
   - Entry with critical language
   → Should trigger immediate alert

2. Temporal Clustering:
   - Multiple high-intensity entries in short time
   → Should trigger alert

3. Dispersed Emotions:
   - High-intensity entries spread over time
   → Should not trigger alert

4. Crisis Mode Activation:
   - Alert triggered
   → Should activate crisis mode
   → Should force Therapist persona

5. Cooldown Expiration:
   - 48 hours pass
   → Should auto-deactivate
   → Should return to normal mode

6. RIVET Integration:
   - Dangerous phase transition detected
   → Should trigger alert
```

---

## Adaptive Framework

### Overview

Sentinel now includes an **adaptive configuration system** that automatically adjusts emotional density calculation based on user journaling cadence and writing style. The system adapts to different usage patterns to maintain consistent psychological measurement across different cadences.

### User Cadence Detection

```
User Cadence Detection
─────────────────────────────────────────────────────────────

Purpose: Detect user's journaling pattern to adapt Sentinel parameters

Method:
  1. Calculate days between consecutive entries
  2. Filter outliers (gaps > 30 days = breaks, not pattern)
  3. Calculate average and standard deviation
  4. Classify user type based on average cadence

User Types:
  - power_user: ≤ 2 days between entries (daily/near-daily)
  - frequent: 2-4 days between entries (2-3 times per week)
  - weekly: 4-9 days between entries (once per week)
  - sporadic: > 9 days between entries (less than weekly)
  - insufficient_data: < 5 entries total

Recalculation:
  - Recalculate cadence every 10 new entries
  - Track user type transitions over time
```

### Adaptive Sentinel Configuration

```
Adaptive Configuration by User Type
─────────────────────────────────────────────────────────────

Power User (daily):
  - emotionalIntensityWeight: 0.25
  - emotionalDiversityWeight: 0.25
  - thematicCoherenceWeight: 0.25
  - temporalDynamicsWeight: 0.25
  - emotionalConcentrationWeight: 0.0
  - explicitEmotionMultiplier: 1.0-1.0
  - normalizationMethod: linear
  - normalizationFloor: 50
  - temporalDecayFactor: 0.95
  - highIntensityThreshold: 0.7
  - minWordsForFullScore: 100

Frequent User (2-3x/week):
  - emotionalIntensityWeight: 0.30
  - emotionalDiversityWeight: 0.20
  - thematicCoherenceWeight: 0.20
  - temporalDynamicsWeight: 0.20
  - emotionalConcentrationWeight: 0.10
  - explicitEmotionMultiplier: 1.0-1.3
  - normalizationMethod: sqrt
  - normalizationFloor: 50
  - temporalDecayFactor: 0.97
  - highIntensityThreshold: 0.7
  - minWordsForFullScore: 100

Weekly User:
  - emotionalIntensityWeight: 0.35
  - emotionalDiversityWeight: 0.15
  - thematicCoherenceWeight: 0.15
  - temporalDynamicsWeight: 0.15
  - emotionalConcentrationWeight: 0.20
  - explicitEmotionMultiplier: 1.0-1.5
  - normalizationMethod: sqrt
  - normalizationFloor: 50
  - temporalDecayFactor: 0.98
  - highIntensityThreshold: 0.65
  - minWordsForFullScore: 75

Sporadic User:
  - emotionalIntensityWeight: 0.40
  - emotionalDiversityWeight: 0.10
  - thematicCoherenceWeight: 0.10
  - temporalDynamicsWeight: 0.15
  - emotionalConcentrationWeight: 0.25
  - explicitEmotionMultiplier: 1.0-1.5
  - normalizationMethod: sqrt
  - normalizationFloor: 40
  - temporalDecayFactor: 0.99
  - highIntensityThreshold: 0.6
  - minWordsForFullScore: 50
```

### Emotional Concentration Metric

```
Emotional Concentration Calculation
─────────────────────────────────────────────────────────────

Purpose: Detect when multiple emotional terms cluster in same semantic family

Method:
  1. Group emotional terms by semantic family (fear, anger, sadness, etc.)
  2. Calculate concentration score for each family
  3. Return maximum concentration across families

Emotion Families:
  - fear: afraid, scared, terrified, anxious, worried, etc.
  - anger: angry, furious, mad, irritated, frustrated, etc.
  - sadness: sad, depressed, miserable, down, hopeless, etc.
  - joy: happy, joyful, excited, elated, thrilled, etc.
  - disgust: disgusted, revolted, repulsed, sickened, etc.
  - surprise: surprised, shocked, astonished, amazed, etc.
  - shame: ashamed, embarrassed, humiliated, guilty, etc.

Formula:
  concentration = (family_term_count / total_terms) × avg_intensity

Properties:
  - Higher concentration = more focused emotional state
  - Important for sparse journalers (weekly/sporadic)
  - Range: [0.0, 1.0]
```

**Pseudocode:**
```python
def calculate_emotional_concentration(emotional_terms, config):
    """
    Calculate emotional concentration score
    
    Args:
        emotional_terms: Map of term -> intensity
        config: SentinelConfig
    
    Returns:
        Concentration score (0.0-1.0)
    """
    if not emotional_terms:
        return 0.0
    
    # Group terms by emotion family
    family_groups = {}
    for term, intensity in emotional_terms.items():
        family = find_emotion_family(term)
        if family:
            family_groups.setdefault(family, []).append((term, intensity))
    
    # Calculate concentration for each family
    max_concentration = 0.0
    for family, terms in family_groups.items():
        if len(terms) >= 2:  # Multiple terms from same family
            avg_intensity = sum(i for _, i in terms) / len(terms)
            concentration = (len(terms) / len(emotional_terms)) * avg_intensity
            max_concentration = max(max_concentration, concentration)
    
    return max_concentration.clamp(0.0, 1.0)
```

### Explicit Emotion Detection

```
Explicit Emotion Detection
─────────────────────────────────────────────────────────────

Purpose: Boost scores for explicit emotion statements

Patterns:
  - "I feel [emotion]"
  - "I am [emotion]"
  - "I'm [emotion]"
  - "I'm so [emotion]"
  - "I'm feeling [emotion]"
  - "I can't cope/handle/deal"

Multiplier Calculation:
  - Base multiplier: config.explicitEmotionMultiplierMin
  - Increment per match: (max - min) / 3
  - Max multiplier: config.explicitEmotionMultiplierMax

Formula:
  multiplier = min + (increment × match_count.clamp(0, 3))

Properties:
  - Rewards explicit emotional expression
  - Important for users who express emotions directly
  - Range: [min, max] (typically 1.0-1.5)
```

**Pseudocode:**
```python
def calculate_explicit_emotion_multiplier(text, config):
    """
    Calculate multiplier for explicit emotion statements
    
    Args:
        text: Entry text
        config: SentinelConfig
    
    Returns:
        Multiplier (1.0-1.5 typically)
    """
    patterns = [
        r'\bi\s+feel\s+(\w+)',
        r'\bi\s+am\s+(\w+)',
        r'\bi\'m\s+(\w+)',
        r'\bi\'m\s+so\s+(\w+)',
        r'\bi\s+can\'t\s+(handle|deal|cope)',
        r'\bi\'m\s+feeling\s+(\w+)',
    ]
    
    match_count = 0
    for pattern in patterns:
        if re.search(pattern, text, re.IGNORECASE):
            match_count += 1
    
    if match_count == 0:
        return config.explicit_emotion_multiplier_min
    
    increment = (config.explicit_emotion_multiplier_max - 
                config.explicit_emotion_multiplier_min) / 3
    
    multiplier = config.explicit_emotion_multiplier_min + \
                 (increment * min(match_count, 3))
    
    return multiplier.clamp(
        config.explicit_emotion_multiplier_min,
        config.explicit_emotion_multiplier_max
    )
```

### Adaptive Word Count Normalization

```
Word Count Normalization
─────────────────────────────────────────────────────────────

Purpose: Normalize emotional density scores by entry length

Methods:
  1. Linear: divide by word_count
  2. Sqrt: divide by sqrt(word_count)
  3. Log: divide by log(word_count + 1)

Selection by User Type:
  - Power user: linear (entries typically similar length)
  - Frequent/Weekly/Sporadic: sqrt (entries vary more in length)

Formula:
  normalized_score = raw_score / normalization_function(word_count)

Properties:
  - Prevents long entries from dominating scores
  - Adapts to user writing style
  - Maintains score comparability across entries
```

**Pseudocode:**
```python
def normalize_by_word_count(raw_score, word_count, config):
    """
    Normalize score by word count using adaptive method
    
    Args:
        raw_score: Raw emotional density score
        word_count: Number of words in entry
        config: SentinelConfig
    
    Returns:
        Normalized score
    """
    effective_count = max(word_count, config.normalization_floor)
    
    if config.normalization_method == WordCountNormalization.linear:
        return raw_score / effective_count
    elif config.normalization_method == WordCountNormalization.sqrt:
        return raw_score / sqrt(effective_count)
    elif config.normalization_method == WordCountNormalization.log:
        return raw_score / log(effective_count + 1)
```

### Enhanced Emotional Density Calculation

```
Adaptive Emotional Density Pipeline
─────────────────────────────────────────────────────────────

INPUT: JournalEntry
  ├─ text, timestamp, userId

PROCESS:
  1. Extract emotional terms and intensities
     └─ emotional_terms = extract_emotional_terms(entry.text)
  
  2. Calculate base components
     ├─ emotional_intensity = calculate_intensity(emotional_terms)
     ├─ emotional_diversity = calculate_diversity(emotional_terms)
     ├─ thematic_coherence = calculate_coherence(entry.text)
     └─ temporal_dynamics = calculate_temporal(entry, prior_entries)
  
  3. Calculate NEW components
     ├─ emotional_concentration = calculate_concentration(emotional_terms, config)
     └─ explicit_multiplier = calculate_explicit_multiplier(entry.text, config)
  
  4. Weighted combination
     └─ raw_score = (intensity × weight_intensity) +
                     (diversity × weight_diversity) +
                     (coherence × weight_coherence) +
                     (temporal × weight_temporal) +
                     (concentration × weight_concentration)
  
  5. Apply explicit emotion multiplier
     └─ raw_score *= explicit_multiplier
  
  6. Normalize by word count
     └─ normalized_score = normalize(raw_score, word_count, config)

OUTPUT: Emotional Density Score (0.0-1.0)
```

**Pseudocode:**
```python
def calculate_emotional_density(entry, prior_entries, config):
    """
    Calculate adaptive emotional density score
    
    Args:
        entry: JournalEntry
        prior_entries: List of recent JournalEntry objects
        config: SentinelConfig
    
    Returns:
        Emotional density score (0.0-1.0)
    """
    # Extract emotional terms
    emotional_terms = extract_emotional_terms(entry.text)
    
    # Calculate base components
    emotional_intensity = calculate_emotional_intensity(emotional_terms)
    emotional_diversity = calculate_emotional_diversity(emotional_terms)
    thematic_coherence = calculate_thematic_coherence(entry.text)
    temporal_dynamics = calculate_temporal_dynamics(entry, prior_entries)
    
    # NEW: Calculate emotional concentration
    emotional_concentration = calculate_emotional_concentration(
        emotional_terms,
        config
    )
    
    # NEW: Detect explicit emotion statements
    explicit_multiplier = calculate_explicit_emotion_multiplier(
        entry.text,
        config
    )
    
    # Weighted combination
    raw_score = (
        emotional_intensity * config.emotional_intensity_weight +
        emotional_diversity * config.emotional_diversity_weight +
        thematic_coherence * config.thematic_coherence_weight +
        temporal_dynamics * config.temporal_dynamics_weight +
        emotional_concentration * config.emotional_concentration_weight
    )
    
    # Apply explicit emotion multiplier
    raw_score *= explicit_multiplier
    
    # Normalize by word count
    word_count = len(entry.text.split())
    normalized_score = normalize_by_word_count(raw_score, word_count, config)
    
    return normalized_score.clamp(0.0, 1.0)
```

### Configuration Transitions

```
Smooth Configuration Transitions
─────────────────────────────────────────────────────────────

When user type changes:
  1. Detect type transition (e.g., power_user → weekly)
  2. Start gradual interpolation over 5 entries
  3. Linearly blend old and new configs
  4. Complete transition after 5 entries

Transition Formula:
  config_t = old_config × (1 - progress) + new_config × progress
  progress = entries_since_transition / 5

Benefits:
  - Prevents sudden algorithmic shifts
  - Maintains measurement continuity
  - Smooth user experience
```

---

## References

- **Location**: `lib/services/sentinel/`
- **Main Analyzer**: `sentinel_analyzer.dart`
- **Crisis Mode**: `crisis_mode.dart`
- **Configuration**: `sentinel_config.dart`
- **Integration**: `lib/arc/chat/services/enhanced_lumara_api.dart`
- **Adaptive Framework**: `lib/services/adaptive/` (NEW)


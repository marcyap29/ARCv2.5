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

## References

- **Location**: `lib/services/sentinel/`
- **Main Analyzer**: `sentinel_analyzer.dart`
- **Crisis Mode**: `crisis_mode.dart`
- **Configuration**: `sentinel_config.dart`
- **Integration**: `lib/arc/chat/services/enhanced_lumara_api.dart`


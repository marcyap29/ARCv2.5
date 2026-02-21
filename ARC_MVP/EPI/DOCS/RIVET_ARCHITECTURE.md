# RIVET Architecture Pseudocode

**RIVET (Risk-Validation Evidence Tracker)** - Phase transition validation system

## Overview

RIVET validates keyword evidence before allowing phase transitions. It ensures phase changes are well-supported by evidence through two core metrics: **ALIGN** (alignment score) and **TRACE** (evidence accumulation).

---

## Core Components

### 1. RivetService
Main service orchestrating RIVET calculations and gate decisions.

### 2. RivetState
Current state tracking:
- `align`: ALIGN score (0.0-1.0)
- `trace`: TRACE score (0.0-1.0)
- `sustainCount`: Number of consecutive entries meeting thresholds
- `sawIndependentInWindow`: Whether independent event observed in sustainment window

### 3. RivetEvent
Input event containing:
- `eventId`: Unique identifier
- `date`: Timestamp
- `source`: Evidence source (journal, draft, chat, etc.)
- `keywords`: Set of keywords extracted
- `predPhase`: Predicted phase from PhaseTracker
- `refPhase`: Reference phase (user-confirmed or predicted)
- `tolerance`: Phase-specific tolerance map

---

## Core Algorithms

### ALIGN Score Calculation

```
ALIGN (Alignment Score)
─────────────────────────────────────────────────────────────
Purpose: Measures consistency between predicted and actual phase

Formula:
  ALIGN_t = (1 - β) × ALIGN_{t-1} + β × s_t

Where:
  β = 2 / (N + 1)          # Smoothing parameter
  N = smoothing window     # Default: 10
  s_t = sample alignment   # 1.0 if pred==ref, else 0.0

Sample Alignment (s_t):
  s_t = max(0, 1 - |ref - pred| / tolerance)
  
  For categorical phases (current implementation):
    s_t = (pred == ref) ? 1.0 : 0.0

Properties:
  - Exponential moving average (EMA)
  - Reacts to recent alignment changes
  - Smooths out noise in phase predictions
  - Range: [0.0, 1.0]
```

**Pseudocode:**
```python
def calculate_align(current_align, sample_align, smoothing_param=10):
    """
    Update ALIGN score using exponential smoothing
    
    Args:
        current_align: Previous ALIGN value
        sample_align: Current sample alignment (0.0 or 1.0)
        smoothing_param: N parameter (default: 10)
    
    Returns:
        Updated ALIGN score
    """
    beta = 2.0 / (smoothing_param + 1.0)
    new_align = (1 - beta) * current_align + beta * sample_align
    return clamp(new_align, 0.0, 1.0)

def sample_align(predicted_phase, reference_phase):
    """
    Calculate sample alignment for current entry
    
    Args:
        predicted_phase: Phase predicted by PhaseTracker
        reference_phase: User-confirmed or predicted phase
    
    Returns:
        1.0 if phases match, 0.0 otherwise
    """
    return 1.0 if predicted_phase == reference_phase else 0.0
```

---

### TRACE Score Calculation

```
TRACE (Evidence Accumulation Score)
─────────────────────────────────────────────────────────────
Purpose: Tracks keyword evidence accumulation over time

Formula:
  TRACE_t = 1 - exp(- Σ e_i / K)

Where:
  e_i = evidence weight for keyword i
  K = saturation parameter (default: 20)
  Σ e_i = accumulated evidence mass

Evidence Weight Calculation:
  base_weight = 1.0
  independence_boost = 1.2 if (different_day OR different_source) else 1.0
  novelty_boost = 1.0 + 0.5 × keyword_drift
  evidence_increment = base_weight × independence_boost × novelty_boost

Accumulation:
  current_mass = -K × ln(1 - TRACE_{t-1})
  new_mass = current_mass + evidence_increment
  TRACE_t = 1 - exp(-new_mass / K)

Properties:
  - Saturating accumulator (approaches 1.0 asymptotically)
  - Rewards evidence variety and independence
  - Range: [0.0, 1.0)
```

**Pseudocode:**
```python
def calculate_trace(current_trace, evidence_increment, saturation_param=20):
    """
    Update TRACE score using saturating accumulator
    
    Args:
        current_trace: Previous TRACE value
        evidence_increment: Evidence weight for current entry
        saturation_param: K parameter (default: 20)
    
    Returns:
        Updated TRACE score
    """
    # Convert TRACE back to accumulated mass
    current_mass = -saturation_param * log(1 - clamp(current_trace, 0, 0.999999))
    
    # Add new evidence
    new_mass = current_mass + evidence_increment
    
    # Convert back to TRACE score
    new_trace = 1 - exp(-new_mass / saturation_param)
    return clamp(new_trace, 0.0, 1.0)

def calculate_evidence_increment(event, last_event):
    """
    Calculate evidence increment with independence and novelty boosts
    
    Args:
        event: Current RivetEvent
        last_event: Previous RivetEvent (if any)
    
    Returns:
        Evidence increment value
    """
    base_weight = 1.0
    
    # Independence boost: different day or source
    independence_boost = 1.2 if is_independent(event, last_event) else 1.0
    
    # Novelty boost: keyword drift (Jaccard distance)
    novelty_boost = calculate_novelty_boost(event, last_event)
    
    return base_weight * independence_boost * novelty_boost

def is_independent(event, last_event):
    """
    Check if event is independent from last event
    
    Args:
        event: Current event
        last_event: Previous event (may be None)
    
    Returns:
        True if different day or different source
    """
    if last_event is None:
        return True
    
    different_day = (event.date - last_event.date).days >= 1
    different_source = event.source != last_event.source
    
    return different_day or different_source

def calculate_novelty_boost(event, last_event):
    """
    Calculate novelty boost based on keyword drift
    
    Uses Jaccard distance to measure keyword variety
    
    Args:
        event: Current event
        last_event: Previous event (may be None)
    
    Returns:
        Boost multiplier (1.0 to 1.5)
    """
    if last_event is None:
        return 1.1
    
    keywords_a = event.keywords
    keywords_b = last_event.keywords
    
    if not keywords_a and not keywords_b:
        return 1.0
    
    # Jaccard similarity
    intersection = len(keywords_a & keywords_b)
    union = len(keywords_a | keywords_b)
    
    if union == 0:
        return 1.0
    
    jaccard_similarity = intersection / union
    keyword_drift = 1.0 - jaccard_similarity
    
    # Boost range: 1.0 to 1.5
    return 1.0 + 0.5 * keyword_drift
```

---

### Gate Opening Decision

```
Gate Opening Conditions
─────────────────────────────────────────────────────────────
The gate opens when ALL of the following are true:

1. ALIGN ≥ A* (ALIGN threshold, default: 0.6)
2. TRACE ≥ T* (TRACE threshold, default: 0.6)
3. Conditions sustained for W entries (sustainment window, default: 2)
4. At least one independent event observed in the window

Gate Decision Logic:
  meets_thresholds = (ALIGN ≥ A*) AND (TRACE ≥ T*)
  
  IF meets_thresholds:
    sustain_count = previous_sustain_count + 1
  ELSE:
    sustain_count = 0
    saw_independent = false
  
  IF meets_thresholds AND independence_detected:
    saw_independent = true
  
  gate_open = (sustain_count ≥ W) AND saw_independent
```

**Pseudocode:**
```python
def evaluate_gate(state, new_align, new_trace, independence_detected, 
                   align_threshold=0.6, trace_threshold=0.6, sustain_window=2):
    """
    Evaluate if gate should open for phase transition
    
    Args:
        state: Current RivetState
        new_align: Updated ALIGN score
        new_trace: Updated TRACE score
        independence_detected: Whether current event is independent
        align_threshold: A* threshold (default: 0.6)
        trace_threshold: T* threshold (default: 0.6)
        sustain_window: W parameter (default: 2)
    
    Returns:
        Tuple of (gate_open: bool, new_state: RivetState, why_not: str?)
    """
    # Check if thresholds are met
    meets_thresholds = (new_align >= align_threshold) and (new_trace >= trace_threshold)
    
    # Update sustainment count
    if meets_thresholds:
        new_sustain_count = state.sustain_count + 1
        new_saw_independent = state.saw_independent_in_window or independence_detected
    else:
        new_sustain_count = 0
        new_saw_independent = False
    
    # Gate opens if sustained AND independent event seen
    gate_open = (new_sustain_count >= sustain_window) and new_saw_independent
    
    # Generate explanation if gate closed
    why_not = None
    if not gate_open:
        if not meets_thresholds:
            why_not = f"Needs ALIGN≥{align_threshold} and TRACE≥{trace_threshold} together"
        elif not new_saw_independent:
            why_not = "Need at least one independent event in window"
        else:
            why_not = f"Needs sustainment {new_sustain_count}/{sustain_window}"
    
    new_state = RivetState(
        align=new_align,
        trace=new_trace,
        sustain_count=new_sustain_count,
        saw_independent_in_window=new_saw_independent
    )
    
    return (gate_open, new_state, why_not)
```

---

## Main Ingestion Flow

```
RIVET Event Ingestion Pipeline
─────────────────────────────────────────────────────────────

INPUT: RivetEvent
  ├─ eventId, date, source, keywords
  ├─ predPhase (from PhaseTracker)
  └─ refPhase (user-confirmed or predicted)

PROCESS:
  1. Calculate sample ALIGN (s_t)
     └─ s_t = (predPhase == refPhase) ? 1.0 : 0.0
  
  2. Update ALIGN with EMA
     └─ ALIGN_t = (1-β) × ALIGN_{t-1} + β × s_t
  
  3. Calculate evidence increment
     ├─ base_weight = 1.0
     ├─ independence_boost = is_independent(event, last_event) ? 1.2 : 1.0
     ├─ novelty_boost = 1.0 + 0.5 × keyword_drift
     └─ evidence_increment = base_weight × independence_boost × novelty_boost
  
  4. Update TRACE with saturating accumulator
     ├─ current_mass = -K × ln(1 - TRACE_{t-1})
     ├─ new_mass = current_mass + evidence_increment
     └─ TRACE_t = 1 - exp(-new_mass / K)
  
  5. Evaluate gate conditions
     ├─ meets_thresholds = (ALIGN ≥ A*) AND (TRACE ≥ T*)
     ├─ sustain_count = meets_thresholds ? (sustain_count + 1) : 0
     ├─ saw_independent = saw_independent OR independence_detected
     └─ gate_open = (sustain_count ≥ W) AND saw_independent

OUTPUT: RivetGateDecision
  ├─ open: bool
  ├─ stateAfter: RivetState
  ├─ whyNot: str? (if gate closed)
  └─ transitionInsights: PhaseTransitionInsights
```

**Pseudocode:**
```python
def ingest_event(service, event, last_event=None):
    """
    Main RIVET ingestion function
    
    Args:
        service: RivetService instance
        event: RivetEvent to process
        last_event: Previous RivetEvent (optional)
    
    Returns:
        RivetGateDecision
    """
    # Get last event from history if not provided
    if last_event is None:
        last_event = service.event_history[-1] if service.event_history else None
    
    # 1. Calculate sample ALIGN
    sample_align = sample_align(event.pred_phase, event.ref_phase)
    
    # 2. Update ALIGN with exponential smoothing
    beta = 2.0 / (service.smoothing_param + 1.0)
    new_align = (1 - beta) * service.state.align + beta * sample_align
    
    # 3. Calculate evidence increment
    evidence_increment = calculate_evidence_increment(event, last_event)
    
    # 4. Update TRACE with saturating accumulator
    new_trace = calculate_trace(service.state.trace, evidence_increment, service.saturation_param)
    
    # 5. Evaluate gate conditions
    independence_detected = is_independent(event, last_event)
    gate_open, new_state, why_not = evaluate_gate(
        service.state,
        new_align,
        new_trace,
        independence_detected,
        service.align_threshold,
        service.trace_threshold,
        service.sustain_window
    )
    
    # Update service state
    service.state = new_state
    service.event_history.append(event)
    service.state_history.append(new_state)
    
    # Calculate transition insights
    transition_insights = calculate_phase_transition_insights(
        current_phase=event.ref_phase,
        event_history=service.event_history,
        updated_state=new_state
    )
    
    return RivetGateDecision(
        open=gate_open,
        state_after=new_state,
        why_not=why_not,
        transition_insights=transition_insights
    )
```

---

## Integration with Phase System

```
RIVET ↔ PhaseTracker Integration
─────────────────────────────────────────────────────────────

Data Flow:
  Conversation (Journal Entry)
    ↓
  PhaseTracker (predicts phase)
    ↓
  Keyword Extraction
    ↓
  RivetEvent Creation
    ↓
  RIVET.ingest(event)
    ↓
  Gate Decision
    ↓
  IF gate_open:
    → Apply phase transition to user profile
  ELSE:
    → Keep current phase, log why gate closed
```

**Pseudocode:**
```python
def process_journal_entry(entry, phase_tracker, rivet_service):
    """
    Process conversation through phase detection and RIVET validation
    
    Args:
        entry: JournalEntry
        phase_tracker: PhaseTracker instance
        rivet_service: RivetService instance
    
    Returns:
        Tuple of (phase_change_allowed: bool, gate_decision: RivetGateDecision)
    """
    # 1. PhaseTracker predicts phase
    predicted_phase = phase_tracker.predict_phase(entry)
    
    # 2. Extract keywords
    keywords = extract_keywords(entry)
    
    # 3. Create RIVET event
    rivet_event = RivetEvent(
        event_id=generate_event_id(entry),
        date=entry.timestamp,
        source=EvidenceSource.journal,
        keywords=keywords,
        pred_phase=predicted_phase,
        ref_phase=predicted_phase,  # Or user-confirmed if available
        tolerance={}
    )
    
    # 4. Ingest into RIVET
    gate_decision = rivet_service.ingest(rivet_event)
    
    # 5. Return gate decision
    return (gate_decision.open, gate_decision)
```

---

## Configuration Parameters

```
RIVET Configuration
─────────────────────────────────────────────────────────────

Thresholds:
  A* (align_threshold) = 0.6      # ALIGN must be ≥ 0.6
  T* (trace_threshold) = 0.6      # TRACE must be ≥ 0.6

Sustainment:
  W (sustain_window) = 2           # Must sustain for 2 entries

Smoothing:
  N (smoothing_param) = 10         # EMA smoothing window

Saturation:
  K (saturation_param) = 20        # TRACE saturation parameter

Multipliers:
  independence_boost = 1.2         # Boost for independent events
  novelty_base = 1.0               # Base novelty multiplier
  novelty_max = 1.5                # Max novelty multiplier
```

---

## State Management

```
RIVET State Persistence
─────────────────────────────────────────────────────────────

State Storage:
  - RivetState: Current ALIGN, TRACE, sustain_count, saw_independent
  - Event History: List of all RivetEvents processed
  - State History: List of RivetStates after each event

Persistence:
  - Stored in Hive (local database)
  - Synced to Firestore (cloud backup)
  - Recoverable on app restart

State Recovery:
  IF state exists:
    → Load state from storage
    → Replay recent events if needed
  ELSE:
    → Initialize with default state (ALIGN=0, TRACE=0)
```

---

## Error Handling & Edge Cases

```
Edge Cases
─────────────────────────────────────────────────────────────

1. First Event:
   - No previous state → Use default state
   - Independence boost = 1.2 (first event is always independent)
   - Novelty boost = 1.1 (no previous keywords to compare)

2. Empty Keywords:
   - Evidence increment still calculated (base weight)
   - Novelty boost = 1.0 if both events have no keywords

3. State Reset:
   - If gate closes, sustain_count resets to 0
   - saw_independent resets to false

4. Event Editing:
   - Recalculate state from edited event
   - Replay subsequent events if needed
   - Maintain history integrity
```

---

## Performance Considerations

```
Optimization Strategies
─────────────────────────────────────────────────────────────

1. State Caching:
   - Keep current state in memory
   - Only persist on significant changes

2. History Limiting:
   - Keep last N events in memory
   - Archive older events to storage

3. Batch Processing:
   - Process multiple events in batch
   - Update state once per batch

4. Lazy Evaluation:
   - Only calculate transition insights when needed
   - Cache expensive calculations
```

---

## Testing Strategy

```
Test Scenarios
─────────────────────────────────────────────────────────────

1. Gate Opening:
   - ALIGN and TRACE both above thresholds
   - Sustained for W entries
   - Independent event in window
   → Gate should open

2. Gate Closing:
   - ALIGN or TRACE below threshold
   → Gate should close, sustain_count resets

3. Independence Detection:
   - Different day events
   - Different source events
   → Should boost evidence

4. Novelty Detection:
   - Keyword drift over time
   → Should boost evidence

5. State Persistence:
   - Save and reload state
   → Should maintain continuity
```

---

## Adaptive Framework

### Overview

RIVET now includes an **adaptive configuration system** that automatically adjusts algorithmic parameters based on user journaling cadence. The core principle: **Psychological time ≠ Calendar time**. A phase transition takes the same number of journal entries whether written daily or weekly, but spans different calendar periods.

### User Cadence Detection

```
User Cadence Detection
─────────────────────────────────────────────────────────────

Purpose: Detect user's journaling pattern to adapt RIVET parameters

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

**Pseudocode:**
```python
def calculate_cadence(entries):
    """
    Calculate user journaling cadence
    
    Args:
        entries: List of JournalEntry objects
    
    Returns:
        UserCadenceMetrics
    """
    if len(entries) < 5:
        return UserCadenceMetrics.insufficient_data()
    
    # Calculate days between consecutive entries
    days_between = []
    for i in range(1, len(entries)):
        days_diff = (entries[i].timestamp - entries[i-1].timestamp).days
        days_between.append(days_diff)
    
    # Filter outliers (gaps > 30 days = breaks)
    filtered_gaps = [d for d in days_between if d <= 30]
    
    if not filtered_gaps:
        return UserCadenceMetrics.sporadic()
    
    avg_days = sum(filtered_gaps) / len(filtered_gaps)
    std_dev = calculate_std_dev(filtered_gaps, avg_days)
    
    return UserCadenceMetrics(
        avg_days_between=avg_days,
        std_dev=std_dev,
        total_entries=len(entries),
        window_days=30
    )

def classify_user_type(metrics):
    """
    Classify user based on cadence metrics
    
    Args:
        metrics: UserCadenceMetrics
    
    Returns:
        UserType enum
    """
    avg = metrics.avg_days_between
    
    if avg <= 2.0:
        return UserType.power_user
    elif avg <= 4.0:
        return UserType.frequent
    elif avg <= 9.0:
        return UserType.weekly
    else:
        return UserType.sporadic
```

### Adaptive RIVET Configuration

```
Adaptive Configuration by User Type
─────────────────────────────────────────────────────────────

Power User (daily):
  - minStabilityDays: 7
  - maxStabilityDays: 14
  - minEntriesForDetection: 7
  - minEntriesInWindow: 5
  - phaseConfidenceThreshold: 0.65
  - transitionConfidenceThreshold: 0.60
  - temporalDecayFactor: 0.95
  - minIntensityForEmerging: 0.70
  - minIntensityForEstablished: 0.80

Frequent User (2-3x/week):
  - minStabilityDays: 14
  - maxStabilityDays: 28
  - minEntriesForDetection: 7
  - minEntriesInWindow: 5
  - phaseConfidenceThreshold: 0.60
  - transitionConfidenceThreshold: 0.55
  - temporalDecayFactor: 0.97
  - minIntensityForEmerging: 0.65
  - minIntensityForEstablished: 0.75

Weekly User:
  - minStabilityDays: 28
  - maxStabilityDays: 56
  - minEntriesForDetection: 6
  - minEntriesInWindow: 4
  - phaseConfidenceThreshold: 0.55
  - transitionConfidenceThreshold: 0.50
  - temporalDecayFactor: 0.98
  - minIntensityForEmerging: 0.60
  - minIntensityForEstablished: 0.70

Sporadic User:
  - minStabilityDays: 42
  - maxStabilityDays: 84
  - minEntriesForDetection: 5
  - minEntriesInWindow: 4
  - phaseConfidenceThreshold: 0.50
  - transitionConfidenceThreshold: 0.45
  - temporalDecayFactor: 0.99
  - minIntensityForEmerging: 0.55
  - minIntensityForEstablished: 0.65
```

### Phase Intensity Calculation

```
Phase Intensity Calculator
─────────────────────────────────────────────────────────────

Purpose: Calculate how strongly an entry matches a phase signature

Components:
  1. Semantic Match (40%): Keyword alignment with phase signature
  2. Emotional Alignment (30%): Emotional tone matches phase expectations
  3. Consistency (30%): Similar signals across recent entries

Formula:
  intensity = (semantic_match × 0.4) + 
              (emotional_alignment × 0.3) + 
              (consistency × 0.3)

Phase States:
  - emerging: Low confidence, high intensity
  - established: High confidence, high intensity
  - stable: High confidence, moderate/low intensity
  - unclear: Low confidence, low intensity
```

**Pseudocode:**
```python
def calculate_phase_intensity(entry, target_phase, config):
    """
    Calculate phase intensity for an entry
    
    Args:
        entry: JournalEntry
        target_phase: PhaseSignature
        config: RivetConfig
    
    Returns:
        Phase intensity score (0.0-1.0)
    """
    # Semantic match: keyword alignment
    semantic_match = calculate_semantic_match(entry, target_phase)
    
    # Emotional alignment: tone matches phase expectations
    emotional_alignment = calculate_emotional_alignment(entry, target_phase)
    
    # Consistency: similar signals across recent entries
    consistency = calculate_consistency(entry, target_phase)
    
    intensity = (semantic_match * 0.4) + \
                (emotional_alignment * 0.3) + \
                (consistency * 0.3)
    
    return intensity.clamp(0.0, 1.0)

def determine_phase_state(confidence, intensity, config):
    """
    Determine phase state from confidence and intensity
    
    Args:
        confidence: Phase confidence score
        intensity: Phase intensity score
        config: RivetConfig
    
    Returns:
        PhaseState enum
    """
    if confidence < config.phase_confidence_threshold:
        if intensity >= config.min_intensity_for_emerging:
            return PhaseState.emerging
        else:
            return PhaseState.unclear
    else:
        if intensity >= config.min_intensity_for_established:
            return PhaseState.established
        else:
            return PhaseState.stable
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

- **Location**: `lib/prism/atlas/rivet/`
- **Main Service**: `rivet_service.dart`
- **Models**: `rivet_models.dart`
- **Storage**: `rivet_storage.dart`
- **Integration**: `rivet_provider.dart`
- **Adaptive Framework**: `lib/services/adaptive/` (NEW)


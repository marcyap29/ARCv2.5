# Phase Detection Factors - Comprehensive Breakdown

## Current Factors (Excluding Text Length)

### 1. **Selected Keywords** (Highest Priority - 70% weight when available)
**Location**: `PhaseScoring._scoreFromKeywords()`, `PhaseRecommender._getPhaseFromKeywords()`

**How it works**:
- User explicitly selects keywords from a list
- Each phase has a comprehensive keyword set (100-200+ keywords per phase)
- Scoring formula: `matches + (coverage * 0.5) + (relevance * 2.0)`
  - `coverage` = matches / total_keywords_in_phase
  - `relevance` = matches / total_user_keywords
- If score ≥ 1.0, returns that phase immediately
- If keywords provided: 70% keyword weight, 30% other factors

**Keyword Sets** (examples):
- **Recovery**: stressed, anxious, tired, healing, calm, rest, breathe, peace, restore, balance, meditation, mindfulness, self-care, therapy, support, comfort, safe, renewal, recharge, reset, health, wellness, acceptance, forgiveness, patience
- **Discovery**: curious, excited, hopeful, learning, goals, dreams, exploration, new, beginning, wonder, question, explore, creativity, spirituality, mystery, awe, fascination
- **Expansion**: grateful, joyful, confident, energized, happy, blessed, opportunity, progress, abundance, flourishing, thriving, success, achievement, growth, expanding, reach, possibility, energy, outward, more, bigger, increase
- **Transition**: uncertain, change, challenge, transition, work, family, relationship, career, move, leaving, switch, patterns, habits, setback, between
- **Consolidation**: reflection, awareness, patterns, habits, routine, stable, organize, weave, integrate, ground, settle, consistency, home, friendship, consolidate
- **Breakthrough**: clarity, insight, breakthrough, transformation, wisdom, epiphany, suddenly, realized, understand, aha, purpose, threshold, crossing, momentum, coherent, unlock, path, crisp, landing

**Weight**: 70% when keywords provided, otherwise 0%

---

### 2. **Emotion** (Strong Signal - 0.9 score when matched)
**Location**: `PhaseRecommender.recommend()` lines 28-37, `PhaseScoring._scoreFromEmotion()`

**How it works**:
- Direct emotion → phase mapping (strong emotions override other signals)
- Strong emotions (0.9 score):
  - `depressed, tired, stressed, anxious, angry` → **Recovery**
  - `excited, curious, hopeful` → **Discovery**
  - `happy, blessed, grateful, energized, relaxed` → **Expansion**
- Weaker emotions (0.6 score):
  - `uncertain, confused` → **Transition**
  - `content, peaceful` → **Consolidation**
  - `amazed, surprised` → **Breakthrough**
- Default (0.3 score): Unknown emotions → **Discovery**

**Weight**: Uses `math.max()` - additive (doesn't override, adds to score)

---

### 3. **Content Keywords** (Text Analysis - 0.7-0.8 score when matched)
**Location**: `PhaseRecommender.recommend()` lines 39-76, `PhaseScoring._scoreFromContent()`

**How it works**:
- Scans entry text for phase-specific keywords (same sets as selected keywords)
- Uses simple substring matching: `text.contains(keyword)`
- Score calculation: `(matches / total_keywords_in_phase) * multiplier`
  - Transition: 0.8 (if reason + action match), 0.7 (action only)
  - Consolidation: 0.8
  - Breakthrough: 0.8
  - Recovery: 0.7
  - Expansion: 0.7
  - Discovery: 0.7

**Special Cases**:
- **Transition** requires BOTH:
  - Reason contains: `relationship, work, school, family`
  - AND text contains: `switch, move, change, leaving, transition`

**Weight**: Uses `math.max()` - additive (doesn't override, adds to score)

---

### 4. **Emotion Reason** (Context Signal)
**Location**: `PhaseRecommender.recommend()` line 43, `PhaseScoring._scoreFromContent()`

**How it works**:
- The "why" behind the emotion (e.g., "because of work stress")
- Used specifically for **Transition** detection:
  - If reason contains: `relationship, work, job, career, school, family, home, move, moving, relocation`
  - AND text contains transition action words
  - → Strong Transition signal (0.8 score)

**Weight**: Only used for Transition phase, otherwise ignored

---

### 5. **Text Structure** (Currently: Text Length - TO BE REMOVED)
**Location**: `PhaseScoring._scoreFromStructure()`

**Current implementation** (to be removed):
- < 20 chars → Expansion (0.4)
- > 100 chars → Consolidation (0.4)
- < 10 words → Transition (0.3)
- Otherwise → Discovery (0.2)

**Weight**: Uses `math.max()` - additive

---

## Additional Factors (Not Currently Used in Main Detection)

### 6. **Health Data** (Available but not in main flow)
**Location**: `PhaseAwareAnalysisService._applyHealthPhaseAdjustments()`

**How it works**:
- Can adjust phase scores based on health metrics
- Not currently integrated into `PhaseRecommender` or `PhaseScoring`

**Weight**: Not currently used

---

### 7. **Mood Field** (Available but not used)
**Location**: Journal entries have a `mood` field

**How it works**:
- Some services analyze `entry.mood` separately
- Not integrated into main `PhaseRecommender` logic

**Weight**: Not currently used

---

### 8. **Recent Entry Patterns** (Used in PhaseDetectorService, not PhaseRecommender)
**Location**: `PhaseDetectorService.detectCurrentPhase()`

**How it works**:
- Analyzes last 10-20 entries or last 28 days
- Aggregates keywords across multiple entries
- Used for overall phase detection, not single-entry detection

**Weight**: Separate service, not used in single-entry detection

---

## Current Weighting System

### PhaseRecommender.recommend() (Binary Decision):
1. **Selected Keywords** → Immediate return if score ≥ 1.0
2. **Strong Emotions** → Immediate return
3. **Content Keywords** → Immediate return (first match wins)
4. **Text Length** → Fallback (to be removed)
5. **Discovery** → Ultimate fallback

### PhaseScoring.score() (Probability Scores):
1. **Selected Keywords**: 70% weight (if provided)
2. **Emotion**: `math.max()` (additive, doesn't override)
3. **Content Keywords**: `math.max()` (additive, doesn't override)
4. **Text Structure**: `math.max()` (additive, to be removed)
5. **Normalization**: Ensures scores sum to reasonable total, caps at 0.95

---

## Recommended Factors to Consider (Not Currently Implemented)

1. **Temporal Markers**: Past/present/future tense, time references
2. **Question Density**: Number of questions per entry (Discovery indicator)
3. **Certainty Language**: "I know" vs "I think" vs "I wonder"
4. **Action Verbs**: Active vs passive language
5. **Negation Patterns**: Negative vs positive framing
6. **Repetition**: Recurring themes/words (Consolidation indicator)
7. **Entry Frequency**: How often user journals (Consolidation = regular, Discovery = sporadic)
8. **Entry Timing**: Time of day patterns
9. **Media Attachments**: Photos, audio (could indicate different phases)
10. **LUMARA Interaction**: Frequency and type of LUMARA responses

---

## Current Issues

1. **Text Length is Arbitrary**: No psychological basis for 20/100 char thresholds
2. **Keyword Matching is Simple**: Uses substring, not semantic understanding
3. **No Context**: Doesn't consider previous entries or user history
4. **Binary vs Probabilistic**: `PhaseRecommender` is binary, `PhaseScoring` is probabilistic - inconsistency
5. **No Confidence Scores**: Can't tell when detection is uncertain
6. **Keyword Sets Overlap**: Many keywords appear in multiple phases
7. **No Learning**: Doesn't adapt to user's language patterns

---

## Questions for Claude/ChatGPT Refinement

1. What's the optimal weighting between keywords, emotions, and content?
2. Should we use semantic similarity instead of exact keyword matching?
3. How should we handle ambiguous cases (multiple phases with similar scores)?
4. Should we consider temporal patterns (phase transitions over time)?
5. What's the best way to incorporate user feedback/corrections?
6. Should text length be removed entirely, or replaced with better structure analysis?
7. How do we handle multilingual entries?
8. Should we use ML/NLP models for better semantic understanding?

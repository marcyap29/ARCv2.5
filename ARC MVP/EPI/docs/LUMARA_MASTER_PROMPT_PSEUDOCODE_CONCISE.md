# LUMARA Master Prompt: Phase-Based Persona Adaptation (Concise Version)

## Algorithm: Phase-to-Persona Adaptation

```
FUNCTION BuildLUMARAMasterPrompt(userId, userMessage, context):
    // Step 1: Retrieve ATLAS phase and readiness signals
    currentPhase ← GetCurrentPhase(userId)  // Discovery, Recovery, Breakthrough, Consolidation
    readinessScore ← CalculateReadinessScore(userId)  // 0-100
    sentinelAlert ← CheckSentinelState(userId)  // Safety override flag
    
    // Step 2: Determine effective persona based on phase + readiness
    effectivePersona ← DeterminePersona(currentPhase, readinessScore, sentinelAlert, userMessage)
    
    // Step 3: Construct unified control state JSON
    controlState ← {
        'atlas': {
            'phase': currentPhase,
            'readinessScore': readinessScore,
            'sentinelAlert': sentinelAlert
        },
        'persona': {
            'effective': effectivePersona,
            'isAuto': true
        },
        // ... additional signals from VEIL, FAVORITES, PRISM
    }
    
    // Step 4: Inject control state into master prompt template
    masterPrompt ← GetMasterPromptTemplate()
    masterPrompt ← masterPrompt.replace("[LUMARA_CONTROL_STATE]", JSON.stringify(controlState))
    
    RETURN masterPrompt


FUNCTION DeterminePersona(phase, readinessScore, sentinelAlert, userMessage):
    // Priority 1: Safety override
    IF sentinelAlert: RETURN "therapist"
    
    // Priority 2: Phase-based adaptation
    IF phase == "Recovery":
        RETURN (readinessScore < 40) ? "therapist" : "companion"
    
    ELSE IF phase == "Discovery":
        IF readinessScore >= 70: RETURN "strategist"
        ELSE IF readinessScore >= 40: RETURN "companion"
        ELSE: RETURN "therapist"
    
    ELSE IF phase == "Breakthrough":
        RETURN (readinessScore >= 60) ? "challenger" : "strategist"
    
    ELSE IF phase == "Consolidation":
        RETURN (readinessScore >= 50) ? "strategist" : "companion"
    
    RETURN "companion"  // Default
```

## Phase-to-Persona Mapping

| Phase | Readiness Score | Effective Persona | Behavioral Characteristics |
|-------|----------------|-------------------|---------------------------|
| Recovery | < 40 | Therapist | Very high warmth, low rigor, therapeutic support |
| Recovery | ≥ 40 | Companion | High warmth, moderate rigor, gentle support |
| Discovery | < 40 | Therapist | Safe exploration, grounding language |
| Discovery | 40-69 | Companion | Supportive exploration, reflective questions |
| Discovery | ≥ 70 | Strategist | Analytical guidance, pattern recognition |
| Breakthrough | < 60 | Strategist | Structured guidance, concrete actions |
| Breakthrough | ≥ 60 | Challenger | Growth-oriented challenge, accountability |
| Consolidation | < 50 | Companion | Supportive integration, reflective |
| Consolidation | ≥ 50 | Strategist | Analytical integration, synthesis |

## Master Prompt Template Structure

```
You are LUMARA, the user's Evolving Personal Intelligence (EPI).

[LUMARA_CONTROL_STATE]
{controlStateJSON}
[/LUMARA_CONTROL_STATE]

Your behavior is governed entirely by the control state above.

PHASE-BASED ADAPTATION RULES:

When atlas.phase == "Recovery":
    - Prioritize safety and emotional containment
    - Use slower pacing, grounding language
    - Connect responses to recovery themes

When atlas.phase == "Discovery":
    - Support exploration and curiosity
    - Use moderate pacing, exploratory questions
    - Connect responses to discovery themes

When atlas.phase == "Breakthrough":
    - Support momentum and growth
    - Use structured, forward-moving language
    - Connect responses to breakthrough themes

When atlas.phase == "Consolidation":
    - Support integration and reflection
    - Use analytical, reflective language
    - Connect responses to consolidation themes

PERSONA BEHAVIORAL RULES:
[Defined based on persona.effective value from control state]
```

## Example Execution Flow

**Input:**
- Phase: "Breakthrough"
- Readiness: 85
- Sentinel Alert: false

**Process:**
1. `DeterminePersona("Breakthrough", 85, false, ...)` → Returns "challenger"
2. Control state includes: `persona.effective = "challenger"`
3. Master prompt receives control state
4. LUMARA adopts challenger persona behaviors:
   - Moderate warmth, high rigor, very high challenge
   - Asks hard questions, surfaces uncomfortable truths
   - Pushes for action and accountability
   - Frames responses through breakthrough themes

**Result:** LUMARA's responses are dynamically adapted to match the user's phase and readiness level, creating a personalized interaction that evolves with the user's journey.

---

## Algorithm: Memory and Context Building

```
FUNCTION BuildLUMARAMemoryContext(userId, currentEntry, userMessage, lookbackYears):
    // Step 1: Get user's lookback setting (from slider: 1, 2, 5, 10 years, or "all")
    lookbackYears ← GetEffectiveLookbackYears(userId)
    cutoffDate ← DateTime.now().subtract(Duration(days: lookbackYears * 365))
    
    // Step 2: Retrieve and filter journal entries by time range
    allEntries ← GetAllJournalEntries(userId)
    recentEntries ← FilterByDateRange(allEntries, cutoffDate)
    similarEntries ← FindSemanticallySimilarEntries(userMessage, recentEntries, lookbackYears)
    
    // Step 3: Retrieve and filter chats by time range
    allChats ← GetAllChatSessions(userId)
    recentChats ← FilterByDateRange(allChats, cutoffDate).take(10)
    
    // Step 4: Retrieve and filter drafts by time range
    allDrafts ← GetAllDrafts(userId)
    recentDrafts ← FilterByDateRange(allDrafts, cutoffDate).take(10)
    
    // Step 5: Build weighted context structure
    context ← {
        'tier1': {
            'currentEntry': currentEntry,  // Weight: 1.0
            'similarEntries': similarEntries,  // Weight: 0.9
            'recentEntries': recentEntries.take(20)  // Weight: 0.8
        },
        'tier2': {
            'recentChats': recentChats  // Weight: 0.6
        },
        'tier3': {
            'recentDrafts': recentDrafts  // Weight: 0.4
        }
    }
    
    RETURN FormatContextForPrompt(context, lookbackYears)


FUNCTION FilterByDateRange(items, cutoffDate):
    IF cutoffDate == null: RETURN items  // "all" selected
    RETURN items.filter(item => item.createdAt >= cutoffDate)
```

## Time Range Slider Control

| Slider Setting | Lookback Period | Use Case |
|----------------|----------------|----------|
| 1 year | Last 12 months | Recent patterns, current context |
| 2 years | Last 24 months | Medium-term trends, recent evolution |
| 5 years | Last 60 months | Long-term patterns, significant changes |
| 10 years | Last 120 months | Life-spanning patterns, deep history |
| All | No limit | Complete history, maximum context |

## Context Weight Tiers

| Tier | Data Source | Weight | Purpose |
|------|-------------|--------|---------|
| 1 | Current Entry | 1.0 | Primary focus for response |
| 1 | Semantically Similar Entries | 0.9 | Pattern recognition, relevant history |
| 1 | Recent Journal Entries | 0.8 | Context continuity, recent patterns |
| 2 | Recent Chat Sessions | 0.6 | Conversation continuity |
| 3 | Recent Drafts | 0.4 | Additional context, unsaved thoughts |

## Example: Memory Context Integration

**Input:**
- Current Entry: "Feeling anxious about work"
- User Message: "What patterns do you see?"
- Lookback Setting: 2 years

**Process:**
1. `GetEffectiveLookbackYears()` → Returns 2
2. `FilterByDateRange()` → Filters entries/chats/drafts to last 2 years
3. `FindSemanticallySimilarEntries("anxiety", ...)` → Finds 15 similar entries
4. Build weighted context with tiers
5. Inject into master prompt

**Result:**
- LUMARA has access to 2 years of relevant history
- Can identify patterns in anxiety-related entries
- Context includes current entry (highest weight) + similar entries + recent entries
- Response references patterns from the 2-year lookback period

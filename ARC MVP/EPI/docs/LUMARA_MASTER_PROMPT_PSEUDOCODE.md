# LUMARA Master Prompt: Phase-Based Persona Adaptation Pseudocode

## Overview

This pseudocode demonstrates how LUMARA's master prompt system utilizes a user's ATLAS phase to dynamically modify the prompt, which in turn updates LUMARA's persona behavior. This represents the integration between ATLAS (phase detection) and LUMARA (adaptive intelligence).

---

## Algorithm: Phase-Based Master Prompt Construction

```
FUNCTION BuildLUMARAMasterPrompt(userId, userMessage, context):
    // ============================================================
    // STEP 1: Gather Phase and Readiness Signals from ATLAS
    // ============================================================
    
    atlasState ← {}
    
    // Retrieve current user phase from ATLAS
    currentPhase ← GetCurrentPhase(userId)
    // Possible values: "Discovery", "Recovery", "Breakthrough", "Consolidation"
    
    // Retrieve readiness score from RIVET (ALIGN + TRACE metrics)
    readinessScore ← CalculateReadinessScore(userId)
    // Range: 0-100, where 0 = low readiness, 100 = high readiness
    
    // Check safety sentinel status
    sentinelAlert ← CheckSentinelState(userId)
    // Boolean: true if user needs maximum safety/support
    
    atlasState['phase'] ← currentPhase
    atlasState['readinessScore'] ← readinessScore
    atlasState['sentinelAlert'] ← sentinelAlert
    
    
    // ============================================================
    // STEP 2: Gather Additional Context Signals
    // ============================================================
    
    // VEIL: Tone and rhythm intelligence
    veilState ← {
        'sophisticationLevel': GetSophisticationLevel(userId),
        'timeOfDay': GetTimeOfDay(),
        'health': GetHealthSignals(userId)
    }
    
    // FAVORITES: User's preferred response style
    favoritesState ← {
        'favoritesProfile': GetFavoritesProfile(userId),
        'count': GetFavoritesCount(userId)
    }
    
    // PRISM: Multimodal cognitive context
    prismState ← {
        'prism_activity': GetPrismActivity(context),
        'emotional_tone': DetectEmotionalTone(userMessage)
    }
    
    
    // ============================================================
    // STEP 3: Determine Effective Persona Based on Phase + Context
    // ============================================================
    
    effectivePersona ← DeterminePersona(
        currentPhase,
        readinessScore,
        sentinelAlert,
        userMessage,
        prismState
    )
    
    // Persona options: "companion", "therapist", "strategist", "challenger"
    
    personaState ← {
        'selected': GetUserSelectedPersona(userId),  // May be "auto"
        'effective': effectivePersona,
        'isAuto': (GetUserSelectedPersona(userId) == "auto")
    }
    
    
    // ============================================================
    // STEP 4: Construct Unified Control State JSON
    // ============================================================
    
    controlState ← {
        'atlas': atlasState,
        'veil': veilState,
        'favorites': favoritesState,
        'prism': prismState,
        'persona': personaState,
        'responseMode': DetermineResponseMode(userMessage),
        'webAccess': GetWebAccessSetting(userId)
    }
    
    controlStateJSON ← JSON.stringify(controlState)
    
    
    // ============================================================
    // STEP 5: Inject Control State into Master Prompt Template
    // ============================================================
    
    masterPrompt ← GetMasterPromptTemplate()
    
    // Replace placeholder with actual control state
    masterPrompt ← masterPrompt.replace(
        "[LUMARA_CONTROL_STATE]",
        controlStateJSON
    )
    
    RETURN masterPrompt


FUNCTION DeterminePersona(phase, readinessScore, sentinelAlert, userMessage, prismState):
    // Priority 1: Safety override (highest priority)
    IF sentinelAlert == true:
        RETURN "therapist"  // Maximum safety and support
    
    // Priority 2: Explicit user request detection
    IF userMessage != null:
        questionIntent ← DetectQuestionIntent(userMessage)
        IF questionIntent == "explicit_advice":
            RETURN "strategist"
        IF questionIntent == "hard_truth":
            RETURN "challenger"
        IF questionIntent == "emotional_support":
            RETURN "therapist"
    
    // Priority 3: Phase-based persona adaptation
    IF phase == "Recovery":
        // Recovery phase: prioritize safety and support
        IF readinessScore < 40:
            RETURN "therapist"  // Low readiness → therapeutic support
        ELSE:
            RETURN "companion"  // Moderate readiness → gentle companion
    
    ELSE IF phase == "Discovery":
        // Discovery phase: adaptive based on readiness
        IF readinessScore >= 70:
            RETURN "strategist"  // High readiness → analytical guidance
        ELSE IF readinessScore >= 40:
            RETURN "companion"  // Moderate readiness → supportive exploration
        ELSE:
            RETURN "therapist"  // Low readiness → safe exploration
    
    ELSE IF phase == "Breakthrough":
        // Breakthrough phase: can handle challenge and structure
        IF readinessScore >= 60:
            RETURN "challenger"  // High readiness → growth-oriented challenge
        ELSE:
            RETURN "strategist"  // Moderate readiness → structured guidance
    
    ELSE IF phase == "Consolidation":
        // Consolidation phase: structured reflection and integration
        IF readinessScore >= 50:
            RETURN "strategist"  // Moderate-high readiness → analytical integration
        ELSE:
            RETURN "companion"  // Lower readiness → supportive integration
    
    // Priority 4: Emotional state override
    emotionalTone ← prismState['emotional_tone']
    IF emotionalTone IN ["distressed", "anxious", "sad"]:
        RETURN "therapist"
    
    // Default fallback
    RETURN "companion"


FUNCTION GetMasterPromptTemplate():
    RETURN """
    You are LUMARA, the user's Evolving Personal Intelligence (EPI).
    
    Your behavior is governed entirely by the unified control state below.
    This state is computed BACKEND-SIDE. You DO NOT modify the state. You only follow it.
    
    [LUMARA_CONTROL_STATE]
    {CONTROL_STATE_JSON}
    [/LUMARA_CONTROL_STATE]
    
    Treat everything inside this block as the single, authoritative source of truth.
    Your tone, reasoning style, pacing, warmth, structure, rigor, challenge level,
    therapeutic framing, and multimodal sensitivity MUST follow this profile exactly.
    
    ============================================================
    
    HOW TO INTERPRET THE CONTROL STATE:
    
    A. ATLAS (Readiness + Safety Sentinel)
    - phase: Current identity stage (Discovery, Recovery, Breakthrough, Consolidation)
    - readinessScore: 0-100, where high = more structure/clarity, low = slower pacing
    - sentinelAlert: true = MAXIMUM safety, no challenge, supportive ECHO mode
    
    B. PERSONA
    - effective: Your current persona (companion, therapist, strategist, challenger)
    - isAuto: Whether persona was auto-selected or user-chosen
    
    PERSONA BEHAVIORAL RULES:
    
    When persona == "companion":
        - Warm, supportive, adaptive presence
        - High warmth, moderate rigor, low challenge
        - Conversational output, reflective questions
        - Focus: emotional support, gentle exploration, validation
    
    When persona == "therapist":
        - Deep therapeutic support with gentle pacing
        - Very high warmth, low rigor, very low challenge
        - Uses ECHO (Empathize, Clarify, Hold Space, Offer) explicitly
        - Uses SAGE (Situation, Action, Growth, Essence) for structure
        - Focus: emotional processing, safety, slow movement, containment
    
    When persona == "strategist":
        - Sharp, analytical insights with concrete actions
        - Low warmth, high rigor, high challenge
        - STRUCTURED OUTPUT FORMAT (5 sections):
          1. Signal Separation (short-window vs long-horizon patterns)
          2. Phase Determination (with confidence basis)
          3. Interpretation (system terms: load, capacity, risk)
          4. Phase-Appropriate Actions (2-4 concrete steps)
          5. Optional Reflection (only if reduces ambiguity)
        - NO encouragement language, NO "would you like to..."
        - State conclusions cleanly, recommend actions directly
        - Focus: pattern recognition, operational clarity, decisive guidance
    
    When persona == "challenger":
        - Direct feedback that pushes growth
        - Moderate warmth, high rigor, very high challenge
        - Asks hard questions, surfaces uncomfortable truths
        - Pushes for action and accountability
        - Focus: growth edges, honest assessment, forward momentum
    
    PHASE-BASED ADAPTATION:
    
    When atlas.phase == "Recovery":
        - Prioritize safety and emotional containment
        - Use slower pacing, grounding language
        - Connect responses to recovery themes: healing, rest, gradual progress
        - If readinessScore < 40: Emphasize therapist persona behaviors
        - If readinessScore >= 40: Use companion persona with recovery focus
    
    When atlas.phase == "Discovery":
        - Support exploration and curiosity
        - Use moderate pacing, exploratory questions
        - Connect responses to discovery themes: new insights, pattern recognition
        - If readinessScore >= 70: Use strategist persona for analytical exploration
        - If readinessScore < 40: Use therapist persona for safe exploration
    
    When atlas.phase == "Breakthrough":
        - Support momentum and growth
        - Use structured, forward-moving language
        - Connect responses to breakthrough themes: transformation, action, momentum
        - If readinessScore >= 60: Use challenger persona for growth-oriented push
        - If readinessScore < 60: Use strategist persona for structured guidance
    
    When atlas.phase == "Consolidation":
        - Support integration and reflection
        - Use analytical, reflective language
        - Connect responses to consolidation themes: integration, synthesis, stability
        - If readinessScore >= 50: Use strategist persona for analytical integration
        - If readinessScore < 50: Use companion persona for supportive integration
    
    READINESS SCORE INTERPRETATION:
    - High readiness (>= 70): More structure, clearer direction, more decisiveness
    - Moderate readiness (40-69): Balanced approach, adaptive pacing
    - Low readiness (< 40): Slower pacing, grounding, cautious forward movement
    
    ============================================================
    
    [Additional prompt sections for VEIL, FAVORITES, PRISM, etc.]
    """
```

---

## Example: Phase-to-Persona Flow

### Scenario 1: User in Recovery Phase, Low Readiness

```
Input:
  - phase: "Recovery"
  - readinessScore: 25
  - sentinelAlert: false
  - userMessage: "I'm feeling overwhelmed today"

Process:
  1. DeterminePersona("Recovery", 25, false, userMessage, ...)
  2. Phase == "Recovery" AND readinessScore < 40
  3. RETURN "therapist"

Control State:
  {
    "atlas": {
      "phase": "Recovery",
      "readinessScore": 25,
      "sentinelAlert": false
    },
    "persona": {
      "effective": "therapist",
      "isAuto": true
    }
  }

Master Prompt Effect:
  - LUMARA adopts therapist persona
  - Very high warmth, low rigor, very low challenge
  - Uses ECHO framework explicitly
  - Slow pacing, grounding language
  - Connects responses to recovery themes
  - Emphasizes safety and emotional containment
```

### Scenario 2: User in Breakthrough Phase, High Readiness

```
Input:
  - phase: "Breakthrough"
  - readinessScore: 85
  - sentinelAlert: false
  - userMessage: "I want to push forward with my goals"

Process:
  1. DeterminePersona("Breakthrough", 85, false, userMessage, ...)
  2. Phase == "Breakthrough" AND readinessScore >= 60
  3. RETURN "challenger"

Control State:
  {
    "atlas": {
      "phase": "Breakthrough",
      "readinessScore": 85,
      "sentinelAlert": false
    },
    "persona": {
      "effective": "challenger",
      "isAuto": true
    }
  }

Master Prompt Effect:
  - LUMARA adopts challenger persona
  - Moderate warmth, high rigor, very high challenge
  - Asks hard questions, surfaces uncomfortable truths
  - Pushes for action and accountability
  - Connects responses to breakthrough themes
  - Emphasizes growth edges and forward momentum
```

### Scenario 3: User in Discovery Phase, Moderate Readiness

```
Input:
  - phase: "Discovery"
  - readinessScore: 55
  - sentinelAlert: false
  - userMessage: "What patterns do you see in my journal entries?"

Process:
  1. DeterminePersona("Discovery", 55, false, userMessage, ...)
  2. Phase == "Discovery" AND readinessScore >= 40 AND readinessScore < 70
  3. RETURN "companion"

Control State:
  {
    "atlas": {
      "phase": "Discovery",
      "readinessScore": 55,
      "sentinelAlert": false
    },
    "persona": {
      "effective": "companion",
      "isAuto": true
    }
  }

Master Prompt Effect:
  - LUMARA adopts companion persona
  - High warmth, moderate rigor, low challenge
  - Conversational output, reflective questions
  - Connects responses to discovery themes
  - Supports exploration and curiosity
```

---

## Key Design Principles

1. **Phase as Primary Signal**: The user's ATLAS phase is the primary determinant of persona adaptation, providing context for appropriate support style.

2. **Readiness as Modulator**: Readiness score modulates persona selection within phase constraints, allowing fine-grained adaptation.

3. **Safety Override**: Sentinel alerts always override phase-based selection to ensure user safety.

4. **Dynamic Prompt Injection**: The control state JSON is dynamically injected into the master prompt template, allowing real-time adaptation without prompt regeneration.

5. **Persona Consistency**: Once a persona is selected, the master prompt enforces consistent behavioral rules throughout the interaction.

6. **Phase-Aware Framing**: Responses are framed through the lens of the user's current phase, connecting insights to phase-appropriate themes.

---

## Integration with ATLAST

This pseudocode demonstrates how ATLAS (the phase detection system) integrates with LUMARA (the adaptive intelligence) through the master prompt system:

- **ATLAS** provides: phase, readiness score, safety signals
- **LUMARA Master Prompt** receives: unified control state JSON
- **LUMARA Behavior** adapts: persona, tone, structure, pacing based on phase

This creates a closed-loop system where user state (phase) directly influences AI behavior (persona) through a structured, interpretable control mechanism.

---

## Algorithm: Memory and Context Building from User Data

```
FUNCTION BuildLUMARAMemoryContext(userId, currentEntry, userMessage, lookbackYears):
    // ============================================================
    // STEP 1: Retrieve User Settings for Time Range
    // ============================================================
    
    // Get lookback years from user settings (slider control: 1, 2, 5, 10 years, etc.)
    lookbackYears ← GetEffectiveLookbackYears(userId)
    // Default: 1 year, User can adjust via slider: 1, 2, 5, 10, or "all"
    
    // Calculate cutoff date based on lookback years
    cutoffDate ← DateTime.now().subtract(Duration(days: lookbackYears * 365))
    
    // Get additional context settings
    similarityThreshold ← GetSimilarityThreshold(userId)  // 0.0-1.0, default 0.6
    maxMatches ← GetEffectiveMaxMatches(userId)  // Default: 10-20 matches
    
    
    // ============================================================
    // STEP 2: Retrieve Journal Entries (Tier 1: Highest Weight)
    // ============================================================
    
    allJournalEntries ← GetAllJournalEntries(userId)
    
    // Filter by time range (lookback years)
    recentJournalEntries ← FilterByDateRange(allJournalEntries, cutoffDate)
    
    // Sort by date (newest first)
    recentJournalEntries ← SortByDate(recentJournalEntries, descending: true)
    
    // Limit to most recent entries for base context
    baseContextEntries ← recentJournalEntries.take(20).toList()
    
    // If user message provided, find semantically similar entries
    IF userMessage != null AND userMessage.trim().isNotEmpty:
        similarEntries ← FindSemanticallySimilarEntries(
            query: userMessage,
            entries: recentJournalEntries,
            threshold: similarityThreshold,
            maxResults: maxMatches,
            lookbackYears: lookbackYears
        )
    ELSE:
        similarEntries ← []
    
    
    // ============================================================
    // STEP 3: Retrieve Chat Sessions (Tier 2: Medium Weight)
    // ============================================================
    
    allChatSessions ← GetAllChatSessions(userId)
    
    // Filter by time range
    recentChatSessions ← FilterByDateRange(allChatSessions, cutoffDate)
    
    // Sort by date (newest first)
    recentChatSessions ← SortByDate(recentChatSessions, descending: true)
    
    // Limit to most recent chats
    recentChats ← recentChatSessions.take(10).toList()
    
    // Extract chat messages and LUMARA responses
    chatContext ← ExtractChatContext(recentChats)
    
    
    // ============================================================
    // STEP 4: Retrieve Drafts (Tier 3: Lower Weight, but included)
    // ============================================================
    
    allDrafts ← GetAllDrafts(userId)
    
    // Filter by time range
    recentDrafts ← FilterByDateRange(allDrafts, cutoffDate)
    
    // Sort by date (newest first)
    recentDrafts ← SortByDate(recentDrafts, descending: true)
    
    // Limit to most recent drafts
    recentDrafts ← recentDrafts.take(10).toList()
    
    // Extract draft content
    draftContext ← ExtractDraftContent(recentDrafts)
    
    
    // ============================================================
    // STEP 5: Build Weighted Context Structure
    // ============================================================
    
    contextParts ← []
    
    // TIER 1: Current entry (if provided) - HIGHEST WEIGHT
    IF currentEntry != null:
        contextParts.append({
            'tier': 1,
            'weight': 1.0,
            'label': 'CURRENT ENTRY (PRIMARY FOCUS)',
            'content': currentEntry.text,
            'metadata': {
                'date': currentEntry.createdAt,
                'phase': currentEntry.phase,
                'mood': currentEntry.mood,
                'keywords': currentEntry.keywords
            }
        })
    
    // TIER 1: Semantically similar entries - HIGH WEIGHT
    IF similarEntries.length > 0:
        contextParts.append({
            'tier': 1,
            'weight': 0.9,
            'label': 'SEMANTICALLY RELEVANT HISTORY',
            'content': FormatSimilarEntries(similarEntries),
            'metadata': {
                'count': similarEntries.length,
                'timeRange': f"Within {lookbackYears} years",
                'similarityScores': ExtractSimilarityScores(similarEntries)
            }
        })
    
    // TIER 1: Recent journal entries - HIGH WEIGHT
    IF baseContextEntries.length > 0:
        contextParts.append({
            'tier': 1,
            'weight': 0.8,
            'label': 'RECENT JOURNAL ENTRIES (PATTERN CONTEXT)',
            'content': FormatJournalEntries(baseContextEntries),
            'metadata': {
                'count': baseContextEntries.length,
                'timeRange': f"Last {lookbackYears} years",
                'dateRange': [baseContextEntries.last.createdAt, baseContextEntries.first.createdAt]
            }
        })
    
    // TIER 2: Recent chat sessions - MEDIUM WEIGHT
    IF chatContext.length > 0:
        contextParts.append({
            'tier': 2,
            'weight': 0.6,
            'label': 'RECENT CHAT CONVERSATIONS',
            'content': chatContext,
            'metadata': {
                'count': recentChats.length,
                'timeRange': f"Last {lookbackYears} years"
            }
        })
    
    // TIER 3: Recent drafts - LOWER WEIGHT
    IF draftContext.length > 0:
        contextParts.append({
            'tier': 3,
            'weight': 0.4,
            'label': 'RECENT DRAFTS (UNSAVED THOUGHTS)',
            'content': draftContext,
            'metadata': {
                'count': recentDrafts.length,
                'timeRange': f"Last {lookbackYears} years"
            }
        })
    
    
    // ============================================================
    // STEP 6: Format Context for Master Prompt
    // ============================================================
    
    formattedContext ← FormatContextForPrompt(contextParts)
    
    RETURN {
        'context': formattedContext,
        'metadata': {
            'lookbackYears': lookbackYears,
            'cutoffDate': cutoffDate,
            'totalEntries': recentJournalEntries.length,
            'totalChats': recentChatSessions.length,
            'totalDrafts': recentDrafts.length,
            'similarMatches': similarEntries.length,
            'contextTiers': [1, 2, 3]
        }
    }


FUNCTION FindSemanticallySimilarEntries(query, entries, threshold, maxResults, lookbackYears):
    // Apply time range filter first
    cutoffDate ← DateTime.now().subtract(Duration(days: lookbackYears * 365))
    filteredEntries ← entries.filter(entry => entry.createdAt >= cutoffDate)
    
    // Calculate semantic similarity for each entry
    scoredEntries ← []
    FOR EACH entry IN filteredEntries:
        similarityScore ← CalculateSemanticSimilarity(query, entry.content)
        IF similarityScore >= threshold:
            scoredEntries.append({
                'entry': entry,
                'score': similarityScore,
                'excerpt': ExtractRelevantExcerpt(entry.content, query, length: 200)
            })
    
    // Sort by similarity score (highest first)
    scoredEntries.sort((a, b) => b.score.compareTo(a.score))
    
    // Return top matches
    RETURN scoredEntries.take(maxResults).toList()


FUNCTION FormatContextForPrompt(contextParts):
    // Sort by tier (ascending) and weight (descending)
    sortedParts ← contextParts.sort((a, b) => {
        IF a.tier != b.tier:
            RETURN a.tier.compareTo(b.tier)  // Lower tier first
        ELSE:
            RETURN b.weight.compareTo(a.weight)  // Higher weight first
    })
    
    // Build formatted string
    formatted ← ""
    FOR EACH part IN sortedParts:
        formatted += f"\n**{part.label}** (Weight: {part.weight}):\n"
        formatted += part.content
        formatted += "\n"
    
    RETURN formatted
```

---

## Algorithm: Time Range Slider Control

```
FUNCTION GetEffectiveLookbackYears(userId):
    // Retrieve user's lookback setting from preferences
    userSetting ← GetUserLookbackSetting(userId)
    
    // Possible values: 1, 2, 5, 10, or "all"
    IF userSetting == "all":
        RETURN null  // No time limit
    ELSE IF userSetting IS NUMBER:
        RETURN userSetting
    ELSE:
        RETURN 1  // Default: 1 year


FUNCTION FilterByDateRange(items, cutoffDate):
    IF cutoffDate == null:
        RETURN items  // No filtering if "all" selected
    
    // Filter items created after cutoff date
    filtered ← items.filter(item => item.createdAt >= cutoffDate)
    
    RETURN filtered


FUNCTION ApplyLookbackFilterToContext(context, lookbackYears):
    cutoffDate ← DateTime.now().subtract(Duration(days: lookbackYears * 365))
    
    // Apply filter to all context tiers
    filteredContext ← {
        'journalEntries': FilterByDateRange(context.journalEntries, cutoffDate),
        'chats': FilterByDateRange(context.chats, cutoffDate),
        'drafts': FilterByDateRange(context.drafts, cutoffDate),
        'similarEntries': FilterByDateRange(context.similarEntries, cutoffDate),
        'metadata': {
            'lookbackYears': lookbackYears,
            'cutoffDate': cutoffDate,
            'totalItemsBefore': CountAllItems(context),
            'totalItemsAfter': CountAllItems(filteredContext)
        }
    }
    
    RETURN filteredContext
```

---

## Integration: Memory Context + Master Prompt

```
FUNCTION BuildCompleteLUMARAPrompt(userId, currentEntry, userMessage):
    // Step 1: Get user's lookback setting (from slider)
    lookbackYears ← GetEffectiveLookbackYears(userId)
    
    // Step 2: Build memory context from entries, chats, drafts
    memoryContext ← BuildLUMARAMemoryContext(
        userId: userId,
        currentEntry: currentEntry,
        userMessage: userMessage,
        lookbackYears: lookbackYears
    )
    
    // Step 3: Build control state (phase, persona, etc.)
    controlState ← BuildLUMARAMasterPrompt(userId, userMessage, memoryContext)
    
    // Step 4: Combine control state with memory context
    completePrompt ← controlState.masterPrompt
    
    // Append memory context to prompt
    completePrompt += "\n\n--- MEMORY CONTEXT (USER DATA) ---\n"
    completePrompt += memoryContext.context
    completePrompt += f"\n\n**CONTEXT METADATA**:\n"
    completePrompt += f"- Lookback Period: {lookbackYears} years\n"
    completePrompt += f"- Total Entries in Context: {memoryContext.metadata.totalEntries}\n"
    completePrompt += f"- Total Chats in Context: {memoryContext.metadata.totalChats}\n"
    completePrompt += f"- Similar Matches Found: {memoryContext.metadata.similarMatches}\n"
    
    // Add instructions for using context
    completePrompt += "\n**INSTRUCTIONS FOR USING MEMORY CONTEXT**:\n"
    completePrompt += "- CURRENT ENTRY has highest weight (1.0) - focus primarily on this\n"
    completePrompt += "- SEMANTICALLY RELEVANT HISTORY (weight 0.9) - use actively to show patterns\n"
    completePrompt += "- RECENT JOURNAL ENTRIES (weight 0.8) - use for pattern recognition and connections\n"
    completePrompt += "- RECENT CHAT CONVERSATIONS (weight 0.6) - use for conversation continuity\n"
    completePrompt += "- RECENT DRAFTS (weight 0.4) - use as additional context if relevant\n"
    completePrompt += "- Respect the lookback period: only reference entries within the specified time range\n"
    
    RETURN completePrompt
```

---

## Example: Memory Context Building with Time Range

### Scenario: User with 2-Year Lookback Setting

```
Input:
  - userId: "user123"
  - currentEntry: { text: "Feeling anxious about work", createdAt: "2025-01-08" }
  - userMessage: "What patterns do you see in my anxiety?"
  - lookbackYears: 2  // User set slider to 2 years

Process:
  1. GetEffectiveLookbackYears("user123") → Returns 2
  2. cutoffDate = DateTime.now() - (2 * 365 days) = "2023-01-08"
  
  3. BuildLUMARAMemoryContext(...):
     - GetAllJournalEntries() → 500 total entries
     - FilterByDateRange(entries, "2023-01-08") → 180 entries within 2 years
     - FindSemanticallySimilarEntries("anxiety", entries, ...) → 15 similar entries
     - GetAllChatSessions() → 50 total chats
     - FilterByDateRange(chats, "2023-01-08") → 25 chats within 2 years
     - GetAllDrafts() → 30 total drafts
     - FilterByDateRange(drafts, "2023-01-08") → 12 drafts within 2 years
  
  4. Build weighted context:
     - TIER 1: Current entry (weight 1.0)
     - TIER 1: 15 similar entries about anxiety (weight 0.9)
     - TIER 1: 20 most recent journal entries (weight 0.8)
     - TIER 2: 10 most recent chats (weight 0.6)
     - TIER 3: 10 most recent drafts (weight 0.4)

Output Context:
  {
    'context': """
    **CURRENT ENTRY (PRIMARY FOCUS)** (Weight: 1.0):
    Feeling anxious about work
    
    **SEMANTICALLY RELEVANT HISTORY** (Weight: 0.9):
    From 2024-06-15: "Work stress is overwhelming me again..."
    From 2024-03-22: "Anxiety about the presentation tomorrow..."
    [13 more similar entries]
    
    **RECENT JOURNAL ENTRIES (PATTERN CONTEXT)** (Weight: 0.8):
    [20 most recent entries from last 2 years]
    
    **RECENT CHAT CONVERSATIONS** (Weight: 0.6):
    [10 most recent chat sessions]
    
    **RECENT DRAFTS (UNSAVED THOUGHTS)** (Weight: 0.4):
    [10 most recent drafts]
    """,
    'metadata': {
      'lookbackYears': 2,
      'cutoffDate': '2023-01-08',
      'totalEntries': 180,
      'totalChats': 25,
      'totalDrafts': 12,
      'similarMatches': 15
    }
  }
```

### Scenario: User Changes Slider from 2 Years to 10 Years

```
Input:
  - userId: "user123"
  - lookbackYears: 10  // User changed slider from 2 to 10 years

Process:
  1. GetEffectiveLookbackYears("user123") → Returns 10 (updated setting)
  2. cutoffDate = DateTime.now() - (10 * 365 days) = "2015-01-08"
  
  3. Rebuild context with new time range:
     - FilterByDateRange(entries, "2015-01-08") → 450 entries within 10 years
     - FilterByDateRange(chats, "2015-01-08") → 45 chats within 10 years
     - FilterByDateRange(drafts, "2015-01-08") → 28 drafts within 10 years
  
  4. Semantic search now searches across 10 years instead of 2:
     - FindSemanticallySimilarEntries(...) → 35 similar entries (more matches)

Result:
  - LUMARA now has access to 10 years of history instead of 2
  - Can identify longer-term patterns and trends
  - More comprehensive context for pattern recognition
  - Semantic matches include older relevant entries
```

---

## Key Design Principles for Memory Context

1. **Time Range Control**: User-controlled slider allows adjusting how far back LUMARA looks (1, 2, 5, 10 years, or "all")

2. **Weighted Context Tiers**: Different data sources have different weights:
   - Tier 1 (Highest): Current entry, semantically similar entries, recent journal entries
   - Tier 2 (Medium): Recent chat sessions
   - Tier 3 (Lower): Recent drafts

3. **Semantic Similarity**: When user provides a query, LUMARA finds semantically similar entries within the lookback period

4. **Progressive Filtering**: Time range filter is applied at multiple stages:
   - Initial retrieval from database
   - Semantic similarity search
   - Context building

5. **Metadata Tracking**: System tracks what data is included and why, providing transparency

6. **Dynamic Adaptation**: Context adapts in real-time as user changes lookback settings

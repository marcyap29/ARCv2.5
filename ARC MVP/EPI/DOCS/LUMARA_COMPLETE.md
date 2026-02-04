# LUMARA - Complete Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [User Guide](#user-guide)
3. [Technical Specification](#technical-specification)
4. [Response Systems](#response-systems)
5. [Firebase Integration](#firebase-integration)
6. [Implementation Summary](#implementation-summary)
7. [Related Documentation](#related-documentation)

---

## Overview

LUMARA (Lifelong Unified Memory and Adaptive Response Architecture) is ARC's adaptive intelligence system that provides personalized responses based on user phase, engagement mode, and historical context.

**Key Features:**
- Phase-based persona adaptation
- Three-tier engagement system (Reflect/Explore/Integrate)
- Two-stage memory system (Context Selection + CHRONICLE). LUMARA Enterprise Architecture: four-subsystem spine (ARC, ATLAS, CHRONICLE, AURORA) coordinated by the LUMARA Orchestrator when `FeatureFlags.useOrchestrator` is true; see DOCS/LUMARA_ORCHESTRATOR.md, SUBSYSTEMS.md.
- Firebase-only API architecture
- Unified prompt system

---

## User Guide

### Response Length Settings

#### Engagement-Mode-Based Response Lengths (Primary Driver)

**Response length is determined by Engagement Mode, not Persona:**

- **REFLECT Mode**: 200 words base (5 sentences)
  - Brief, surface-level observations
  - Focused on grounding and pattern recognition
  - No exploratory questions

- **EXPLORE Mode**: 400 words base (10 sentences)
  - Deeper investigation with follow-up questions
  - Allows connecting questions and alternative framings
  - Medium-length responses for investigation

- **INTEGRATE Mode**: 500 words base (15 sentences)
  - Comprehensive cross-domain synthesis
  - Longest responses for developmental analysis
  - Cross-domain connections and trajectory themes

#### Conversation Mode Response Length Overrides

**Extended Analysis Modes:**
- **"Analyze"** (ConversationMode.ideas): 600 words base (18 sentences)
  - Extended analysis with practical suggestions
  - Longer than INTEGRATE mode for comprehensive analysis
  - Available in both in-journal and in-chat interfaces
  
- **"Deep Analysis"** (ConversationMode.think): 750 words base (22 sentences)
  - Comprehensive deep analysis with structured scaffolding
  - Longest response mode for thorough investigation
  - Available in main menu and suggestion sheets
  - Includes interpretation, structured analysis, and concrete action suggestions

**Note:** These conversation mode overrides take precedence over engagement mode base lengths when active. Persona density modifiers still apply to these extended lengths.

**Persona Density Modifiers:**
- Persona affects communication style/density, not base length:
  - **Companion**: 1.0x (neutral - warm and conversational)
  - **Strategist**: 1.15x (+15% for analytical detail)
  - **Grounded**: 0.9x (-10% for concise clarity)
  - **Challenger**: 0.85x (-15% for sharp directness)

**Example Word Limits:**

| Engagement Mode | Companion | Strategist | Grounded | Challenger |
|-----------------|-----------|------------|----------|------------|
| **REFLECT**     | 200       | 230        | 180      | 170        |
| **EXPLORE**     | 400       | 460        | 360      | 340        |
| **INTEGRATE**   | 500       | 575        | 450      | 425        |

### Auto Mode vs Manual Mode

**Auto Mode (responseLength.auto = true):**
- LUMARA automatically determines response length based on context
- **ENFORCED LIMIT**: Responses are capped at 10-15 sentences maximum
- LUMARA chooses the appropriate length within this range based on:
  - Engagement Mode (primary driver)
  - Persona density modifier
  - `behavior.verbosity` (0.0-1.0)
  - `engagement.response_length` (concise/moderate/detailed)
  - Context complexity
- **Strict enforcement**: LUMARA must count sentences and stop at 15 maximum

**Manual Mode (responseLength.auto = false):**
- User sets exact limits via sliders:
  - **Max Sentences**: 3, 5, 10, 15, or ∞ (infinity)
  - **Sentences Per Paragraph**: 3, 4, or 5
- **ABSOLUTE STRICT LIMIT**: LUMARA must follow these settings exactly
- No exceptions - if max_sentences = 10, response must have exactly 10 sentences or fewer
- Paragraph structure must match sentences_per_paragraph setting

**Truncation:**
- Responses are truncated at sentence boundaries to prevent mid-sentence cuts
- 25% buffer allows natural flow before truncation triggers

### Memory Retrieval Settings

#### Max Similar Entries (also called "Max Matches")

**What it does:**
- Controls how many past journal entries LUMARA retrieves when building context
- Determines the **breadth of historical context** available to LUMARA
- Range: 1-20 entries (default: 5)

**How it works:**
- When you write a journal entry or chat message, LUMARA searches your journal history
- It finds entries with similar themes, emotions, or topics (using semantic similarity)
- `maxMatches` determines how many of these similar entries to include in the context
- More entries = broader context, but potentially more noise
- Fewer entries = more focused context, but might miss relevant connections

**When to adjust:**
- **Increase** (10-20): If you want LUMARA to consider more of your history, see broader patterns
- **Decrease** (1-3): If you want more focused responses, less historical context

### Engagement Discipline Settings

#### Max Temporal Connections

**What it does:**
- Controls how many references to past entries LUMARA can make **in a single response**
- Determines how many historical connections LUMARA mentions when responding
- Range: 1-5 connections (default: 2)

**How it works:**
- When LUMARA responds, it can reference past journal entries to show patterns or connections
- `maxTemporalConnections` limits how many of these references appear in one response
- This prevents responses from becoming cluttered with too many historical callbacks
- Each "connection" is typically a mention like: "This connects to your entry from [date] where you wrote about..."

**Key Difference: Max Similar Entries vs Max Temporal Connections**

| Setting | What It Controls | When It's Used |
|---------|-----------------|----------------|
| **Max Similar Entries** | How many past entries LUMARA **retrieves** for context | During context building (before response generation) |
| **Max Temporal Connections** | How many past entries LUMARA **mentions** in response | During response generation (in the actual response text) |

**Analogy:**
- **Max Similar Entries** = How many books LUMARA reads to prepare for the conversation
- **Max Temporal Connections** = How many books LUMARA actually quotes or references in its response

### Recommended Settings

**For focused, concise responses:**
- Max Similar Entries: 3-5
- Max Temporal Connections: 1-2
- Response Length: Manual, 5-10 sentences

**For comprehensive, pattern-rich responses:**
- Max Similar Entries: 10-15
- Max Temporal Connections: 3-4
- Response Length: Auto (10-15 sentences) or Manual, 15 sentences

**For minimal historical context:**
- Max Similar Entries: 1-3
- Max Temporal Connections: 1
- Response Length: Manual, 3-5 sentences

---

## Technical Specification

### Master Prompt System

LUMARA uses a unified master prompt system that dynamically adapts based on user phase, engagement mode, and context.

#### Phase-Based Persona Adaptation

The master prompt system utilizes a user's ATLAS phase to dynamically modify the prompt, which in turn updates LUMARA's persona behavior.

**Algorithm Overview:**

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
```

#### Phase-to-Persona Mapping

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

#### Control State Structure

The unified control state JSON includes:

```json
{
  "atlas": {
    "phase": "discovery",
    "readinessScore": 65,
    "sentinelAlert": false
  },
  "persona": {
    "effective": "companion",
    "isAuto": true
  },
  "engagement": {
    "mode": "explore",
    "response_length": "moderate",
    "max_temporal_connections": 2
  },
  "memory": {
    "max_similar_entries": 5,
    "lookback_years": 2
  },
  "veil": {
    "sophisticationLevel": 0.7,
    "timeOfDay": "evening"
  }
}
```

### Two-Stage Memory System

LUMARA uses a two-stage memory system for context building:

1. **Context Selection**: Retrieves relevant entries based on time window and semantic similarity
2. **CHRONICLE**: Longitudinal aggregated memory; synthesizes patterns across retrieved entries. Part of the four-subsystem spine (ARC, ATLAS, CHRONICLE, AURORA) coordinated by the LUMARA Orchestrator (see DOCS/LUMARA_ORCHESTRATOR.md).

**Memory Context Building:**

```
FUNCTION BuildLUMARAMemoryContext(userId, currentEntry, userMessage, lookbackYears):
    // Step 1: Get user's lookback setting (from slider: 1, 2, 5, 10 years, or "all")
    lookbackYears ← GetEffectiveLookbackYears(userId)
    cutoffDate ← DateTime.now().subtract(Duration(days: lookbackYears * 365))
    
    // Step 2: Retrieve and filter journal entries by time range
    allEntries ← GetAllJournalEntries(userId)
    recentEntries ← FilterByDateRange(allEntries, cutoffDate)
    similarEntries ← FindSemanticallySimilarEntries(userMessage, recentEntries, lookbackYears)
    
    // Step 3: Build weighted context structure
    context ← {
        'tier1': {
            'currentEntry': currentEntry,  // Weight: 1.0
            'similarEntries': similarEntries,  // Weight: 0.9
            'recentEntries': recentEntries.take(20)  // Weight: 0.8
        }
    }
    
    RETURN FormatContextForPrompt(context, lookbackYears)
```

---

## Response Systems

LUMARA's responses are controlled by **three independent systems** that layer together:

| System | When It's Set | What It Controls |
|--------|---------------|------------------|
| **EngagementMode** | Before you write (or via voice command) | Depth of engagement & cross-domain connections |
| **EntryClassifier** | Automatic (content-based) | Response length based on message type |
| **ConversationMode** | After LUMARA responds | Follow-up continuation style |

### EngagementMode

**Purpose:** Controls how deeply LUMARA engages with your content.

**APPLIES TO:** ALL interaction types - voice conversations, text chat, journal reflections, and all LUMARA interactions.

**When set:** User selects before writing (DEFAULT / EXPLORE / INTEGRATE selector) OR uses voice/text commands to switch mid-conversation.

**Modes:**

| Mode | Behavior | Historical References | Best For |
|------|----------|----------------------|----------|
| **DEFAULT** | Answer naturally like Claude. 60-80% pure answers with NO references, 20-40% with 1-3 brief references. | 20-40% of responses (1-3 refs) | Casual conversation, quick questions, factual queries |
| **EXPLORE** | Surface patterns + invite deeper examination. Ask follow-up questions. Proactive connections. | 50-70% of responses (2-5 dated refs) | Active sense-making, pattern analysis, temporal queries |
| **INTEGRATE** | Synthesize across domains and time horizons. Connect past entries, other life areas. Full synthesis. | 80-100% of responses (extensive refs) | Holistic understanding, big picture, comprehensive analysis |

**Voice/Text Commands for Mode Switching:**
- **To DEFAULT:** "Keep it simple", "Just answer briefly", "Quick response"
- **To EXPLORE:** "Explore this more", "Show me patterns", "Go deeper on this"
- **To INTEGRATE:** "Full synthesis", "Connect across everything", "Big picture"

### EntryClassifier

**Purpose:** Automatically classifies entry type and adjusts response length.

**Classification Types:**
- `factual` - 0 examples (no pattern recognition)
- `reflective` - 2-4 dated examples required
- `analytical` - 3-8 examples for deep analysis
- `conversational` - 0 examples (no pattern recognition)
- `metaAnalysis` - Extensive examples for synthesis

### ConversationMode

**Purpose:** Controls follow-up continuation style after LUMARA responds.

**Modes:**
- `continue` - Natural conversation flow
- `ideas` - Extended analysis (600 words)
- `think` - Deep analysis (750 words)
- `different` - Alternative perspective

---

## Firebase Integration

### ✅ All User-Facing LUMARA Features Use Firebase

1. **✅ Main Chat Messages** (`lumara_assistant_cubit.dart`)
   - Uses: `sendChatMessage` Cloud Function
   - Status: Fully migrated, no local API key fallback

2. **✅ Message Continuation** (`lumara_assistant_cubit.dart:447`)
   - Uses: `sendChatMessage` Cloud Function
   - Status: **Just migrated** - now Firebase-only

3. **✅ In-Journal Reflections** (`enhanced_lumara_api.dart`)
   - Uses: `generateJournalReflection` Cloud Function
   - Status: Fully migrated

4. **✅ Journal Prompts** (`journal_screen.dart`)
   - Uses: `generateJournalPrompts` Cloud Function
   - Status: Fully migrated with local fallback for prompts only

5. **✅ Conversation Summaries** (`lumara_assistant_cubit.dart:2146`)
   - Uses: `sendChatMessage` Cloud Function
   - Status: Fully migrated with simple fallback

### ⚠️ Unused/Non-Critical Code Paths (Not User-Facing)

These functions exist but are **NOT CALLED** in active LUMARA flows:

1. **Streaming Function** (`_processMessageWithStreaming`)
   - Status: Defined but never called
   - Action: Can be safely removed or left as-is

2. **VEIL-EDGE Integration**
   - Status: May be used in edge cases, not primary LUMARA flow
   - Action: Can be migrated later if needed

3. **Privacy Guardrail Wrapper**
   - Status: Wrapper function, not direct LUMARA usage
   - Action: Can be migrated later if needed

### 📋 Non-LUMARA Services

These services use `provideArcLLM()` but are **NOT part of LUMARA**:
- `echo_service.dart` - ECHO service (separate from LUMARA)
- `lumara_share_service.dart` - Sharing service (may need migration)
- `journal_screen.dart` - Uses for non-LUMARA features

### ✅ Confirmation

**All active LUMARA user-facing features use Firebase backend exclusively.**
- No local API key fallback for LUMARA features
- All LLM calls go through Firebase Functions
- Error handling provides graceful degradation (simple fallbacks, not API key usage)

---

## Implementation Summary

### LUMARA v3.0 Pattern Recognition System

Successfully implemented the LUMARA Response Generation System v3.0 specification with comprehensive pattern recognition capabilities and favorites library-only functionality.

#### ✅ Completed Changes

1. **Favorites System Updates**
   - Removed favorites-based learning/adaptation, made favorites library-only
   - Updated comments to clarify favorites are "Library reference only"
   - Added explicit instructions: "Do NOT adapt writing style based on these examples"

2. **ResponseMode Class Enhancement**
   - Added `minPatternExamples`, `maxPatternExamples`, `requireDates` fields
   - Updated all persona factory methods with pattern requirements:
     - **Companion**: 2-4 dated examples required
     - **Therapist**: 1-3 examples for continuity
     - **Strategist**: 3-8 examples for deep analysis
     - **Challenger**: 1-2 sharp, focused examples

3. **Master Prompt Builder Transformation**
   - Constraints-first approach - word limits and pattern requirements at the top
   - Comprehensive banned phrases list (13 melodramatic phrases)
   - Pattern recognition guidelines for Companion with good/bad examples
   - Word allocation breakdown (40% validate, 40% patterns, 20% insights)

4. **Unified Prompt System (v3.2)**
   - Consolidated master prompt and user prompt into single unified prompt
   - Eliminated duplication and override risk
   - Single source of truth for all LUMARA instructions

### Critical Files That Control Output

1. **Master Prompt (System Prompt)**
   - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
   - Contains word limit enforcement
   - Contains Companion mode detection
   - Contains banned phrases list

2. **Control State Builder**
   - `lib/arc/chat/services/lumara_control_state_builder.dart`
   - Sets persona.effective
   - Sets responseMode.maxWords
   - Sets entryClassification

3. **Entry Classification**
   - `lib/services/lumara/entry_classifier.dart`
   - Classifies entries correctly
   - Determines pattern requirements

4. **Context Builder**
   - `lib/arc/chat/llm/prompts/lumara_context_builder.dart`
   - Favorites are library-only
   - Memory context building

---

## Related Documentation

- [LUMARA Vision](./LUMARA_Vision.md) - Complete vision document
- [Voice Mode Complete](./VOICE_MODE_COMPLETE.md) - Voice mode implementation
- [Engagement Discipline](./Engagement_Discipline.md) - Engagement mode details
- [Prompt References](./PROMPT_REFERENCES.md) - All LUMARA prompts

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Maintainer**: ARC Development Team

# LUMARA - Complete Guide

**Version:** 2.0  
**Last Updated:** February 12, 2026  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Narrative Intelligence](#narrative-intelligence)
3. [Subsystems](#subsystems)
4. [Orchestrator](#orchestrator)
5. [User Guide](#user-guide)
6. [Technical Specification](#technical-specification)
7. [Response Systems](#response-systems)
8. [LLM Integration](#llm-integration)
9. [Implementation Summary](#implementation-summary)
10. [Related Documentation](#related-documentation)

---

## Overview

**ARC** is the journaling and narrative-capture subsystem; **LUMARA** is the orchestrator that uses ARC's data (plus CHRONICLE, ATLAS, AURORA) to provide a single assistant that can answer like ChatGPT/Claude by default and, when needed, act as a persistent, developmentally aware partner with long-term memory and pattern recognition.

### What is ARC?

**ARC** = **Personal Intelligence Reactor**. One of four subsystems in the EPI (Evolving Personal Intelligence) app spine.

**Role:** Narrative **capture** and **reflection**.

- **Capture:** Journal entries (text, voice, Arcforms) form a continuous stream of self-documentation (VEIL "Verbalize" — immediate capture).
- **Reflection:** In-journal and in-chat conversations with LUMARA turn entries into reflected narrative (patterns, questions, connections in the moment).
- **Context for LUMARA:** ARC supplies **recent entries** and **base context** so the Master Prompt has current-journal context. It does not decide *when* to use that context; LUMARA does.

**What ARC does *not* do:** It does not run the LLM, choose personas, or route queries. It feeds the pipeline; LUMARA consumes it.

**Implementation:** `lib/arc/` (journaling, chat, reflections); orchestrator-facing logic in `lib/arc/chat/services/arc_subsystem.dart`.

### What is LUMARA?

**LUMARA** = **Lifelong Unified Memory and Adaptive Response Architecture**. It is the **orchestrator** of narrative intelligence and the layer that actually produces assistant responses.

**Core responsibilities:**

1. **Orchestration:** Coordinate four subsystems (ARC, ATLAS, CHRONICLE, AURORA); route user intents; build the prompt so the LLM sees: recent entries (ARC), current phase (ATLAS), longitudinal memory (CHRONICLE), rhythm (AURORA).
2. **Phase-aware response:** Adapt tone, depth, and suggestions to the user's developmental phase (e.g. Recovery vs Transition vs Breakthrough).
3. **Memory and context:** Two-stage model — (1) context selection (which recent/similar entries to pull in), (2) CHRONICLE (aggregated temporal layers). Enables "How have I changed?" and "What was going on last year?" from synthesized narrative, not only raw search.
4. **Unified conversation:** One assistant. Persona (Companion, Therapist, Strategist, Challenger), engagement mode (Default / Explore / Integrate), response length, and CHRONICLE-backed vs raw-backed modes are all integrated in a single conversation experience.

### Pipeline

```
User journals (ARC)
       ↓
Layer 0 raw entries → CHRONICLE synthesis (VEIL: Examine → Integrate → Link)
       ↓
LUMARA Orchestrator
  ├─ ARC:     recent entries + base context
  ├─ ATLAS:   current phase + rationale
  ├─ CHRONICLE: temporal aggregations (monthly / yearly / multi-year)
  └─ AURORA:  rhythm/regulation (stub for now)
       ↓
Master Prompt (phase-aware, CHRONICLE-backed or raw-backed)
       ↓
LLM response (Groq primary, Gemini fallback)
```

### Capabilities

- **Answer like ChatGPT or Claude:** Default behavior: 60–80% pure answers with no historical references; 20–40% with 1–3 brief references when relevant.
- **Long-term context:** Retrieves and uses ARC + CHRONICLE for queries like "Tell me about my week," "How have I changed?"
- **Pattern recognition across time:** Themes, emotional arcs, phase distribution (monthly); theme shifts (yearly); developmental arcs (multi-year).
- **Phase-aware tone:** Responses adapt to the user's current phase (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough).
- **Actionable insights:** Concrete suggestions when appropriate (via persona and engagement mode).
- **Persistent relationship:** Memory is not reset each session. Context selection + CHRONICLE provide continuity.
- **Narrative authority:** The system proposes synthesis; the user can refine, correct, and own the narrative (collaborative autobiography).

---

## Narrative Intelligence

**Narrative intelligence** is the capacity of a system to understand, synthesize, and work *with* a person's life story over time—not by building a hidden model *of* them, but by co-creating a shared biographical understanding. It combines:

1. **Temporal continuity** — Connecting experiences across days, months, and years.
2. **Pattern recognition** — Identifying themes, phases, and recurrences from ongoing self-documentation.
3. **Developmental awareness** — Knowing *where* someone is in their psychological journey, not just *what* they said.
4. **Narrative authority** — The human is the authority on their own story. The system proposes; the user refines and owns.
5. **Collaborative autobiography** — AI handles synthesis and pattern detection; the human retains editorial control.

Implemented through the **VEIL cycle** (Verbalize → Examine → Integrate → Link): immediate capture, pattern recognition, synthesis into coherent narrative, and cross-temporal biographical linking. CHRONICLE is the automated implementation. The result is **collaborative biographical intelligence** across unbounded time, with bounded computational cost.

---

## Subsystems

All subsystems implement the interface in `lib/lumara/subsystems/subsystem.dart`:
- **name** – Subsystem identifier (e.g. `'CHRONICLE'`, `'ARC'`).
- **canHandle(CommandIntent)** – Whether this subsystem should be queried for the given intent.
- **query(CommandIntent)** – Returns `Future<SubsystemResult>`.

### CHRONICLE (Longitudinal Memory)

**Role:** Aggregated longitudinal context (synthesis across time). Wraps `ChronicleQueryRouter`, `ChronicleContextBuilder`.

**Location:** `lib/lumara/subsystems/chronicle_subsystem.dart`

**CanHandle:** temporalQuery, patternAnalysis, developmentalArc, historicalParallel, comparison, decisionSupport, specificRecall.

**Output:** `chronicleContext` (string) and `chronicleLayerNames` (list). Sets prompt mode to `chronicleBacked` when present.

### ARC (Capture / Recent Context)

**Role:** Recent journal entries and entry contents. Wraps `LumaraContextSelector`, `LumaraReflectionSettingsService`.

**Location:** `lib/arc/chat/services/arc_subsystem.dart`

**CanHandle:** temporalQuery, patternAnalysis, developmentalArc, historicalParallel, comparison, recentContext, decisionSupport, specificRecall.

**Output:** `recentEntries` (list of maps: date, relativeDate, daysAgo, title, id), `entryContents` (list of content strings).

### ATLAS (Developmental Phase)

**Role:** Current developmental phase and rationale. Informs tone and phase calibration.

**Location:** `lib/arc/chat/services/atlas_subsystem.dart`

**Wraps:** `UserPhaseService` (getCurrentPhase, getCurrentPhaseRationale, getPhaseDescription).

**Output:** Phase name, description, rationale → injected as SUBSYSTEM CONTEXT block.

### AURORA (Rhythm / Regulation)

**Role:** Rhythm and regulation summary (usage patterns, optimal timing).

**Location:** `lib/arc/chat/services/aurora_subsystem.dart`

**CanHandle:** usagePatterns, optimalTiming, recentContext, temporalQuery.

**Status:** Stub — `aggregations` is empty until full implementation.

### Summary Table

| Subsystem | Location | Main output for prompt | Status |
|-----------|----------|------------------------|--------|
| CHRONICLE | lumara/subsystems/ | chronicleContext, chronicleLayerNames | Implemented |
| ARC | arc/chat/services/ | recentEntries, baseContext | Implemented |
| ATLAS | arc/chat/services/ | ATLAS line in SUBSYSTEM CONTEXT block | Implemented |
| AURORA | arc/chat/services/ | AURORA line in SUBSYSTEM CONTEXT block | Stub (empty) |

All four registered in `EnhancedLumaraApi._ensureOrchestrator()`.

---

## Orchestrator

### Role

- **Coordinates data, does not replace the Master Prompt.** Parses user query into intent, queries all subsystems in parallel, aggregates results.
- **Single entry point for journal reflection context.** When `FeatureFlags.useOrchestrator` is true, `EnhancedLumaraApi` calls `LumaraOrchestrator.execute()`.
- **Gradual migration.** Feature flag allows A/B and rollout; legacy path remains for voice.

### Flow

1. **Parse:** `CommandParser` turns user query into `CommandIntent` (intent type, raw query, optional userId/entryId).
2. **Route:** Orchestrator asks each subsystem `canHandle(intent)`. All that return true are queried in parallel.
3. **Aggregate:** `ResultAggregator` collects `SubsystemResult`s into `OrchestrationResult`.
4. **Consume:** `EnhancedLumaraApi` uses `OrchestrationResult.toContextMap()` to build the prompt.

### Key Types and Locations

| Item | Location |
|------|----------|
| **Subsystem interface** | `lib/lumara/subsystems/subsystem.dart` |
| **CommandParser** | `lib/lumara/orchestrator/command_parser.dart` |
| **LumaraOrchestrator** | `lib/lumara/orchestrator/lumara_orchestrator.dart` |
| **ResultAggregator / OrchestrationResult** | `lib/lumara/orchestrator/result_aggregator.dart`, `lib/lumara/models/orchestration_result.dart` |
| **Models** | `lib/lumara/models/` (IntentType, CommandIntent, SubsystemResult) |
| **Integration** | `lib/arc/chat/services/enhanced_lumara_api.dart` |
| **Feature flag** | `lib/state/feature_flags.dart` – `FeatureFlags.useOrchestrator` |

### When the Orchestrator Runs

- **Journal reflection (text),** with feature flag on, CHRONICLE initialized, `userId` set: orchestrator runs.
- **Voice or flag false:** Legacy path (direct context selector + query router + context builder).

### Enterprise Architecture Principles

- **Wrap, don't rebuild** — CHRONICLE stays; wrap as ChronicleSubsystem.
- **Orchestrator vs Master Prompt** — Orchestrator coordinates data; Master Prompt controls LLM behavior.
- **Gradual migration** — Feature flag for A/B and rollout.
- **Preserve quality** — Orchestrator path must match or exceed legacy output.

---

## User Guide

### Response Length Settings

#### Engagement-Mode-Based Response Lengths (Primary Driver)

- **REFLECT Mode**: 200 words base (5 sentences) — Brief observations, grounding, pattern recognition
- **EXPLORE Mode**: 400 words base (10 sentences) — Deeper investigation with follow-up questions
- **INTEGRATE Mode**: 500 words base (15 sentences) — Comprehensive cross-domain synthesis

#### Conversation Mode Overrides

- **"Analyze"** (ConversationMode.ideas): 600 words base (18 sentences)
- **"Deep Analysis"** (ConversationMode.think): 750 words base (22 sentences)

**Persona Density Modifiers:**
- **Companion**: 1.0x (warm, conversational)
- **Strategist**: 1.15x (analytical detail)
- **Grounded**: 0.9x (concise clarity)
- **Challenger**: 0.85x (sharp directness)

| Engagement Mode | Companion | Strategist | Grounded | Challenger |
|-----------------|-----------|------------|----------|------------|
| **REFLECT** | 200 | 230 | 180 | 170 |
| **EXPLORE** | 400 | 460 | 360 | 340 |
| **INTEGRATE** | 500 | 575 | 450 | 425 |

### Auto Mode vs Manual Mode

**Auto Mode** (responseLength.auto = true): Automatic length based on context, capped at 10-15 sentences.

**Manual Mode** (responseLength.auto = false): User sets exact limits via sliders (Max Sentences: 3/5/10/15/∞; Sentences Per Paragraph: 3/4/5). Strict enforcement.

### Memory Retrieval Settings

**Max Similar Entries (1-20, default 5):** How many past entries LUMARA **retrieves** for context.

**Max Temporal Connections (1-5, default 2):** How many past entries LUMARA **mentions** in a response.

| Setting | Controls | When Used |
|---------|----------|-----------|
| Max Similar Entries | How many entries retrieved | Context building (before response) |
| Max Temporal Connections | How many entries mentioned | Response generation (in the response text) |

---

## Technical Specification

### Master Prompt System

LUMARA uses a unified master prompt system (`lib/arc/chat/llm/prompts/lumara_master_prompt.dart`) that dynamically adapts based on user phase, engagement mode, and context.

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

#### Two-Stage Memory System

1. **Context Selection:** Retrieves relevant entries based on time window and semantic similarity.
2. **CHRONICLE:** Longitudinal aggregated memory; synthesizes patterns across retrieved entries. Part of the four-subsystem spine coordinated by the Orchestrator (see [Orchestrator](#orchestrator) above).

---

## Response Systems

LUMARA's responses are controlled by **three independent systems**:

| System | When Set | Controls |
|--------|----------|----------|
| **EngagementMode** | Before writing (or voice command) | Depth of engagement & cross-domain connections |
| **EntryClassifier** | Automatic (content-based) | Response length based on message type |
| **ConversationMode** | After LUMARA responds | Follow-up continuation style |

### EngagementMode

| Mode | Behavior | Historical References | Best For |
|------|----------|----------------------|----------|
| **DEFAULT** | Answer naturally (60-80% pure, 20-40% with refs) | 20-40% (1-3 refs) | Casual, quick questions |
| **EXPLORE** | Surface patterns + invite examination | 50-70% (2-5 refs) | Active sense-making, temporal queries |
| **INTEGRATE** | Synthesize across domains and time | 80-100% (extensive refs) | Holistic understanding, big picture |

### Voice/Text Commands for Mode Switching

- **To DEFAULT:** "Keep it simple", "Just answer briefly", "Quick response"
- **To EXPLORE:** "Explore this more", "Show me patterns", "Go deeper on this"
- **To INTEGRATE:** "Full synthesis", "Connect across everything", "Big picture"

### EntryClassifier

Types: `factual` (0 examples), `reflective` (2-4 dated), `analytical` (3-8), `conversational` (0), `metaAnalysis` (extensive).

### ConversationMode

Modes: `continue` (natural flow), `ideas` (600 words analysis), `think` (750 words deep analysis), `different` (alternative perspective).

---

## LLM Integration

### Cloud LLM Providers (v3.3.24+)

**Primary:** Groq (Llama 3.3 70B / Mixtral 8x7b fallback). Firebase `proxyGroq` Cloud Function hides API key.

**Fallback:** Google Gemini via Firebase `proxyGemini` Cloud Function.

**Mode-aware temperature:** Explore 0.8, Integrate 0.7, Reflect 0.6.

**Streaming:** Both providers support streaming responses to the UI via `onStreamChunk` callback.

### Chat Phase Classification (v3.3.25)

`ChatPhaseService` auto-classifies LUMARA chat sessions into ATLAS phases using the same `PhaseInferenceService` pipeline as journal entries. Runs after every assistant response. Manual override via bottom sheet.

### Critical Files

| File | Role |
|------|------|
| `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` | Master prompt, word limits, banned phrases |
| `lib/arc/chat/services/lumara_control_state_builder.dart` | Control state JSON (persona, mode, limits) |
| `lib/services/lumara/entry_classifier.dart` | Entry classification, pattern requirements |
| `lib/arc/chat/llm/prompts/lumara_context_builder.dart` | Memory context building |
| `lib/arc/chat/services/enhanced_lumara_api.dart` | Main API: context → prompt → LLM |
| `lib/arc/chat/bloc/lumara_assistant_cubit.dart` | Chat: system prompt building |
| `lib/arc/chat/services/chat_phase_service.dart` | Chat session phase classification |

---

## Implementation Summary

### LUMARA v3.0 Pattern Recognition System

1. **Favorites System:** Library reference only; no learning/adaptation from favorites.
2. **ResponseMode Enhancement:** `minPatternExamples`, `maxPatternExamples`, `requireDates` per persona.
3. **Master Prompt Builder:** Constraints-first approach, banned phrases list (13), pattern recognition guidelines, word allocation (40% validate, 40% patterns, 20% insights).
4. **Unified Prompt System (v3.2):** Consolidated master + user prompt into single unified prompt.

---

## Related Documentation

- [LUMARA Vision](./LUMARA_Vision.md) — Vision document
- [Voice Mode Complete](./VOICE_MODE_COMPLETE.md) — Voice mode implementation
- [Engagement Discipline](./Engagement_Discipline.md) — Engagement mode details
- [Prompt References](./PROMPT_REFERENCES.md) — All LUMARA prompts (includes Master Prompt Architecture §16)
- [CHRONICLE Complete](./CHRONICLE_COMPLETE.md) — CHRONICLE feature spec
- [ARCHITECTURE](./ARCHITECTURE.md) — System-wide architecture

**Consolidated from:** This document merges content from the following docs (now archived): `ARC_AND_LUMARA_OVERVIEW.md`, `NARRATIVE_INTELLIGENCE.md`, `SUBSYSTEMS.md`, `LUMARA_ORCHESTRATOR.md`, `LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md`.

---

**Document Version**: 2.0  
**Last Updated**: February 12, 2026  
**Maintainer**: ARC Development Team

# ARC and LUMARA: Capabilities Overview

**Purpose:** Shareable context for an AI or developer who needs to understand what ARC and LUMARA are and what they can do. Use this as a single block of context when onboarding or handing off.

**Last updated:** February 2026

---

## One-line summary

**ARC** is the journaling and narrative-capture subsystem; **LUMARA** is the orchestrator that uses ARC’s data (plus CHRONICLE, ATLAS, AURORA) to provide a single assistant that can answer like ChatGPT/Claude by default and, when needed, act as a persistent, developmentally aware partner with long-term memory and pattern recognition.

---

## What is ARC?

**ARC** = **Personal Intelligence Reactor**. It is one of four subsystems in the EPI (Evolving Personal Intelligence) app spine.

**Role:** Narrative **capture** and **reflection**.

- **Capture:** Journal entries (text, voice, Arcforms) form a continuous stream of self-documentation (VEIL “Verbalize” — immediate capture).
- **Reflection:** In-journal and in-chat conversations with LUMARA turn entries into reflected narrative (patterns, questions, connections in the moment).
- **Context for LUMARA:** ARC supplies **recent entries** and **base context** so the Master Prompt has current-journal context. It does not decide *when* to use that context; LUMARA does.

**What ARC does *not* do:** It does not run the LLM, choose personas, or route queries. It feeds the pipeline; LUMARA consumes it.

**Implementation:** `lib/arc/` (journaling, chat, reflections); orchestrator-facing logic in `lib/arc/chat/services/arc_subsystem.dart` (wraps `LumaraContextSelector`, provides `recentEntries`, `baseContext`).

---

## What is LUMARA?

**LUMARA** = **Lifelong Unified Memory and Adaptive Response Architecture**. It is the **orchestrator** of narrative intelligence and the layer that actually produces assistant responses.

**Role:** Decide *when* and *how* to use captured narrative and aggregated memory so that responses are phase-aware, context-aware, and developmentally coherent—while still answering normal questions like a general-purpose assistant.

**Core responsibilities:**

1. **Orchestration:** Coordinate four subsystems (ARC, ATLAS, CHRONICLE, AURORA); route user intents; build the prompt so the LLM sees: recent entries (ARC), current phase (ATLAS), longitudinal memory (CHRONICLE), rhythm (AURORA).
2. **Phase-aware response:** Adapt tone, depth, and suggestions to the user’s developmental phase (e.g. Recovery vs Transition vs Breakthrough).
3. **Memory and context:** Two-stage model — (1) context selection (which recent/similar entries to pull in), (2) CHRONICLE (aggregated temporal layers). Enables “How have I changed?” and “What was going on last year?” from synthesized narrative, not only raw search.
4. **Unified conversation:** One assistant. Persona (Companion, Therapist, Strategist, Challenger), engagement mode (Default / Explore / Integrate), response length, and CHRONICLE-backed vs raw-backed modes are all integrated in a single conversation experience.

**Implementation:** `lib/lumara/orchestrator/` (when orchestrator feature is on); main API path: `EnhancedLumaraApi` in `lib/arc/chat/services/enhanced_lumara_api.dart` (builds master prompt, injects subsystem context, calls LLM).

---

## How they work together (pipeline)

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
LLM response
```

- **ARC** feeds the pipeline and supplies the “now” of the narrative.
- **CHRONICLE** (VEIL narrative integration) turns the entry stream into compressed, editable narrative layers (monthly → yearly → multi-year) that LUMARA can query.
- **LUMARA** combines all subsystem outputs so every response can be grounded in both immediate context and long-term biographical understanding.

---

## What LUMARA can do (capabilities)

- **Answer like ChatGPT or Claude:** Default behavior is “act like Claude in normal conversation”: 60–80% pure answers with no historical references; 20–40% with 1–3 brief references when relevant. Technical and general questions get direct answers; memory retrieval can be skipped for speed (`skipHeavyProcessing`).
- **Use long-term context when it matters:** For queries like “Tell me about my week/month,” “What have I been working on?,” “How have I changed?,” “What patterns do you see?,” LUMARA retrieves and uses ARC + CHRONICLE (and optionally Explore/Integrate modes) to give synthesized, dated, narrative-grounded answers.
- **Pattern recognition across time:** Themes, emotional arcs, phase distribution (monthly); theme shifts and phase transitions (yearly); developmental arcs and “how the person evolved” (multi-year). Supports queries such as “What themes keep recurring?” and “Have I dealt with this before?”
- **Phase-aware tone and suggestions:** Responses adapt to the user’s current phase (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough). Same question can get a different tone/depth depending on where they are.
- **Actionable insights when appropriate:** Can give concrete suggestions, next steps, and recommendations—especially when the user asks (“What should I do?”, “Suggest next steps”) or when “Allow Prescriptive Guidance” is on. Personas (e.g. Strategist) provide concrete, actionable steps.
- **Persistent relationship:** Memory is not reset each session. Context selection + CHRONICLE + (where used) MIRA provide continuity so the assistant can “remember” and connect dots across months and years.
- **Narrative authority:** The system proposes synthesis and framing; the user can refine, correct, and own the narrative (collaborative autobiography, not a hidden model of the user).

---

## Supporting subsystems (brief)

- **ATLAS:** Developmental phase intelligence. Infers current phase from recent entries; supplies phase + rationale to LUMARA for phase-aware responses.
- **CHRONICLE:** Longitudinal memory. Hierarchical temporal aggregation (Layer 0 raw → monthly → yearly → multi-year). Implements VEIL Examine/Integrate/Link. Query intents include: specific recall, pattern identification, developmental trajectory, historical parallel, inflection point, temporal query.
- **AURORA:** Rhythm and regulation (e.g. time-of-day, energy). Currently a stub; intended to align responses with daily/energy context.

---

## Key technical anchors

| Item | Location / note |
|------|------------------|
| ARC subsystem wrapper | `lib/arc/chat/services/arc_subsystem.dart` |
| LUMARA API, prompt building | `lib/arc/chat/services/enhanced_lumara_api.dart` |
| Master prompt (behavior, Claude-like, retrieval rules) | `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` |
| Engagement modes (Default / Explore / Integrate) | `lib/models/engagement_discipline.dart` |
| CHRONICLE query routing, synthesis | `lib/chronicle/` (query/, synthesis/, storage/) |
| Context selection for LUMARA | `lib/arc/chat/services/lumara_context_selector.dart` |

---

## Narrative intelligence (concept)

**Narrative intelligence** = the system’s capacity to understand, synthesize, and work *with* a person’s life story over time via:

- Temporal continuity (connecting experiences across time)
- Pattern recognition (themes, phases, recurrences)
- Developmental awareness (where they are in their journey, not just what they said)
- Narrative authority (user owns the story; system proposes, user refines)
- Collaborative autobiography (AI synthesizes and detects patterns; human keeps editorial control)

ARC and LUMARA implement this: ARC is the capture and “fuel”; LUMARA is the orchestrator that makes it usable in conversation while still behaving like a general assistant when that’s what the user needs.

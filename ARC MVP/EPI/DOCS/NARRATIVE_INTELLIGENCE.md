# Narrative Intelligence: ARC and LUMARA

**Purpose:** Define narrative intelligence and describe how ARC and LUMARA implement it within the EPI (Evolving Personal Intelligence) system.

**Last updated:** February 2026

---

## What Is Narrative Intelligence?

**Narrative intelligence** is the capacity of a system to understand, synthesize, and work *with* a person’s life story over time—not by building a hidden model *of* them, but by co-creating a shared biographical understanding. It combines:

1. **Temporal continuity** — Connecting experiences across days, months, and years so that “who you are” and “who you’re becoming” are visible.
2. **Pattern recognition** — Identifying themes, phases, and recurrences (e.g. career dissatisfaction, creative cycles, relationship patterns) from ongoing self-documentation.
3. **Developmental awareness** — Knowing *where* someone is in their psychological journey (recovery, transition, breakthrough, discovery, expansion, consolidation), not just *what* they said.
4. **Narrative authority** — Treating the human as the authority on their own story. The system proposes synthesis and framing; the user refines, corrects, and owns the narrative.
5. **Collaborative autobiography** — AI handles synthesis and pattern detection; the human retains editorial control. Intelligence that works *with* you, not by secretly modeling you.

In this architecture, narrative intelligence is implemented through the **VEIL cycle** (Verbalize → Examine → Integrate → Link): immediate capture, pattern recognition across recent events, synthesis into coherent narrative, and cross-temporal biographical linking. CHRONICLE is the automated implementation of that cycle. The result is not “AI memory” in the usual sense—it is **collaborative biographical intelligence** across unbounded time, with bounded computational cost and user-held narrative authority.

---

## ARC: Narrative Capture & Reflection

**ARC** (the **Personal Intelligence Reactor**) is the subsystem responsible for **narrative capture and reflection**. It is the primary source of the raw material that narrative intelligence operates on.

### Role in Narrative Intelligence

- **Capture:** Journal entries (text, voice, Arcforms) create a continuous stream of self-documentation. This is the **Verbalize** stage of VEIL: immediate capture of experience.
- **Reflection:** In-journal and in-chat conversations with LUMARA turn entries into reflected narrative—surfacing patterns, questions, and connections in the moment.
- **Context for LUMARA:** ARC supplies recent entries and entry contents so the Master Prompt has current-journal context. When the LUMARA orchestrator is used, the **ARC subsystem** wraps `LumaraContextSelector` and provides `recentEntries` and `baseContext` for prompts.

### Why It Matters

Without consistent self-documentation, no system can maintain developmental intelligence. ARC is the “fuel” that powers LUMARA’s understanding: daily (or regular) journaling produces structured temporal data that CHRONICLE aggregates and that ATLAS uses for phase detection. ARC’s output is the Layer 0 (raw) input to the rest of the narrative intelligence pipeline.

### Technical Placement

- **Subsystem:** One of the four in the LUMARA spine (ARC, ATLAS, CHRONICLE, AURORA).
- **Implementation:** `lib/arc/` (journaling, chat, reflections); orchestrator-facing logic in `lib/arc/chat/services/arc_subsystem.dart`, wrapping context selection and reflection settings.

---

## LUMARA: Orchestrator of Narrative Intelligence

**LUMARA** (Lifelong Unified Memory and Adaptive Response Architecture) is ARC’s **adaptive intelligence layer**. It is the orchestrator that makes narrative intelligence usable: it decides *when* and *how* to use captured narrative and aggregated memory so that responses are phase-aware, context-aware, and developmentally coherent.

### Role in Narrative Intelligence

- **Orchestration:** LUMARA coordinates the four subsystems (ARC, ATLAS, CHRONICLE, AURORA). It routes user intents, gathers context from each subsystem, and builds the prompt so that the LLM sees a coherent picture: recent entries (ARC), current phase (ATLAS), longitudinal memory (CHRONICLE), and rhythm/regulation (AURORA).
- **Phase-aware response:** LUMARA adapts tone, depth, and suggestions to the user’s developmental phase (e.g. Recovery vs Transition vs Breakthrough), so the same question gets a response that fits *where they are* in their story.
- **Memory and context:** LUMARA uses a two-stage memory model: (1) context selection (which recent/similar entries to pull in) and (2) CHRONICLE (aggregated temporal layers). That combination keeps context bounded while allowing “How have I changed?” or “What was going on last year?” to be answered from synthesized narrative, not only raw search.
- **Unified prompt system:** Persona, engagement mode (Reflect/Explore/Integrate), response length, and CHRONICLE-backed vs raw-backed modes are all integrated so that narrative intelligence is expressed in a single, consistent conversation experience.

### Why It Matters

LUMARA inverts the usual AI-assistant design: instead of adding memory to a generic model, it builds understanding from continuous self-documentation (ARC) and longitudinal synthesis (CHRONICLE). The result is an assistant that can speak to who you’re *becoming* over time, detect when you’re stuck, connect dots across months, and maintain continuity through long processes—feeling less like a stateless chatbot and more like a persistent, developmentally aware partner.

### Technical Placement

- **Orchestrator:** `lib/lumara/orchestrator/` (when `FeatureFlags.useOrchestrator` is enabled).
- **Subsystems:** ARC, ATLAS, CHRONICLE, AURORA; each implements the `Subsystem` interface; LUMARA discovers them, calls `canHandle` / `query`, and aggregates results for the Master Prompt.
- **API:** Firebase-backed; `EnhancedLumaraApi` builds the master prompt and injects subsystem context (ARC recent entries, ATLAS phase, CHRONICLE aggregations, AURORA rhythm).

---

## How They Work Together

```
User journals (ARC)
       ↓
Layer 0 raw entries → CHRONICLE synthesis (VEIL: Examine → Integrate → Link)
       ↓
LUMARA Orchestrator
  ├─ ARC: recent entries + base context
  ├─ ATLAS: current phase + rationale
  ├─ CHRONICLE: temporal aggregations (monthly/yearly/multi-year)
  └─ AURORA: rhythm/regulation (stub for now)
       ↓
Master Prompt (phase-aware, CHRONICLE-backed or raw-backed)
       ↓
LLM response that reflects narrative intelligence
```

- **ARC** feeds the pipeline and supplies the “now” of the narrative.
- **CHRONICLE** (driven by the VEIL narrative integration cycle) turns that stream into compressed, editable narrative layers that LUMARA can query.
- **LUMARA** ties ARC, ATLAS, CHRONICLE, and AURORA together so that every response can be grounded in both immediate context and long-term biographical understanding, with the user retaining narrative authority through editing and refinement.

---

## Summary

| Concept | Meaning |
|--------|----------|
| **Narrative intelligence** | System capacity to understand and co-create a person’s life story over time: temporal continuity, pattern recognition, developmental awareness, and user-held narrative authority, implemented via the VEIL cycle and CHRONICLE. |
| **ARC** | Narrative capture and reflection; the journaling and reflection subsystem that produces the raw stream (Layer 0) and supplies recent context to LUMARA. |
| **LUMARA** | Orchestrator of narrative intelligence; coordinates ARC, ATLAS, CHRONICLE, and AURORA so that responses are phase-aware, context-aware, and grounded in both recent and longitudinal narrative. |

Together, ARC and LUMARA implement narrative intelligence as **collaborative autobiography**: the AI handles synthesis and pattern detection, the human retains narrative authority, and both contribute to a shared, developmentally coherent story over time.

# EPI & LUMARA — Overview

**Purpose:** Quick orientation for users and agents reading this repo. What the app is, what LUMARA is, and where to go next.

---

## What is EPI?

**EPI** = **Evolving Personal Intelligence**. It is the app: a journaling and narrative-capture platform with an AI assistant that has long-term memory and developmental awareness. The codebase lives under `ARC_MVP/EPI/` (Flutter app, `lib/`, `DOCS/`).

---

## What is LUMARA?

**LUMARA** = **Lifelong Unified Memory and Adaptive Response Architecture**.

LUMARA is **not** the journal. It is the **orchestrator** that:

1. **Coordinates four subsystems** — ARC (recent journal + capture), ATLAS (developmental phase), CHRONICLE (longitudinal memory/synthesis), AURORA (rhythm/regulation).
2. **Routes user intents** — Parses what the user is asking (quick answer, pattern exploration, “how have I changed?”, etc.) and decides which subsystems to query.
3. **Builds the prompt** — Aggregates recent entries (ARC), current phase (ATLAS), synthesized narrative across time (CHRONICLE), and optional rhythm context (AURORA) into one context map for the LLM.
4. **Produces the assistant** — One unified chat/reflection experience: it can answer like ChatGPT/Claude by default, or act as a phase-aware, memory-backed partner when the user wants depth.

So: **ARC** = where you write and what’s recent. **LUMARA** = the layer that uses that (plus CHRONICLE, ATLAS, AURORA) to power the assistant.

---

## Pipeline (simplified)

```
User journals (ARC) → Raw entries → CHRONICLE synthesis (VEIL: Examine → Integrate → Link)
                                        ↓
LUMARA Orchestrator ← ARC, ATLAS, CHRONICLE, AURORA
        ↓
Master Prompt (phase-aware, CHRONICLE-backed or raw-backed)
        ↓
LLM (Groq primary, Gemini fallback) → Response to user
```

**CHRONICLE / VEIL cycle:** Capture happens in **ARC** (VEIL **Verbalize**). **CHRONICLE** then runs the rest of the cycle: **Examine** (pattern recognition), **Integrate** (synthesis into narrative layers), **Link** (cross-temporal biographical linking). Those temporal layers (monthly, yearly, multi-year) are what LUMARA reads when it queries CHRONICLE. So: raw entries flow into CHRONICLE; LUMARA uses both recent raw context (ARC) and pre-synthesized narrative (CHRONICLE) to build the prompt.

---

## Execution chain (Firebase → Cloudflare)

- **LLM inference:** The app calls **Firebase Cloud Functions** (`proxyGroq` primary, `proxyGemini` fallback). No Cloudflare in the main chat path; prompts are scrubbed (PRISM) client-side, then sent to Firebase, which forwards to Groq/Gemini.
- **Plugins (e.g. web search):** When LUMARA uses external tools (SwarmSpace), the flow is **app → Firebase** (`swarmspaceRouter` callable) **→ Cloudflare Workers** (plugin execution: Brave, Tavily, etc.). Auth is via Firebase ID token; the same Firebase project hosts both LLM proxies and the SwarmSpace router that delegates to Cloudflare.

So: **one Firebase entry point** for LUMARA (auth + callables); **Cloudflare** is used only for SwarmSpace plugin execution, not for the core LUMARA LLM call.

---

## Aurora, Rivet, Prism, ECHO (clarified)

| Term | Role in EPI / LUMARA |
|------|----------------------|
| **AURORA** | One of the four LUMARA subsystems: **rhythm / regulation** (usage patterns, optimal timing). In the orchestrator it is currently a **stub** (empty aggregations). Circadian/rhythm logic lives in **CircadianProfileService** and **AuroraCard**. |
| **Rivet** | Decision and state layer for timeline and chat. **RivetService** / **RivetEvent** drive timeline and feed state; **RivetDecisionAnalyzer** in chat can produce decision triggers. Not a LUMARA subsystem. |
| **Prism** | **Content distillation and privacy.** (1) **PrismAdapter** extracts key points/excerpts from entries for chat and journal UI. (2) Before any payload is sent to the cloud, **PRISM scrub** (in `gemini_send` / `lumaraSend`) removes or masks PII. So: Prism = key-point extraction + outbound PII protection for LUMARA. |
| **ECHO** | **On-device / voice pipeline**, separate from LUMARA cloud. Phase-aware prompts and on-device LLM (e.g. Qwen/Gemma via **QwenAdapter**). Used for voice mode and ECHO demos; does not replace LUMARA—LUMARA remains the cloud orchestrator (Groq/Gemini via Firebase). |

---

## Subsystems (at a glance)

| Subsystem   | Role                               | Main output for LUMARA                    |
|------------|-------------------------------------|-------------------------------------------|
| **ARC**    | Capture + recent journal context   | Recent entries, entry contents, base context |
| **ATLAS**  | Current developmental phase        | Phase name, rationale, description        |
| **CHRONICLE** | Longitudinal memory & synthesis | Aggregated narrative (monthly/yearly/multi-year) |
| **AURORA** | Rhythm / regulation                | Usage patterns, optimal timing (stub)     |

All four implement the same subsystem interface; the **LUMARA Orchestrator** queries them in parallel and aggregates results into the prompt.

---

## Key concepts

- **Narrative intelligence** — Understanding and synthesizing a person’s story over time (themes, phases, “how have I changed?”) while treating the user as the authority on their own story.
- **VEIL cycle (and how CHRONICLE uses it)** — **Verbalize** = capture in ARC (journal entries). **Examine** → **Integrate** → **Link** = CHRONICLE’s job: pattern recognition, synthesis into narrative layers, and cross-temporal linking. LUMARA then consumes both raw recent context (ARC) and CHRONICLE’s aggregated layers (monthly/yearly/multi-year) so the assistant can answer from synthesized narrative as well as from recent entries.
- **Two-stage memory** — (1) Context selection: which recent/similar entries to pull in. (2) CHRONICLE: pre-synthesized temporal layers. LUMARA uses both.
- **Phase-aware response** — Tone and depth adapt to the user’s current phase (e.g. Recovery, Discovery, Breakthrough) via ATLAS.

---

## Where to read more

| Topic              | Document |
|--------------------|----------|
| **LUMARA in depth** (orchestrator, subsystems, prompts, LLM) | [LUMARA_COMPLETE.md](LUMARA_COMPLETE.md) |
| **System architecture** (5 modules, data flow)               | [ARCHITECTURE.md](ARCHITECTURE.md)       |
| **Firebase → Cloudflare** (SwarmSpace API, plugins)          | [Swarmspace_Overview.md](Swarmspace_Overview.md) |
| **Docs index and when to read what**                         | [README.md](README.md)                    |
| **Context for agents / onboarding**                          | [claude.md](claude.md)                    |

---

*This overview is part of `DOCS/`. For version and change history, see [CHANGELOG.md](CHANGELOG.md) and [CONFIGURATION_MANAGEMENT.md](CONFIGURATION_MANAGEMENT.md).*

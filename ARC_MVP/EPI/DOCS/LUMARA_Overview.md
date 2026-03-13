# LUMARA — Overview

**Purpose:** Quick orientation for users and agents reading this repo. What the app is, how LUMARA works, and where to go next. Use this as context for Claude or other agents.

---

## What is LUMARA?

**LUMARA** is the **app name**: a journaling and narrative-capture platform with an AI assistant that has long-term memory and developmental awareness. The product is **narrative intelligence** — understanding and synthesizing a person’s story over time (themes, phases, “how have I changed?”) while treating the user as the authority on their own story.

- **Codebase:** Flutter app under `ARC_MVP/EPI/` (package `my_app`). `lib/` = Dart source, `DOCS/` = app docs.
- **Firebase project:** `arc-epi` (auth, Firestore, Cloud Functions).
- **Name note:** “EPI” is no longer part of the product name; the app is **LUMARA**, and the domain is **narrative intelligence**.

---

## LUMARA as orchestrator

**LUMARA** is also the **orchestrator layer** inside the app. It is not “the journal” — it is the system that:

1. **Coordinates four subsystems** — ARC (recent journal + capture), ATLAS (developmental phase), CHRONICLE (longitudinal memory/synthesis), AURORA (rhythm/regulation).
2. **Routes user intents** — Parses what the user is asking (quick answer, pattern exploration, research, writing, reflection) and decides which subsystems to query or which agent to run (Research, Writing, or reflection path).
3. **Builds the prompt** — Aggregates recent entries (ARC), current phase (ATLAS), synthesized narrative across time (CHRONICLE), and optional rhythm context (AURORA) into one context map for the LLM.
4. **Produces the assistant** — One unified chat/reflection experience: it can answer in a general way by default, or act as a phase-aware, memory-backed partner when the user wants depth.

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

**CHRONICLE / VEIL cycle:** Capture happens in **ARC** (VEIL **Verbalize**). **CHRONICLE** then runs the rest of the cycle: **Examine** (pattern recognition), **Integrate** (synthesis into narrative layers), **Link** (cross-temporal biographical linking). Those temporal layers (monthly, yearly, multi-year) are what LUMARA reads when it queries CHRONICLE. LUMARA uses both recent raw context (ARC) and pre-synthesized narrative (CHRONICLE) to build the prompt.

---

## Execution chain (Firebase → Cloudflare)

- **LLM inference:** The app calls **Firebase Cloud Functions** (`proxyGroq` primary, `proxyGemini` fallback). No Cloudflare in the main chat path; prompts are scrubbed (PRISM) client-side, then sent to Firebase, which forwards to Groq/Gemini.
- **Plugins (e.g. web search):** When LUMARA uses external tools (SwarmSpace), the flow is **app → Firebase** (`swarmspaceRouter` callable) **→ Cloudflare Workers** (plugin execution: Brave, Tavily, etc.). Auth is via Firebase ID token; the same Firebase project hosts both LLM proxies and the SwarmSpace router that delegates to Cloudflare.

So: **one Firebase entry point** for LUMARA (auth + callables); **Cloudflare** is used only for SwarmSpace plugin execution, not for the core LUMARA LLM call.

---

## Subsystems (at a glance)

| Subsystem   | Role                               | Main output for LUMARA                    |
|------------|-------------------------------------|-------------------------------------------|
| **ARC**    | Capture + recent journal context   | Recent entries, entry contents, base context |
| **ATLAS**  | Current developmental phase        | Phase name, rationale, description        |
| **CHRONICLE** | Longitudinal memory & synthesis | Aggregated narrative (monthly/yearly/multi-year) |
| **AURORA** | Rhythm / regulation                | Usage patterns, optimal timing (stub)     |

All four implement the same subsystem interface (`lib/lumara/subsystems/subsystem.dart`); the **LUMARA Orchestrator** queries them and aggregates results into the prompt. In code, **ChronicleSubsystem** and **WritingSubsystem** (and related wiring) live under `lib/lumara/subsystems/`.

---

## Aurora, Rivet, Prism, ECHO (clarified)

| Term | Role in LUMARA |
|------|----------------|
| **AURORA** | One of the four LUMARA subsystems: **rhythm / regulation** (usage patterns, optimal timing). In the orchestrator it is currently a **stub** (empty aggregations). Circadian/rhythm logic lives in **CircadianProfileService** and **AuroraCard**. |
| **Rivet** | Decision and state layer for timeline and chat. **RivetService** / **RivetEvent** drive timeline and feed state; **RivetDecisionAnalyzer** in chat can produce decision triggers. Not a LUMARA subsystem. |
| **Prism** | **Content distillation and privacy.** (1) **PrismAdapter** extracts key points/excerpts from entries for chat and journal UI. (2) Before any payload is sent to the cloud, **PRISM scrub** (in `gemini_send` / `lumaraSend`) removes or masks PII. So: Prism = key-point extraction + outbound PII protection for LUMARA. |
| **ECHO** | **On-device / voice pipeline**, separate from LUMARA cloud. Phase-aware prompts and on-device LLM (e.g. Qwen/Gemma via **QwenAdapter**). Used for voice mode and ECHO demos; does not replace LUMARA—LUMARA remains the cloud orchestrator (Groq/Gemini via Firebase). |

---

## Codebase layout (main lib/ domains)

| Path | Description |
|------|-------------|
| **`lib/arc/`** | Chat (LUMARA UI, cubit, prompts), unified feed, outputs, timeline, voice, journal capture, internal (e.g. Prism adapter). |
| **`lib/lumara/`** | Orchestrator, intent classifier, subsystems; **`lumara/agents/`** = Research, Writing, Vision, Agents UI (screens, services, widgets). |
| **`lib/chronicle/`** | Dual chronicle, storage, synthesis, scheduling, embeddings, retrieval, VEIL integration. |
| **`lib/prism/`** | Atlas, pipelines, extractors, MCP, vital, repositories. |
| **`lib/echo/`** | Echo service, prompts, providers, response (e.g. LumaraAssistantCubit echo path). |
| **`lib/mira/`** | Store (MCP, ArcX), ingest, retrieval, reasoning, veil. |
| **`lib/core/`** | Feature flags, services (media pick, audio, etc.), constants, LLM, Mira. |
| **`lib/services/`** | SwarmSpace (PrismService, plugin_activity_log_service, swarmspace_client), Lumara, Sentinel, etc. |
| **`lib/shared/`** | UI (home, settings, onboarding), widgets, tab bar, app colors, text styles. |

---

## App shell and tabs (unified feed)

- **Entry:** `lib/main.dart` → `bootstrap()` → `App()` (`lib/app/app.dart`).
- **Feature flag:** `lib/core/feature_flags.dart` — `FeatureFlags.USE_UNIFIED_FEED = true` (current default).
- **Home:** `lib/shared/ui/home/home_view.dart` — `HomeCubit` drives `selectedIndex`; tabs:

| Index | Tab label | Widget |
|-------|------------|--------|
| 0 | LUMARA | `UnifiedFeedScreen` |
| 1 | Agents | `AgentsScreen` |
| 2 | Outputs | `OutputsTabScreen` |
| 3 | Settings | `SettingsView` |

Legacy mode (when `USE_UNIFIED_FEED` is false): LUMARA | Conversations (no Agents/Outputs/Settings as separate tabs).

---

## Chat orchestration and agents

- **LumaraChatOrchestrator** (`lib/lumara/orchestrator/lumara_chat_orchestrator.dart`): classifies intent via **ChatIntentClassifier**, then routes to Research agent, Writing agent, or **reflection path** (normal LUMARA streaming in cubit).
- **Agents (Agents tab):** Research (`ResearchScreen`, `ResearchAgent`, `research_pipeline.dart`), Writing (`WritingAgent`, writing screens/prompts), Vision/OCR (`vision_ocr_screen.dart`, `document_parser.dart`), Plugin Activity, Plugin Catalog.
- **Reflection path:** `LumaraAssistantCubit`, `enhanced_lumara_api.dart`, control state built from ARC/CHRONICLE/ATLAS; LLM via Firebase (`proxyGroq` / `proxyGemini`).
- **SwarmSpace:** Client in `lib/services/swarmspace/`; Firebase callable `swarmspaceRouter` in `functions/src/swarmspaceRouter.ts`; plugins (e.g. brave-search, vision-ocr, tavily-search) run on Cloudflare or Cloud Functions.

---

## Key concepts

- **Narrative intelligence** — The product domain: understanding and synthesizing a person’s story over time (themes, phases, “how have I changed?”) while treating the user as the authority on their own story.
- **VEIL cycle (and how CHRONICLE uses it)** — **Verbalize** = capture in ARC (journal entries). **Examine** → **Integrate** → **Link** = CHRONICLE’s job: pattern recognition, synthesis into narrative layers, and cross-temporal linking. LUMARA then consumes both raw recent context (ARC) and CHRONICLE’s aggregated layers (monthly/yearly/multi-year).
- **Two-stage memory** — (1) Context selection: which recent/similar entries to pull in. (2) CHRONICLE: pre-synthesized temporal layers. LUMARA uses both.
- **Phase-aware response** — Tone and depth adapt to the user’s current phase (e.g. Recovery, Discovery, Breakthrough) via ATLAS.

---

## Where to read more

| Topic | Document |
|-------|----------|
| **LUMARA in depth** (orchestrator, subsystems, prompts, LLM) | [LUMARA_COMPLETE.md](LUMARA_COMPLETE.md) |
| **System architecture** (5 modules, data flow) | [ARCHITECTURE.md](ARCHITECTURE.md) |
| **Firebase → Cloudflare** (SwarmSpace API, plugins) | [Swarmspace_Overview.md](Swarmspace_Overview.md) |
| **Docs index and when to read what** | [README.md](README.md) |
| **Context for agents / onboarding** | [claude.md](claude.md) |
| **Phase 5 / codebase grounding** (paths, widgets, flows) | `DOCS/CODEBASE_OVERVIEW_FOR_PHASE5.md` at repo root |

---

*This overview is part of `DOCS/`. For version and change history, see [CHANGELOG.md](CHANGELOG.md) and [CONFIGURATION_MANAGEMENT.md](CONFIGURATION_MANAGEMENT.md).*

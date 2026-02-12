# LUMARA Orchestrator Roadmap (Weeks 1–6)

**Purpose:** Week-by-week plan for the LUMARA Enterprise Architecture: four-subsystem spine (ARC, ATLAS, CHRONICLE, AURORA) coordinated by the LUMARA Orchestrator. This is separate from the CHRONICLE internal build (synthesis, scheduling) in `DOCS/archive/CHRONICLE_IMPLEMENTATION_PLAN.md`.

**Last updated:** February 2026

---

## Status overview

| Week | Theme | Status | Notes |
|------|--------|--------|--------|
| 1 | Foundation | ✅ Done | Subsystem interface, models, ChronicleSubsystem |
| 2 | Orchestrator | ✅ Done | CommandParser, ResultAggregator, LumaraOrchestrator |
| 3 | Integration | ✅ Done | `useOrchestrator` flag, wire in EnhancedLumaraApi |
| 4 | Harden & document | ✅ Done | Test (ARC data shape), CHRONICLE_CONTEXT_FOR_CLAUDE.md updated |
| 5 | ARC subsystem | ✅ Done | ArcSubsystem + orchestrator; API uses ARC for recentEntries/baseContext when present |
| 6 | Multi-subsystem & next | ✅ Done | ATLAS/AURORA subsystems; inject into master prompt; roadmap updated |

---

## Week 1: Foundation ✅

- Add `Subsystem` interface (`lib/lumara/subsystems/subsystem.dart`).
- Add models: `IntentType`, `CommandIntent`, `SubsystemResult` (`lib/lumara/models/`).
- Implement `ChronicleSubsystem` wrapping `ChronicleQueryRouter` + `ChronicleContextBuilder`.
- Unit tests for ChronicleSubsystem.

**Deliverables:** `lib/lumara/subsystems/`, `lib/lumara/models/`, `test/lumara/subsystems/chronicle_subsystem_test.dart`.

---

## Week 2: Orchestrator ✅

- Add `CommandParser` (string → `CommandIntent`).
- Add `OrchestrationResult` and `ResultAggregator`.
- Add `LumaraOrchestrator`: parse → route to subsystems (parallel) → aggregate.
- Unit tests for parser, aggregator, orchestrator.

**Deliverables:** `lib/lumara/orchestrator/`, `test/lumara/orchestrator/`.

---

## Week 3: Integration ✅

- Add `FeatureFlags.useOrchestrator` (default `false`) in `lib/state/feature_flags.dart`.
- In `EnhancedLumaraApi.generatePromptedReflectionV23`, when flag is true (and CHRONICLE initialized, non-voice, `userId` set): call `LumaraOrchestrator.execute()`, derive `chronicleContext` and `chronicleLayerNames` from `OrchestrationResult`, keep legacy `LumaraContextSelector` for recent entries.
- Fallback: when flag false or conditions not met, use legacy query router + context builder.

**Deliverables:** Feature flag, orchestrator path in `lib/arc/chat/services/enhanced_lumara_api.dart`.

---

## Week 4: Harden & document ✅

- **Tests:** Optional test for orchestrator path in EnhancedLumaraApi (e.g. with `useOrchestrator == true` and mocked or no-op CHRONICLE).
- **Docs:** Update `CHRONICLE_CONTEXT_FOR_CLAUDE.md`: mark checklist item 4 (Subsystem + orchestrator) done; update §6 to state that orchestrator and ChronicleSubsystem exist and integration is behind `FeatureFlags.useOrchestrator`.
- **Optional:** Flip `useOrchestrator` to `true` by default after validation, or expose in settings for beta.

---

## Week 5: ARC subsystem ✅

- **Goal:** Move “recent entries” (journal context) behind the orchestrator so one code path uses only orchestration.
- Define an **ARC subsystem** (or “ARC context” subsystem) that returns recent journal entries (and optionally chat summary) for the current request. Implementation can delegate to existing `LumaraContextSelector` (or a thin wrapper).
- Register ARC subsystem with `LumaraOrchestrator`.
- In `EnhancedLumaraApi`, when `useOrchestrator` is true: get both CHRONICLE and ARC from `OrchestrationResult` (e.g. `toContextMap()` or dedicated getters); build `recentEntries` / `baseContext` from ARC result instead of calling `LumaraContextSelector` directly.
- **Outcome:** Single orchestration path for journal reflection context (CHRONICLE + ARC); legacy path remains for flag-off and voice.

---

## Week 6: Multi-subsystem & next ✅

- **ATLAS:** Added `AtlasSubsystem` (`lib/arc/chat/services/atlas_subsystem.dart`) wrapping `UserPhaseService`: returns current phase, description, and rationale in `data['aggregations']`. Registered with orchestrator; context injected into master prompt.
- **AURORA:** Added `AuroraSubsystem` stub (`lib/arc/chat/services/aurora_subsystem.dart`) for rhythm/regulation; returns empty aggregations until full implementation. Registered with orchestrator; injection path ready.
- **Prompt building:** In `EnhancedLumaraApi.generatePromptedReflectionV23`, after building `modeSpecificInstructions`, ATLAS and AURORA context from `orchResult.toContextMap()` are prepended as a "SUBSYSTEM CONTEXT" block (when present) so the master prompt receives full enterprise context.
- **Roadmap:** Next steps documented below.

**Deliverables:** `atlas_subsystem.dart`, `aurora_subsystem.dart`; registration in `_ensureOrchestrator()`; injection in `enhanced_lumara_api.dart` (enterprise block prepended to `modeSpecificInstructions`).

---

## Next steps (post–Week 6)

- **Full AURORA:** Implement rhythm/regulation summary (usage patterns, optimal timing, VEIL integration) and populate `aggregations` in `AuroraSubsystem.query()`.
- **Polymeta→CHRONICLE renames:** Complete remaining checklist items in `CHRONICLE_CONTEXT_FOR_CLAUDE.md` (UI strings, docs, any leftover references).
- **MemoryModeService vs CHRONICLE:** Clarify boundaries and document in CHRONICLE context doc; ensure no duplicate longitudinal memory paths.
- **Feature flag:** Consider flipping `FeatureFlags.useOrchestrator` to `true` by default after validation, or exposing in settings for beta.
- **Tests:** Optional integration test with `useOrchestrator == true` and mocked subsystems to assert ATLAS/AURORA strings appear in the prompt.

---

## Relationship to other docs

- **CHRONICLE_CONTEXT_FOR_CLAUDE.md:** Polymeta→CHRONICLE renames, implementation checklist, relationship of MemoryModeService to CHRONICLE. Orchestrator work satisfies “Add LUMARA orchestrator/subsystem router” in that checklist.
- **MASTER_PROMPT_CONTEXT.md:** Describes how the master prompt and control state work; orchestrator feeds context into the same prompt building flow.
- **CHRONICLE_IMPLEMENTATION_PLAN.md** (archive): CHRONICLE-internal phases (synthesis engine, query router, scheduling, PRISM). That plan is largely reflected in existing `lib/chronicle/`; this roadmap is about the **LUMARA** orchestrator and four-subsystem spine on top of it.

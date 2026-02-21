# LUMARA Orchestrator

**Purpose:** Overview of the LUMARA Orchestrator: how it coordinates the four-subsystem spine (ARC, ATLAS, CHRONICLE, AURORA) and feeds aggregated context into the Master Prompt.

**Related:** [LUMARA_ORCHESTRATOR_ROADMAP.md](LUMARA_ORCHESTRATOR_ROADMAP.md) (week-by-week plan); [SUBSYSTEMS.md](SUBSYSTEMS.md) (subsystem roles); [LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md](LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md) (canonical file/doc summary).

**Last updated:** February 2026

---

## 1. Role of the Orchestrator

- **Coordinates data, does not replace the Master Prompt.** The orchestrator parses the user query into an intent, queries all subsystems that can handle that intent (in parallel), and aggregates results. The Master Prompt continues to control LLM behavior; it receives pre-aggregated context when the orchestrator path is used.
- **Single entry point for journal reflection context.** When `FeatureFlags.useOrchestrator` is true and conditions are met, `EnhancedLumaraApi` calls `LumaraOrchestrator.execute()` instead of calling CHRONICLE and context selection directly. One code path builds the prompt from `OrchestrationResult`.
- **Gradual migration.** A feature flag allows A/B and rollout; legacy path remains when the flag is false or for voice (which skips heavy processing).

---

## 2. Flow

1. **Parse:** `CommandParser` turns the user query string into a `CommandIntent` (intent type, raw query, optional userId/entryId).
2. **Route:** The orchestrator asks each registered subsystem whether it `canHandle(intent)`. All that return true are queried **in parallel**.
3. **Aggregate:** `ResultAggregator` collects `SubsystemResult`s into an `OrchestrationResult` with a single intent and a list of results.
4. **Consume:** `EnhancedLumaraApi` uses `OrchestrationResult.toContextMap()` to get string context per subsystem (e.g. CHRONICLE, ARC, ATLAS, AURORA) and `getSubsystemData('ARC')` for structured data (recentEntries, entryContents). It builds the prompt from this plus control state.

---

## 3. Key Types and Locations

| Item | Location |
|------|----------|
| **Subsystem interface** | `lib/lumara/subsystems/subsystem.dart` |
| **CommandParser** | `lib/lumara/orchestrator/command_parser.dart` |
| **LumaraOrchestrator** | `lib/lumara/orchestrator/lumara_orchestrator.dart` |
| **ResultAggregator / OrchestrationResult** | `lib/lumara/orchestrator/result_aggregator.dart`, `lib/lumara/models/orchestration_result.dart` |
| **Models** | `lib/lumara/models/` (IntentType, CommandIntent, SubsystemResult, OrchestrationResult) |
| **Integration** | `lib/arc/chat/services/enhanced_lumara_api.dart` – `_ensureOrchestrator()`, orchestrator path in `generatePromptedReflectionV23` |
| **Feature flag** | `lib/state/feature_flags.dart` – `FeatureFlags.useOrchestrator` |

---

## 4. Context Map and Prompt Injection

- **toContextMap()** returns `Map<String, String>`: subsystem name → string content for the prompt. CHRONICLE and ATLAS/AURORA use the `aggregations` key in their `SubsystemResult.data`; ARC uses structured `recentEntries` / `entryContents` (not surfaced as a single string in the context map for prompt building; EnhancedLumaraApi reads them via `getSubsystemData('ARC')`).
- **CHRONICLE:** Full longitudinal context string and optional layer names; sets prompt mode to `chronicleBacked` when present.
- **ARC:** Recent journal entries and entry contents; used for `recentEntries` and `baseContext` in `buildMasterUserMessage`.
- **ATLAS / AURORA:** Phase summary and rhythm/regulation summary (AURORA currently stub). Injected as a **SUBSYSTEM CONTEXT** block prepended to `modeSpecificInstructions` so the Master Prompt receives ATLAS and AURORA context when present.

---

## 5. When the Orchestrator Runs

- **Journal reflection (text),** with `FeatureFlags.useOrchestrator == true`, CHRONICLE initialized, and `userId` set: orchestrator runs; CHRONICLE, ARC, ATLAS, and AURORA are queried; prompt is built from `OrchestrationResult`.
- **Voice or flag false:** Legacy path (direct context selector and, when applicable, query router + context builder). No orchestrator call.

---

## 6. Tests

- **Orchestrator:** `test/lumara/orchestrator/` – CommandParser, ResultAggregator, LumaraOrchestrator (routing, multi-subsystem, ARC data shape, error handling).
- **Subsystems:** `test/lumara/subsystems/chronicle_subsystem_test.dart` – ChronicleSubsystem name, canHandle, query behavior.

See [LUMARA_ORCHESTRATOR_ROADMAP.md](LUMARA_ORCHESTRATOR_ROADMAP.md) for week-by-week deliverables and next steps.

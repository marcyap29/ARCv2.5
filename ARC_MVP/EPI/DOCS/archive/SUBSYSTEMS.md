# LUMARA Subsystems

**Purpose:** Reference for the four subsystems in the LUMARA Enterprise Architecture (ARC, ATLAS, CHRONICLE, AURORA): what each provides, where it lives, and how the orchestrator uses it.

**Related:** [LUMARA_ORCHESTRATOR.md](LUMARA_ORCHESTRATOR.md); [LUMARA_ORCHESTRATOR_ROADMAP.md](LUMARA_ORCHESTRATOR_ROADMAP.md).

**Last updated:** February 2026

---

## 1. Subsystem Interface

All subsystems implement the interface in `lib/lumara/subsystems/subsystem.dart`:

- **name** – Subsystem identifier (e.g. `'CHRONICLE'`, `'ARC'`).
- **canHandle(CommandIntent)** – Whether this subsystem should be queried for the given intent.
- **query(CommandIntent)** – Returns `Future<SubsystemResult>` (data map, optional error).

The orchestrator discovers subsystems via registration; it calls `canHandle` then `query` in parallel for all that return true.

---

## 2. CHRONICLE (Longitudinal Memory)

**Role:** Aggregated longitudinal context (synthesis across time). Replaces direct use of “Polymeta” as the named memory subsystem in the spine; the existing `lib/chronicle/` package is wrapped, not replaced.

**Location:** `lib/lumara/subsystems/chronicle_subsystem.dart`

**Wraps:** `ChronicleQueryRouter`, `ChronicleContextBuilder` (from `lib/chronicle/query/`).

**CanHandle:** temporalQuery, patternAnalysis, developmentalArc, historicalParallel, comparison, decisionSupport, specificRecall (not usagePatterns, optimalTiming, recentContext).

**Output:** `SubsystemResult.data`: `context` (string), `layers` (list of layer names). For the prompt, `toContextMap()` uses `aggregations`-style content. EnhancedLumaraApi uses this as `chronicleContext` and `chronicleLayerNames`; prompt mode becomes `chronicleBacked` when present.

---

## 3. ARC (Capture / Recent Context)

**Role:** Recent journal entries and entry contents for the current request. Supplies “recent entries” and “base context” so the Master Prompt has current-journal context without the API calling `LumaraContextSelector` directly on the orchestrator path.

**Location:** `lib/arc/chat/services/arc_subsystem.dart`

**Wraps:** `LumaraContextSelector`, `LumaraReflectionSettingsService` (memory focus, engagement mode).

**CanHandle:** temporalQuery, patternAnalysis, developmentalArc, historicalParallel, comparison, recentContext, decisionSupport, specificRecall.

**Output:** `SubsystemResult.data`: `recentEntries` (list of maps: date, relativeDate, daysAgo, title, id), `entryContents` (list of content strings). EnhancedLumaraApi reads these via `getSubsystemData('ARC')` and builds `recentEntries` and `baseContext` for `buildMasterUserMessage`.

---

## 4. ATLAS (Developmental Phase)

**Role:** Current developmental phase and rationale for the user. Informs tone and phase calibration in the prompt.

**Location:** `lib/arc/chat/services/atlas_subsystem.dart`

**Wraps:** `UserPhaseService` (getCurrentPhase, getCurrentPhaseRationale, getPhaseDescription).

**CanHandle:** Same reflection-related intents as CHRONICLE/ARC (temporalQuery, patternAnalysis, developmentalArc, historicalParallel, comparison, recentContext, decisionSupport, specificRecall).

**Output:** `SubsystemResult.data`: `aggregations` (string: phase name, description, rationale). Surfaced in `toContextMap()['ATLAS']` and injected into the prompt as part of the SUBSYSTEM CONTEXT block (ATLAS (developmental phase): …).

---

## 5. AURORA (Rhythm / Regulation)

**Role:** Rhythm and regulation summary (usage patterns, optimal timing, future: VEIL integration). Intended for safety and UX limits (e.g. voice session limits, cooldowns).

**Location:** `lib/arc/chat/services/aurora_subsystem.dart`

**CanHandle:** usagePatterns, optimalTiming, recentContext, temporalQuery.

**Output (current):** Stub – `aggregations` is empty until full AURORA implementation (usage_tracker, session limits, etc.). When present, `toContextMap()['AURORA']` is injected as “AURORA (rhythm/regulation): …” in the SUBSYSTEM CONTEXT block.

**Future:** Per [LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md](LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md), AURORA may include aurora_service, usage_tracker, VoiceSessionLog; voice limits (e.g. 3 min session, 15 min cooldown, 3/day).

---

## 6. Summary Table

| Subsystem  | Location                          | Main output for prompt                    | Status        |
|------------|------------------------------------|-------------------------------------------|---------------|
| CHRONICLE  | lumara/subsystems/                 | chronicleContext, chronicleLayerNames     | Implemented   |
| ARC        | arc/chat/services/                 | recentEntries, baseContext (entry contents)| Implemented   |
| ATLAS      | arc/chat/services/                 | ATLAS line in SUBSYSTEM CONTEXT block     | Implemented   |
| AURORA     | arc/chat/services/                 | AURORA line in SUBSYSTEM CONTEXT block    | Stub (empty)  |

All four are registered in `EnhancedLumaraApi._ensureOrchestrator()` and participate when the orchestrator runs (feature flag on, non-voice, CHRONICLE initialized, userId set).

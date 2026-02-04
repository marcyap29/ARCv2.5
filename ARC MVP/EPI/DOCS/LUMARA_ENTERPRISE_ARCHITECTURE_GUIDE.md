# LUMARA Enterprise Architecture Guide

**Purpose:** Canonical reference for the LUMARA four-subsystem spine (ARC, ATLAS, CHRONICLE, AURORA) coordinated by the LUMARA Orchestrator. Use this guide for implementation order, file/doc targets, success criteria, and principles.

**Related:** [LUMARA_ORCHESTRATOR_ROADMAP.md](LUMARA_ORCHESTRATOR_ROADMAP.md) (week-by-week execution); [CHRONICLE_CONTEXT_FOR_CLAUDE.md](CHRONICLE_CONTEXT_FOR_CLAUDE.md) (Polymeta→CHRONICLE renames).

**Last updated:** February 2026

---

## 1. Overview

- **Orchestrator:** Coordinates data from four subsystems; does not replace the Master Prompt.
- **Master Prompt:** Controls LLM behavior; receives pre-aggregated context when using the orchestrator path.
- **Migration:** Feature flag (`FeatureFlags.useOrchestrator`) for A/B and gradual rollout.

---

## 2. File and Doc Summary (Section 5)

### New Directories/Files (from guide)

| Path / items | Notes |
|--------------|--------|
| **lib/lumara/subsystems/** – subsystem.dart, chronicle_subsystem.dart, arc_subsystem.dart, atlas_subsystem.dart, aurora_subsystem.dart | Guide lists all five under lumara/subsystems. Current: subsystem + chronicle_subsystem live in lumara/subsystems/; arc, atlas, aurora live in **lib/arc/chat/services/** and implement Subsystem. |
| **lib/lumara/orchestrator/** – command_parser.dart, lumara_orchestrator.dart, result_aggregator.dart, enterprise_formatter.dart (optional) | First three present; enterprise_formatter optional and not added. |
| **lib/lumara/models/** – command_intent.dart, subsystem_result.dart, intent_type.dart, orchestration_result.dart | All four present. |
| **lib/aurora/** – aurora_service.dart, usage_tracker.dart; Hive model VoiceSessionLog | Guide calls for these for AURORA usage/limits. Current lib/aurora/ has different layout (circadian, VEIL, etc.). |
| **lib/arc/voice/** – command_syntax_validator.dart, enterprise_voice_mode.dart; enterprise voice screen | Not yet added; directory does not exist. |

### Files to Modify

| File | Change | Status |
|------|--------|--------|
| [enhanced_lumara_api.dart](../lib/arc/chat/services/enhanced_lumara_api.dart) | Add orchestrator + feature flag; orchestrator path builds prompt from OrchestrationResult | ✅ Done |
| [lumara_master_prompt.dart](../lib/arc/chat/llm/prompts/lumara_master_prompt.dart) | Add buildSystemPrompt/buildUserMessage(aggregatedContext) when refactoring; keep legacy APIs for legacy path | 🔲 Not done (legacy APIs kept; ATLAS/AURORA injected via modeSpecificInstructions) |
| Voice entry point | Use EnterpriseVoiceMode when enterprise voice enabled | 🔲 Not done (no EnterpriseVoiceMode / lib/arc/voice yet) |

### Docs to Add (per guide)

| Doc | Status |
|-----|--------|
| DOCS/LUMARA_ORCHESTRATOR.md | ✅ Done |
| DOCS/SUBSYSTEMS.md | ✅ Done |
| DOCS/MASTER_PROMPT_V2.md (or section in MASTER_PROMPT_CONTEXT.md) | ✅ Done (§12 + orchestrator flow in §7) |
| DOCS/ENTERPRISE_VOICE.md | ✅ Done |

### Docs to Update

| Doc | Change | Status |
|-----|--------|--------|
| CHRONICLE_CONTEXT_FOR_CLAUDE.md | Orchestrator integration, Polymeta → CHRONICLE checklist | ✅ Partially done |
| MASTER_PROMPT_CONTEXT.md | Refactored Master Prompt role, orchestrator flow | ✅ Done (§12, §7 flow, diagram note) |
| claude.md, ARCHITECTURE.md, LUMARA_COMPLETE.md, LUMARA_Vision.md | Polymeta → CHRONICLE; four-subsystem spine | ✅ Done |

---

## 3. Success Criteria (Section 6)

**Technical:** All four subsystems operational; orchestrator routes correctly; Master Prompt receives pre-aggregated context; response quality ≥ legacy; latency acceptable (e.g. &lt;2s).

**Safety:** Voice: 3min session, 15min cooldown, 3/day; AURORA tracks usage; sabbatical after 30 days if specified.

**UX:** Responses natural; temporal queries better; voice intentional (command-driven); no regressions.

---

## 4. Principles (Section 7)

- **Wrap, don’t rebuild** – CHRONICLE stays; wrap as ChronicleSubsystem.
- **Orchestrator vs Master Prompt** – Orchestrator coordinates data; Master Prompt controls LLM behavior.
- **Gradual migration** – Feature flag for A/B and rollout.
- **Safety first** – Enterprise voice and AURORA enforce limits.
- **Preserve quality** – Orchestrator path must match or exceed legacy output.

---

## 5. Immediate Next Steps (Section 8)

1. Store the definitive guide as the canonical reference → **this file (DOCS/LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md)**.
2. Create feature branch `feature/lumara-orchestrator` (if not already present).
3. Weeks 1–6 executed per [LUMARA_ORCHESTRATOR_ROADMAP.md](LUMARA_ORCHESTRATOR_ROADMAP.md): Subsystem interface, ChronicleSubsystem, orchestrator, integration, ARC/ATLAS/AURORA, prompt injection.
4. Run tests: ChronicleSubsystem and orchestrator tests; ensure orchestrator path behavior matches or exceeds legacy.

**Remaining (post–Week 6):**

- ~~Add docs: LUMARA_ORCHESTRATOR.md, SUBSYSTEMS.md, MASTER_PROMPT_V2 (or section), ENTERPRISE_VOICE.md.~~ ✅ Done.
- ~~Update docs: MASTER_PROMPT_CONTEXT, claude.md, ARCHITECTURE.md, LUMARA_COMPLETE.md, LUMARA_Vision.md (Polymeta → CHRONICLE; four-subsystem spine).~~ ✅ Done.
- Implement enterprise voice: lib/arc/voice, EnterpriseVoiceMode, command_syntax_validator, voice entry point.
- Optional: buildSystemPrompt/buildUserMessage(aggregatedContext) refactor; enterprise_formatter; AURORA usage_tracker / VoiceSessionLog per guide.

---

*No code or doc edits in the original plan—only the implementation roadmap. Execute in order; use this guide for file targets and FAQs.*

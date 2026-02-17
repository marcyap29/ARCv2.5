# Prompt Tracker

**Version:** 1.4.0  
**Last Updated:** February 15, 2026  
**Purpose:** Prompt change tracking and quick reference. Full prompt catalog and version history live in [PROMPT_REFERENCES.md](PROMPT_REFERENCES.md).

---

## How to use this tracker

- **Full catalog and version history:** See [PROMPT_REFERENCES.md](PROMPT_REFERENCES.md) – document scope and sources, all prompt sections, and Version History table.
- **This file:** Quick reference for recent prompt-related changes and where prompt changes are tracked.

---

## Recent prompt-related changes

| Date | Change | Source / doc |
|------|--------|--------------|
| 2026-02-15 | Agent prompts: research_prompts.dart, writing_prompts.dart (LUMARA research/writing agents); add to PROMPT_REFERENCES when consolidating | CONFIGURATION_MANAGEMENT.md; CHANGELOG [3.3.37] |
| 2026-02-15 | Doc sync v3.3.36: Agents screen, connection service, bug_tracker (35 records); prompt audit (no new prompts) | CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Doc sync v3.3.35: LUMARA agents, orchestrator, CHRONICLE alignment; prompt audit (no new prompts) | CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Doc sync v3.3.34: LUMARA API, control state, CHRONICLE query (query_plan, context_builder, query_router); prompt audit (no new prompts) | CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Master prompt expansion: lumara_master_prompt.dart +~560 lines, LumaraControlStateBuilder +82; control state block, CHRONICLE/vectorization. Documented in MASTER_PROMPT_CHRONICLE_VECTORIZATION.md | CHANGELOG [3.3.33]; CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Doc sync: Full repo Documentation & Git Backup run; prompt audit (no new prompts); catalog v2.3.0 current | CONFIGURATION_MANAGEMENT.md |
| 2026-02-13 | Prompt audit: §20 Quick Answers / MMCO Polish (`quickanswers_router.dart` — pre-LLM gate, MMCO ground truth, optional on-device polish) | PROMPT_REFERENCES.md v2.3.0 |
| 2026-02-13 | v3.3.26 prompts: §17 Intellectual Honesty / Pushback (master prompt `<intellectual_honesty>`, truth_check injection, Evidence Review); §18 Crossroads Decision Capture (4-step flow, trigger patterns, decision archaeology query); §19 CHRONICLE Edit Validation (pattern suppression and contradiction warnings) | PROMPT_REFERENCES.md v2.2.0 |
| 2026-02-12 | Doc consolidation: Merged UNIFIED_INTENT_CLASSIFIER_PROMPT (§15 — Unified Intent Depth Classifier with full LLM prompt) and MASTER_PROMPT_CONTEXT (§16 — Master Prompt Architecture, structure, control state, entry points). Originals archived. | PROMPT_REFERENCES.md v2.1.0 |
| 2026-02-11 | Groq primary LLM: proxyGroq/proxyGemini backend proxy entries; transparent proxy note | PROMPT_REFERENCES.md v2.0.0 |
| 2026-02-11 | CHRONICLE synthesis prompts (Monthly/Yearly/Multi-Year Narrative); Voice Split-Payload Prompt; CHRONICLE Speed-Tiered Context System; Conversation Summary Prompt | PROMPT_REFERENCES.md v1.9.0 |
| 2026-01-31 | Document scope and sources; LUMARA source note (lumara_system_prompt vs lumara_master_prompt, lumara_profile.json) | PROMPT_REFERENCES.md v1.8.0 |
| 2026-01-30 | CHRONICLE prompts (Query Classifier, VEIL EXAMINE); Backend (Firebase) prompts; Voice Journal Entry Creation | PROMPT_REFERENCES.md v1.7.0 |
| 2026-01-24 | REFLECT → DEFAULT mode; Layer 2.5–2.7 (Direct Answer, Context Retrieval, Mode Switching) | PROMPT_REFERENCES.md v1.6.0 |
| 2026-01-23 | Template variables, ECHO variables, Bible context blocks, on-device variants, voice phase word limits, session summary | PROMPT_REFERENCES.md v1.5.0 |

---

## Where prompt changes are tracked

- **PROMPT_REFERENCES.md** – Authoritative prompt catalog; Version History at end of file; each section cites source files.
- **CHANGELOG.md** – App/release changes that affect prompts (e.g. Wispr Flow cache fix, Phase Quiz/Phase tab).
- **claude.md** – Context guide; Recent Updates; Documentation & Configuration Management Role.

---

## Configuration tracking

Prompt changes are included in [CONFIGURATION_MANAGEMENT.md](CONFIGURATION_MANAGEMENT.md) inventory and change log. When prompts in the codebase change, update PROMPT_REFERENCES.md (and this tracker if adding a row above) and note in CONFIGURATION_MANAGEMENT.

---

**Status:** ✅ Active – Prompt changes tracked via PROMPT_REFERENCES.md version history and this quick reference.

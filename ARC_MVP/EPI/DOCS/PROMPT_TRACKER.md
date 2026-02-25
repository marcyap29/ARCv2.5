# Prompt Tracker

**Version:** 1.7.0  
**Last Updated:** February 24, 2026  
**Purpose:** Prompt change tracking and quick reference. Full prompt catalog and version history live in [PROMPT_REFERENCES.md](PROMPT_REFERENCES.md).

---

## How to use this tracker

- **Full catalog and version history:** See [PROMPT_REFERENCES.md](PROMPT_REFERENCES.md) – document scope and sources, all prompt sections, and Version History table.
- **This file:** Quick reference for recent prompt-related changes and where prompt changes are tracked.

---

## Recent prompt-related changes

| Date | Change | Source / doc |
| 2026-02-24 | Doc sync: Prompt audit v2.8.0 — added LUMARA Groq Cached Prompt (`lumara_groq_cached_prompt.dart`, used by groq_send.dart) | PROMPT_REFERENCES.md v2.8.0 |
| 2026-02-22 | Doc sync v3.3.57: Firebase Functions Node 22 LTS, package-lock; no prompt changes | CONFIGURATION_MANAGEMENT.md |
| 2026-02-22 | Doc sync (Documentation & Git Backup run); prompt audit — no new prompts; CONFIGURATION_MANAGEMENT, bug_tracker refresh | CONFIGURATION_MANAGEMENT.md |
| 2026-02-20 | Doc sync v3.3.56: PRISM compression, CHRONICLE date-aware routing, LUMARA token caps, landscape orientation; no prompt changes | CONFIGURATION_MANAGEMENT.md |
| 2026-02-20 | Prompt audit v2.7.0: added §1 ECHO On-Device LLM System Prompt (Qwen adapter) — `lib/echo/providers/llm/prompt_templates.dart`; dir rename ARC MVP → ARC_MVP committed (v3.3.55) | PROMPT_REFERENCES.md v2.7.0 |
| 2026-02-19 | Doc sync v3.3.54: PDF content service, journal/CHRONICLE/MCP/media, pubspec; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.53: iOS project (Runner.xcodeproj); bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.52: Google Drive sync push, MCP export/management, DOCS checklist; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.51: Journal capture, journal repository, dual CHRONICLE (agentic loop, dual_chronicle_view); bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.50: Egress PII/LumaraInlineApi security tests; backend, auth, gemini_send, subscription, AssemblyAI; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.49: CHRONICLE layer0, dual CHRONICLE/LUMARA, lumara_system_prompt/prompt_library/optimizer; LumaraInlineApi PII fix; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | Doc sync v3.3.48: Universal prompt optimization layer (80/20, provider-agnostic); UNIVERSAL_PROMPT_OPTIMIZATION.md; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-19 | UNIVERSAL_PROMPT_OPTIMIZATION.md — prompt optimization use cases (userChat, userReflect, gapClassification, etc.), provider adapters; add to PROMPT_REFERENCES when consolidating | UNIVERSAL_PROMPT_OPTIMIZATION.md |
| 2026-02-18 | Doc sync v3.3.47: Dual CHRONICLE refactor, PROMPT_REFERENCES +104, bugtracker index/audit; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-18 | PROMPT_REFERENCES.md extended (+104) — prompt catalog update | PROMPT_REFERENCES.md |
| 2026-02-18 | Doc sync v3.3.46: Drive/backup UI, DOCS cleanup (redundant Dual Chronicle docs removed); bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-18 | Doc sync v3.3.45: Dual CHRONICLE intelligence summary, LUMARA definitive overview; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-18 | Doc sync v3.3.44: CHRONICLE search (hybrid/BM25/semantic), unified feed, Arcform 3D; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-17 | Doc sync v3.3.43: Dual CHRONICLE UI, LUMARA assistant, journal capture, onboarding, unified feed; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-17 | Doc sync v3.3.42: ARCHITECTURE paper/archive ref, LaTeX gitignore, Narrative/LUMARA archive refs; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-17 | Doc sync v3.3.41: Dual CHRONICLE, Writing with LUMARA, timeline/feed; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-16 | Doc sync v3.3.40: PROMPT_REFERENCES updated; agent_operating_system_prompt, lumara_intent_classifier, orchestration; bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Doc sync v3.3.39: Research/writing prompts expansion (research_prompts, writing_prompts); screen/tab refinements; prompt audit (no new files, content expanded); bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
| 2026-02-15 | Doc sync v3.3.38: Writing drafts/research storage, archive/delete, ARCX agents export/import; prompt audit (no new prompts); bug_tracker tracked | CONFIGURATION_MANAGEMENT.md |
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
| 2026-01-23 | Template variables, ECHO variables, on-device variants, voice phase word limits, session summary | PROMPT_REFERENCES.md v1.5.0 |

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

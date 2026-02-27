# Bugtracker Triage Backlog

**Document Version:** 1.0.0  
**Last Updated:** 2026-02-26  
**Source:** BUGTRACKER_AUDIT_REPORT.md (2026-02-26), static analysis run, discovery since 2026-02-25

---

## Priority order (ready for root-cause / fix assignment)

| Priority | Bug ID | Summary | Severity | Component | Effort | Rationale |
|----------|--------|---------|----------|-----------|--------|-----------|
| 1 | BUG-ANALYZER-001 | dart analyze 349+ errors (lib + test + tool) | High | #build #lumara #aurora #echo #mira #prism #mcp #test | Complex | Blocks clean build; production lib errors first |
| 2 | — | Veil Edge Future vs List type mismatch (4 call sites) | High | #lumara | Quick win | Direct type error; add await or change signature |
| 3 | — | Aurora notification_models missing; ActiveWindow, AbstinenceWindow | High | #aurora | Medium | Core AURORA feature; create or relocate models |
| 4 | — | Start Entry Flow media_strip, media_preview_dialog missing | High | #ui-ux | Medium | Entry capture flow; fix import paths |
| 5 | — | ECHO llm_bridge_adapter, ArcLLM import path | High | #echo | Quick win | Import path fix |
| 6 | — | PRISM Vital MCP schema files missing | High | #prism #mcp | Medium | Create schema or update imports |
| 7 | — | Ollama ollama_config.g.dart generated file stale | Medium | #build | Quick win | Regenerate Hive adapter |
| 8 | — | Voice mode firestore param | Medium | #lumara | Quick win | Check Firebase API |
| 9 | — | First Responder mode tests (deleted feature) | Low | #test | Medium | Exclude or archive tests |
| 10 | — | Veil Edge, Aurora integration tests (package paths) | Low | #test | Medium | Update package paths |

---

## Quick-win vs deferred

### Quick wins (1–2 hrs each)
- Veil Edge Future/List (await)
- ECHO llm_bridge_adapter import
- Ollama adapter regeneration
- Voice firestore param
- testing_mode_display Color shades
- arcx_import_service_unified null default

### Deferred (stale/removed features)
- First Responder mode tests (context_trigger, debrief, redaction, enhanced_export)
- Old Veil Edge registry/router tests (package:my_app/lumara/veil_edge)
- AppMode.firstResponder, AppMode.coach

---

## Effort estimates

| Effort | Count | Notes |
|--------|-------|------|
| Quick win | ~6 | Single-file, single-fix items |
| Medium | ~8 | Multi-file or model creation |
| Complex | 1 | BUG-ANALYZER-001 — systematic fix across components |

---

## Component tags

- **#build** — Analyzer, Hive, generated files
- **#lumara** — Veil Edge, Voice, LUMARA chat
- **#aurora** — ActiveWindow, SleepProtection, notification_models
- **#echo** — Privacy, Qwen adapter, ArcLLM
- **#mira** — chat_to_mira, mira_basics_adapters
- **#prism** — prism_vital, MCP schema
- **#mcp** — MCP schema, CLI tools
- **#test** — Stale tests, mocks, package paths
- **#ui-ux** — Start Entry Flow, Testing Mode Display

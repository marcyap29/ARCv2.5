# Static Analysis Findings — February 2026

### BUG-ANALYZER-001: dart analyze reports 349+ errors (lib + test + tool)
**Version:** 1.0.0 | **Date Logged:** 2026-02-26 | **Status:** Open

#### 🐛 **BUG DESCRIPTION**
- **Issue Summary:** `dart analyze` reports 349+ errors across lib/, test/, and tool/ directories. These block clean builds and indicate broken imports, missing files, API mismatches, and stale tests after refactors.
- **Affected Components:** Ollama, Veil Edge, Aurora (ActiveWindow, SleepProtection), Start Entry Flow, Widget Quick Actions, ECHO (privacy, Qwen adapter), MIRA, PRISM Vital, Onboarding, Testing Mode Display, Arcform Share tests, CHRONICLE tests, Aurora integration tests, MCP tests, First Responder mode tests, Veil Edge tests, Entry Classifier tests, MCP CLI tools.
- **Reproduction Steps:** Run `dart analyze` in ARC_MVP/EPI.
- **Expected Behavior:** Zero errors.
- **Actual Behavior:** 349+ errors (extends_non_class, undefined_class, uri_does_not_exist, argument_type_not_assignable, undefined_named_parameter, invalid_override, etc.).
- **Severity Level:** High (production lib/ errors); Medium (test failures).
- **First Reported:** 2026-02-26 | **Reporter:** Bugtracker Discovery Agent

#### 🔧 **FIX IMPLEMENTATION**
- **Fix Summary:** Not yet implemented. Fix strategy: group by component, fix lib/ first, then update or exclude stale tests.
- **Technical Details:** See “How to Fix” section below.
- **Files Modified:** [None yet]
- **Testing Performed:** `dart analyze` 2026-02-26.
- **Fix Applied:** [Not yet] | **Implementer:** —

#### 🎯 **RESOLUTION ANALYSIS**
- **Root Cause:** Accumulated tech debt from refactors (chat refactor 7ab2a51dd, LUMARA vision reposition v3.3.59, Code Simplifier, package renames). Missing/moved files (notification_models.dart, media_strip.dart, llm_bridge_adapter.dart, etc.); package path changes (my_app/arc, my_app/lumara, my_app/mode); API signature changes (ChatRepo.addMessage, JournalRepository.createJournalEntry, RivetSweepService.analyzeEntries); deleted features (First Responder mode, old Veil Edge structure); stale generated files (ollama_config.g.dart).
- **Fix Mechanism:** (1) Fix broken imports and create/relocate missing files. (2) Regenerate Hive/Ollama adapters. (3) Update test mocks to match new API signatures. (4) Update or exclude tests for removed features (First Responder, old Veil Edge paths).
- **Impact Mitigation:** Restores `dart analyze` clean state; unblocks CI; improves maintainability.
- **Prevention Measures:** Run `dart analyze` before merge; keep tests in sync with API changes; document package layout in CONFIGURATION_MANAGEMENT.
- **Related Issues:** build-fixes-session-feb-2026.md (AppLifecycleState, FeedRepository types), ios-build-local-embedding-service-errors.md.

#### 📋 **TRACKING INFORMATION**
- **Bug ID:** BUG-ANALYZER-001
- **Component Tags:** [#build], [#lumara], [#aurora], [#echo], [#mira], [#prism], [#mcp], [#test]
- **Version Fixed:** —
- **Verification Status:** Open
- **Documentation Updated:** 2026-02-26

---

## How to Fix (grouped by component)

### 1. Lib/ — Critical (blocks production build)

| Component | Location | Issue | Fix |
|-----------|----------|-------|-----|
| Ollama | ollama_config.g.dart | OllamaConfig, BinaryReader/Writer undefined | Regenerate Hive adapter: ensure `OllamaConfig` model exists; run `dart run build_runner build` |
| Veil Edge | veil_edge_service.dart:51,187,193,199 | `Future<List<JournalEntry>>` passed where `List<JournalEntry>` expected | `await` the futures before passing, or change callee to accept `Future` |
| Voice | voice_mode_launcher.dart:79 | Named param `firestore` undefined | Update Firestore/Firebase dependency call; check Firebase API for correct param name |
| Aurora | active_window_detector.dart, sleep_protection_service.dart | Missing `../models/notification_models.dart`; `ActiveWindow`, `AbstinenceWindow` undefined | Create `notification_models.dart` with ActiveWindow, AbstinenceWindow; or relocate models; fix import path |
| Aurora | notification_service.dart:225 | `confidence` getter on Object | Cast to correct type or add typed variable before accessing `confidence` |
| Start Entry Flow | start_entry_flow.dart:14–15,163,378 | Missing media_strip.dart, media_preview_dialog.dart | Update imports to correct package path (e.g. `package:epi/...`) or restore moved files |
| Widget Quick Actions | widget_quick_actions_service.dart:5 | Missing multimodal_integration_service.dart | Fix import path or restore service; check MCP orchestrator layout |
| ECHO | privacy_guardrail_interceptor.dart:8,313–314 | Missing llm_bridge_adapter; ArcLLM undefined | Update import to `package:epi/services/llm_bridge_adapter.dart` (or current path); ensure ArcLLM exported |
| ECHO | qwen_adapter.dart:2,8 | Missing model_adapter; implements non-class | Fix import path; implement correct interface/abstract class |
| MIRA | chat_to_mira.dart:84 | addEdge not on MiraService | Add addEdge to MiraService or use correct API |
| MIRA | mira_basics_adapters.dart:26 | `.map` on Future | Use `.then((x) => x.map(...))` or `await` then `.map` |
| ARCX | arcx_import_service_unified.dart:165 | Param `f` null default for non-null type | Add explicit default or make param nullable |
| PRISM Vital | prism_vital.dart:1–5,16,21,41,50,64–65 | Missing pointer_health, node_health_summary, mcp_redaction_policy; VitalWindow, PointerHealthV1, NodeHealthSummaryV1, McpRedactionPolicy | Create missing MCP schema files or update imports to current layout |
| Onboarding | onboarding_view.dart:3,35 | Missing audio_service | Update import to `package:epi/...` or create/restore AudioService |
| Testing Mode Display | testing_mode_display.dart:89,110 | Color.shade100, Color.shade900 undefined | Use MaterialColor shades (e.g. Colors.blue.shade100) or correct Color extension |

### 2. Test/ — Medium (blocks `flutter test`)

| Test File | Issue | Fix |
|-----------|-------|-----|
| arcform_share_test.dart | ArcShareMode.social/direct removed; ArcformSharePayload params changed | Update enum and payload usage to match current model |
| synthesis_scheduler_test.dart | Missing mocks; synthesis_scheduler_test.mocks.dart | Run `dart run build_runner build` for mocks; or update imports |
| aurora_integration_test.dart | package:my_app/lumara/... paths; VeilEdgeService, ChatRepo, ChatSession, ChatMessage | Update to package:epi/... and arc/chat paths |
| journal_entry_projector_metadata_test.dart | MockJournalRepository missing methods; createJournalEntry signature | Add ensureBoxOpen, getRecentJournalEntries, migrateLumaraBlocks, removeDuplicateEntries; add userId param to createJournalEntry |
| chat_mcp_test.dart | MockChatRepo missing updateSessionMetadata, updateSessionPhase; addMessage signature | Add missing methods; add messageId, timestamp params to addMessage |
| phase_regime_mcp_test.dart | RivetSweepService.analyzeEntries needs userId | Add userId param to mock |
| storage_profiles_test.dart | AppMode.firstResponder, AppMode.coach removed | Update to current AppMode enum values |
| memory_system_integration_test.dart | MockContextProvider.buildContext needs scope | Add LumaraScope? scope param |
| first_responder/* | mode/first_responder removed (ContextTriggerService, DebriefCubit, etc.) | Exclude tests or move to archive; or restore feature |
| enhanced_export_service_test.dart | FRSettings, RedactionService, EnhancedExportService removed | Exclude or update to current export API |
| entry_classifier_test.dart | EntryClassifier private methods removed | Use public API or restore/extract testable helpers |
| veil_edge/* | package:my_app/lumara/veil_edge paths; VeilEdgeRouter, RivetPolicyEngine, etc. | Update to arc/chat/veil_edge paths |
| pattern_recognition_test.dart | LocalEmbeddingService.embeddingDimension | Add getter or use alternative |

### 3. Tool/ — Low (CLI tools)

| File | Issue | Fix |
|------|-------|-----|
| arc_mcp_export.dart | Missing mcp_export_service, mcp_schemas, mcp_validator; McpExportScope | Update imports to current MCP layout; define or import McpExportScope |

---

**Full analyzer output:** Run `dart analyze 2>&1` in ARC_MVP/EPI. Error count: ~349.

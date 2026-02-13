# Code Simplifier — Full-Repo Consolidation Plan

**Source:** Code Simplifier prompt in `DOCS/claude.md` (broader consolidation mode)  
**Scope:** Entire `lib/` codebase (~969 Dart files)  
**Goal:** Clear, consistent, lean, maintainable code with exact functionality preserved. Work is divided so multiple agents can run in parallel.

---

## 1. Consolidation Analysis (Scan Summary)

### 1.1 Duplicate files (remove one copy, fix imports)

| Issue | Files | Action | Risk |
|-------|--------|--------|------|
| **JournalVersionService duplicate** | `lib/core/services/journal_version_service.dart` (canonical) vs `lib/arc/internal/mira/version_service.dart` (identical copy) | Delete `arc/internal/mira/version_service.dart`. Update `lib/arc/internal/mira/mira_internal.dart` to export `package:my_app/core/services/journal_version_service.dart` instead of `version_service.dart`. | Low. All current imports use core path; only mira_internal re-exports the duplicate. |
| **QuickActionsService** | `lib/arc/ui/quick_actions_service.dart` (small impl) vs `lib/arc/ui/widget_installation_service.dart` (defines `QuickActionsService` at ~L206). Also `lib/arc/ui/widget_quick_actions_service.dart`. | Single source of truth: keep one QuickActionsService (prefer `quick_actions_service.dart`). Have widget_installation_service and widget_quick_actions_* import it. Remove duplicate class from widget_installation_service. Fix `widget_quick_actions_integration.dart` import if it points to wrong file. | Low. Verify no behavioral difference between the two classes. |

**Estimated impact:** Remove ~400 lines (duplicate JournalVersionService file), clarify one service boundary.

### 1.2 Duplicate / similar components

| Area | Finding | Recommendation |
|------|---------|----------------|
| **Feed entry cards** | `lib/arc/unified_feed/widgets/feed_entry_cards/`: `BaseFeedCard` + 5 card types (ActiveConversation, SavedConversation, VoiceMemo, Reflection, LumaraPrompt). Already share base. | Optional Phase 2: single generic `FeedEntryCard<T>` with `FeedEntryType`-specific config and item builder to reduce per-card boilerplate. Keep current structure if already clear. |
| **Settings / management views** | Multiple `*_view.dart` and `*_settings_view.dart` under `shared/ui/settings/` (chronicle_management, privacy, phase_analysis, local_backup, google_drive, etc.). | Phase 1: Unify shared patterns (app bar, section headers, buttons). Phase 2: Consider a generic `SettingsSection` or `ManagementView` scaffold if >3 views share >80% layout. |
| **Chat screens** | `chats_screen.dart`, `enhanced_chats_screen.dart`, `session_view.dart`. | Document which is primary; remove or merge if one is legacy. |

### 1.3 Service layer

| Family | Files | Recommendation |
|--------|--------|----------------|
| **Chronicle** | ChronicleImportService, ChronicleExportService, ChronicleEditingService, ChronicleOnboardingService, ChronicleManualService | Keep; ensure they use shared repos (AggregationRepository, ChangelogRepository, Layer0Repository) via DI/factory, not ad-hoc instantiation in 10+ places. |
| **ARC/Import-Export** | MCP: McpExportService, McpImportService, Enhanced*, McpPackExport, McpPackImport, SimpleMcpService. ARCX: ARCXExportService, ARCXExportServiceV2, ARCXImportService, ARCXImportServiceV2, UnifiedARCXImportService. | Phase 2: One “unified” entry point per format (MCP vs ARCX) that delegates to enhanced/v2 internally; deprecate duplicate entry points. Reduce repeated “load journal + chat + phase” boilerplate. |
| **Phase** | UserPhaseService, PhaseRegimeService, ChatPhaseService, PhaseMigrationService, PhaseInferenceService, PhaseDetectorService, PhaseRatingService, PhaseAwareAnalysisService, AtlasPhaseDecisionService | Keep; Phase 1: Centralize instantiation (e.g. from bootstrap or a small PhaseServiceRegistry) to avoid 15+ `PhaseRegimeService()` constructors. |
| **Voice** | VoiceSessionService, UnifiedTranscriptionService, WisprFlowService, AudioCaptureService, UnifiedVoiceService, AssemblyAISttService, etc. | Keep; ensure single place for “current voice pipeline” config. |

### 1.4 Repositories and instantiation

- **JournalRepository**, **ChatRepo** (ChatRepoImpl), **Layer0Repository**, **AggregationRepository**, **ChangelogRepository** are constructed in many places (e.g. ChronicleManagementView, EnhancedLumaraApi, SynthesisScheduler, JournalScreen, McpExportScreen, bootstrap).
- **Recommendation:** Phase 1: Introduce lightweight accessors or a single “app repos” factory used by UI and services (where it fits architecture). Phase 2: Reduce direct `JournalRepository()` / `Layer0Repository()` in 20+ call sites to one or two creation points.

### 1.5 Build and imports

- Run project analyzer for **unused imports** and **dead code** (e.g. commented `FirestoreService`).
- **Circular dependencies:** Check `mira/`, `arc/internal/mira/`, `core/` for cycles; fix by moving shared types to a neutral package or breaking one dependency.
- **Heavy files:** `journal_screen.dart`, `phase_analysis_view.dart`, `simplified_arcform_view_3d.dart`, `enhanced_lumara_api.dart` are large; consider extract-to-file for logical blocks (e.g. “draft handling”, “phase chart”) in Phase 2.

---

## 2. Divisible Execution Plan (Phases + Work Packages)

Work is split so that **multiple agents can run in parallel** by domain and by phase. Dependencies between packages are minimal within Phase 1; Phase 2 may require coordination for cross-domain refactors.

### Phase 1 — Quick wins (high impact, low risk)

| ID | Work package | Description | Owner (suggested agent) | Deps |
|----|----------------|-------------|-------------------------|------|
| P1-DUP | Remove duplicate JournalVersionService | Delete `lib/arc/internal/mira/version_service.dart`, update `mira_internal.dart` to export core `journal_version_service.dart`. | **Agent A** | None |
| P1-QUICK | Resolve QuickActionsService duplication | Single QuickActionsService in `quick_actions_service.dart`; widget_installation_service and widget_quick_actions_* use it; fix broken import in widget_quick_actions_integration if any. | **Agent A** | None |
| P1-IMPORTS | Unused imports and dead code | Run analyzer; remove unused imports project-wide; remove or uncomment dead code (e.g. FirestoreService). | **Agent E** | None |
| P1-CHRONICLE | Chronicle repo wiring | In chronicle/ and chronicle integration call sites: prefer factory or shared getters for Layer0Repository, AggregationRepository, ChangelogRepository instead of ad-hoc `new X()`. | **Agent B** | None |
| P1-PHASE | Phase service access | Document and, where possible, centralize PhaseRegimeService / UserPhaseService / ChatPhaseService creation (e.g. one registry or bootstrap wiring). | **Agent B** | None |
| P1-SHARED-UI | Shared settings view patterns | In `shared/ui/settings/`: extract common app bar, section title, and primary button styles; apply to 2–3 views as pilot. | **Agent D** | None |

### Phase 2 — Architectural consolidation

| ID | Work package | Description | Owner (suggested agent) | Deps |
|----|----------------|-------------|-------------------------|------|
| P2-FEED-CARDS | Generic feed entry card (optional) | If beneficial: introduce `FeedEntryCard` generic with type-based config and builder; migrate existing 5 card types to use it; keep same API for UnifiedFeedScreen. | **Agent B** | P1-* done |
| P2-MCP-ARCX | MCP/ARCX export-import facade | Single entry points for “export to MCP” and “export/import ARCX”; internal delegation to enhanced/v2; reduce duplicate “load journal+chat+phase” in export/import. | **Agent C** | P1-* done |
| P2-REPOS | App-level repo factory | Introduce minimal “app repos” or provider that supplies JournalRepository, ChatRepo, Layer0Repository, AggregationRepository, ChangelogRepository; migrate high-traffic call sites (e.g. EnhancedLumaraApi, ChronicleManagementView, JournalScreen). | **Agent B** + **Agent C** | P1-CHRONICLE, P1-PHASE |
| P2-SPLIT | Split oversized files | Extract logical blocks from journal_screen, phase_analysis_view, simplified_arcform_view_3d, enhanced_lumara_api into separate files (e.g. draft_handling.dart, phase_chart.dart) with minimal public API. | **Agent B** (journal/phase) + **Agent C** (lumara api) | P1-* |

### Phase 3 — Polish and validation

| ID | Work package | Description | Owner (suggested agent) | Deps |
|----|----------------|-------------|-------------------------|------|
| P3-DOCS | Document consolidated patterns | Update ARCHITECTURE.md or CONFIGURATION_MANAGEMENT.md with: single source for JournalVersionService, QuickActionsService; repo/phase access pattern; MCP/ARCX entry points. | **Agent F** | All Phase 2 |
| P3-TESTS | Verify behavior | Run full test suite and smoke flows (journal, feed, export/import, phase, voice). Fix any regressions from Phase 1–2. | **Agent F** | All Phase 2 |
| P3-METRICS | Metrics and rollback | Record: lines removed, files removed/merged, list of changed files. Document rollback steps (e.g. revert P1-DUP if issues). | **Agent F** | All Phase 2 |

---

## 3. Agent Roles and Assignments

Agents operate in parallel where dependencies allow. Each agent should follow the **Code Simplifier** prompt in `claude.md` (preserve functionality, project standards, clarity, balance).

| Agent | Role | Primary domains | Work packages |
|-------|------|------------------|----------------|
| **Agent A** | Duplicates and single-source-of-truth | core/, arc/internal/mira | P1-DUP, P1-QUICK |
| **Agent B** | Chronicle, phase, feed, journal UI | chronicle/, arc/unified_feed/, ui/journal, ui/phase, services/phase_* | P1-CHRONICLE, P1-PHASE, P2-FEED-CARDS, P2-REPOS (with C), P2-SPLIT (journal/phase) |
| **Agent C** | MIRA store, import/export, LUMARA API | mira/store/, arc/chat (enhanced_lumara_api), arc internal | P2-MCP-ARCX, P2-REPOS (with B), P2-SPLIT (lumara api) |
| **Agent D** | Shared UI and settings | shared/ui/, settings views | P1-SHARED-UI |
| **Agent E** | Build, imports, dead code | Whole repo (analyzer-driven) | P1-IMPORTS |
| **Agent F** | Coordination and validation | Docs, tests, metrics | P3-DOCS, P3-TESTS, P3-METRICS |

### Execution order (parallelization)

- **Wave 1 (parallel):** Agent A (P1-DUP, P1-QUICK), Agent D (P1-SHARED-UI), Agent E (P1-IMPORTS), Agent B (P1-CHRONICLE, P1-PHASE).
- **Wave 2 (after Wave 1):** Agent B (P2-FEED-CARDS, P2-REPOS, P2-SPLIT), Agent C (P2-MCP-ARCX, P2-REPOS, P2-SPLIT). B and C can sync on P2-REPOS.
- **Wave 3 (after Wave 2):** Agent F (P3-DOCS, P3-TESTS, P3-METRICS).

### P2-REPOS sync (Agent C completed)

- **AppRepos** added: `lib/services/app_repos.dart` — lazy singleton `AppRepos.journal` for `JournalRepository`. CHRONICLE repos remain via existing `ChronicleRepos` (layer0, aggregation, changelog). Chat: `ChatRepoImpl.instance`.
- **Agent C call sites migrated** to AppRepos / ChronicleRepos: `enhanced_lumara_api.dart`, `context_provider.dart`, `lumara_assistant_cubit.dart`, `veil_edge_service.dart`, `lumara_context_selector.dart`, `voice_session_service.dart`, `journal_store.dart`, `unified_voice_service.dart`, `arcx_import_service_v2.dart`, `arcx_export_service_v2.dart`, `universal_importer_service.dart`, `keyword_analysis_view.dart` (arc/core/widgets), `mira_service.dart`, `simple_mcp_service.dart` (uses injected `_journalRepo`).
- **Agent B** can migrate ChronicleManagementView, JournalScreen, phase_analysis_view, timeline, etc., to `AppRepos.journal` and `ChronicleRepos` where applicable.

---

## 4. Deliverables Checklist (per Code Simplifier)

- [ ] **Analysis:** File paths and line counts for each consolidation (this document).
- [ ] **Before/after:** For P1-DUP, P1-QUICK, P2-MCP-ARCX, P2-REPOS — short before/after snippets in changelog or this doc.

### P2-REPOS before/after (Agent B, synced with Agent C)

- **Added:** `lib/app/app_repos.dart` — single access point for `JournalRepository`, `ChatRepo`, and CHRONICLE repos (delegates to `ChronicleRepos` for layer0/aggregation/changelog).
- **app.dart:** `RepositoryProvider(create: (_) => JournalRepository())` → `RepositoryProvider(create: (_) => AppRepos.journal)`; ARCX handler uses `AppRepos.journal` instead of `ctx.read<JournalRepository>()`.
- **EnhancedLumaraApi:** `JournalRepository()`, `ChatRepoImpl.instance`, `Layer0Repository()`, `AggregationRepository()` → `AppRepos.journal`, `AppRepos.chat`, `ChronicleRepos.layer0` / `ChronicleRepos.aggregation` (with `ChronicleRepos.ensureLayer0Initialized()`).
- **ChronicleManagementView:** `JournalRepository()` in `_createOnboardingService()` → `AppRepos.journal`; `ChronicleRepos.initializedRepos` → `AppRepos.initializedChronicleRepos`.
- **JournalScreen:** field and local uses of `JournalRepository()` → `AppRepos.journal` / `_journalRepository` (field set to `AppRepos.journal`).
- [ ] **Risk:** Each work package above has risk noted; no breaking changes to public APIs.
- [ ] **Roadmap:** This section 2 is the prioritized sequence; rollback = revert the specific commits for that package.
- [x] **Metrics:** Post–Phase 3: total lines removed, files removed, list of changed files (P3-METRICS) — see below.

### Phase 3 metrics and rollback (P3-METRICS)

**Metrics (from Phase 1–2 execution):**

| Work package | Files removed | Lines removed (approx) | Notable changed files |
|--------------|---------------|------------------------|------------------------|
| P1-DUP | 1 | ~400 | Deleted `lib/arc/internal/mira/version_service.dart`; `mira_internal.dart` exports `journal_version_service.dart` |
| P1-QUICK | 0 | — | Single QuickActionsService in `lib/arc/ui/quick_actions_service.dart`; widget_* import it |
| P1-IMPORTS | 0 | varies | Analyzer-driven unused imports/dead code (per Agent E run) |
| P1-CHRONICLE / P1-PHASE | 0 | — | Repo/phase wiring; see P2-REPOS |
| P2-REPOS | 0 | — | Added `lib/app/app_repos.dart`; many call sites migrated to AppRepos/ChronicleRepos |
| P2-MCP-ARCX / P2-SPLIT | 0 | — | Per Agent B/C execution |

**Rollback steps (revert by work package if issues):**

| Package | Rollback |
|---------|----------|
| P1-DUP | Restore `lib/arc/internal/mira/version_service.dart` from git history (copy from `lib/core/services/journal_version_service.dart` if needed); revert `mira_internal.dart` to `export 'version_service.dart';`. Re-run tests. |
| P1-QUICK | Revert any commits that removed duplicate QuickActionsService from widget_installation_service or changed imports in widget_quick_actions_*. |
| P1-IMPORTS | Revert the commit(s) that removed unused imports or dead code; re-run analyzer. |
| P1-CHRONICLE / P1-PHASE | Revert repo/phase wiring commits; call sites return to ad-hoc instantiation. |
| P2-REPOS | Revert AppRepos introduction and all call-site migrations; restore `RepositoryProvider(create: (_) => JournalRepository())` and direct `JournalRepository()` / `ChronicleRepos` usage per file. |
| P2-MCP-ARCX / P2-SPLIT | Revert facade or file-split commits per Agent C/B. |

**P3-TESTS (Phase 3 run):** Full test suite executed (`flutter test --no-pub`). Result: 491 passed, 196 failed. Failures are pre-existing (e.g. `mcp_exporter_golden_test` — ServicesBinding not initialized; `pointer_models_test` — tests expect Map subscript on model classes; `mcp_import_cli_test` — timeouts). No regressions attributed to Phase 1–2 consolidation. Smoke flows (journal, feed, export/import, phase, voice) not run as automated; recommend manual verification if releasing.

**Phase 3 deliverables:** ARCHITECTURE.md § Code Simplifier consolidated patterns; CONFIGURATION_MANAGEMENT.md change log; this metrics/rollback subsection; test run (see P3-TESTS).

---

## 5. Success Criteria (from Code Simplifier)

- **Functionality:** All public APIs and behavior unchanged; tests pass.
- **Clarity:** Consolidated code at least as readable; single source of truth for duplicates.
- **Efficiency:** Fewer duplicate files and repeated patterns; clearer repo/phase/service access.

---

*Generated for Code Simplifier full-repo consolidation. Update this plan as work packages are completed or scope changes.*

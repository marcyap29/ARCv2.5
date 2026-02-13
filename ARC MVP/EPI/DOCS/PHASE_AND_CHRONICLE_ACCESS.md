# Phase and Chronicle Service Access (P1 Consolidation)

**Source:** CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md P1-CHRONICLE, P1-PHASE  
**Goal:** Single access pattern for CHRONICLE repositories and phase services; avoid ad-hoc `new Layer0Repository()` or `PhaseRegimeService(analytics, rivet)` in many call sites.

---

## CHRONICLE repositories

Use **ChronicleRepos** (`lib/chronicle/core/chronicle_repos.dart`) instead of constructing repositories directly:

- **`ChronicleRepos.layer0`** — shared `Layer0Repository`
- **`ChronicleRepos.aggregation`** — shared `AggregationRepository`
- **`ChronicleRepos.changelog`** — shared `ChangelogRepository`
- **`ChronicleRepos.ensureLayer0Initialized()`** — call before using `layer0` if it must be ready immediately
- **`ChronicleRepos.initializedRepos`** — `Future<(Layer0Repository, AggregationRepository, ChangelogRepository)>`; use in factories that need all three with Layer0 already initialized

**Example:** `VeilChronicleFactory`, `ChronicleBackgroundTasksFactory`, and `ChronicleManagementView` use `await ChronicleRepos.initializedRepos` and pass the triple into `SynthesisEngine` or onboarding/export services.

---

## Phase services

### PhaseRegimeService

Use **PhaseServiceRegistry** (`lib/services/phase_service_registry.dart`) instead of constructing `PhaseRegimeService(AnalyticsService(), RivetSweepService(...))` in many places:

- **`await PhaseServiceRegistry.phaseRegimeService`** — returns the shared, initialized `PhaseRegimeService`. Prefer this when you need the service (e.g. in async methods, initState follow-ups).
- **`PhaseServiceRegistry.phaseRegimeServiceSync`** — returns the cached instance or `null` if not yet created; use only when you know the service has already been obtained (e.g. after app startup).

**Example:** `app.dart` (ARCX import handler), `home_view.dart` (voice phase), `timeline_cubit.dart`, `phase_analysis_settings_view.dart` use `PhaseServiceRegistry.phaseRegimeService`.

### UserPhaseService

`UserPhaseService` is used via static methods / notifiers (e.g. `UserPhaseService.phaseChangeNotifier`). No registry change in P1.

### ChatPhaseService

`ChatPhaseService` is created per chat session and depends on `ChatRepo`. Keep constructing it with `ChatPhaseService(chatRepo)` where a session-scoped instance is needed (e.g. `session_view.dart`, `lumara_assistant_cubit.dart`).

---

## Rollback

- **ChronicleRepos:** Revert commits that introduced `chronicle_repos.dart` and restored direct `Layer0Repository()` / `AggregationRepository()` / `ChangelogRepository()` in chronicle and integration call sites.
- **PhaseServiceRegistry:** Revert commits that introduced `phase_service_registry.dart` and restored direct `PhaseRegimeService(analytics, rivet)` in the migrated call sites.

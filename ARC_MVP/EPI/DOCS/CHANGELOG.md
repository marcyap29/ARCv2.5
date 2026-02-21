# EPI LUMARA MVP - Changelog

**Version:** 3.3.55
**Last Updated:** February 20, 2026

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.87 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [3.3.55] - February 20, 2026

### Repo directory rename (ARC MVP → ARC_MVP); prompt audit PROMPT_REFERENCES v2.7.0

- **Repo structure:** Directory renamed from `ARC MVP` (with space) to `ARC_MVP` (with underscore) — filesystem rename committed to git; no code changes.
- **Prompt audit:** `PROMPT_REFERENCES.md` v2.7.0 — added §1 ECHO On-Device LLM System Prompt (`lib/echo/providers/llm/prompt_templates.dart`; `PromptTemplates.systemPrompt`, task templates, few-shot examples). Previously untracked; used by ECHO Qwen/Gemma on-device adapter.
- **Docs:** CHANGELOG, CONFIGURATION_MANAGEMENT, PROMPT_TRACKER, bug_tracker updated.

**Files:** 1 directory renamed, 4 docs updated. bug_tracker tracked.

---

## [3.3.54] - February 19, 2026

### PDF content service; journal capture, CHRONICLE layer0, MCP orchestrators, media alt text, journal screen; pubspec

- **New:** `lib/core/services/pdf_content_service.dart`.
- **Journal / CHRONICLE:** `journal_capture_cubit.dart`, `journal_screen.dart`; `layer0_populator.dart` (CHRONICLE storage).
- **MCP:** `chat_multimodal_processor.dart`, `ios_vision_orchestrator.dart` (mira/store/mcp/orchestrator).
- **Media:** `media_alt_text_generator.dart` updates.
- **Dependencies:** `pubspec.yaml`, `pubspec.lock`, `.flutter-plugins-dependencies`.

**Files:** 8 modified, 1 new (pdf_content_service). bug_tracker tracked.

---

## [3.3.53] - February 19, 2026

### iOS project (Runner.xcodeproj/project.pbxproj)

- **iOS:** `Runner.xcodeproj/project.pbxproj` updates.

**Files:** 1 modified. bug_tracker tracked.

---

## [3.3.52] - February 19, 2026

### Google Drive sync folder push screen; Drive settings; unified feed; MCP export/management; DOCS checklist

- **Google Drive:** New `sync_folder_push_screen.dart` — push timeline entries (previously synced from Drive) back to the sync folder; `google_drive_service.dart`, `google_drive_settings_view.dart` updates.
- **Unified feed:** `unified_feed_screen.dart` updates.
- **MCP:** `mcp_export_screen.dart`, `mcp_management_screen.dart` updates.
- **DOCS:** CONFIGURATION_MANAGEMENT.md — documentation update checklist (PROMPT_TRACKER, bug_tracker, ARCHITECTURE); claude.md — Step 2 required-every-run note for PROMPT_TRACKER, bug_tracker, ARCHITECTURE.
- **iOS:** Runner.xcodeproj/project.pbxproj.

**Files:** 8 modified, 1 new (sync_folder_push_screen). bug_tracker tracked.

---

## [3.3.51] - February 19, 2026

### Journal capture, journal repository, dual CHRONICLE (agentic loop, dual_chronicle_view)

- **Journal:** `journal_capture_cubit.dart`, `journal_repository.dart` (lib/arc/internal/mira) updates.
- **Dual CHRONICLE:** `agentic_loop_orchestrator.dart`, `dual_chronicle_view.dart` updates.

**Files:** 4 modified. bug_tracker tracked.

---

## [3.3.50] - February 19, 2026

### Egress PII & LumaraInlineApi security tests; backend, auth, gemini_send, subscription, AssemblyAI

- **Security tests:** New `test/services/egress_pii_and_lumara_inline_test.dart` — egress PII scrubbing (PrismAdapter, PiiScrubber.rivetScrub); LumaraInlineApi softer/deeper reflection paths use scrubbed text only (addresses DevSecOps audit test gaps).
- **Backend:** `functions/index.js` updates.
- **Services:** `firebase_auth_service.dart`, `gemini_send.dart`, `subscription_service.dart`, `assemblyai_service.dart` refactors/updates.
- **DOCS:** `DEVSECOPS_SECURITY_AUDIT.md` — test coverage and assertions updated.

**Files:** 6 modified, 1 new (egress_pii_and_lumara_inline_test). bug_tracker tracked.

---

## [3.3.49] - February 19, 2026

### CHRONICLE layer0 retrieval, dual CHRONICLE/LUMARA, ARCX/MCP, DevSecOps audit; LumaraInlineApi PII fix

- **CHRONICLE:** New `lib/chronicle/layer0_retrieval/chronicle_layer0_retrieval_service.dart`. Dual CHRONICLE: `agentic_loop_orchestrator.dart`, `clarification_processor.dart`, `intelligence_summary_models.dart`, `lumara_chronicle_repository.dart`, `intelligence_summary_generator.dart`; `dual_chronicle_view.dart`, `intelligence_summary_view.dart`; `chronicle_phase_signal_service.dart`. New: `lumara_connection_fade_preferences.dart`.
- **LUMARA / prompts:** `lumara_assistant_cubit.dart`, `lumara_system_prompt.dart`, `prompt_library.dart`, `enhanced_lumara_api.dart`; `prompt_optimization_types.dart`, `universal_prompt_optimizer.dart`. **Security:** `lumara_inline_api.dart` — `generateSofterReflection` and `generateDeeperReflection` now pass scrubbed text to EnhancedLumaraApi (PII fix).
- **ARCX / MCP:** `arcx_manifest.dart`, `arcx_export_service_v2.dart`, `arcx_import_service_v2.dart`; `mcp_pack_export_service.dart`, `mcp_pack_import_service.dart`.
- **UI:** `current_phase_arcform_preview.dart`.
- **DOCS:** `DEVSECOPS_SECURITY_AUDIT.md` — audit run 2026-02-19; LumaraInlineApi PII fix and egress checklist updated.

**Files:** 22 modified, 2 new (layer0_retrieval_service, lumara_connection_fade_preferences). bug_tracker tracked.

---

## [3.3.48] - February 19, 2026

### Universal prompt optimization layer (80/20, provider-agnostic); enhanced_lumara_api

- **Prompt optimization:** New `lib/arc/chat/prompt_optimization/` — provider-agnostic optimization (smart context, structured output, response cache). Components: `universal_prompt_optimizer.dart`, `universal_response_generator.dart`, `provider_manager.dart`, `response_cache.dart`, `readiness_calculator.dart`, `prompt_optimization_types.dart`; providers: `provider_adapter.dart`, `groq_adapter.dart`, `openai_adapter.dart`, `claude_adapter.dart`; UI: `provider_settings_section.dart`. Use cases: userChat, userReflect, userVoice, gapClassification, patternExtraction, seekingDetection, intelligenceSummary, crisisDetection.
- **DOCS:** New `DOCS/UNIVERSAL_PROMPT_OPTIMIZATION.md` (80/20 framework, architecture, code locations, use cases, integration).
- **LUMARA API:** `enhanced_lumara_api.dart` updated for optimization layer integration.

**Files:** 1 modified (enhanced_lumara_api), 1 new DOCS, 12 new (prompt_optimization/). bug_tracker tracked.

---

## [3.3.47] - February 18, 2026

### Dual CHRONICLE refactor, intelligence summary, search, prompts, phase/Arcform, bugtracker index/audit

- **Dual CHRONICLE:** `user_chronicle_repository.dart` removed (replaced by adapter/query path); `chronicle_dual.dart`, `agentic_loop_orchestrator.dart`, `dual_chronicle_services.dart`, `intelligence_summary_generator.dart`, `intelligence_summary_repository.dart`, `promotion_service.dart`; `gap_analyzer.dart`, `clarification_processor.dart`; `chronicle_models.dart`. New: `chronicle_query_adapter.dart`, `intelligence_summary_schedule_preferences.dart`, `lumara_comments_loader.dart`; `chronicle_phase_signal_service.dart`, `lumara_comments_context_loader.dart`. `dual_chronicle_view.dart`, `intelligence_summary_view.dart` extended. Sacred separation test simplified.
- **CHRONICLE search:** `chronicle_rerank_service.dart`, `chronicle_search.dart`, `feature_based_reranker.dart`, `hybrid_search_engine.dart` updates.
- **LUMARA / prompts:** `lumara_master_prompt.dart`, `enhanced_lumara_api.dart`; `lumara_onboarding_screen.dart`, `lumara_settings_welcome_screen.dart`; `PROMPT_REFERENCES.md` extended (+104).
- **Phase / Arcform:** `phase_colors.dart`, `phase_regime_service.dart`, `rivet_sweep_service.dart`; `phase_analysis_view.dart`, `phase_analysis_settings_view.dart`; `simplified_arcform_view_3d.dart`, `animated_arcform_view.dart`.
- **Settings / home / drive:** `settings_view.dart`, `simplified_settings_view.dart`, `google_drive_settings_view.dart`, `drive_folder_picker_screen.dart`, `home_view.dart`; `journal_capture_view_*`, `notification_service.dart`.
- **DOCS:** `CHRONICLE_COMPLETE.md`, `LUMARA_DEFINITIVE_OVERVIEW.md`, `LUMARA_DUAL_CHRONICLE_GUIDE.md` updates. Bugtracker: new `BUGTRACKER_MASTER_INDEX.md`, `BUGTRACKER_AUDIT_REPORT.md`. iOS project file updates.

**Files:** 42 modified, 1 deleted (user_chronicle_repository), 6+ new (adapters, loaders, schedule prefs, chat_draft_viewer_screen; bugtracker index/audit). bug_tracker tracked.

---

## [3.3.46] - February 18, 2026

### Google Drive folder picker, local backup settings, home; DOCS cleanup (redundant Dual Chronicle docs removed)

- **Backup/Drive:** `google_drive_service.dart` (+25); `drive_folder_picker_screen.dart` extended (+99); `local_backup_settings_view.dart` refactor (+51/−16); `home_view.dart` (+35). Drive folder selection and local backup settings UI.
- **DOCS cleanup:** Removed redundant `LUMARA_DUAL_CHRONICLE_COMPLETE_GUIDE.md`, `LUMARA_DUAL_CHRONICLE_IMPLEMENTATION.md`, `LUMARA_DUAL_CHRONICLE_WHEN_TO_ACTIVATE.md` from DOCS (superseded by `LUMARA_DUAL_CHRONICLE_GUIDE.md`; originals remain in `DOCS/archive/`).

**Files:** 4 modified, 3 DOCS deleted (redundant Dual Chronicle docs). bug_tracker tracked.

---

## [3.3.45] - February 18, 2026

### Dual CHRONICLE intelligence summary, settings, DOCS LUMARA definitive overview

- **Dual CHRONICLE:** Intelligence summary — new `intelligence_summary_models.dart`, `intelligence_summary_repository.dart`, `intelligence_summary_generator.dart`; new `intelligence_summary_view.dart`. `dual_chronicle_view.dart` extended (+356/−74); `agentic_loop_orchestrator.dart`, `dual_chronicle_services.dart`, `chronicle_dual.dart` updates. Settings: `settings_view.dart` (+14) for Timeline & Learning.
- **DOCS:** New `LUMARA_DEFINITIVE_OVERVIEW.md`.

**Files:** 5 modified, 4 new (lib/chronicle/dual/models, repositories, services; lib/shared/ui/chronicle), 1 new DOCS. bug_tracker tracked.

---

## [3.3.44] - February 18, 2026

### CHRONICLE search (hybrid/BM25/semantic), unified feed, Arcform 3D, archive doc

- **CHRONICLE search:** New `lib/chronicle/search/` — `chronicle_search.dart`, `hybrid_search_engine.dart`, `bm25_index.dart`, `semantic_index.dart`, `adaptive_fusion_engine.dart`, `chronicle_rerank_service.dart`, `feature_based_reranker.dart`, `rerank_context_builder.dart`, `chronicle_search_models.dart`. Hybrid search and reranking for CHRONICLE context.
- **Unified feed:** `unified_feed_screen.dart` extended (+57/−3).
- **Arcform 3D:** `simplified_arcform_view_3d.dart` refactor (+68/−31).
- **DOCS:** `DOCS/archive/LUMARA_ARCHITECTURE_SECTION.md` minor update.

**Files:** 3 modified, 9 new (lib/chronicle/search/). bug_tracker tracked.

---

## [3.3.43] - February 17, 2026

### Dual CHRONICLE UI, LUMARA assistant, journal capture, onboarding, unified feed

- **Dual CHRONICLE:** `dual_chronicle_view.dart` extended (+311); `agentic_loop_orchestrator.dart`, `chronicle_models.dart`, `lumara_chronicle_repository.dart`, `dual_chronicle_services.dart` updates (+96 net). Timeline & Learning (Dual Chronicle) UI and service wiring.
- **LUMARA assistant:** `lumara_assistant_cubit.dart` extended (+117) — cubit logic and state.
- **Journal capture:** `journal_capture_cubit.dart` (+55), `journal_capture_view.dart` (core + ui) updates.
- **Unified feed:** `unified_feed_screen.dart` refactor (+187/−91).
- **Home & onboarding:** `home_view.dart`, `arc_onboarding_sequence.dart` updates; `ONBOARDING_TEXT.md` updated.

**Files:** 13 modified (DOCS/ONBOARDING_TEXT; lib/arc/chat/bloc, core, ui, unified_feed; lib/chronicle/dual; lib/shared/ui/chronicle, home, onboarding). bug_tracker tracked.

---

## [3.3.42] - February 17, 2026

### Docs: consolidation refs, ARCHITECTURE paper/archive ref, LaTeX artifacts gitignore

- **ARCHITECTURE.md:** Paper §2 reference updated — formal source `NARRATIVE_INTELLIGENCE_WHITE_PAPER.tex` (§2); repo-aligned draft archived at `DOCS/archive/NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION.md`.
- **NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION.md:** Removed from DOCS (content in .tex §2 and archive).
- **LUMARA_ARCHITECTURE_SECTION.md:** Alignment with ARCHITECTURE.md confirmed; already in DOCS/archive.
- **.gitignore:** LaTeX build artifacts — added `*.synctex.gz` and comment (regenerate with pdflatex/latexmk).
- **bug_tracker:** Tracked for v3.3.42 doc sync.

**Files:** DOCS only (.gitignore, ARCHITECTURE, CONFIGURATION_MANAGEMENT, CHANGELOG, bug_tracker, PROMPT_TRACKER; NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION deleted).

---

## [3.3.41] - February 17, 2026

### Dual CHRONICLE, Writing with LUMARA screen, timeline/feed/settings, white paper .tex

- **Dual CHRONICLE:** New `lib/chronicle/dual/` (chronicle_dual, intelligence, models, repositories, services, storage); new `lib/shared/ui/chronicle/dual_chronicle_view.dart`; new `test/chronicle/dual/sacred_separation_test.dart`. DOCS: LUMARA_DUAL_CHRONICLE_GUIDE.md (consolidated; prior COMPLETE_GUIDE, IMPLEMENTATION, WHEN_TO_ACTIVATE archived).
- **Writing with LUMARA:** New `writing_with_lumara_screen.dart`; `chat_draft_viewer_screen.dart` removed. Writing screen and writing agent/draft_composer/writing_models updates.
- **Timeline:** `timeline_cubit.dart`, `timeline_entry_model.dart`, `timeline_view.dart`, `interactive_timeline_view.dart` extended (+185 net interactive_timeline_view).
- **Unified feed:** `feed_entry.dart`, `feed_repository.dart`, `feed_helpers.dart`, `expanded_entry_view.dart`, `unified_feed_screen.dart` updates.
- **Settings & journal:** `settings_view.dart`, `journal_screen.dart`; `lumara_assistant_screen.dart`, `research_screen.dart`, `writing_screen.dart`; `agents_screen.dart` minor.
- **DOCS:** NARRATIVE_INTELLIGENCE_WHITE_PAPER.tex updated (content/restructure).

**Files:** 21 modified, 1 deleted (chat_draft_viewer_screen); 3 new DOCS (LUMARA_DUAL_CHRONICLE_*); new lib/chronicle/dual/, dual_chronicle_view, writing_with_lumara_screen, test/chronicle/dual/. bug_tracker tracked.

---

## [3.3.40] - February 16, 2026

### LUMARA agents expansion, Narrative Intelligence paper (.tex), chats/settings, orchestration

- **Agents screen:** `agents_screen.dart` major extension (+475 net) — expanded UI and flows for agents tab.
- **Chats:** `saved_chats_screen.dart` extended (+267 net); `enhanced_chats_screen.dart` updates (+76 net).
- **LUMARA settings:** `lumara_settings_screen.dart` extended (+132 net); `lumara_reflection_settings_service.dart` (+51); `lumara_assistant_screen.dart` updates.
- **Orchestrator & intent:** `chat_intent_classifier.dart`, `lumara_chat_orchestrator.dart` updates; new `lumara_intent_classifier.dart`; new `orchestration_violation_checker.dart`.
- **Research/writing agents:** `research_agent.dart`, `research_prompts.dart`, `synthesis_engine.dart`; `writing_agent.dart`, `writing_prompts.dart`, `draft_composer.dart` updates.
- **Arc agents drafts:** New `lib/arc/agents/drafts/` — `agent_draft.dart`, `draft_repository.dart`, `new_draft_screen.dart`; new `lib/lumara/agents/prompts/agent_operating_system_prompt.dart`.
- **Unified feed:** `unified_feed_screen.dart` minor updates; `research_screen.dart`, `writing_screen.dart` small tweaks.
- **DOCS:** `NARRATIVE_INTELLIGENCE_WHITE_PAPER.md` and `NARRATIVE_INTELLIGENCE_PAPER_COMPARISON.md` removed; `NARRATIVE_INTELLIGENCE_WHITE_PAPER.tex` added (LaTeX source for paper). `PROMPT_REFERENCES.md` updated (+77).

**Files:** 22 modified, 2 deleted (DOCS .md), 7 new (.tex, arc/agents/drafts, lumara_intent_classifier, agent_operating_system_prompt, orchestration_violation_checker). bug_tracker tracked.

---

## [3.3.39] - February 15, 2026

### LUMARA agents: research/writing prompts expansion, screen and tab refinements

- **Research prompts:** `research_prompts.dart` extended (+148 lines) — expanded prompt definitions for research agent.
- **Writing prompts:** `writing_prompts.dart` extended (+150 lines) — expanded prompt definitions for writing agent.
- **Research screen:** `research_screen.dart` updates (+81 net) — UI and flow refinements.
- **Writing screen:** `writing_screen.dart` updates (+54 net) — UI and flow refinements.
- **Research Agent tab:** `research_agent_tab.dart` refinements (+75 net).
- **LUMARA assistant cubit:** `lumara_assistant_cubit.dart` updates (+39 net).
- **Agents screen:** `agents_screen.dart` minor updates (+10 net).

**Files:** 7 modified (research_prompts, writing_prompts, research_screen, writing_screen, research_agent_tab, lumara_assistant_cubit, agents_screen). bug_tracker tracked.

---

## [3.3.38] - February 15, 2026

### LUMARA agents: writing drafts storage, research persistence, archive/delete UI, ARCX export/import

- **Writing drafts:** `WritingDraftRepository` extended with `listDrafts`, `getDraft`, `markFinished`, `archiveDraft`, `unarchiveDraft`, `deleteDraft`. File-based storage under `writing_drafts/{userId}/{draftId}.md` with frontmatter (status, archived, archived_at). `WritingDraftRepositoryImpl` used in WritingScreen, EnhancedLumaraApi, LumaraAssistantCubit so composed drafts are stored.
- **Writing UI:** `AgentsChronicleService.getContentDrafts` wired to writing repo; `ContentDraft` extended (createdAt, status, archived, wordCount). Writing Agent tab: Active/Archived sections, card actions (Mark finished, Archive/Unarchive, Delete with confirm), Created date and metadata.
- **Research persistence:** `ResearchArtifactRepository` singleton with JSON file persistence (`research_artifacts.json`); `StoredResearchArtifact` gains archived/archivedAt; `listForUser`, `listAllForExport`, `replaceAllForImport`, `archiveArtifact`, `unarchiveArtifact`, `deleteArtifact`. `getResearchReports` wired to repo; archive/delete/unarchive service methods.
- **Research UI:** Research Agent tab: Active/Archived sections; card menu Archive/Unarchive/Delete (with confirm); "Created" date; `ResearchReport` gains archived/archivedAt.
- **ARCX export/import:** `_exportAgentsData` copies `writing_drafts/` tree and serializes research artifacts to `payload/extensions/agents/`. `_importAgentsData` restores writing_drafts and loads research_artifacts.json. Called after voice notes in all export flows; import after voice notes.

**Files:** 17 modified (writing/repository, agents_chronicle_service, content_draft, research_models, research_artifact_repository, writing_agent_tab, research_agent_tab, content_draft_card, research_report_card, writing_screen, enhanced_lumara_api, lumara_assistant_cubit, arcx_export/import_service_v2), 1 new (lumara_cloud_generate). bug_tracker tracked.

---

## [3.3.37] - February 15, 2026

### LUMARA agents: research/writing prompts, timeline context, synthesis and draft updates

- **Research agent:** `research_agent.dart`, `synthesis_engine.dart` updates; new `research_prompts.dart` — prompt definitions for research agent.
- **Writing agent:** `draft_composer.dart` extended (+265 net), `writing_agent.dart`, `writing_models.dart`; new `writing_prompts.dart` — prompt definitions for writing agent.
- **Writing screen:** `writing_screen.dart` updates (+66 net).
- **Timeline context:** New `timeline_context_service.dart` — supplies timeline/journal context for agents.

**Files:** 6 modified (writing_screen, research_agent, synthesis_engine, draft_composer, writing_agent, writing_models), 3 new (research_prompts, writing_prompts, timeline_context_service).

---

## [3.3.36] - February 15, 2026

### LUMARA agents screen, connection service, and bug tracker

- **Agents screen:** `agents_screen.dart` extended (+230 net) — UI and behavior for agents tab.
- **Agents connection service:** New `agents_connection_service.dart` — connection/wiring for LUMARA agents.
- **Bug tracker:** New record `build-fixes-session-feb-2026.md` (session consolidation: AppLifecycleState import, FeedRepository type errors, _buildRunAnalysisCard scope). Index and record count updated to 35; version 3.2.6.

**Files:** 2 modified (agents_screen, bug_tracker.md), 2 new (agents_connection_service, bug record).

---

## [3.3.35] - February 15, 2026

### LUMARA agents, orchestrator, CHRONICLE alignment, and settings refactor

- **LUMARA agents:** New `lib/lumara/agents/` — research agent (query planner, search orchestrator, synthesis engine, CHRONICLE cross-reference, citation manager, web search tool), writing subsystem, content drafts; screens: `agents_tab_view`, `research_screen`, `writing_screen`, `writing_with_lumara_screen`; `chronicle_theme_ignore_list_storage`. Orchestrator: `lumara_chat_orchestrator`, `chat_intent_classifier`, `research_report_adapter`.
- **LUMARA chat/settings:** `lumara_assistant_cubit` (+169), `lumara_assistant_screen`, `enhanced_lumara_api`; `lumara_settings_screen` major simplification (~-900 lines). Wispr/transcription config tweaks.
- **CHRONICLE:** `chronicle_index` (+38), `pattern_query_router`, `related_entries_service`, `aggregation_repository`, `layer0_repository`; `pattern_index_viewer` updates. Intent/orchestrator: `intent_type`, `command_parser`.
- **Home/settings:** `home_view`, `settings_view` minor updates.
- **Documentation:** New `CHRONICLE_PAPER_VS_IMPLEMENTATION.md` (paper vs codebase alignment); `CHRONICLE-2026_02_15.md`.

**Files:** 16 modified, multiple new (agents/, screens, chronicle_theme_ignore_list_storage, orchestrator/classifier/adapter, writing_subsystem; 2 DOCS).

---

## [3.3.34] - February 15, 2026

### LUMARA API, control state, and CHRONICLE query stack

- **EnhancedLumaraApi:** Updates in `enhanced_lumara_api.dart` (+34 lines) — LUMARA API integration.
- **LumaraControlStateBuilder:** Further extension in `lumara_control_state_builder.dart` (+86 net) — control state construction.
- **CHRONICLE query:** `query_plan.dart` (+17 net), `context_builder.dart` refactor (+100 net), `query_router.dart` (+123 net) — query planning, context building, and routing.
- **Docs:** `NARRATIVE_INTELLIGENCE_OVERVIEW.md` minor edit.

**Files:** 6 modified (DOCS, enhanced_lumara_api, lumara_control_state_builder, query_plan, context_builder, query_router).

---

## [3.3.33] - February 15, 2026

### Master prompt, control state, and Narrative Intelligence docs

- **LUMARA master prompt:** Significant expansion in `lumara_master_prompt.dart` (+~560 lines) — identity, control state block, CHRONICLE/vectorization integration, mode-dependent context injection.
- **LumaraControlStateBuilder:** Extended in `lumara_control_state_builder.dart` (+82 lines) — control state JSON structure and sources (atlas, veil, favorites, prism, therapy, engagement, responseMode, memory, webAccess).
- **Documentation:** New `MASTER_PROMPT_CHRONICLE_VECTORIZATION.md` — single reference for master prompt build, contents, CHRONICLE and vectorization integration. New `NARRATIVE_INTELLIGENCE_OVERVIEW.md` — high-level overview of Narrative Intelligence and LUMARA for general audience.

**Files:** 2 modified (lumara_master_prompt.dart, lumara_control_state_builder.dart), 2 new (DOCS).

---

## [3.3.32] - February 15, 2026

### Unified feed expanded entry and CHRONICLE related entries

- **ExpandedEntryView:** Significant updates to unified feed expanded entry widget (layout, behavior).
- **RelatedEntriesService:** CHRONICLE related-entries logic extended (+38 lines).

**Files:** 2 modified (`expanded_entry_view.dart`, `related_entries_service.dart`).

---

## [3.3.31] - February 15, 2026

### Voice Moonshine spec, transcription cleanup, unified feed and narrative docs

- **Voice transcription:** New spec `VOICE_TRANSCRIPTION_MOONSHINE_SPEC.md` — Apple On-Device Speech primary; Wispr Flow optional; mandatory cleanup pass (filler words, misrecognitions) before PRISM. `TranscriptCleanupService` added; `UnifiedTranscriptionService` and voice session/timeline storage updated. Voice mode screen refactor.
- **Unified feed:** `FeedEntry`, `feed_helpers`, `ExpandedEntryView`, `UnifiedFeedScreen` and `HomeView` updates for feed behavior and navigation.
- **Narrative Intelligence:** `NARRATIVE_INTELLIGENCE_WHITE_PAPER.md` edits.
- **iOS:** Moonshine on-device models removed from repo (see .gitignore); Runner/project references retained.
**Files:** 17 changed (DOCS, lib voice/transcription/cleanup, unified_feed, home_view; iOS project).

---

## [3.3.30] - February 14, 2026 (working)

### Phase Check-In enhancements

- **PhaseCheckInService:** Configurable interval — user can choose 14, 30, or 60 days between check-ins (SharedPreferences `phase_check_in_interval_days`). Default remains 30. `getCurrentPhaseName()` now uses display-phase logic (profile first, then regime; RIVET gate respected) via PhaseServiceRegistry/RIVET.
- **Phase Analysis Settings:** Phase Check-in card extended with interval selector (14/30/60 days) and description.
- **Settings / Timeline / Feed / CHRONICLE:** Local backup settings view refactor; settings_view, simplified_settings_view expanded; timeline_view, timeline_with_ideas_view, and interactive_timeline_view updates; expanded_entry_view and unified_feed_screen improvements; chronicle_layers_viewer enhancements. Journal capture cubit and journal_repository minor cleanup.

### Documentation

- **Narrative Intelligence paper:** New `NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION.md` (§2 System Architecture for paper/PDF) and `NARRATIVE_INTELLIGENCE_PAPER_COMPARISON.md` (paper vs repo alignment). White paper edits in `NARRATIVE_INTELLIGENCE_WHITE_PAPER.md`.

**Files (uncommitted):** 15 modified (DOCS, lib phase_check_in_service, settings, timeline incl. interactive_timeline_view, feed, chronicle_layers_viewer, journal_capture_cubit, journal_repository), 2 new (narrative paper docs).

---

## [3.3.29] - February 13, 2026

### Phase Check-In (monthly phase recalibration)

- **PhaseCheckInService** (`lib/services/phase_check_in_service.dart`): Singleton service for monthly phase check-in. Tracks last check-in and reminder preference (SharedPreferences). Check-in due when reminder enabled, 30 days since last (or account creation), and not dismissed in last 7 days.
- **PhaseCheckIn model** (`lib/models/phase_check_in_model.dart` + `.g.dart`): Hive model for check-in records (phase, timestamp, etc.). Registered in bootstrap.
- **Phase Check-in bottom sheet** (`lib/ui/phase/phase_check_in_bottom_sheet.dart`): UI to confirm current phase or run 3-question diagnostic; integrates with PhaseCheckInService and CHRONICLE/phase stack.
- **HomeView:** Shows phase check-in bottom sheet once per session when due (2s delay after init).
- **Phase Analysis Settings:** New "Phase Check-in" card with toggle "Show reminder when due" and description; uses PhaseCheckInService for preference.

### Bugtracker and build / environment

- **Bug records (2 new):** [ios-build-rivet-models-keywords-set-type.md](bugtracker/records/ios-build-rivet-models-keywords-set-type.md) — iOS build fix for `rivet_models.g.dart` keywords `List` vs `Set<String>` (`.toSet()` in read). [ollama-serve-address-in-use-and-quit-command.md](bugtracker/records/ollama-serve-address-in-use-and-quit-command.md) — Ollama port 11434 in use; `ollama quit` not recognized.
- **bug_tracker.md:** Version 3.2.5; 34 records; index and Recent code changes table updated. ios-release-build-third-party-warnings record updated.
- **RIVET:** `rivet_models.g.dart` fix (keywords type) as per bug record.

### Google Drive and settings

- **Google Drive:** `google_drive_service.dart`, `drive_folder_picker_screen.dart`, `google_drive_settings_view.dart` — updates (folder picker and settings behavior).
- **Ollama:** `ollama_config.g.dart` (generated) added under chat services.

**Files:** 13 modified, 7 new (phase_check_in model/service/UI, 2 bug records, ollama_config.g). Excludes .DS_Store and .flutter-plugins-dependencies.

---

## [3.3.28] - February 13, 2026

### Code Simplifier Phase 1 execution (consolidation & cleanup)

**Removed / consolidated:**
- **`lib/arc/internal/mira/version_service.dart`** — Deleted (~1.3k lines). Version management is canonical in `lib/core/services/journal_version_service.dart`; `mira_internal.dart` now re-exports the core service (P1-DUP per CODE_SIMPLIFIER_CONSOLIDATION_PLAN).
- **`lib/services/firestore_service.dart`** — Removed (dead/unused code per P1-IMPORTS).

**New / refactored:**
- **App repos & phase registry:** `lib/app/app_repos.dart`, `lib/services/app_repos.dart`, `lib/services/phase_service_registry.dart` — Centralized repository and phase-service access (P2-REPOS / P1-PHASE).
- **Settings consolidation:** `advanced_settings_view.dart` significantly reduced; shared patterns moved to `settings_common.dart`. `chronicle_management_view.dart`, `phase_analysis_settings_view.dart`, `simplified_settings_view.dart`, `settings_view.dart` updated for consistent structure.
- **QuickActionsService:** Single source in `quick_actions_service.dart`; `widget_installation_service.dart` duplicate removed (P1-QUICK).
- **CHRONICLE:** New `lib/chronicle/core/`, `lib/chronicle/related_entries_service.dart`; `veil_chronicle_factory.dart`, `background_tasks.dart` updates.
- **Docs:** `CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md`, `PHASE_AND_CHRONICLE_ACCESS.md`, `Orchestrator Plan Templates/` added under DOCS.

**Touched (imports, wiring, minor):** LUMARA chat/cubit, enhanced_lumara_api, context_provider, voice/journal services, MIRA/memory services, ARCX/MCP services, timeline_cubit, journal_capture views, expanded_entry_view, universal_importer_service, home_view, phase_quiz_v2_screen, privacy_settings_view, journal_screen, and ~30 other files (cleanup, re-exports, repo/phase access).

**Files:** 60 modified, 2 deleted, several new (app_repos, phase_service_registry, settings_common, chronicle/core, related_entries_service, DOCS additions). Net line reduction from duplicate removal and settings consolidation.

---

## [3.3.27] - February 13, 2026 (working changes)

### ARCHITECTURE.md Module Naming Refactor

**`ARCHITECTURE.md`:**
- Module 1 renamed **ARC** → **LUMARA** (`lib/arc/`). Clarified as the user-facing timeline and interface (journaling, chat, Arcform) — not a peer subsystem in the LUMARA orchestration spine. Data flows from this interface into CHRONICLE (Layer 0) and is consumed by the Orchestrator via CHRONICLE and ATLAS.
- Module 3 renamed **MIRA** → **CHRONICLE** (`lib/chronicle/`, storage: `lib/mira/`). Now explicitly covers longitudinal memory, synthesis, and **on-device vector generation** (embeddings). Submodules list updated to include `embeddings/`, `index/`, `query/`, `synthesis/`, `storage/`, `scheduling/`. Key features rewritten: Layer 0, vector generation, context selection, MCP/ARCX.
- System diagram updated: ARC→LUMARA (interface), MIRA→CHRONICLE with storage/synthesis/embeddings nodes.
- All references (entry creation flow, export/import flow, APIs, test structure) updated from ARC/MIRA to LUMARA/CHRONICLE.
- Executive Summary reworded: "5-module architecture: LUMARA (interface), PRISM, CHRONICLE, AURORA, ECHO".

### Pattern Index (Vectorizer) Integration into Orchestrator

**`enhanced_lumara_api.dart`:**
- During CHRONICLE initialization, now creates `PatternQueryRouter` from `LocalEmbeddingService` + `ChronicleIndexStorage` + `ChronicleIndexBuilder` + `ThreeStagePatternMatcher`.
- Passes `patternQueryRouter` to `ChronicleSubsystem` constructor.

**`chronicle_subsystem.dart`:**
- New optional `PatternQueryRouter? patternQueryRouter` parameter.
- For pattern-like intents (`patternAnalysis`, `developmentalArc`, `historicalParallel`), runs vectorizer query and merges result into CHRONICLE context via `<chronicle_pattern_index>` tags.
- When query router says `usesChronicle: false` but pattern index returns results, still returns that context.

### VEIL-CHRONICLE Scheduler Starts at App Launch

**`home_view.dart`:**
- `_startVeilChronicleScheduler()` called via `addPostFrameCallback` at `HomeView` init.
- Uses `VeilChronicleFactory.createAndStart()` with `SynthesisTier.premium`. First run at midnight; subsequent runs follow user cadence preference.

### Pattern Index UI and Timestamp Tracking

**New: `lib/chronicle/storage/pattern_index_last_updated.dart`**
- `PatternIndexLastUpdatedStorage`: SharedPreferences persistence for last pattern index update timestamp per user.

**`synthesis_scheduler.dart`:**
- After updating pattern index, saves timestamp via `PatternIndexLastUpdatedStorage.setLastUpdated()`.

**`chronicle_management_view.dart`:**
- New "Pattern index (vectorizer)" section: shows last updated timestamp, error state, and "Update pattern index now" button for manual rebuild from existing monthly aggregations.
- After full onboarding completes, automatically triggers `_updatePatternIndexNow()`.

### Narrative Intelligence White Paper

**New: `DOCS/NARRATIVE_INTELLIGENCE_WHITE_PAPER.md`**
- Comprehensive white paper describing the Narrative Intelligence framework: architecture (LUMARA, Narrative Intelligence modules, CHRONICLE memory), VEIL cycle, five-module breakdown, subsystem spine (ARC, ATLAS, CHRONICLE, AURORA), vector generation, intellectual honesty, Crossroads decision capture, and implementation status.

**Files changed (7 modified + 2 new):**
- `docs/ARCHITECTURE.md` — Module naming refactor (ARC→LUMARA, MIRA→CHRONICLE)
- `lib/arc/chat/services/enhanced_lumara_api.dart` — PatternQueryRouter in Orchestrator
- `lib/chronicle/scheduling/synthesis_scheduler.dart` — Pattern index timestamp
- `lib/chronicle/storage/pattern_index_last_updated.dart` (NEW)
- `lib/lumara/subsystems/chronicle_subsystem.dart` — Vectorizer integration
- `lib/shared/ui/home/home_view.dart` — VEIL-CHRONICLE scheduler at launch
- `lib/shared/ui/settings/chronicle_management_view.dart` — Pattern index UI
- `DOCS/NARRATIVE_INTELLIGENCE_WHITE_PAPER.md` (NEW)

### Documentation sync (prompt audit, config management)

**2026-02-13:** Ran Documentation, Configuration Management and Git Backup workflow. PROMPT REFERENCES AUDIT: added §20 Quick Answers / MMCO Polish to PROMPT_REFERENCES.md (v2.3.0). PROMPT_TRACKER v1.4.0; CONFIGURATION_MANAGEMENT change log updated.

### Documentation sync (claude.md, bugtracker)

**`DOCS/claude.md`:**
- Table of Contents — Prompts: added section with links to all prompt blocks (Documentation/Config/Git Backup, Code Simplifier, Bugtracker Consolidation, DevSecOps). TOC updated to reflect current document (Code Consolidation prompt removed; section names aligned).

**`DOCS/bugtracker/`:**
- **bug_tracker.md** (v3.2.4): 32 records; Build & Platform section and Recent code changes table updated.
- **records/** (3 new): `ios-build-local-embedding-service-errors.md`, `ios-build-native-embedding-channel-swift-scope.md`, `ios-release-build-third-party-warnings.md` — iOS release build and CHRONICLE embedding stack issues (Dart type/parse, Swift NativeEmbeddingChannel scope, third-party warnings).

---

## [3.3.26] - February 13, 2026 (working changes)

### Crossroads Decision Capture System

New subsystem for capturing life decisions at the moment they surface in conversation, storing them in CHRONICLE, and revisiting outcomes later.

**New directory: `lib/crossroads/`**
- `CrossroadsService`: Manages the four-prompt capture flow (What are you deciding? → Life context → Real options → What success looks like), saves complete/partial captures, schedules outcome revisitation, and builds confirmation/revisitation prompts.
- `CrossroadsCaptureStep` enum: `none`, `prompt1`–`prompt4`, `complete`.
- `CrossroadsCaptureState`: In-memory state for a capture session.
- `PendingOutcomeStore`: SharedPreferences-based storage for due outcome prompt IDs.

**New: `lib/crossroads/models/decision_capture.dart`**
- `DecisionCapture` Hive model: `decisionStatement`, `lifeContext`, `optionsConsidered`, `successMarker`, `outcomeLog`, `outcomeLoggedAt`, `phaseAtCapture`, `sentinelScoreAtCapture`, `triggerConfidence`, `triggerPhrase`, `userInitiated`, `linkedJournalEntryId`.
- `DecisionOutcomePrompt` Hive model: scheduled outcome revisitation with `dueDate`.

**New: `lib/crossroads/storage/decision_capture_repository.dart`**
- Hive-backed CRUD for `DecisionCapture` and `DecisionOutcomePrompt`.

**New: `lib/prism/atlas/rivet/rivet_decision_analyzer.dart`**
- `RivetDecisionAnalyzer`: Phrase-based detection of decision moments in chat messages. Five phrase categories (`consideration`, `activeChoice`, `seekingOpinion`, `actionFraming`, `futureWeighing`) with phase-weighted confidence. Phase sensitivity: Transition 0.90 → Discovery 0.45 → Recovery 0.35.

**`rivet_models.dart` (extended):**
- `DecisionPhraseCategory` enum, `DecisionTriggerSignal` (phraseCategory, detectedPhrase, currentPhase, phaseWeight, phraseWeight, rawMessageContext).
- `RivetOutputType` enum (`phaseTransition`, `decisionTrigger`), `RivetOutput` class unifying transition and decision signals.

**`lumara_assistant_cubit.dart` (Crossroads integration):**
- `LumaraAssistantLoaded` state extended: `pendingCrossroadsSignal`, `pendingCrossroadsConfirmationText`, `pendingCrossroadsUserMessage`, `crossroadsCaptureStep`, `crossroadsCapturePromptText`, `pendingOutcomeCapture`. Convenience methods `clearedCrossroadsPending()`, `clearedCrossroadsCapture()`, `clearedPendingOutcome()`.
- Decision trigger detection runs per turn before sending to LLM. If RIVET detects a decision moment and `shouldSurfaceCrossroadsPrompt()` returns true, emits confirmation state (pausing the message).
- `acceptCrossroadsConfirmation()`: Starts four-prompt capture flow.
- `declineCrossroadsConfirmation()`: Clears pending and sends original message normally.
- `submitCrossroadsAnswer()`: Advances capture step; on completion, saves to Hive via `CrossroadsService` and populates CHRONICLE Layer 0.
- `cancelCrossroadsCapture()`: Saves partial capture.
- `checkPendingOutcomePrompt()`: At conversation start, checks for due outcome revisitation.
- `submitOutcomeResponse()`: Logs outcome text to the decision capture.

**`lumara_assistant_screen.dart` (Crossroads UI):**
- `_buildCrossroadsConfirmationCard()`: Yes/No card replacing input bar when a decision trigger is detected.
- Send flow routes to `submitCrossroadsAnswer()` during capture, `submitOutcomeResponse()` for outcome revisitation.
- Input hint adapts: "Your answer..." (capture), "How did it turn out?..." (outcome), "Ask LUMARA anything..." (normal).
- `checkPendingOutcomePrompt()` called via `addPostFrameCallback` at screen load.

**`bootstrap.dart`:**
- Registered `DecisionCaptureAdapter` (Hive ID 118) and `DecisionOutcomePromptAdapter` (Hive ID 119).

**CHRONICLE Layer 0 integration:**
- `layer0_populator.dart`: New `populateFromDecisionCapture()` — writes decision captures as `entry_type: "decision"` entries with full `decision_data` in analysis.
- `raw_entry_schema.dart`: New `ChronicleEntryType` enum (`journal`, `decision`). `RawEntryAnalysis` gains `entryType` and `decisionData` fields; `isDecision` helper getter.

**Monthly synthesis (`monthly_synthesizer.dart`):**
- Decision entries extracted separately and formatted via `_formatDecisionCapturesForSynthesis()`.
- Narrative prompt includes "DECISION CAPTURES this month" section; instructions treat them as inflection-point markers.
- Monthly markdown gains "Decision captures (Crossroads)" section.

**CHRONICLE query (`query_router.dart`, `query_plan.dart`):**
- New `QueryIntent.decisionArchaeology`: "What decisions have I made about X?"
- Routes to Layer 0 + monthly aggregations.
- System prompt: "List what the user decided, when, and (if available) what the outcome was."

**CHRONICLE export (`chronicle_export_service.dart`):**
- New `decisions/` directory in export. Each decision exported as YAML+markdown (`_buildDecisionMarkdown()`).
- `ChronicleExportResult` gains `decisionsCount`.

**VEIL scheduler (`veil_chronicle_scheduler.dart`):**
- Nightly cycle now runs `CrossroadsService().checkDueOutcomePrompts(userId)` for outcome revisitation.

### LUMARA Intellectual Honesty / Pushback System

New system enabling LUMARA to gently push back when users make claims that contradict their own journal record, while respecting narrative authority.

**Master Prompt (`lumara_master_prompt.dart`):**
- New `<intellectual_honesty>` section: defines WHEN to push back (factual contradictions, pattern denial, recent-entry contradictions) vs. WHEN NOT to (reframing, evolving perspectives, ambiguous patterns). "Both/And" technique: cite evidence neutrally, allow legitimate disagreement, distinguish fact from interpretation.

**New: `lib/chronicle/editing/contradiction_checker.dart`**
- `ChronicleContradictionChecker`: Detects user claims via simple heuristics, checks against CHRONICLE Layer 0 entries. Returns `ContradictionResult` with `aggregationSummary` and `entryExcerpts`. `toTruthCheckBlock()` generates injectable system prompt context.

**Real-time pushback (chat path — `lumara_assistant_cubit.dart`):**
- Before calling LLM, checks if user message is a claim. If CHRONICLE contradicts it, injects `truth_check` block into system prompt. `PushbackEvidence` attached to assistant message for Evidence Review UI.

**Real-time pushback (reflection path — `enhanced_lumara_api.dart`):**
- Same contradiction check and `truth_check` injection in `buildPromptForRequest()`.

**New: `lib/arc/chat/data/models/pushback_evidence.dart`**
- `PushbackEvidence` model: `aggregationSummary` (e.g. "5 entries in the last 30 days touch on this") + `entryExcerpts` (dated excerpts).

**`lumara_message.dart`:**
- New `pushbackEvidence` field on `LumaraMessage`. Added to `copyWith`, `props`.

**New: `lib/arc/chat/ui/widgets/evidence_review_widget.dart`**
- `EvidenceReviewWidget`: Expandable "What I'm seeing" card below assistant messages with pushback. Shows summary, expand reveals individual entry excerpts.

### CHRONICLE Cross-Temporal Pattern Index (On-Device Embeddings)

New on-device semantic indexing system for cross-temporal pattern recognition using TFLite Universal Sentence Encoder.

**New: `lib/chronicle/embeddings/local_embedding_service.dart`**
- `LocalEmbeddingService`: Loads `universal_sentence_encoder.tflite` model. Generates sentence embeddings on-device for semantic matching.

**New: `lib/chronicle/index/chronicle_index_builder.dart`**
- `ChronicleIndexBuilder`: Builds and maintains cross-temporal pattern index from monthly aggregation themes. Clusters themes by embedding similarity, tracks theme appearances across time, identifies dominant patterns.

**New: `lib/chronicle/index/monthly_aggregation_adapter.dart`**
- `MonthlyAggregation.fromChronicleAggregation()`: Converts CHRONICLE aggregations to the format needed by the index builder.

**New: `lib/chronicle/matching/three_stage_matcher.dart`**
- `ThreeStageMatcher`: Three-stage semantic matching pipeline (exact → embedding cosine → fuzzy).

**New: `lib/chronicle/storage/chronicle_index_storage.dart`**
- Persistent storage for the cross-temporal pattern index.

**New models:**
- `lib/chronicle/models/chronicle_index.dart`, `dominant_theme.dart`, `pattern_insights.dart`, `theme_appearance.dart`, `theme_cluster.dart`.

**New: `lib/chronicle/query/pattern_query_router.dart`**
- Routes pattern-related queries through the cross-temporal index.

**Integration:**
- `veil_chronicle_factory.dart`: Creates `LocalEmbeddingService` + `ChronicleIndexStorage` + `ChronicleIndexBuilder` and passes to narrative integration.
- `chronicle_narrative_integration.dart`: EXAMINE stage updates pattern index after monthly synthesis.
- `synthesis_scheduler.dart`: Pattern index updated after each monthly synthesis.

**Dependencies:**
- `pubspec.yaml`: Added `tflite_flutter: ^0.12.1`. Asset: `assets/models/universal_sentence_encoder.tflite`.

### CHRONICLE Edit Validation

**New: `lib/chronicle/editing/edit_validation_models.dart`**
- `EditValidationResult` (approved / warning / conflict), `EditWarningType` (patternSuppression), `SuppressedPattern`, `EntryContradiction`.

**New: `lib/chronicle/editing/edit_validator.dart`**
- `EditValidator`: Detects pattern suppression (themes removed that appear in many entries) and factual contradictions in user edits to CHRONICLE content.

**New: `lib/chronicle/services/chronicle_editing_service.dart`**
- `ChronicleEditingService`: Validates edits against source entries. Returns approved / warning (with affected entry IDs) / conflict.

### CHRONICLE Import Service

**New: `lib/chronicle/services/chronicle_import_service.dart`**
- `ChronicleImportService`: Imports aggregations from a directory exported by `ChronicleExportService`. Parses monthly/yearly/multiyear subdirectories.
- `ChronicleImportResult` with counts per layer.

**`aggregation_repository.dart`:**
- New public `parseFromMarkdownContent()` method for import parsing.

### CHRONICLE Schedule Preferences

**New: `lib/chronicle/scheduling/chronicle_schedule_preferences.dart`**
- `ChronicleScheduleCadence` enum: `daily`, `weekly`, `monthly` with `label`, `description`, `interval`.
- `ChronicleSchedulePreferences`: Persists cadence via SharedPreferences.

**`veil_chronicle_scheduler.dart` (refactored):**
- Replaced fixed 24-hour `Timer.periodic` with cadence-based `_runAndReschedule()`. First run at next midnight; subsequent runs use user preference.
- `stop()` clears userId/tier state.

### Expanded Entry View Enhancements

**`expanded_entry_view.dart`:**
- Full journal entry now loaded via `FutureBuilder<JournalEntry?>` to access LUMARA blocks and metadata.
- Written content: When entry has `lumaraBlocks`, renders interleaved writer text + LUMARA reflection blocks (`_buildReadOnlyLumaraBlock()`) + user comments.
- Related entries: Uses `metadata['relatedEntryIds']` to show real linked entries (tappable cards with title/date, navigate to full entry).
- LUMARA's note: Shows actual `overview` or `lumaraBlocks` content instead of placeholder.

### Journal Screen View-Only Improvements

**`journal_screen.dart`:**
- `_buildContinuationField()`: In view-only mode, shows read-only user comment with paragraph formatting (`_buildViewOnlyParagraphs()`).
- `_buildContentView()`: Paragraph formatting (double newlines → separate `Text` widgets) instead of single `Text` block.

**`inline_reflection_block.dart`:**
- New `readOnly` parameter (default `false`). When true, hides action buttons (regenerate, reflect deeply, continue thought, share, TTS, menu).

### Splash Screen Phase Display Cleanup

**`lumara_splash_screen.dart`:**
- Removed `_getPhaseFromEntries()` backfill migration — splash is now display-only.
- Phase display uses same source as Phase Page: profile first, then regime. No default to "Discovery"; `_currentPhase` starts empty.

### Phase Analysis View — Unified Phase Source

**`phase_analysis_view.dart`:**
- New `_displayPhaseName` field: single source of truth (profile first, then regime; same as splash/timeline).
- Rotating phase shape only shown when phase is set; "Set your phase" placeholder with icon when no phase exists.
- `_buildArcformContent()` refactored to use `_displayPhaseName` throughout.

### CHRONICLE Management UI Improvements

**`chronicle_management_view.dart`:**
- **Import**: New "Import Aggregations" button using `ChronicleImportService` + `FilePicker`.
- **Schedule cadence**: New "Automatic synthesis" section with `FilterChip` selection (Daily/Weekly/Monthly) persisted via `ChronicleSchedulePreferences`.
- **Progress UX**: Two-phase progress bar (0-50% backfill, 50-100% synthesis). Indeterminate animation when total is unknown. Stages label updates ("Backfilling Layer 0..." → "Synthesizing current month..."). Back button returns to menu during progress instead of popping route. "Please wait" shown when no fraction.
- Removed `ChronicleManualService` dependency.

### UI Polish

**Timeline export dialogs (`interactive_timeline_view.dart`):**
- Dark-theme-safe: explicit `kcSurfaceColor` background, `kcPrimaryTextColor` text, `Colors.black54` barrier.
- Multi-entry delete: icon + "Delete (N)" text label with count and tooltip.

**MCP export (`mcp_export_screen.dart`):**
- Custom date range validation: requires both start and end dates; start must be on or before end.
- All dialogs: dark-theme-safe colors.

**Files changed (32 modified + 21 new):**
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` — Crossroads flow, pushback injection
- `lib/arc/chat/data/models/lumara_message.dart` — pushbackEvidence field
- `lib/arc/chat/data/models/pushback_evidence.dart` (NEW)
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` — intellectual_honesty section
- `lib/arc/chat/services/enhanced_lumara_api.dart` — pushback injection (reflection path)
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — Crossroads UI, evidence review
- `lib/arc/chat/ui/lumara_splash_screen.dart` — phase display cleanup
- `lib/arc/chat/ui/widgets/evidence_review_widget.dart` (NEW)
- `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart` — dark-theme dialogs, delete label
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — full entry with blocks/related
- `lib/chronicle/editing/contradiction_checker.dart` (NEW)
- `lib/chronicle/editing/edit_validation_models.dart` (NEW)
- `lib/chronicle/editing/edit_validator.dart` (NEW)
- `lib/chronicle/embeddings/local_embedding_service.dart` (NEW)
- `lib/chronicle/index/chronicle_index_builder.dart` (NEW)
- `lib/chronicle/index/monthly_aggregation_adapter.dart` (NEW)
- `lib/chronicle/integration/chronicle_narrative_integration.dart` — pattern index update
- `lib/chronicle/integration/veil_chronicle_factory.dart` — index builder creation
- `lib/chronicle/integration/veil_chronicle_integration.dart` (NEW)
- `lib/chronicle/matching/three_stage_matcher.dart` (NEW)
- `lib/chronicle/models/chronicle_index.dart` (NEW)
- `lib/chronicle/models/dominant_theme.dart` (NEW)
- `lib/chronicle/models/pattern_insights.dart` (NEW)
- `lib/chronicle/models/query_plan.dart` — decisionArchaeology intent
- `lib/chronicle/models/theme_appearance.dart` (NEW)
- `lib/chronicle/models/theme_cluster.dart` (NEW)
- `lib/chronicle/query/pattern_query_router.dart` (NEW)
- `lib/chronicle/query/query_router.dart` — decisionArchaeology routing
- `lib/chronicle/scheduling/chronicle_schedule_preferences.dart` (NEW)
- `lib/chronicle/scheduling/synthesis_scheduler.dart` — pattern index integration
- `lib/chronicle/services/chronicle_editing_service.dart` (NEW)
- `lib/chronicle/services/chronicle_export_service.dart` — decisions export
- `lib/chronicle/services/chronicle_import_service.dart` (NEW)
- `lib/chronicle/services/chronicle_onboarding_service.dart` — two-phase progress
- `lib/chronicle/storage/aggregation_repository.dart` — public parse method
- `lib/chronicle/storage/chronicle_index_storage.dart` (NEW)
- `lib/chronicle/storage/layer0_populator.dart` — decision capture population
- `lib/chronicle/storage/raw_entry_schema.dart` — decision entry type
- `lib/chronicle/synthesis/monthly_synthesizer.dart` — decisions in narrative/markdown
- `lib/crossroads/crossroads_service.dart` (NEW)
- `lib/crossroads/models/decision_capture.dart` (NEW)
- `lib/crossroads/storage/decision_capture_repository.dart` (NEW)
- `lib/echo/rhythms/veil_chronicle_scheduler.dart` — cadence-based scheduling, Crossroads check
- `lib/main/bootstrap.dart` — Hive adapters 118/119
- `lib/prism/atlas/rivet/rivet_decision_analyzer.dart` (NEW)
- `lib/prism/atlas/rivet/rivet_models.dart` — decision trigger models
- `lib/shared/ui/settings/chronicle_management_view.dart` — import, cadence, progress UX
- `lib/ui/export_import/mcp_export_screen.dart` — validation, dark-theme dialogs
- `lib/ui/journal/journal_screen.dart` — view-only paragraphs, readOnly blocks
- `lib/ui/journal/widgets/inline_reflection_block.dart` — readOnly parameter
- `lib/ui/phase/phase_analysis_view.dart` — unified phase source
- `test/chronicle/pattern_recognition_test.dart` (NEW)
- `pubspec.yaml` — tflite_flutter, USE model asset

---

## [3.3.25] - February 12, 2026 (working changes)

### Chat Phase Classification System

LUMARA chat sessions now receive ATLAS phase classifications, bringing the same phase intelligence that journal entries have to the chat experience.

**New file: `lib/arc/chat/services/chat_phase_service.dart`**
- `ChatPhaseService`: Classifies chat sessions into ATLAS phases using `PhaseInferenceService` (same pipeline as journal entries). Concatenates all user + assistant messages for holistic analysis.
- Auto-classification fires after every assistant response (fire-and-forget in `lumara_assistant_cubit.dart`).
- Reclassification on session revisit (`session_view.dart` triggers on load).
- Manual user phase override with `setUserPhaseOverride()` / `clearUserPhaseOverride()`.
- `backfillAllSessions()` for batch-classifying existing chats without phases.
- Respects user override — never auto-reclassifies when override is set.

**Chat model phase helpers (`chat_models.dart`):**
- `autoPhase`, `autoPhaseConfidence`, `userPhaseOverride`, `isPhaseLocked`, `displayPhase` — stored in session metadata (no Hive schema change).

**Chat repo (`chat_repo.dart`, `chat_repo_impl.dart`, `enhanced_chat_repo.dart`, `enhanced_chat_repo_impl.dart`):**
- New `updateSessionPhase()` method merges phase fields into existing metadata.

### Chat Session Phase UI

**Session view (`session_view.dart`):**
- Phase displayed in app bar subtitle: colored dot + phase label (tappable).
- Bottom sheet phase selector with all 6 ATLAS phases, current-phase checkmark, "Reset to Auto" option.
- `_setPhaseOverride()` and `_clearPhaseOverride()` for manual control.

**Chat lists (`chats_screen.dart`, `enhanced_chats_screen.dart`):**
- Phase chip shown on each chat session card (colored pill with phase name).
- Both screens now show all sessions including archived (`listAll(includeArchived: true)`).
- Enhanced screen shows "Archived" label on archived chats.

**Chat drawer (`chat_navigation_drawer.dart`):**
- Shows all sessions including archived.

### Phase Regime Service — Chat Session Integration

**`phase_regime_service.dart`:**
- `rebuildRegimesFromEntries()` now accepts `includeChatSessions` parameter (default: `true`).
- Loads chat sessions with phase data and treats them as phase data points alongside journal entries.
- New `_PhaseDataPoint` class for non-journal phase contributions (date, phase, confidence).
- Chat phase points contribute to 10-day window sliding analysis, extending date range if chat dates fall outside journal range.

### 3D Constellation Phase Card in Feed

**`simplified_arcform_view_3d.dart`:**
- New `cardOnly` and `onCardTap` parameters. When `cardOnly: true`, only the first snapshot card (header + 3D constellation) is rendered — no Change Phase button, no Past/Example Phases sections.
- Loading state gets a fixed 260px height in card mode.
- Tap delegates to `onCardTap` when provided.

**`unified_feed_screen.dart`:**
- Replaced `CurrentPhaseArcformPreview` with `SimplifiedArcformView3D(cardOnly: true)` for the 3D constellation card in the Unified Feed.
- Tapping opens full Phase Analysis page; refreshes on return.

### Draft Reflection Fix

**`reflection_handler.dart`:**
- Draft entries (`draft_*` IDs) now skip AURORA session tracking and go straight to LUMARA, fixing "Entry not found: draft_..." error when reflecting on unsaved new entries.

### Documentation

**`claude.md`:**
- Added PROMPT REFERENCES AUDIT (MANDATORY) section: checks for `PROMPT_REFERENCES.md` existence, compares codebase prompts vs documented, updates tracker and config management.
- Added "Prompt catalog drift" to Missing & Incomplete Documentation checklist.

### Documentation Consolidation & Optimization

Full implementation of the brutal documentation efficiency audit (claude.md §550-808). 190 .md files audited. 23 files removed from active docs (archived or deleted), zero information lost.

**Phase 1 — Obsolete/empty (7 files):** Deleted `UI_UX.md` (empty). Archived: `CHRONICLE_CONTEXT_FOR_CLAUDE.md`, `LUMARA_ORCHESTRATOR_ROADMAP.md`, `DOCUMENTATION_CONSOLIDATION_AUDIT_2026-02.md`, `TIMELINE_LEGACY_ENTRIES.md`, `PAYMENTS_CLARIFICATION.md`, `ENTERPRISE_VOICE.md`.

**Phase 2 — Prompt consolidation (2 → PROMPT_REFERENCES v2.1.0):** Merged `UNIFIED_INTENT_CLASSIFIER_PROMPT.md` (§15) and `MASTER_PROMPT_CONTEXT.md` (§16) into PROMPT_REFERENCES. Originals archived.

**Phase 3 — LUMARA architecture (5 → LUMARA_COMPLETE v2.0):** Merged `ARC_AND_LUMARA_OVERVIEW.md`, `NARRATIVE_INTELLIGENCE.md`, `SUBSYSTEMS.md`, `LUMARA_ORCHESTRATOR.md`, `LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md` into comprehensive LUMARA_COMPLETE.md. Originals archived.

**Phase 4 — Stripe (7 → 1 new doc):** Created `stripe/STRIPE_TESTING_AND_MIGRATION.md` merging 7 small helper files. Active stripe docs: 4 (README + SETUP + TESTING + ANALYSIS). Originals in stripe/archive/.

**Phase 5 — Bugtracker (2 duplicates archived):** `BUG_TRACKER_MASTER_INDEX.md` and `BUG_TRACKER_PART1_CRITICAL.md` archived (bug_tracker.md is canonical).

#### Files added
- `lib/arc/chat/services/chat_phase_service.dart`

#### Files modified
- `lib/arc/chat/chat/chat_models.dart` — Phase helpers on ChatSession
- `lib/arc/chat/chat/chat_repo.dart` — `updateSessionPhase()` abstract method
- `lib/arc/chat/chat/chat_repo_impl.dart` — `updateSessionPhase()` implementation
- `lib/arc/chat/chat/enhanced_chat_repo.dart` — `updateSessionPhase()` forward
- `lib/arc/chat/chat/enhanced_chat_repo_impl.dart` — `updateSessionPhase()` delegate
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` — Auto-classify after assistant response
- `lib/arc/chat/chat/ui/session_view.dart` — Phase in app bar, phase selector, reclassify on load
- `lib/arc/chat/chat/ui/chats_screen.dart` — Phase chips, show all sessions
- `lib/arc/chat/chat/ui/enhanced_chats_screen.dart` — Phase chips, show all sessions, archived label
- `lib/arc/chat/ui/widgets/chat_navigation_drawer.dart` — Show all sessions
- `lib/services/phase_regime_service.dart` — Chat session integration, `_PhaseDataPoint`
- `lib/ui/phase/simplified_arcform_view_3d.dart` — `cardOnly` / `onCardTap` parameters
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — 3D constellation card in feed
- `lib/arc/chat/services/reflection_handler.dart` — Draft entry fix
- `docs/claude.md` — Prompt references audit section

---

## [3.3.24] - February 11, 2026

### Groq as Primary LLM Provider (Llama 3.3 70B / Mixtral)

LUMARA now uses **Groq** (Llama 3.3 70B) as the **primary** cloud LLM, with **Gemini** demoted to fallback. This provides faster inference via Groq's purpose-built inference hardware while maintaining full backward compatibility. Mixtral 8x7b serves as a secondary fallback within the Groq tier.

**New files:**
- `lib/arc/chat/services/groq_service.dart` — Core Groq API client: non-streaming (`generateContent`) and streaming (`generateContentStream` via SSE). `GroqModel` enum with `llama33_70b` (128K context) and `mixtral_8x7b` (32K context). Auto-fallback from Llama to Mixtral on error.
- `lib/arc/chat/llm/providers/groq_provider.dart` — `GroqProvider` LLM provider: uses Firebase `proxyGroq` when signed in, direct API key when not. Implements `isAvailable()` and `generateResponse()`.
- `lib/services/groq_send.dart` — Firebase proxy client: calls `proxyGroq` Cloud Function via `httpsCallable`. Passes system/user/model/temperature/maxTokens/entryId/chatId.
- `SET_GROQ_SECRET.md` — Setup guide for Groq API key in Firebase Secret Manager (`firebase functions:secrets:set GROQ_API_KEY`).

**Backend (Firebase Cloud Functions):**
- `functions/index.js` — New `proxyGroq` Cloud Function: authenticates user, calls Groq OpenAI-compatible API (`api.groq.com/openai/v1/chat/completions`), hides API key from client. Supports `llama-3.3-70b-versatile` and `mixtral-8x7b-32768`. New `groqChatCompletion()` helper via `https.request`. `GROQ_API_KEY` added to secrets. `healthCheck` updated to list `proxyGroq`.

**LLM Provider Architecture:**
- `lib/arc/chat/config/api_config.dart` — New `LLMProvider.groq` enum value. Groq config loaded from environment and auto-saved from runtime environment. `bestProvider` now prefers Groq → Gemini → other external → internal. `clearAllApiKeys()` includes Groq.
- `lib/arc/chat/llm/llm_provider_factory.dart` — New `LLMProviderType.groq` and `GroqProvider` instantiation. Maps `LLMProvider.groq` → `LLMProviderType.groq`.

**LUMARA Reflection API:**
- `lib/arc/chat/services/enhanced_lumara_api.dart` — `GroqService` integrated as primary for journal reflections. Call chain: Groq (streaming or non-streaming) → Gemini fallback. Mode-aware temperature (`explore: 0.8`, `integrate: 0.7`, `reflect: 0.6`, default: 0.7`). Logging updated from "Gemini" to "Groq/Gemini".

**UI & Error Messages:**
- `lib/arc/chat/ui/lumara_settings_screen.dart` — Default provider changed from "Gemini" to "Groq (Llama 3.3 70B / Mixtral)". Claude, ChatGPT, Venice, OpenRouter removed from provider selection. API Keys card now shows Groq + Gemini only.
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` — Logging updated to "Cloud API (Groq/Gemini)" throughout.
- `lib/services/gemini_send.dart` — Error message updated to mention Groq.
- `lib/ui/journal/journal_screen.dart` — Error snackbar text updated: "LUMARA needs a Groq or Gemini API key."

---

## [3.3.23] - February 11, 2026

### CHRONICLE Speed-Tiered Context System

New `ResponseSpeed` enum (`instant`, `fast`, `normal`, `deep`) maps engagement modes and voice status to latency targets, ensuring CHRONICLE context is built at the appropriate speed for each use case.

**ResponseSpeed (new enum in `query_plan.dart`):**
- `instant` (<1s): Mini-context only (50–100 tokens) — used by explore mode and voice.
- `fast` (<10s): Single-layer compressed (~2k tokens) — used by integrate and reflect modes.
- `normal` (<30s): Multi-layer context (~8–10k tokens) — default for legacy text queries.
- `deep` (30–60s): Full context for synthesis — used when >2 layers selected.

**ChronicleQueryRouter (mode-aware routing):**
- Accepts `EngagementMode` and `isVoice` parameters.
- `explore` or `isVoice` → instant speed, no CHRONICLE layers (rawEntry plan).
- `integrate` → fast speed, yearly layer only, drill-down enabled.
- `reflect` → fast speed, single layer (monthly or yearly inferred from query keywords and intent).
- Legacy (no mode) → classify intent via LLM, then normal/deep based on layer count.
- New `_selectLayersForMode()` and `_inferReflectLayer()` methods.

**ChronicleContextBuilder (speed-tiered building):**
- `instant` → calls `buildMiniContext()` for first layer only.
- `fast` → new `_buildSingleLayerContext()` loads one layer and compresses via `_compressForSpeed()` (~2k token target).
- `normal` / `deep` → existing multi-layer `_buildMultiLayerContext()`.
- `_compressForSpeed()` preserves headings and bullet points, truncates paragraph bodies to first sentence, adds "[Additional details available on request]" when token estimate exceeds target.
- All tiers use `ChronicleContextCache` for reads and writes (except deep mode).

**EnhancedLumaraApi integration:**
- Passes `mode` and `isVoice` to query router.
- Uses `ChronicleContextCache.instance` for context builder.
- Voice always gets mini-context even when plan is rawEntry (falls back to current-month monthly layer).
- Logs speed target alongside layer count.

#### Files added
- `lib/chronicle/query/chronicle_context_cache.dart` — Singleton in-memory TTL cache (30min, max 50)

#### Files modified
- `lib/chronicle/models/query_plan.dart` — `ResponseSpeed` enum; `speedTarget` field on `QueryPlan`
- `lib/chronicle/query/query_router.dart` — Mode-aware routing; `_selectLayersForMode`, `_inferReflectLayer`
- `lib/chronicle/query/context_builder.dart` — Speed-tiered building; cache integration; `_buildSingleLayerContext`, `_compressForSpeed`
- `lib/arc/chat/services/enhanced_lumara_api.dart` — Passes `mode`/`isVoice` to router; cache integration; voice mini-context fallback

---

### CHRONICLE Context Cache

New singleton `ChronicleContextCache` provides in-memory caching of built CHRONICLE contexts to speed up repeated queries on the same period.

- **TTL:** 30 minutes per entry.
- **Max entries:** 50 (LRU eviction of oldest on overflow).
- **Key:** `userId:layers:period`.
- **Invalidation:** `JournalRepository.saveJournalEntry()` invalidates cache for the entry's month and year periods so subsequent reflections see fresh content.

#### Files added
- `lib/chronicle/query/chronicle_context_cache.dart`

#### Files modified
- `lib/arc/internal/mira/journal_repository.dart` — Invalidates cache on save (monthly + yearly periods)
- `lib/chronicle/query/context_builder.dart` — Accepts optional cache; reads/writes cache (except deep mode)
- `lib/arc/chat/services/enhanced_lumara_api.dart` — Passes `ChronicleContextCache.instance` to context builder

---

### Streaming LUMARA Responses

LUMARA reflections now stream to the UI in real-time as chunks arrive from the Gemini API, providing immediate visual feedback instead of waiting for the full response.

**EnhancedLumaraApi:**
- New `onStreamChunk` callback parameter. When set, uses `geminiSendStream` for token-by-token streaming.
- Falls back to non-streaming `geminiSend` if stream is unavailable (e.g., Firebase proxy without direct API key).
- On fallback, emits the full response as a single chunk.

**ReflectionHandler:**
- Passes `onStreamChunk` through to `EnhancedLumaraApi` in both entryId and no-entryId paths.

**JournalScreen:**
- `onStreamChunk` callback updates the LUMARA inline block content in real-time via `setState`.
- Accumulated `StringBuffer` holds partial response; block content updates on each chunk.
- Loading message shows "Streaming..." while chunks arrive.

#### Files modified
- `lib/arc/chat/services/enhanced_lumara_api.dart` — `onStreamChunk` parameter; streaming/fallback logic
- `lib/arc/chat/services/reflection_handler.dart` — Passes `onStreamChunk` to API
- `lib/ui/journal/journal_screen.dart` — Real-time streaming UI for LUMARA inline blocks

---

### Unified Feed: Scroll-to-Top/Bottom Navigation

Direction-aware scroll navigation buttons appear in the feed when scrolling, providing quick navigation similar to ChatGPT/Claude.

- **Scrolling down** (and not near bottom): "Jump to bottom" pill button appears centered at bottom.
- **Scrolling up** (and not near top): "Jump to top" pill button appears centered at bottom.
- **Threshold-based**: Only appears after 150px from edges and when total scroll extent exceeds 400px.
- **Animated**: 200ms opacity animation. Pill design with icon + text, primary color accent, shadow, rounded corners.
- **`_scrollToTop()` / `_scrollToBottom()`**: 400ms animated scroll with `easeOut` curve.

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Scroll state tracking, direction detection, overlay buttons, `_scrollToTop`/`_scrollToBottom`

---

### Feed Content Display Improvements

Several refinements to how entry content is displayed in feed cards and the expanded entry view.

**FeedEntry.preview:**
- Strips `## Summary\n\n...\n\n---\n\n` prefix from content before computing preview text, so card previews show actual body content instead of summary headers.

**FeedRepository timestamp:**
- Uses `entry.createdAt` instead of `entry.updatedAt` for feed timestamp. Entries now sort by original creation date rather than last edit date.

**FeedHelpers.contentWithoutPhaseHashtags:**
- Preserves newlines when stripping phase hashtags instead of collapsing all whitespace to single spaces. Paragraph structure is maintained in display content.

**ExpandedEntryView paragraph rendering:**
- `---` lines become visual `Divider` widgets (matches edit mode appearance).
- Markdown headers (`#` lines) are skipped in display (structural, not display content).
- Single newlines within paragraphs preserved as line breaks (previously collapsed).
- Line height increased from 1.5 to 1.6.
- Summary section only shown when meaningfully different from body (60% overlap detection prevents redundant display).

**ReflectionCard preview:**
- Collapses newlines in preview text to single spaces for compact single-line card display.

#### Files modified
- `lib/arc/unified_feed/models/feed_entry.dart` — `_summaryPrefix` regex; strip summary from preview
- `lib/arc/unified_feed/repositories/feed_repository.dart` — `createdAt` instead of `updatedAt` for timestamp
- `lib/arc/unified_feed/utils/feed_helpers.dart` — Preserve newlines in hashtag stripping
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — Divider for `---`, skip headers, preserve newlines, summary overlap detection
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart` — Collapse newlines in preview

---

### Phase Display: Regime Phase Without RIVET Gate

`UserPhaseService.getDisplayPhase()` now shows the regime phase even when the RIVET gate is closed. Previously, regime phase was only displayed when `rivetGateOpen == true`, which meant imported or RIVET-detected phases were invisible until the gate opened. Now, any existing regime phase is trusted and displayed, with the user's explicit profile phase still taking priority.

#### Files modified
- `lib/services/user_phase_service.dart` — `getDisplayPhase()` shows regime phase regardless of RIVET gate status

---

### Phase Timeline: Bottom Sheet Phase Change Dialog

The "Change Current Phase" dialog has been redesigned from a basic `AlertDialog` to a polished modal bottom sheet.

- Phase list shows colored circle indicators, phase names, and highlights the current phase with a "Current" `Chip`.
- Current phase is non-tappable (prevents no-op selection).
- Non-current phases have forward arrow icon.
- Descriptive subtitle: "Your current phase will end today and the new one begins now."
- No redundant confirmation dialog after selection — phase changes immediately.
- Fires `PhaseRegimeService.regimeChangeNotifier` and `UserPhaseService.phaseChangeNotifier` after change so phase preview and Gantt card refresh instantly.

#### Files modified
- `lib/ui/phase/phase_timeline_view.dart` — Bottom sheet dialog, notifier firing, removed redundant confirmation

---

### Phase Analysis: Direct Timeline Navigation

Tapping the Gantt card or edit-phases button in the feed now navigates directly to the editable Phase Timeline view instead of the Phase Analysis overview.

**PhaseAnalysisView:**
- New `initialView` parameter. When set to `'timeline'`, the view opens directly on the timeline tab.

**Gantt card & edit button:**
- Both now navigate to `PhaseAnalysisView(initialView: 'timeline')`.

#### Files modified
- `lib/ui/phase/phase_analysis_view.dart` — `initialView` parameter; set `_selectedView` in `initState`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Gantt card and edit button pass `initialView: 'timeline'`

---

### Gantt Card & Phase Preview: Auto-Refresh on Change

`_PhaseJourneyGanttCard` now listens to both `PhaseRegimeService.regimeChangeNotifier` and `UserPhaseService.phaseChangeNotifier` and auto-reloads when a change is detected — matching the behavior of `CurrentPhaseArcformPreview`. Listeners are properly disposed.

Additional notification improvements:
- `HomeView.initState()` fires both notifiers on app startup (via `addPostFrameCallback`) to ensure phase preview is fresh on launch.
- `App._AppState` fires both notifiers after ARCX import completes.
- `UnifiedFeedScreen` pull-to-refresh fires both notifiers.
- `SimplifiedArcformView3D` fires both notifiers after a phase change in the 3D view.

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Gantt card listens to notifiers; pull-to-refresh fires notifiers
- `lib/shared/ui/home/home_view.dart` — Fires notifiers on startup
- `lib/app/app.dart` — Fires notifiers after ARCX import
- `lib/ui/phase/simplified_arcform_view_3d.dart` — Fires notifiers after phase change

---

### DevSecOps Security Audit: Verified Findings

The security audit document has been updated from "to audit" stubs to verified findings across multiple domains.

**Verified (previously "to audit"):**
- **Auth (§2):** Firebase callables enforce `request.auth`; backend checks `if (!request.auth)` and throws `unauthenticated`. UID/email from `request.auth`, no client-only gate for sensitive operations.
- **Secrets (§3):** Gemini key in Firebase secrets (`defineSecret`); WisprFlow redacts key in logs; `api_config.dart` uses masked key. **Finding:** `assemblyai_provider.dart` logs token substring — reduce in production.
- **Storage (§5):** `flutter_secure_storage` in use for encryption keys; iOS Keychain/Secure Enclave via `ARCXCrypto.swift`; no reversible maps in cloud/backup.
- **Network (§6):** No `badCertificateCallback`, `HttpOverrides`, or `allowBadCertificates` found.
- **Logging (§7):** Email/UID in debug logs (`firebase_auth_service`, `subscription_service`). Token substring logged. Sentry commented out. **Recommendation:** Use release-mode guards.
- **Rate limiting (§10):** Client passes entryId/chatId; backend returns tier/limits. `proxyGemini` does not enforce rate limit in code — recommend adding.
- **Deep links (§20):** Internal only (`patterns://` for in-app routing). No external handler found.

**Summary expanded** with verified findings and remaining audit items (§4 input validation, §14 retention, §15 compliance, §17 sensitive UI, §19 audit trail).

#### Files modified
- `DOCS/DEVSECOPS_SECURITY_AUDIT.md` — Verified findings for auth, secrets, storage, network, logging, rate limiting, deep links; expanded summary

---

## [3.3.22] - February 10, 2026 (working changes)

### RIVET Sweep: Phase Hierarchy Fix

RIVET Sweep now uses `entry.computedPhase` (which respects `userPhaseOverride > autoPhase > legacyPhaseTag`) instead of only checking `autoPhase`. This ensures that entries with manual phase overrides, imported phases, or locked phases are not re-inferred during RIVET Sweep analysis.

- Locked entries (`isPhaseLocked: true`) are explicitly noted in debug logging but their phase is respected.
- Only entries with no existing phase data are inferred from content via `PhaseRecommender`.

#### Files modified
- `lib/services/rivet_sweep_service.dart` — `computedPhase` priority hierarchy; locked-entry handling

---

### Phase Analysis: Confirmation Dialog Before Clear

Running Phase Analysis now shows a warning dialog when existing phase regimes are present, explaining that all regimes will be cleared and re-analyzed. The user must confirm "Clear & Re-analyze" before proceeding. Previously, regimes were silently cleared.

After analysis completes, both `PhaseRegimeService.regimeChangeNotifier` and `UserPhaseService.phaseChangeNotifier` are fired so the phase preview on the LUMARA tab refreshes immediately.

#### Files modified
- `lib/ui/phase/phase_analysis_view.dart` — Confirmation dialog; fires notifiers after analysis

---

### Phase Preview: Debug Logging

Added two debug print statements to `CurrentPhaseArcformPreview` for tracing phase resolution (regime phase, RIVET gate status, profile phase, and final display phase). Aids in diagnosing phase display mismatches.

#### Files modified
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — Debug prints

---

### DevSecOps: Security Audit Scope Expanded

**claude.md:** The DevSecOps Security Audit Role has been expanded from PII/egress-only (5 responsibilities) to a full 10-domain security audit covering: PII/egress, authentication, secrets, input validation, storage, network, logging, feature flags, dependencies, and rate limiting. Key code areas updated to match.

**DEVSECOPS_EGRESS_PII_AUDIT.md → DEVSECOPS_SECURITY_AUDIT.md:**
- Old narrow PII egress audit document deleted.
- New `DEVSECOPS_SECURITY_AUDIT.md` created with 10 sections, an egress checklist table (12 paths verified), and structured "To audit" guidance for each security domain.

#### Files deleted
- `DOCS/DEVSECOPS_EGRESS_PII_AUDIT.md`

#### Files added
- `DOCS/DEVSECOPS_SECURITY_AUDIT.md`

#### Files modified
- `docs/claude.md` — DevSecOps role expanded to 10 security domains
- `DOCS/CONFIGURATION_MANAGEMENT.md` — Audit doc renamed in inventory

---

## [3.3.21] - February 10, 2026 (working changes)

### Phase Locking: Prevent Re-Inference on Reload/Import

Phase assignments are now locked after inference to prevent ATLAS from randomly choosing a different phase when entries are reloaded, the timeline filter changes, or data is imported. Once a phase is determined — by ATLAS, by the user, or from a backup — it stays.

**JournalCaptureCubit:**
- Phase backfill now skips entries where `isPhaseLocked == true`.
- After inference, entries are saved with `isPhaseLocked: true` so subsequent reloads never re-infer.

**Import Services (ARCX v2 + MCP ZIP):**
- Import now defaults `isPhaseLocked: true` if the entry had any phase data (`autoPhase`, `userPhaseOverride`, or `legacyPhaseTag`) — even if the backup didn't explicitly set the flag.
- Phase inference after import also sets `isPhaseLocked: true`.

#### Files modified
- `lib/arc/core/journal_capture_cubit.dart` — Phase backfill respects `isPhaseLocked`; locks after inference
- `lib/mira/store/arcx/services/arcx_import_service_v2.dart` — Smart `isPhaseLocked` default; lock after inference
- `lib/mira/store/mcp/import/mcp_pack_import_service.dart` — Same `isPhaseLocked` logic

---

### Phase Regime Change Notification System

New `ValueNotifier`-based notification system ensures the phase preview on the LUMARA tab stays in sync with regime and phase changes from any source (RIVET/ATLAS sweep, manual change, import, backup restore).

**PhaseRegimeService:**
- New static `regimeChangeNotifier` (`ValueNotifier<DateTime>`) fires on every regime create, update, rebuild, extend, and clear.
- All mutation methods now call `regimeChangeNotifier.value = DateTime.now()`.

**UserPhaseService:**
- New static `phaseChangeNotifier` (`ValueNotifier<DateTime>`) fires on `forceUpdatePhase()`.

**CurrentPhaseArcformPreview:**
- Listens to both `UserPhaseService.phaseChangeNotifier` and `PhaseRegimeService.regimeChangeNotifier`.
- Automatically reloads snapshots when either fires (e.g. after import, phase quiz, or RIVET sweep).
- Also reloads on `didUpdateWidget` (e.g. after navigation back to feed).
- Properly disposes listeners.

**McpImportScreen:**
- Fires both notifiers after each import path completes (4 integration points), ensuring the LUMARA tab phase preview reflects imported data immediately.

#### Files modified
- `lib/services/phase_regime_service.dart` — `regimeChangeNotifier` + fires on mutations
- `lib/services/user_phase_service.dart` — `phaseChangeNotifier` + fires on `forceUpdatePhase`
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — Listens to both notifiers, reloads on change
- `lib/ui/export_import/mcp_import_screen.dart` — Fires notifiers after import

---

### Phase Regimes: Extend Instead of Rebuild

When the timeline loads or entries are imported, phase regimes are now incrementally extended rather than fully rebuilt from scratch. This preserves existing regime history and user-edited regimes instead of wiping them.

- `TimelineCubit._applyFilterAndEmit()`: Changed from `rebuildRegimesFromEntries()` to `extendRegimesWithNewEntries()`.
- `ARCXImportService` (v1): Same change.
- `McpPackImportService`: Same change.

#### Files modified
- `lib/arc/ui/timeline/timeline_cubit.dart` — `extendRegimesWithNewEntries` replaces `rebuildRegimesFromEntries`
- `lib/mira/store/arcx/services/arcx_import_service.dart` — Same
- `lib/mira/store/mcp/import/mcp_pack_import_service.dart` — Same

---

### Phase Timeline: Bulk Phase Apply

Two new bulk-edit actions in the Phase Timeline view allow users to set `userPhaseOverride` and `isPhaseLocked` on all journal entries within a date range or regime period at once.

**"Apply phase by date range" (new button in Phase Timeline):**
- Opens dialog with phase radio selector and start/end date pickers.
- Sets `userPhaseOverride` and `isPhaseLocked: true` on all entries in the selected range.
- Shows snackbar with count of updated entries.

**"Apply this phase to all entries in this period" (new per-regime action):**
- Available in the regime bottom-sheet options.
- Confirmation dialog showing phase name and entry count.
- Locks phase on all entries within the regime's date range.

**PhaseRegimeService (new public methods):**
- `getEntriesForRegime(PhaseRegime)` — returns entries in a regime's date range.
- `getEntriesInDateRange(DateTime start, DateTime? end)` — returns entries in an arbitrary date range.

#### Files modified
- `lib/ui/phase/phase_timeline_view.dart` — Bulk apply buttons, dialogs, methods
- `lib/services/phase_regime_service.dart` — `getEntriesForRegime`, `getEntriesInDateRange`

---

### Onboarding Streamlined (Screens Removed)

Reduced onboarding from 6 screens to 4 by removing the redundant "ARC Intro" and "Sentinel Intro" screens. Remaining screens are more concise and use third-person language for the phase explanation.

**Removed screens:**
- `_ArcIntroScreen` — "Welcome to LUMARA" (redundant with LUMARA Intro)
- `_SentinelIntroScreen` — "One more thing" Sentinel explanation (too early in onboarding)

**Text updates:**
- `_LumaraIntroScreen`: Condensed to "Hi, I'm LUMARA." with intelligence-compounds description.
- `_NarrativeIntelligenceScreen`: Condensed to focus on "Narrative Intelligence" as a new category.
- `PhaseExplanationScreen`: First-person ("I'll ask you", "help me see") → third-person ("identifies", "the analysis refines").

**Flow update:**
- `lumaraIntro` → `narrativeIntelligence` (skips `arcIntro`)
- `narrativeIntelligence` → `phaseExplanation` (skips `sentinelIntro`)
- Fallback mappings preserved: if state lands on removed screens, the next valid screen is shown.

#### Files modified
- `lib/shared/ui/onboarding/arc_onboarding_sequence.dart` — Removed `_ArcIntroScreen`, `_SentinelIntroScreen`; condensed text (~175 lines removed)
- `lib/shared/ui/onboarding/arc_onboarding_cubit.dart` — Flow skips removed screens
- `lib/shared/ui/onboarding/widgets/phase_explanation_screen.dart` — Third-person language

---

### Feed Greeting Simplified (ContextualGreetingService Removed)

The dynamic time-of-day greeting in the Unified Feed header has been replaced with a static, consistent message. `ContextualGreetingService` is no longer used.

**Before:** "Good morning" / "Welcome back" / "Picking up where we left off" (time/recency-based)
**After:** "Share what's on your mind." with a description: "I build context from your entries over time — your patterns, your phases, the decisions you're working through. The longer we work together, the more relevant my responses become."

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Removed `ContextualGreetingService` import/usage; static greeting text

---

### Phase Journey Gantt Card: Interactive Navigation

The Gantt card in the Unified Feed is now tappable. Tapping the card or the new "edit phases" icon button navigates to `PhaseAnalysisView`. Regimes reload on return.

- Card wrapped in `Material` + `InkWell` for tap and ripple.
- New `IconButton` (edit_calendar icon) in the card header row.
- `_loadRegimes()` called after returning from Phase view.

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Gantt card InkWell, edit button, reload on return

---

### Asset Optimization

- `LUMARA_Sigil.png` — Reduced from 256 KB to 42 KB (84% smaller).

---

### Selective Branding Reverts

Two labels changed from "LUMARA" back to "ARC" for internal/analysis contexts:
- `keyword_analysis_view.dart`: "LUMARA is analyzing your entry" → "ARC is analyzing your entry".
- `temporal_notification_service.dart`: "LUMARA Monthly Review" → "ARC Monthly Review".

#### Files modified
- `lib/arc/ui/widgets/keyword_analysis_view.dart`
- `lib/services/temporal_notification_service.dart`

---

## [3.3.20] - February 10, 2026 (working changes)

### ARC → LUMARA Branding Rename

Complete rename of all user-facing "ARC" references to "LUMARA" throughout the application.

**Asset Changes:**
- Deleted `assets/icon/LUMARA_Sigil_White.png`, `assets/icon/app_icon.png`, `assets/images/ARC-Logo.png`.
- Added `assets/icon/LUMARA_Sigil.png` — consolidated single sigil asset used everywhere (splash, tab bar, feed, voice sigil, onboarding, pulsing symbol, LumaraIcon widgets).

**Backup File Naming:**
- `ARC_BackupSet_` → `LUMARA_BackupSet_`, `ARC_Full_` → `LUMARA_Full_`, `ARC_Inc_` → `LUMARA_Inc_` (export filenames).
- Backward-compatible regex: reading existing backups matches both `LUMARA_*` and legacy `ARC_*` patterns.
- Google Drive folder: `ARC Backups` → `LUMARA Backups`.
- Local backup default folder: `ARCX_Backups` → `LUMARA_Backups`.

**UI Text:**
- Splash screen: uses `LUMARA_Sigil.png` instead of `ARC-Logo.png`; comments updated.
- Onboarding: "Welcome to ARC." → "Welcome to LUMARA.", "ARC learns..." → "LUMARA learns...", "ARC and LUMARA are built on..." → "LUMARA is built on...".
- Notifications: `ARC Monthly Review` → `LUMARA Monthly Review`, `ARC 6-Month View` → `LUMARA 6-Month View`, `ARC Year in Review` → `LUMARA Year in Review`.
- Copy.dart: "ARC changes your phase" → "LUMARA changes your phase".
- Keyword analysis: "ARC is analyzing" → "LUMARA is analyzing", "ARC Analysis" → "LUMARA Analysis".
- Arcform export: "ARC MVP" → "LUMARA MVP".
- Chat export: "ARC EPI v1.0" → "LUMARA EPI v1.0".
- Local backup: "Clean ARCX" → "Clean LUMARA archive", updated descriptions.
- Google Drive settings: all "ARC" references → "LUMARA".
- Permissions: "ARC needs a few permissions" → "LUMARA needs a few permissions".

#### Files deleted
- `assets/icon/LUMARA_Sigil_White.png`
- `assets/icon/app_icon.png`
- `assets/images/ARC-Logo.png`

#### Files added
- `assets/icon/LUMARA_Sigil.png`

#### Files modified (branding only)
- `lib/arc/chat/chat/chat_category_models.dart`
- `lib/arc/chat/ui/lumara_splash_screen.dart`
- `lib/arc/chat/ui/widgets/lumara_icon.dart`
- `lib/arc/chat/voice/ui/voice_sigil.dart`
- `lib/arc/core/widgets/keyword_analysis_view.dart`
- `lib/arc/ui/arcforms/arcform_mvp_view.dart`
- `lib/arc/ui/widgets/keyword_analysis_view.dart`
- `lib/core/i18n/copy.dart`
- `lib/mira/store/arcx/services/arcx_export_service_v2.dart`
- `lib/services/arcform_export_service.dart`
- `lib/services/temporal_notification_service.dart`
- `lib/shared/tab_bar.dart`
- `lib/shared/ui/onboarding/arc_onboarding_sequence.dart`
- `lib/shared/ui/onboarding/onboarding_view.dart`
- `lib/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart`
- `lib/shared/ui/settings/google_drive_settings_view.dart`
- `lib/shared/ui/settings/local_backup_settings_view.dart`
- `lib/shared/widgets/lumara_icon.dart`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart`

---

### Phase Sentinel Safety Integration

New Sentinel integration layer ensures RIVET/ATLAS phase proposals are checked against Sentinel (crisis/cluster alert) before being applied. If alert triggers, segment phase is overridden to Recovery as a safety measure.

**New file:** `lib/services/phase_sentinel_integration.dart`
- `resolvePhaseWithSentinel(proposal, allEntries)` — calculates Sentinel score on segment text; returns `PhaseLabel.recovery` if `score.alert` is true, otherwise returns RIVET/ATLAS proposed label.
- Graceful degradation: if Sentinel is unavailable (offline/Firestore), keeps the RIVET/ATLAS phase.

**Applied in:**
- `rivet_sweep_service.dart` — `runAutoPhaseAnalysis()` uses `resolvePhaseWithSentinel()` when creating regimes.
- `phase_analysis_view.dart` — `_runRivetSweep()` applies Sentinel check.
- `phase_analysis_settings_view.dart` — same integration.

**RIVET/ATLAS/Sentinel Roles Documented:**
- Header comments in `rivet_sweep_service.dart` now document the three-system architecture: RIVET (segmentation, gating), ATLAS (phase scoring), Sentinel (safety override).

#### Files added
- `lib/services/phase_sentinel_integration.dart`

#### Files modified
- `lib/services/rivet_sweep_service.dart` — Sentinel integration, updated comments
- `lib/ui/phase/phase_analysis_view.dart` — Sentinel integration
- `lib/shared/ui/settings/phase_analysis_settings_view.dart` — Sentinel integration

---

### Unified Feed: Selective Export, Phase Gantt, Paragraph Rendering

**Selective Export from Feed:**
- Selection bar now shows "Export (N)" button alongside "Delete (N)" when entries are selected.
- `_showExportOptions()` — bottom sheet offering ARCX (encrypted) or ZIP (portable) export.
- `_exportSelectedAsArcx()` — uses `ARCXExportServiceV2` with subset of journal IDs, shows progress dialog, shares via `Share.shareXFiles`.
- `_exportSelectedAsZip()` — uses `McpPackExportService`, shows progress dialog, shares via `Share.shareXFiles`.
- Only saved journal entries (with `journalEntryId`) can be exported.

**Phase Journey Gantt Card:**
- New `_PhaseJourneyGanttCard` widget embedded in the feed between phase Arcform preview and communication actions.
- Gantt-style horizontal bar showing phase regimes over time using `PhaseTimelinePainter`.
- Displays start/end dates, total days, number of phases.
- `PhaseRegimeService.getLastEntryDateInRange()` — returns latest journal entry date in a date range.
- `PhaseRegimeService.extendMostRecentRegimeToLastEntry()` — extends most recent regime end to last entry date.

**Phase Preview Refresh:**
- `_phasePreviewRefreshKey` state variable bumped when returning from Phase view, so both the Arcform preview and Gantt card rebuild with updated phase data.
- Wrapped in `KeyedSubtree` for forced rebuild.

**Paragraph Rendering:**
- `ExpandedEntryView._buildParagraphWidgets()` — splits text on double newlines (paragraph break) or single newlines (line break), renders each paragraph with 12px bottom spacing and 1.5 line height.
- Applied across all content renderers: conversation messages, written reflections, voice memos, LUMARA initiatives.
- `EntryContentRenderer._buildParagraphs()` — same paragraph logic applied in timeline view (replaces single `Text(content)` with properly spaced paragraphs).

**Summary Extraction:**
- `FeedHelpers.extractSummary()` — extracts `## Summary\n\n...\n\n---\n\n` header from content.
- `FeedHelpers.bodyWithoutSummary()` — returns content after the summary section.
- `ExpandedEntryView._buildWrittenContent()` — renders summary (italic, with "Summary" label) and body separately.

**Card Date Formatting:**
- New `FeedHelpers.formatEntryCreationDate()` — formats as "Today, 14:30", "Yesterday, 09:15", "Mar 15, 14:30", or "Mar 15, 2025".
- All 5 feed entry cards now use `formatEntryCreationDate()` — more prominent (12px, 0.8 opacity) than previous `formatFeedDate()` (11px, 0.5 opacity).
- `ReflectionCard` and `SavedConversationCard`: date moved to leading position in metadata row.

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Export, Gantt card, phase preview refresh
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — Paragraph rendering, summary extraction
- `lib/arc/unified_feed/utils/feed_helpers.dart` — `extractSummary`, `bodyWithoutSummary`, `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart` — Date in metadata row, `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart` — Same
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart` — `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart` — Same
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart` — Same
- `lib/arc/ui/timeline/widgets/entry_content_renderer.dart` — Paragraph rendering

---

### RIVET Reset on User Phase Change

When a user manually sets their phase (via quiz, timeline, or onboarding), RIVET is now reset so its gate closes and it accumulates fresh evidence before opening again.

- `PhaseRegimeService.changeCurrentPhase()` — calls `RivetProvider().safeClearUserData()` after creating new regime.
- `UserPhaseService.forceUpdatePhase()` — also resets RIVET.
- `simplified_arcform_view_3d.dart` — phase change now persists to `UserPhaseService.forceUpdatePhase()`.

#### Files modified
- `lib/services/phase_regime_service.dart` — RIVET reset, `getLastEntryDateInRange`, `extendMostRecentRegimeToLastEntry`
- `lib/services/user_phase_service.dart` — RIVET reset on `forceUpdatePhase`
- `lib/ui/phase/simplified_arcform_view_3d.dart` — `forceUpdatePhase` on phase change

---

### Voice Session: Auto-Endpoint Disabled

- `VoiceSessionService`: Endpoint detector callback is now a no-op — voice recording no longer auto-stops on silence.
- Previous behavior caused premature stop when users pause to think.
- User must now explicitly tap the talk button to indicate they're finished speaking.
- Removed `_onEndpointDetected()` method entirely.

#### Files modified
- `lib/arc/chat/voice/services/voice_session_service.dart`

---

### Privacy Settings: Inline PII Scrub Demo

- `PrivacySettingsView`: New "Test privacy protection" card with real-time PII scrubbing demo.
- Inline `TextField` with debounced input (350ms) → runs `PrismAdapter.scrub()` → shows scrubbed output and redaction count.
- Pre-filled example: "Hi, I'm Jane. Email me at jane@example.com or call (555) 123-4567."
- Shows "What we send to the cloud:" label with scrubbed text and "N PII item(s) redacted" counter.

#### Files modified
- `lib/shared/ui/settings/privacy_settings_view.dart`

---

## [3.3.19] - February 9, 2026 (working changes)

### Unified Feed — Phase 2.0: Entry Management, Media, LUMARA Chat Integration, Phase Priority

Building on Phase 1.5 (`v3.3.18`), this update evolves the Unified Feed from read-only browsing into a full entry-management hub with deletion, media display, direct LUMARA chat, and phase-priority fixes across the application.

**Entry Deletion (swipe + batch):**
- Swipe-to-delete on any card that has a `journalEntryId` — `Dismissible` with confirmation dialog, calls `JournalRepository.deleteJournalEntry()`, refreshes feed.
- **Batch selection mode**: "Select entries" (checklist icon) in header actions enters multi-select. Selection overlay with checkboxes on each card. "Delete (N)" button with confirmation dialog deletes all selected entries, then refreshes feed.
- **ExpandedEntryView delete**: Options menu "Delete" is now fully wired — confirmation dialog, actual deletion via `JournalRepository`, calls `onEntryDeleted` callback, pops view, shows snackbar.

**Media Support:**
- `FeedEntry.mediaItems` (`List<MediaItem>`) added to model and populated by `FeedRepository` from journal entry media.
- **ReflectionCard**: Shows `FeedMediaThumbnails` strip (up to 4 thumbnails) beneath content preview.
- **ExpandedEntryView**: Full media section with grid of thumbnail tiles; resolves `ph://`, `file://`, and MCP-style URIs via `MediaResolverService`/`PhotoLibraryService`. Tapping an image opens `FullImageViewer`.
- **New widget**: `FeedMediaThumbnailTile` and `FeedMediaThumbnails` (`widgets/feed_media_thumbnails.dart`) — reusable media thumbnail components.

**LUMARA Chat Integration:**
- "Chat" button in feed now opens `LumaraAssistantScreen` directly (replaces focusing input bar).
- `_buildEntryMessageForLumara()` finds the most recent entry with content and sends it to LUMARA as "Please reflect on this entry" — enabling one-tap reflection on any recent entry.
- `LumaraAssistantScreen` gains `initialMessage` parameter; auto-sends via `addPostFrameCallback` on first frame.
- Removed `ChatNavigationDrawer` — AppBar leading is now a back arrow (when navigable) instead of hamburger menu. "New Chat" removed from popup menu.

**Input Bar Removed:**
- `FeedInputBar` entirely removed from `UnifiedFeedScreen` (import, widget, `_inputFocusNode`, `_onMessageSubmit` all deleted). Chat, Reflect, and Voice are now dedicated action buttons.

**Communication Actions in Populated Feed:**
- Chat / Reflect / Voice row (`_buildCommunicationActions()`) added to the populated feed (above "Today" section, below phase preview), replacing the input bar for quick-start actions.
- Previously these actions only existed in the welcome/empty state.

**Phase Arcform Preview in Feed:**
- `CurrentPhaseArcformPreview` widget embedded in the feed (below header actions, above communication row). Tap opens `PhaseAnalysisView`.
- `onTapOverride` callback added to `CurrentPhaseArcformPreview` for customizable navigation.
- Phase resolution now uses `UserPhaseService.getDisplayPhase()` (profile-first priority) with RIVET gate check via `RivetProvider`.

**Phase Hashtag Stripping:**
- New `FeedHelpers.contentWithoutPhaseHashtags()` strips `#discovery`, `#expansion`, `#transition`, `#consolidation`, `#recovery`, `#breakthrough` from display content. Phase information shows only in card metadata/header, not in body text.
- Applied in: `ReflectionCard`, `ExpandedEntryView` (all content renderers: conversation, reflection, voice memo, LUMARA initiative).

**ExpandedEntryView Edit:**
- Edit button now loads full `JournalEntry` via `JournalRepository.getJournalEntryById()` and opens `JournalScreen` in edit mode.

**Header Actions Rearranged:**
- Voice memo icon replaced by "Select entries" (checklist icon) for batch delete.
- Remaining: Select, Timeline (calendar), Settings gear.

**Phase Priority Fix (UserPhaseService):**
- `getDisplayPhase()` reordered: user's explicit phase (quiz or manual "set overall phase") takes priority over RIVET/regime. This ensures a user who sets "Breakthrough" via the Phase Timeline keeps that phase visible everywhere.
- `PhaseTimelineView`: Changing phase now persists to `UserPhaseService.forceUpdatePhase()`.
- `JournalScreen`: User profile creation preserves existing phase from quiz/snapshots instead of defaulting to "Discovery".

**Auto Phase Analysis After Import:**
- `runAutoPhaseAnalysis()` top-level function added to `rivet_sweep_service.dart` — headless RIVET Sweep that auto-creates phase regimes from all entries (no user navigation required).
- `RivetSweepResult.approvableProposals` getter — combines auto-assign + review proposals, sorted by start date.
- `HomeView`: After successful ARCX/ZIP import, automatically runs phase analysis in background with snackbar notification ("Phase analysis complete — N phases detected").

**Phase Analysis Refactored:**
- `PhaseAnalysisView`: Removed pending analysis approval flow (`_hasUnapprovedAnalysis`, `_lastSweepResult`). Analysis now auto-applies. `_checkPendingAnalysis` clears stale flags (no-op).
- `CombinedAnalysisView`: Removed entire Phase Analysis tab (~564 lines). Now contains only Advanced Analytics.
- **New**: `PhaseAnalysisSettingsView` (`lib/shared/ui/settings/phase_analysis_settings_view.dart`) — dedicated Settings screen for Phase Analysis with run-analysis button and phase statistics cards.
- `SettingsView`: Added "Phase Analysis" menu item linking to `PhaseAnalysisSettingsView`. Renumbered subsequent items.

**CHRONICLE Management Progress UI:**
- `ChronicleManagementView`: Rich progress view replacing generic spinner — circular progress indicator with percentage overlay, stage label ("Backfilling Layer 0..."), entry count ("12 / 340 entries"), and linear progress bar.

**Journal Screen Cleanup:**
- Removed `_trackJournalModeEntry()` and `_showPromptNotice()` (prompt notice dialog was interruptive UX).

**FeedRepository:**
- Phase extraction now uses `entry.computedPhase` (manual user override takes priority over auto-detected).
- Empty-string phase check prevents passing blank phases to `PhaseColors.getPhaseColor()`.

#### Files added
- `lib/arc/unified_feed/widgets/feed_media_thumbnails.dart`
- `lib/shared/ui/settings/phase_analysis_settings_view.dart`

#### Files modified
- `lib/arc/unified_feed/models/feed_entry.dart` — Added `mediaItems` field
- `lib/arc/unified_feed/repositories/feed_repository.dart` — `computedPhase`, empty check, `mediaItems`
- `lib/arc/unified_feed/utils/feed_helpers.dart` — `contentWithoutPhaseHashtags()`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Removed input bar; added batch select, swipe-to-delete, communication actions, phase preview, LUMARA chat integration
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — Media section, working edit/delete, phase hashtag stripping, `onEntryDeleted` callback
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart` — Phase hashtag stripping, media thumbnails
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — `initialMessage`, removed drawer, back arrow navigation
- `lib/services/rivet_sweep_service.dart` — `approvableProposals`, `runAutoPhaseAnalysis()`
- `lib/services/user_phase_service.dart` — Phase priority reordered (profile first)
- `lib/shared/ui/home/home_view.dart` — Auto phase analysis after import
- `lib/shared/ui/settings/chronicle_management_view.dart` — Rich progress UI
- `lib/shared/ui/settings/combined_analysis_view.dart` — Removed Phase Analysis tab
- `lib/shared/ui/settings/settings_view.dart` — Phase Analysis menu item
- `lib/ui/journal/journal_screen.dart` — Removed prompt notice, phase-preserving profile creation
- `lib/ui/phase/phase_analysis_view.dart` — Auto-apply analysis, removed approval flow
- `lib/ui/phase/phase_timeline_view.dart` — `forceUpdatePhase` on phase change
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — `onTapOverride`, profile-first phase resolution

---

## [3.3.18] - February 9, 2026 (working changes)

### Unified Feed — Phase 1.5: Model refactor, pagination, expanded views, timeline navigation

Building on Phase 1 (`v3.3.17`), this update significantly evolves the Unified Feed architecture:

**Model Refactor:**
- **FeedEntry**: `writtenEntry` type renamed to `reflection`; new `lumaraInitiative` type for LUMARA-initiated observations/prompts. Replaced `createdAt`/`updatedAt` with single `timestamp`. Added `FeedMessage` class for in-model conversation messages. Added `themes`, `phaseColor`, `messages`, `isActive`, `audioPath`, `transcriptPath`. Content is now `dynamic` (string or structured). `preview` is a computed getter. Removed Equatable dependency.
- **EntryState**: Simplified from full lifecycle class to streamlined enum-based state.

**FeedRepository Enhancements:**
- Pagination via `getFeed(before, after, limit, types)`.
- `getActiveConversation()` with 20-minute staleness check.
- Robust error handling: journal and chat repos initialize independently; errors don't block feed.
- Phase color extraction via `PhaseColors.getPhaseColor()`.
- Theme extraction from entry metadata.
- Search now includes themes.

**New Widgets:**
- **ExpandedEntryView** (`widgets/expanded_entry_view.dart`): Full-screen detail view for any entry — phase indicator, full content, themes, CHRONICLE-related entries, LUMARA notes, edit/share/delete actions.
- **BaseFeedCard** (`widgets/feed_entry_cards/base_feed_card.dart`): Shared card wrapper with phase-colored left border indicator. All cards extend this.
- **ReflectionCard** (`widgets/feed_entry_cards/reflection_card.dart`): Replaces `WrittenEntryCard` for text-based reflections.
- **LumaraPromptCard** (`widgets/feed_entry_cards/lumara_prompt_card.dart`): LUMARA-initiated observations, check-ins, and prompts detected by CHRONICLE/VEIL/SENTINEL.
- **TimelineModal** (`widgets/timeline/timeline_modal.dart`): Bottom sheet for date-based feed navigation.
- **TimelineView** (`widgets/timeline/timeline_view.dart`): Calendar/timeline view within the modal.

**Infrastructure:**
- **PhaseColors** (`lib/core/constants/phase_colors.dart`): Phase color constants for card borders and indicators.
- **EntryMode** (`lib/core/models/entry_mode.dart`): Enum (`chat`, `reflect`, `voice`) for initial screen state from welcome screen or deep links.
- **app.dart**: Switched from named routes to `onGenerateRoute` to pass `EntryMode` arguments to HomeView.

**UnifiedFeedScreen Enhancements:**
- Infinite scroll / load-more pagination (loads 20 entries at a time).
- Timeline modal accessible from app bar (calendar icon) for date navigation.
- Date filter: jump to specific date, clear filter to return to feed.
- Voice mode launch via callback from HomeView.
- `initialMode` parameter: feed activates chat/reflect/voice mode on first frame (from welcome screen).
- LUMARA observation banner.
- Card taps navigate to ExpandedEntryView.

**HomeView:**
- Simplified from 2 tabs (LUMARA + Phase) to single LUMARA tab in unified mode. Phase accessible via Timeline button inside the feed.
- Passes `onVoiceTap` and `initialMode` to UnifiedFeedScreen.

#### Files added
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/base_feed_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart`
- `lib/arc/unified_feed/widgets/timeline/timeline_modal.dart`
- `lib/arc/unified_feed/widgets/timeline/timeline_view.dart`
- `lib/core/constants/phase_colors.dart`
- `lib/core/models/entry_mode.dart`

#### Files modified
- `lib/arc/unified_feed/models/feed_entry.dart` — Major refactor (see above)
- `lib/arc/unified_feed/models/entry_state.dart` — Simplified
- `lib/arc/unified_feed/repositories/feed_repository.dart` — Pagination, error handling, phase colors
- `lib/arc/unified_feed/services/conversation_manager.dart` — Adapted to new FeedEntry shape
- `lib/arc/unified_feed/services/auto_save_service.dart` — Minor update
- `lib/arc/unified_feed/utils/feed_helpers.dart` — Extended helpers
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Timeline, pagination, modes, expanded view
- `lib/arc/unified_feed/widgets/input_bar.dart` — Minor update
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart` — Uses BaseFeedCard
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart` — Uses BaseFeedCard
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart` — Uses BaseFeedCard
- `lib/shared/ui/home/home_view.dart` — Single tab, passes onVoiceTap/initialMode
- `lib/app/app.dart` — onGenerateRoute for EntryMode

#### Files deleted
- `lib/arc/unified_feed/widgets/feed_entry_cards/written_entry_card.dart` — Replaced by ReflectionCard

### Welcome Screen / First-Use UX & Settings Tab

**Empty state awareness:**
- **UnifiedFeedScreen**: New `onEmptyStateChanged` callback reports whether the feed has entries. Input bar is hidden when the feed is empty so the welcome screen stands alone. Wrapped in `GestureDetector` to dismiss keyboard on outside tap.
- **HomeView**: Tracks `_feedIsEmpty` state. Bottom navigation bar is hidden when the unified feed is in the empty/welcome state, providing a clean first-use onboarding experience. Once entries exist, the full nav appears.

**Tab layout change (unified mode):**
- Restored 2-tab layout: **LUMARA** (index 0) + **Settings** (index 1).
- `_getPageForIndex` routes Settings tab to `SettingsView`.
- Center "+" journal button hidden in unified feed mode (`showCenterButton: false`) since the input bar and quick-start actions replace it.

**tab_bar.dart:**
- The center "+" button is now conditionally rendered based on `showCenterButton` property (previously always rendered regardless of the flag value).

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — `onEmptyStateChanged` callback, input bar hidden in empty state, GestureDetector wrapper
- `lib/shared/tab_bar.dart` — Center button conditional rendering
- `lib/shared/ui/home/home_view.dart` — `_feedIsEmpty` state, nav hidden on empty, Settings tab, showCenterButton logic

### Welcome Screen: Phase Quiz, Settings Gear, Data Import

**Welcome screen redesign (`_buildEmptyState`):**
- **Settings gear** (top-right) — opens SettingsView directly from the welcome screen, giving first-time users access to account/preferences before creating any entries.
- **"Discover Your Phase" button** — prominent gradient button (using `kcPrimaryGradient`) placed between the subtitle and quick-start actions. Launches `PhaseQuizV2Screen` so new users can immediately identify their life phase, which seeds ATLAS phase detection for all future entries.
- **Chat / Reflect / Voice buttons** moved down one row below the Phase Quiz button.
- **"Import your data" link** at the bottom — separated by a divider. Opens `ImportOptionsSheet` bottom sheet for users with existing journal data.
- Welcome content wrapped in `SingleChildScrollView` for small screens and `SafeArea`.

**ImportOptionsSheet** (`widgets/import_options_sheet.dart`):
- Full-height bottom sheet with 5 import source options: LUMARA Backup, Day One, Journey, Text Files, CSV/Excel.
- Each option uses `file_picker` to select files.
- Progress view with circular indicator, percentage, and status messages during import.
- Info card explaining CHRONICLE temporal intelligence will be built from imported data.

**UniversalImporterService** (`services/universal_importer_service.dart`):
- Format-specific importers for each source: LUMARA/ARCX JSON, Day One JSON, Journey JSON, plain text/Markdown (auto-split by date patterns), CSV (column auto-detection).
- Deduplication against existing entries (timestamp + content hash).
- Progress callbacks throughout the pipeline.
- Robust error handling per-entry (bad entries skipped, not blocking).

#### Files added
- `lib/arc/unified_feed/widgets/import_options_sheet.dart`
- `lib/arc/unified_feed/services/universal_importer_service.dart`

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Redesigned `_buildEmptyState` with settings gear, phase quiz, import link; added `_buildPhaseQuizButton`, `_showImportOptions`

---

## [3.3.17] - February 8, 2026

### Unified Feed — Phase 1 (NEW, feature-flagged)

- **Feature flag:** `USE_UNIFIED_FEED` in `lib/core/feature_flags.dart` (default: `false`). When enabled, replaces the 3-tab layout (LUMARA / Phase / Conversations) with a 2-tab layout (LUMARA / Phase) where the LUMARA tab is a unified scrollable feed merging chat and journal entries.
- **FeedEntry model** (`lib/arc/unified_feed/models/feed_entry.dart`): View-layer model aggregating journal entries, chat sessions, and voice memos into a single `FeedEntry` with 4 types (`activeConversation`, `savedConversation`, `voiceMemo`, `writtenEntry`).
- **EntryState** (`lib/arc/unified_feed/models/entry_state.dart`): State tracking (draft, saving, saved, error).
- **FeedRepository** (`lib/arc/unified_feed/repositories/feed_repository.dart`): Aggregates data from JournalRepository, ChatRepo, and VoiceNoteRepository into a unified feed stream.
- **ConversationManager** (`lib/arc/unified_feed/services/conversation_manager.dart`): Active conversation lifecycle — message tracking, auto-save after inactivity (5 min default, configurable), conversation→journal entry persistence with LUMARA inline blocks.
- **AutoSaveService** (`lib/arc/unified_feed/services/auto_save_service.dart`): App lifecycle-aware auto-save triggers (saves on background/pause).
- **ContextualGreetingService** (`lib/arc/unified_feed/services/contextual_greeting.dart`): Time-of-day and recency-based greeting generation for the feed header.
- **FeedHelpers** (`lib/arc/unified_feed/utils/feed_helpers.dart`): Date grouping and sorting utilities.
- **UnifiedFeedScreen** (`lib/arc/unified_feed/widgets/unified_feed_screen.dart`): Main feed screen — LUMARA sigil header with contextual greeting, date-grouped entry cards, pull-to-refresh, empty state with Chat/Write/Voice actions.
- **FeedInputBar** (`lib/arc/unified_feed/widgets/input_bar.dart`): Bottom input bar with text field, voice, attachment, and new entry buttons.
- **Feed entry cards** (`lib/arc/unified_feed/widgets/feed_entry_cards/`): 4 card widgets — `ActiveConversationCard`, `SavedConversationCard`, `VoiceMemoCard`, `WrittenEntryCard`.
- **CustomTabBar** (`lib/shared/tab_bar.dart`): Refactored from hardcoded 3 tabs to dynamic loop over `tabs` list; removed unused `LumaraIcon` import.
- **HomeView** (`lib/shared/ui/home/home_view.dart`): Conditional tab layout — 2 tabs + UnifiedFeedScreen in unified mode, 3 tabs in legacy mode.

#### Files added
- `lib/arc/unified_feed/models/feed_entry.dart`
- `lib/arc/unified_feed/models/entry_state.dart`
- `lib/arc/unified_feed/repositories/feed_repository.dart`
- `lib/arc/unified_feed/services/conversation_manager.dart`
- `lib/arc/unified_feed/services/auto_save_service.dart`
- `lib/arc/unified_feed/services/contextual_greeting.dart`
- `lib/arc/unified_feed/utils/feed_helpers.dart`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart`
- `lib/arc/unified_feed/widgets/input_bar.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/written_entry_card.dart`

#### Files modified
- `lib/core/feature_flags.dart` — Added `USE_UNIFIED_FEED` flag
- `lib/shared/tab_bar.dart` — Dynamic tab generation
- `lib/shared/ui/home/home_view.dart` — Conditional unified/legacy routing

### Google Drive Export Progress UI

- **GoogleDriveSettingsView** (`lib/shared/ui/settings/google_drive_settings_view.dart`): Added visual progress bar with percentage during export/upload to Google Drive. Granular stage-by-stage progress messages (initializing, loading entries, creating ZIP, connecting to Drive, uploading, complete). `LinearProgressIndicator` with accent color, `CircularProgressIndicator` spinner, and percentage text. Brief 100% pause before clearing. New `_setExportProgress()` helper and `_exportPercentage` tracking (0.0–1.0).

---

## [3.3.16] - February 8, 2026

### Reflection Session Safety System (NEW)

- **ReflectionSession model** (`lib/models/reflection_session.dart`): Hive model (typeId 125/126) tracking reflection exchanges per journal entry with pause capability.
- **ReflectionSessionRepository** (`lib/repositories/reflection_session_repository.dart`): Hive-backed CRUD for active, paused, and recent sessions.
- **ReflectionPatternAnalyzer** (`lib/arc/chat/reflection/reflection_pattern_analyzer.dart`): Detects rumination (same themes repeated across 3+ queries without CHRONICLE usage).
- **ReflectionEmotionalAnalyzer** (`lib/arc/chat/reflection/reflection_emotional_analyzer.dart`): Measures validation-seeking ratio; detects avoidance patterns via emotional density.
- **AuroraReflectionService** (`lib/aurora/reflection/aurora_reflection_service.dart`): Risk assessment with 4 signals (prolonged session, rumination, emotional dependence, avoidance); tiered interventions (notice, redirect, pause).
- **ReflectionHandler** (`lib/arc/chat/services/reflection_handler.dart`): Orchestrates reflection flow — creates/retrieves sessions, appends exchanges, runs safety checks, issues interventions.

### RevenueCat In-App Purchases (NEW)

- **RevenueCatService** (`lib/services/revenuecat_service.dart`): In-app purchase management via RevenueCat SDK. Configures at app startup with Firebase UID sync. Login/logout with auth flow. Checks `ARC Pro` entitlement for premium access. Paywall presentation via RevenueCat UI.
- **SubscriptionService** (`lib/services/subscription_service.dart`): Updated to check both Stripe (web) and RevenueCat (in-app) for premium status.
- **Bootstrap** (`lib/main/bootstrap.dart`): RevenueCat configured during app initialization.

### Voice Sigil State Machine

- **VoiceSigil** (`lib/arc/chat/voice/ui/voice_sigil.dart`): Upgraded from simple glowing indicator to 6-state animation system (Idle, Listening, Commitment, Accelerating, Thinking, Speaking) with particle effects, shimmer, and constellation points. LUMARA sigil image as center element.
- **Deleted**: `lib/arc/chat/voice/voice_journal/new_voice_journal_service.dart`, `new_voice_journal_ui.dart` (legacy voice journal files removed).

### PDF Preview

- **PdfPreviewScreen** (`lib/ui/journal/widgets/pdf_preview_screen.dart`): Full-screen in-app PDF viewer with pinch-to-zoom, "Open in app" system action, and file existence validation.

### Google Drive Folder Picker

- **DriveFolderPickerScreen** (`lib/shared/ui/settings/drive_folder_picker_screen.dart`): Browse Google Drive folder hierarchy for import (multi-folder) and sync (single-folder) selection.

### ARCX Clean Service

- **ARCXCleanService** (`lib/mira/store/arcx/services/arcx_clean_service.dart`): Removes chat sessions with fewer than 3 LUMARA responses from device-key-encrypted ARCX archives.
- **clean_arcx_chats.py** (`scripts/clean_arcx_chats.py`): Companion Python script for batch ARCX cleaning.

### Data & Infrastructure

- **DurationAdapter** (`lib/data/hive/duration_adapter.dart`): Hive TypeAdapter for `Duration` (typeId 105) — required for video entries with duration fields.
- **CHRONICLE synthesis**: PatternDetector, MonthlySynthesizer, YearlySynthesizer, MultiYearSynthesizer modified for improved theme extraction and non-theme word filtering.
- **LumaraReflectionOptions** (`lib/arc/chat/models/lumara_reflection_options.dart`): Updated with conversation modes and tone configuration.

#### Files added
- `lib/models/reflection_session.dart`, `lib/models/reflection_session.g.dart`
- `lib/repositories/reflection_session_repository.dart`
- `lib/arc/chat/reflection/reflection_emotional_analyzer.dart`
- `lib/arc/chat/reflection/reflection_pattern_analyzer.dart`
- `lib/arc/chat/services/reflection_handler.dart`
- `lib/aurora/reflection/aurora_reflection_service.dart`
- `lib/data/hive/duration_adapter.dart`
- `lib/services/revenuecat_service.dart`
- `lib/shared/ui/settings/drive_folder_picker_screen.dart`
- `lib/ui/journal/widgets/pdf_preview_screen.dart`
- `lib/mira/store/arcx/services/arcx_clean_service.dart`
- `scripts/clean_arcx_chats.py`
- `DOCS/ARC_AND_LUMARA_OVERVIEW.md`

#### Files deleted
- `lib/arc/chat/voice/voice_journal/new_voice_journal_service.dart`
- `lib/arc/chat/voice/voice_journal/new_voice_journal_ui.dart`

---

## Documentation update - February 7, 2026

**Docs:** Full documentation review and sync. Updated ARCHITECTURE, CHANGELOG, CONFIGURATION_MANAGEMENT, FEATURES, PROMPT_TRACKER, bug_tracker, backend, git.md with current dates. Backend and inventory now reference RevenueCat (in-app) and PAYMENTS_CLARIFICATION; added NARRATIVE_INTELLIGENCE, PAYMENTS_CLARIFICATION, revenuecat/ to DOCS.

---

## [3.3.15] - February 2, 2026 (merge & backup 2026-02-03)

**2026-02-03:** Branch `test` merged into `main`; backup branch `backup-main-2026-02-03` created from `main`.

### Journal & CHRONICLE robustness

- **JournalRepository:** Per-entry try/catch in `getAllJournalEntries` so one bad or legacy entry does not drop the entire list; skip and log on normalize failure.
- **Layer0Populator:** Backwards compatibility for legacy Hive entries: `_safeContent()` and `_safeKeywords()` handle null content/keywords. `populateFromJournalEntry` returns `bool` (true if saved); `populateFromJournalEntries` returns `(succeeded, failed)` counts.
- **Layer0Repository:** New `getMonthsWithEntries(userId)` — distinct months with Layer 0 data for batch synthesis.
- **ChronicleOnboardingService:** Layer 0 backfill uses populator’s succeeded/failed counts; clearer messages (e.g. "X of Y entries", "Z failed"). Batch synthesis builds months from Layer 0 via `getMonthsWithEntries` (not journal date range); message "No Layer 0 entries for this user. Run Backfill Layer 0 first." when none.

### Phase consistency (timeline / Conversations)

- **Phase tab → UserProfile:** After loading Phase tab, call `_updateUserPhaseFromRegimes()` so UserProfile current phase is in sync; timeline and Conversations phase preview then match Phase tab.
- **Current phase preview:** Prefer `UserPhaseService.getCurrentPhase()` (UserProfile) when set, so Conversations/timeline preview matches Phase tab; fallback to RIVET + regime logic when profile phase empty.
- **Home tab label:** "Conversation" → "Conversations" (plural).

#### Files modified

- `lib/arc/internal/mira/journal_repository.dart` — Per-entry try/catch in getAllJournalEntries; skip bad entries
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Backfill counts; synthesis from Layer 0 months; messages
- `lib/chronicle/storage/layer0_populator.dart` — _safeContent/_safeKeywords; return succeeded/failed
- `lib/chronicle/storage/layer0_repository.dart` — getMonthsWithEntries(userId)
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — Prefer profile phase for preview
- `lib/shared/ui/home/home_view.dart` — Tab label "Conversations"
- `lib/ui/phase/phase_analysis_view.dart` — _updateUserPhaseFromRegimes() after load

---

## [3.3.14] - February 2, 2026

### Settings & LUMARA

- **LUMARA from chat:** Drawer "Settings" now opens **Settings → LUMARA** (LumaraFolderView) instead of the full LUMARA settings screen; users can tap "API & providers" for full setup.
- **Settings structure:** Top-level **CHRONICLE** folder added (View CHRONICLE Layers, CHRONICLE Management). LUMARA and CHRONICLE folders moved above Health & Readiness. LUMARA folder includes new "API & providers" tile → LumaraSettingsScreen.
- **Web access default:** LUMARA web access default changed from opt-in (false) to automatic (true) — LUMARA may use the web when needed.
- **LUMARA settings screen:** Status card and Web Access card removed (settings simplified).

### Voice notes (Ideas)

- **VoiceNoteRepository:** Static broadcast added so any instance (e.g. saving from Voice Mode) notifies all `watch()` subscribers; Ideas list refreshes when saving from voice without reopening.

### CHRONICLE

- **Layer 0 backfill:** Re-populates entries when existing Layer 0 entry has different `userId` (e.g. `default_user`), not only when missing.
- **MonthlySynthesizer:** Log when no entries for month: "No entries for … (run Backfill Layer 0 if you have journal entries)."

### Google Drive backup & import

- **GoogleDriveService:** `getOrCreateAppFolder()` now searches for existing "ARC Backups" folder to avoid duplicates. New `getOrCreateDatedSubfolder(date)` (yyyy-MM-dd) with in-memory cache so same-day uploads use one folder. New `listAllBackupFiles()` for Import from Drive (dated subfolders + root).
- **GoogleDriveSettingsView:** Security-scoped access retained after folder pick so Upload works without re-picking (iOS/macOS). In-app sandbox detection (no security-scoped request for Documents/Support/Temp). Import backup list expandable; last upload-from-folder time persisted.

### Local backup

- **LocalBackupSettingsView:** iOS/macOS security-scoped access for backup folder when path is outside app sandbox; start/stop around backup and export operations. User message to re-select folder if access is needed. Helper `_isBackupPathInAppSandbox()`.

#### Files modified

- `lib/arc/chat/services/lumara_reflection_settings_service.dart` — Web access default true
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — Settings → LumaraFolderView; label "Settings"
- `lib/arc/chat/ui/lumara_settings_screen.dart` — Remove Status card, Web Access card
- `lib/arc/voice_notes/repositories/voice_note_repository.dart` — Static broadcast for watch() across instances
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Layer 0 re-populate when userId differs
- `lib/chronicle/synthesis/monthly_synthesizer.dart` — Log when no entries for month
- `lib/services/google_drive_service.dart` — Search app folder; dated subfolder + cache; listAllBackupFiles
- `lib/shared/ui/settings/google_drive_settings_view.dart` — Retain security-scoped access; sandbox check; Import list; last upload time
- `lib/shared/ui/settings/local_backup_settings_view.dart` — Security-scoped access for external backup path
- `lib/shared/ui/settings/settings_view.dart` — CHRONICLE folder; LUMARA/CHRONICLE order; LumaraFolderView "API & providers"; ChronicleFolderView

---

## [3.3.13] - January 31, 2026

### Fix: Wispr Flow cache – new API key used after save without restart

#### Overview
Wispr Flow API key was cached in `WisprConfigService`. After saving a new or updated API key in **LUMARA Settings → External Services**, voice mode could still use the previous key until the app was restarted. Fix: call `WisprConfigService.instance.clearCache()` after saving the API key so the next voice session uses the new key.

#### Changes
- **lumara_settings_screen.dart**: In `_saveWisprApiKey()`, after writing the key to SharedPreferences, call `WisprConfigService.instance.clearCache()` so the new key is used on the next voice mode session without restart.
- **WisprConfigService**: Already had `clearCache()` (clears `_cachedApiKey`, `_hasCheckedPrefs`); settings screen now invokes it on save.

#### Related
- Bug Tracker: `DOCS/bugtracker/records/wispr-flow-cache-issue.md`

---

### Fix: Phase Quiz result matches Phase tab; rotating phase on Phase tab

#### Overview
Phase Quiz V2 result (e.g. Breakthrough) was not persisted, so the main app and Phase tab showed Discovery. Phase tab now uses the quiz result when there are no phase regimes (e.g. right after onboarding). The rotating phase shape from the phase reveal is now shown alongside the detailed 3D constellation on the Phase tab.

#### Changes
- **Phase Quiz V2 → UserProfile**: After completing the phase quiz, the selected phase is persisted via `UserPhaseService.forceUpdatePhase()` (capitalized) so the main app and Phase tab show the same phase.
- **UserPhaseService.forceUpdatePhase**: Now updates both `onboardingCurrentSeason` and `currentPhase` on UserProfile for consistency.
- **Phase tab when no regimes**: When there are no phase regimes (e.g. right after onboarding), Phase tab and SimplifiedArcformView3D use `UserPhaseService.getCurrentPhase()` (quiz result) instead of defaulting to Discovery.
- **Rotating phase on Phase tab**: The same rotating phase shape (AnimatedPhaseShape) used on the phase reveal screen is now displayed above the detailed 3D constellation on the Phase tab, with the phase name label alongside.

#### Methodology
- **Quiz**: Self-reported phase from Q1 ("Which best describes where you are right now?").
- **App (Rivet/Sentinel/Prism)**: Inferred phase from journal content via phase regimes. When no regimes exist, the app respects the quiz result until regimes are created.

#### Files Modified
- `lib/shared/ui/onboarding/phase_quiz_v2_screen.dart` — Persist quiz phase via UserPhaseService after conductQuiz
- `lib/services/user_phase_service.dart` — forceUpdatePhase sets both onboardingCurrentSeason and currentPhase
- `lib/ui/phase/phase_analysis_view.dart` — _phaseFromUserProfile when no regimes; rotating AnimatedPhaseShape above 3D view
- `lib/ui/phase/simplified_arcform_view_3d.dart` — When no regimes, use UserPhaseService.getCurrentPhase() instead of Discovery

---

## [3.3.13] - January 31, 2026

### Fix: iOS Folder Verification Permission Error

#### Overview
Fixed critical issue where folder verification in `VerifyBackupScreen` failed on iOS with "Operation not permitted" error when attempting to scan `.arcx` backup files in user-selected folders.

#### Changes
- **iOS Security-Scoped Resource Access**: Added proper handling of security-scoped resources when accessing user-selected folders on iOS
- **`arcx_scan_service.dart`**: Modified `scanArcxFolder()` to start accessing security-scoped resource before listing directory, with proper cleanup in `finally` block
- **`verify_backup_screen.dart`**: Added security-scoped resource access handling in `_scanFolder()` method with user-friendly error messages
- **Error Handling**: Improved error messages when folder access is denied on iOS

#### Technical Details
- On iOS, `FilePicker` returns security-scoped resource paths that require explicit access permissions
- Added calls to `startAccessingSecurityScopedResourceWithFilePath()` before directory operations
- Added proper cleanup with `stopAccessingSecurityScopedResourceWithFilePath()` in `finally` blocks
- Uses existing `accessing_security_scoped_resource` package (v3.4.0)

#### Files Modified
- `lib/mira/store/arcx/services/arcx_scan_service.dart` - Added security-scoped resource handling
- `lib/shared/ui/settings/verify_backup_screen.dart` - Added security-scoped resource handling and improved error messages

#### Related
- Bug Tracker: `DOCS/bugtracker/records/ios-folder-verification-permission-error.md`

---

## [3.3.13] - January 26, 2026

### Import: Global status bar, percentage, and Import Status screen

#### Overview
When an ARCX/MCP import runs in the background, a mini status bar is shown below the app bar on the home screen so users can see progress (including percentage) without staying on the import screen. Users can also go to **Settings → Import Data** to open the **Import Status** screen, which shows current import progress and a list of files with status (pending / in progress / completed / failed). The app remains usable during import.

#### Changes
- **ImportStatusBar** (`lib/shared/widgets/import_status_bar.dart`): Shown below the app bar when an import is active; shows message, progress bar, and **percentage (0%–100%)**; includes “You can keep using the app”; pushes main content down.
- **ImportStatusScreen** (`lib/shared/ui/settings/import_status_screen.dart`): New screen under Settings → Import. When no import is active: “No import in progress” and “Choose files to import”. When import is active: overall message, progress bar, and list of files with status (Pending / In progress / Completed / Failed). When completed or failed: result summary, file list, Done, and “Import more”.
- **ImportProgressCubit** (`lib/mira/store/arcx/import_progress_cubit.dart`): Global import progress (isActive, message, fraction, error, completed); **per-file status** for multi-file imports (`fileItems`, `ImportFileStatus`, `startWithFiles`, `updateFileStatus`); used by the status bar and Import Status screen.
- **HomeView**: Wraps content with ImportStatusBar so the bar appears when import is running.
- **App**: Provides ImportProgressCubit at app level so import services and UI share the same state.
- **Settings → Import Data**: Opens Import Status screen (with “Choose files to import” to start an import); user can view progress and file list while import runs in the background.
- **Multi-ARCX import**: Uses `startWithFiles` and `updateFileStatus` so the Import Status screen shows per-file status.
- **ARCX import services**: Updated to use ImportProgressCubit for progress updates during import.
- **ARCX import progress screen / MCP import screen**: Adjusted to work with global progress where applicable.

#### Files Modified
- `lib/app/app.dart` — Provide ImportProgressCubit
- `lib/shared/ui/home/home_view.dart` — Show ImportStatusBar
- `lib/shared/ui/settings/settings_view.dart` — Import Data tile opens ImportStatusScreen; multi-ARCX uses startWithFiles/updateFileStatus
- `lib/mira/store/arcx/services/arcx_import_service.dart`, `arcx_import_service_unified.dart`, `arcx_import_service_v2.dart` — Use ImportProgressCubit
- `lib/mira/store/arcx/ui/arcx_import_progress_screen.dart` — Use shared progress
- `lib/ui/export_import/mcp_import_screen.dart` — Import flow
- `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` — iOS project updates

#### New Files
- `lib/mira/store/arcx/import_progress_cubit.dart`
- `lib/shared/widgets/import_status_bar.dart`
- `lib/shared/ui/settings/import_status_screen.dart`

#### Build fix
- **Local backup service** (`lib/services/local_backup_service.dart`): `onProgress` callbacks updated to accept optional fraction parameter `(msg, [fraction])` to match `void Function(String, [double?])?` used by `exportFullBackupChunked` and related export APIs.

---

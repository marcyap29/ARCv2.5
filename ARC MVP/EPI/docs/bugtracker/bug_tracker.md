# EPI MVP - Bug Tracker

**Version:** 3.2.6  
**Last Updated:** 2026-02-15  
**Record count:** 35 individual bug records in [records/](records/). Index below matches all files in records/.

---

## How to use this tracker

- **Index:** Use the sections below to find bugs by category (LUMARA, Timeline & UI, Export/Import, etc.). Each entry links to a detailed record in `records/`.
- **Fix instructions:** Each record in `records/` should include a **How to fix** section (or equivalent) with concrete steps so bugs can be resolved or worked around without hunting through the codebase.
- **Recent code changes:** Table derived from repo and [CHANGELOG.md](../CHANGELOG.md) – use it to see which fixes have bug records and which might need new records.
- **Archive:** Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md) are in [archive/](archive/).

---

## Bug Tracker Index

This bug tracker has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[bug_tracker_part1.md](bug_tracker_part1.md)** | Dec 2025 | v2.1.43 - v2.1.60 (Recent) |
| **[bug_tracker_part2.md](bug_tracker_part2.md)** | Nov 2025 | v2.1.27 - v2.1.42 |
| **[bug_tracker_part3.md](bug_tracker_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.26 & Earlier |

---

## Individual Bug Records

Detailed bug reports are available in the [records/](records/) directory:

### LUMARA Issues
- [lumara-temporal-context-incorrect-dates.md](records/lumara-temporal-context-incorrect-dates.md) - **HIGH:** Incorrect date references in reflections (v3.2.2) ✅ RESOLVED
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections (v3.2.2) ✅ RESOLVED
- [lumara-user-prompt-override.md](records/lumara-user-prompt-override.md) - **CRITICAL:** User prompt overriding master prompt constraints (v3.0) ✅ RESOLVED
- [lumara-response-cutoff.md](records/lumara-response-cutoff.md) - Response truncation issues
- [lumara-subject-drift-and-repetitive-endings.md](records/lumara-subject-drift-and-repetitive-endings.md) - Subject focus and ending phrase issues
- [lumara-integration-formatting.md](records/lumara-integration-formatting.md) - Formatting and integration bugs
- [lumara-settings-refresh-loop.md](records/lumara-settings-refresh-loop.md) - Settings refresh issues

### Timeline & UI Issues
- [timeline-infinite-rebuild-loop.md](records/timeline-infinite-rebuild-loop.md) - Timeline rebuild performance
- [timeline-ordering-timestamps.md](records/timeline-ordering-timestamps.md) - Entry ordering issues
- [timeline-overflow-empty-state.md](records/timeline-overflow-empty-state.md) - Empty state display
- [ui-ux-critical-fixes-jan-08-2025.md](records/ui-ux-critical-fixes-jan-08-2025.md) - Critical UI/UX fixes
- [ui-ux-fixes-jan-2025.md](records/ui-ux-fixes-jan-2025.md) - General UI/UX improvements
- [lumara-ui-overlap-stripe-auth-fixes.md](records/lumara-ui-overlap-stripe-auth-fixes.md) - LUMARA UI overlap and Stripe auth fixes

### Export/Import Issues
- [arcx-export-photo-directory-mismatch.md](records/arcx-export-photo-directory-mismatch.md) - Photo directory structure
- [arcx-import-date-preservation.md](records/arcx-import-date-preservation.md) - Date preservation during import
- [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) - **HIGH:** iOS folder verification permission error (v3.2.2) ✅ RESOLVED
- [mcp-repair-system-fixes.md](records/mcp-repair-system-fixes.md) - MCP repair system issues

### Data & Storage Issues
- [hive-initialization-order.md](records/hive-initialization-order.md) - Hive initialization problems
- [mediaitem-adapter-registration-conflict.md](records/mediaitem-adapter-registration-conflict.md) - MediaItem adapter conflicts
- [photo-duplication-view-entry.md](records/photo-duplication-view-entry.md) - Photo duplication bugs

### API & Integration Issues
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections ✅ RESOLVED
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration
- [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) - **MEDIUM:** Wispr Flow API key cached; new key not used until restart ✅ RESOLVED

### Subscription & Payment Issues
- [stripe-checkout-unauthenticated.md](records/stripe-checkout-unauthenticated.md) - **CRITICAL:** Cloud Run IAM blocking Stripe checkout ✅ RESOLVED
- [stripe-subscription-critical-fixes.md](records/stripe-subscription-critical-fixes.md) - Stripe subscription critical fixes

### Build & Platform Issues
- [build-fixes-session-feb-2026.md](records/build-fixes-session-feb-2026.md) - **CRITICAL:** Session consolidation – AppLifecycleState import, FeedRepository ChatMessage/session types, _buildRunAnalysisCard scope (3 bugs) ✅ RESOLVED
- [ios-build-rivet-models-keywords-set-type.md](records/ios-build-rivet-models-keywords-set-type.md) - **CRITICAL:** iOS build – rivet_models.g.dart keywords List vs Set<String> type error ✅ RESOLVED
- [ios-build-local-embedding-service-errors.md](records/ios-build-local-embedding-service-errors.md) - **CRITICAL:** iOS release build – CHRONICLE embedding stack (Dart parse/type, then EmbeddingService vs LocalEmbeddingService at call sites)
- [ios-build-native-embedding-channel-swift-scope.md](records/ios-build-native-embedding-channel-swift-scope.md) - **CRITICAL:** iOS Swift build – NativeEmbeddingChannel not in scope in AppDelegate.swift:104
- [ios-release-build-third-party-warnings.md](records/ios-release-build-third-party-warnings.md) - iOS release build third-party deprecation/warning noise (Pods, file_picker, Firebase, RevenueCat)

### Environment / Tooling
- [ollama-serve-address-in-use-and-quit-command.md](records/ollama-serve-address-in-use-and-quit-command.md) - Ollama: port 11434 already in use; `ollama quit` unknown command

### Feature-Specific Issues
- [constellation-zero-stars-display.md](records/constellation-zero-stars-display.md) - Constellation visualization
- [draft-creation-unwanted-drafts.md](records/draft-creation-unwanted-drafts.md) - Draft management
- [journal-editor-issues.md](records/journal-editor-issues.md) - Journal editor bugs
- [phase-analysis-integration-bugs.md](records/phase-analysis-integration-bugs.md) - Phase analysis integration
- [rivet-deterministic-recompute.md](records/rivet-deterministic-recompute.md) - RIVET computation issues
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration

---

## Recent code changes (reference for bug tracker)

This section is derived from the repo and [CHANGELOG.md](../CHANGELOG.md) to keep the bug tracker aligned with recent fixes. Use it for triage and to add new records when appropriate.

| Fix / change | Version | Bug record | Notes |
|--------------|---------|------------|--------|
| Reflection Session Safety System | v3.3.16 | — | Feature: AURORA-based risk monitoring with rumination/validation-seeking detection and tiered interventions. 6 new files. |
| RevenueCat In-App Purchases | v3.3.16 | — | Feature: In-app subscription via RevenueCat SDK; dual-channel premium (Stripe web + RevenueCat in-app). |
| Voice Sigil state machine upgrade | v3.3.16 | — | Feature: 6-state animation system replacing old glowing indicator; legacy voice journal files deleted. |
| PDF Preview screen | v3.3.16 | — | Feature: In-app PDF viewer for journal media. |
| Google Drive Folder Picker | v3.3.16 | — | Feature: In-app Google Drive folder browser for import/sync. |
| ARCX Clean Service | v3.3.16 | — | Utility: Remove low-content chats from ARCX archives. |
| DurationAdapter (Hive typeId 105) | v3.3.16 | — | Infrastructure: Required for video entries; fixes serialization of Duration fields. |
| CHRONICLE synthesis improvements | v3.3.16 | — | PatternDetector, Monthly/Yearly/MultiYear synthesizers modified for improved theme filtering. |
| iOS folder verification permission error | v3.3.13 | [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) ✅ | Security-scoped resource access on iOS for VerifyBackupScreen |
| Phase Quiz result not persisting; Phase tab mismatch | v3.3.13 | — | Quiz result now persisted via UserPhaseService; Phase tab uses quiz phase when no regimes. See CHANGELOG [3.3.13] "Phase Quiz result matches Phase tab". |
| llama.xcframework build / simulator | recent | — | Link llama static library directly; device build search paths; simulator stubs; exclude xcframework from simulator. Build/config fixes. |
| Import status bar, mini bar, per-file status | v3.3.13 | — | Feature; not a bug. See CHANGELOG. |
| Wispr Flow cache – new API key not used until restart | v3.3.13 | [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) ✅ | WisprConfigService cached key; fix: clearCache() on save in Settings. |
| iOS release build failure (LocalEmbeddingService) | — | [ios-build-local-embedding-service-errors.md](records/ios-build-local-embedding-service-errors.md) | Dart parse/type; then EmbeddingService vs LocalEmbeddingService at call sites (3 files). |
| iOS Swift: NativeEmbeddingChannel not in scope | — | [ios-build-native-embedding-channel-swift-scope.md](records/ios-build-native-embedding-channel-swift-scope.md) | AppDelegate.swift:104; Runner target membership / compile sources. |
| iOS release build third-party warnings | — | [ios-release-build-third-party-warnings.md](records/ios-release-build-third-party-warnings.md) | DKImagePickerController, file_picker, Firebase, RevenueCat deprecations; tech debt. |
| iOS build: rivet_models.g.dart keywords Set type | 2026-02-13 | [ios-build-rivet-models-keywords-set-type.md](records/ios-build-rivet-models-keywords-set-type.md) ✅ | List<String> assigned to Set<String> in generated adapter; fix: .toSet() in read(). |
| Ollama serve address in use; ollama quit unknown | 2026-02-13 | [ollama-serve-address-in-use-and-quit-command.md](records/ollama-serve-address-in-use-and-quit-command.md) | Environment: port 11434 in use; CLI "quit" not recognized. |

| Voice Moonshine spec, transcription cleanup, unified feed | v3.3.31 | — | Feature: VOICE_TRANSCRIPTION_MOONSHINE_SPEC; TranscriptCleanupService; unified feed/HomeView updates. |
| ExpandedEntryView, RelatedEntriesService | v3.3.32 | — | Unified feed expanded entry widget and CHRONICLE related-entries service updates. |
| Master prompt, control state, Narrative Intelligence docs | v3.3.33 | — | lumara_master_prompt.dart and LumaraControlStateBuilder extended; MASTER_PROMPT_CHRONICLE_VECTORIZATION.md, NARRATIVE_INTELLIGENCE_OVERVIEW.md added. |
| LUMARA API, control state, CHRONICLE query stack | v3.3.34 | — | enhanced_lumara_api, lumara_control_state_builder; query_plan, context_builder, query_router; NARRATIVE_INTELLIGENCE_OVERVIEW edit. |
| LUMARA agents, orchestrator, CHRONICLE alignment, settings refactor | v3.3.35 | — | agents/ (research, writing), orchestrator, intent classifier; CHRONICLE index/pattern/router/repos; lumara_settings_screen refactor; CHRONICLE_PAPER_VS_IMPLEMENTATION.md. |
| AppLifecycleState import; FeedRepository types; _buildRunAnalysisCard order | 2026-02-08 | [build-fixes-session-feb-2026.md](records/build-fixes-session-feb-2026.md) ✅ | auto_save_service: add `dart:ui` show AppLifecycleState. feed_repository: createdAt, metadata ?? {}, msg.id. phase_analysis_view: move _buildRunAnalysisCard before _buildArcformContent, remove duplicate. |
| Agents screen, agents_connection_service | v3.3.36 | — | agents_screen.dart extended; new agents_connection_service.dart. |
| Research/writing prompts, timeline context, synthesis/draft | v3.3.37 | — | research_prompts.dart, writing_prompts.dart, timeline_context_service.dart; research_agent, synthesis_engine, draft_composer, writing_agent, writing_models, writing_screen. |
| Writing drafts storage, research persistence, archive/delete, ARCX agents | v3.3.38 | — | WritingDraftRepository (list/archive/delete); ResearchArtifactRepository JSON persist; Agents tab Active/Archived; ARCX export/import extensions/agents. |

**Source:** `git log --oneline`, [CHANGELOG.md](../CHANGELOG.md), terminal build log. Last synced: 2026-02-15.

---

## Archive

Historical bug tracker files are archived in [archive/](archive/):
- Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md)
- Older bug tracker versions

Individual bug records stay in [records/](records/); only the legacy multi-part tracker files are in archive.

---

**Status**: ✅ Active - All resolved issues documented; Build & Platform: 5 records (session consolidation ✅, rivet Set type ✅, embedding Dart chain, NativeEmbeddingChannel Swift, third-party warnings); Environment: 1 (Ollama). Doc sync v3.3.38: bug_tracker tracked.  
**Last Updated**: 2026-02-15
